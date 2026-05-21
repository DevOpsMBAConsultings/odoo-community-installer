#!/usr/bin/env bash
set -euo pipefail

echo "Installing and configuring Nginx + SSL..."

# ------------------------------------------------------------
# Paths
# ------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

NGINX_TEMPLATE="${REPO_ROOT}/templates/nginx-odoo.conf.template"
NGINX_SSL_TEMPLATE="${REPO_ROOT}/templates/nginx-odoo-ssl.conf.template"
NGINX_SITE="/etc/nginx/sites-available/${DOMAIN}"
NGINX_ENABLED="/etc/nginx/sites-enabled/${DOMAIN}"

# SSL store (local path). Remote storage is configured below (s3 or url).
SSL_STORE="${ODOO_SSL_STORE:-/opt/odoo/ssl-store}"
CERT_DIR="${SSL_STORE}/${DOMAIN}"
FULLCHAIN="${CERT_DIR}/fullchain.pem"
PRIVKEY="${CERT_DIR}/privkey.pem"

# Remote storage: one place to restore from and backup to (for reprovisioned servers).
# - ODOO_SSL_STORAGE=s3  → use S3-compatible storage (AWS, Oracle OCI, MinIO). Restore from bucket, backup to same.
# - ODOO_SSL_STORAGE=url → restore from ODOO_SSL_RESTORE_URL; backup via ODOO_SSL_BACKUP_URL (PUT) or ODOO_SSL_BACKUP_CMD.
# - unset → only local store; optional ODOO_SSL_RESTORE_URL and ODOO_SSL_BACKUP_CMD as before.
SSL_STORAGE_TYPE="${ODOO_SSL_STORAGE:-}"
SSL_RESTORE_URL="${ODOO_SSL_RESTORE_URL:-}"
SSL_BACKUP_URL="${ODOO_SSL_BACKUP_URL:-}"
SSL_BACKUP_TOKEN="${ODOO_SSL_BACKUP_TOKEN:-}"
S3_BUCKET="${ODOO_SSL_S3_BUCKET:-}"
S3_PREFIX="${ODOO_SSL_S3_PREFIX:-odoo-ssl}"
S3_ENDPOINT="${ODOO_SSL_S3_ENDPOINT_URL:-${AWS_ENDPOINT_URL:-}}"

# ------------------------------------------------------------
# Required env vars
# ------------------------------------------------------------
if [[ -z "${DOMAIN:-}" ]]; then
  echo "ERROR: DOMAIN is missing."
  exit 1
fi

if [[ -z "${LETSENCRYPT_EMAIL:-}" ]]; then
  echo "ERROR: LETSENCRYPT_EMAIL is missing."
  exit 1
fi

if [[ ! -f "${NGINX_TEMPLATE}" ]]; then
  echo "ERROR: Missing template: ${NGINX_TEMPLATE}"
  exit 1
fi

# ------------------------------------------------------------
# Install packages
# ------------------------------------------------------------
apt-get update -y
apt-get install -y nginx certbot python3-certbot-nginx
# AWS CLI for S3/R2 (Ubuntu 24.04 has no awscli in apt; use official installer as fallback)
if [[ "${SSL_STORAGE_TYPE}" == "s3" ]]; then
  if ! command -v aws >/dev/null 2>&1; then
    apt-get install -y awscli 2>/dev/null || true
  fi
  if ! command -v aws >/dev/null 2>&1; then
    echo "Installing AWS CLI v2 for S3/R2..."
    apt-get install -y curl unzip
    # Detect CPU architecture — Oracle Cloud ARM64 needs aarch64 build
    ARCH="$(uname -m)"
    case "${ARCH}" in
      aarch64|arm64) AWS_ARCH="aarch64" ;;
      x86_64|amd64)  AWS_ARCH="x86_64"  ;;
      *)             AWS_ARCH="x86_64"  ;;  # best-effort fallback
    esac
    AWS_ZIP_URL="https://awscli.amazonaws.com/awscli-exe-linux-${AWS_ARCH}.zip"
    echo "  Arch detected: ${ARCH} → downloading ${AWS_ZIP_URL}"
    TMP_AWS="/tmp/awscliv2"
    curl -fsSL "${AWS_ZIP_URL}" -o "${TMP_AWS}.zip"
    unzip -o -q "${TMP_AWS}.zip" -d /tmp
    /tmp/aws/install -i /usr/local/aws-cli -b /usr/local/bin
    rm -rf "${TMP_AWS}.zip" /tmp/aws
  fi
  # Sanity-check: verify the installed binary actually runs on this arch
  if ! aws --version >/dev/null 2>&1; then
    echo "⚠️  AWS CLI installed but cannot execute (possible arch mismatch). S3 backup will be skipped."
  fi
fi


# ------------------------------------------------------------
# Restore from predefined remote storage (so new servers get cert without Certbot)
# ------------------------------------------------------------

# --- S3 (and S3-compatible: AWS, Oracle OCI, MinIO) ---
if [[ "${SSL_STORAGE_TYPE}" == "s3" && -n "${S3_BUCKET}" ]]; then
  if [[ ! -f "${FULLCHAIN}" || ! -f "${PRIVKEY}" ]]; then
    S3_URI="s3://${S3_BUCKET}/${S3_PREFIX}/${DOMAIN}/cert.tar.gz"
    echo "Trying to restore SSL certificate from ${S3_URI}..."
    mkdir -p "${CERT_DIR}"
    AWS_OPTS=()
    [[ -n "${S3_ENDPOINT}" ]] && AWS_OPTS+=(--endpoint-url "${S3_ENDPOINT}")
    if aws s3 cp "${S3_URI}" - "${AWS_OPTS[@]}" 2>/dev/null | tar -xzf - -C "${CERT_DIR}" 2>/dev/null; then
      if [[ -f "${FULLCHAIN}" && -f "${PRIVKEY}" ]]; then
        chmod 644 "${FULLCHAIN}"
        chmod 600 "${PRIVKEY}"
        echo "Restored certificate from S3 into ${CERT_DIR}"
      else
        rm -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" 2>/dev/null || true
      fi
    else
      echo "No certificate found in S3 (or download failed); will use Certbot if needed."
    fi
  fi
fi

# --- URL (ODOO_SSL_RESTORE_URL or when storage=url) ---
if [[ -n "${SSL_RESTORE_URL}" ]]; then
  if [[ ! -f "${FULLCHAIN}" || ! -f "${PRIVKEY}" ]]; then
    echo "Restoring SSL certificate from ${SSL_RESTORE_URL}..."
    mkdir -p "${CERT_DIR}"
    if curl -fsSL --connect-timeout 30 "${SSL_RESTORE_URL}" | tar -xzf - -C "${CERT_DIR}" 2>/dev/null; then
      if [[ -f "${FULLCHAIN}" && -f "${PRIVKEY}" ]]; then
        chmod 644 "${FULLCHAIN}"
        chmod 600 "${PRIVKEY}"
        echo "Restored certificate into ${CERT_DIR}"
      else
        echo "⚠️ Archive did not contain fullchain.pem/privkey.pem at top level; ignoring."
        rm -f "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" 2>/dev/null || true
      fi
    else
      echo "⚠️ Failed to download or extract from ODOO_SSL_RESTORE_URL; will try Certbot if needed."
    fi
  fi
fi

# ------------------------------------------------------------
# Decide: use stored cert or request new one
# ------------------------------------------------------------
USE_STORED_CERT=0
if [[ -f "${FULLCHAIN}" && -f "${PRIVKEY}" ]]; then
  if openssl x509 -noout -checkend 86400 -in "${FULLCHAIN}" 2>/dev/null; then
    echo "Using existing SSL certificate from ${CERT_DIR}"
    USE_STORED_CERT=1
  else
    echo "Stored cert expired or invalid; will request new one."
  fi
fi

# ------------------------------------------------------------
# Render Nginx site config
# ------------------------------------------------------------
if [[ "${USE_STORED_CERT}" -eq 1 ]]; then
  [[ -f "${NGINX_SSL_TEMPLATE}" ]] || { echo "ERROR: Missing template: ${NGINX_SSL_TEMPLATE}"; exit 1; }
  sed \
    -e "s|{{DOMAIN}}|${DOMAIN}|g" \
    -e "s|{{ODOO_PORT}}|8069|g" \
    -e "s|{{SSL_CERT_PATH}}|${FULLCHAIN}|g" \
    -e "s|{{SSL_KEY_PATH}}|${PRIVKEY}|g" \
    "${NGINX_SSL_TEMPLATE}" > "${NGINX_SITE}"
else
  sed \
    -e "s|{{DOMAIN}}|${DOMAIN}|g" \
    -e "s|{{ODOO_PORT}}|8069|g" \
    "${NGINX_TEMPLATE}" > "${NGINX_SITE}"
fi

ln -sf "${NGINX_SITE}" "${NGINX_ENABLED}"

# Remove default site to avoid conflicts
rm -f /etc/nginx/sites-enabled/default || true

nginx -t
systemctl enable --now nginx
systemctl reload nginx

# ------------------------------------------------------------
# If we used stored cert, we're done
# ------------------------------------------------------------
if [[ "${USE_STORED_CERT}" -eq 1 ]]; then
  echo "✅ Nginx + SSL (from store) completed for ${DOMAIN}"
  exit 0
fi

# ------------------------------------------------------------
# 🔴 CRITICAL SECTION: firewall + networking stabilization
# ------------------------------------------------------------
echo "Stabilizing firewall / networking before Certbot..."

if ! command -v ufw >/dev/null 2>&1; then
  apt-get install -y ufw
fi

ufw allow 80 || true
ufw allow 443 || true

systemctl stop ufw || true
iptables -F
iptables -X
ip6tables -F || true
ip6tables -X || true
systemctl start ufw || true

sleep 5

# ------------------------------------------------------------
# Request cert with Certbot; on success, save copy to store
# ------------------------------------------------------------
CERTBOT_OK=0
if curl -fsS --connect-timeout 5 "http://${DOMAIN}" >/dev/null; then
  echo "Domain reachable over HTTP. Proceeding with Certbot..."

  if certbot --nginx \
    -d "${DOMAIN}" \
    -m "${LETSENCRYPT_EMAIL}" \
    --agree-tos \
    --non-interactive \
    --redirect; then
    CERTBOT_OK=1
  else
    echo "⚠️ Certbot failed (e.g. rate limit). Nginx remains on HTTP only."
    echo "   You can copy certs to ${CERT_DIR} and re-run this step to use them."
  fi
else
  echo "⚠️ WARNING: ${DOMAIN} not reachable over HTTP. Skipping Certbot."
fi

# ------------------------------------------------------------
# If Certbot succeeded: copy cert to store and switch Nginx to SSL config
# ------------------------------------------------------------
if [[ "${CERTBOT_OK}" -eq 1 ]]; then
  LETSENCRYPT_LIVE="/etc/letsencrypt/live/${DOMAIN}"
  if [[ -d "${LETSENCRYPT_LIVE}" ]]; then
    echo "Saving certificate copy to ${CERT_DIR} for future runs..."
    mkdir -p "${CERT_DIR}"
    cp -p "${LETSENCRYPT_LIVE}/fullchain.pem" "${FULLCHAIN}"
    cp -p "${LETSENCRYPT_LIVE}/privkey.pem" "${PRIVKEY}"
    chmod 644 "${FULLCHAIN}"
    chmod 600 "${PRIVKEY}"
    ODOO_SSL_TARBALL="/tmp/odoo-ssl-${DOMAIN}.tar.gz"
    ( cd "${CERT_DIR}" && tar czf "${ODOO_SSL_TARBALL}" fullchain.pem privkey.pem )
    # Backup to predefined storage (so next server can restore)
    if [[ "${SSL_STORAGE_TYPE}" == "s3" && -n "${S3_BUCKET}" ]]; then
      S3_URI="s3://${S3_BUCKET}/${S3_PREFIX}/${DOMAIN}/cert.tar.gz"
      echo "Uploading certificate to ${S3_URI}..."
      AWS_OPTS=()
      [[ -n "${S3_ENDPOINT}" ]] && AWS_OPTS+=(--endpoint-url "${S3_ENDPOINT}")
      aws s3 cp "${ODOO_SSL_TARBALL}" "${S3_URI}" "${AWS_OPTS[@]}" && echo "Backup to S3 done." || echo "⚠️ S3 upload failed."
    fi
    if [[ -n "${SSL_BACKUP_URL}" ]]; then
      echo "Uploading certificate to backup URL..."
      CURL_OPTS=(-fsSL -X PUT -T "${ODOO_SSL_TARBALL}" "${SSL_BACKUP_URL}")
      [[ -n "${SSL_BACKUP_TOKEN}" ]] && CURL_OPTS+=(-H "Authorization: Bearer ${SSL_BACKUP_TOKEN}")
      curl "${CURL_OPTS[@]}" && echo "Backup to URL done." || echo "⚠️ URL backup failed."
    fi
    if [[ -n "${ODOO_SSL_BACKUP_CMD:-}" ]]; then
      export ODOO_SSL_DOMAIN="${DOMAIN}" ODOO_SSL_CERT_DIR="${CERT_DIR}" ODOO_SSL_TARBALL
      echo "Running ODOO_SSL_BACKUP_CMD..."
      eval "${ODOO_SSL_BACKUP_CMD}" || true
    fi
    rm -f "${ODOO_SSL_TARBALL}"
    # Re-render with store paths so next run uses store
    sed \
      -e "s|{{DOMAIN}}|${DOMAIN}|g" \
      -e "s|{{ODOO_PORT}}|8069|g" \
      -e "s|{{SSL_CERT_PATH}}|${FULLCHAIN}|g" \
      -e "s|{{SSL_KEY_PATH}}|${PRIVKEY}|g" \
      "${NGINX_SSL_TEMPLATE}" > "${NGINX_SITE}"
    nginx -t
    systemctl reload nginx
  fi
fi

systemctl reload nginx

echo "✅ Nginx + SSL step completed for ${DOMAIN}"
