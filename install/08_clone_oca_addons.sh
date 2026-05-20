#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# 08_clone_oca_addons.sh — Clone OCA repositories into /opt/odoo/oca/
# ---------------------------------------------------------------------------
# This script is separate from 08_clone_custom_addons.sh.
# - OCA (official) repos → /opt/odoo/oca/<repo-name>/        (this script)
# - Custom/private repos → /opt/odoo/custom-addons/<name>/   (08_clone_custom_addons.sh)
#
# Invoked by install.sh only when the user opts to install OCA modules.
# Reads OCA_REPOS_LIST (newline-separated URLs) exported by install.sh.
# ---------------------------------------------------------------------------

ODOO_VERSION="${ODOO_VERSION:-18}"
OCA_BASE_DIR="/opt/odoo/oca"
ODOO_USER="odoo"

# Branch to clone — OCA uses X.0 format (e.g. 18.0, 19.0)
if [[ "${ODOO_VERSION}" =~ ^[0-9]+$ ]]; then
  TARGET_BRANCH="${ODOO_VERSION}.0"
else
  TARGET_BRANCH="${ODOO_VERSION}"
fi

echo ""
echo ">>> Cloning OCA repositories for Odoo ${ODOO_VERSION} (branch ${TARGET_BRANCH})"
echo "    Target directory: ${OCA_BASE_DIR}"

# Ensure git is installed
if ! command -v git > /dev/null 2>&1; then
  echo "🔧 git not found — installing..."
  apt-get update -y
  apt-get install -y git
fi

# Create OCA base dir if missing (step 03 should have done this already)
mkdir -p "${OCA_BASE_DIR}"

# OCA_REPOS_LIST is a newline-separated list of https:// URLs exported by install.sh
# If not set or empty, nothing to do.
if [[ -z "${OCA_REPOS_LIST:-}" ]]; then
  echo "⚠️  OCA_REPOS_LIST is empty — no OCA repos to clone. Skipping."
  exit 0
fi

VENV_PIP="/opt/odoo/odoo${ODOO_VERSION}/venv/bin/pip"

cloned_count=0
skipped_count=0

while IFS= read -r repo_url; do
  # Skip blank lines
  [[ -z "${repo_url}" ]] && continue

  repo_name="$(basename "${repo_url}" .git)"
  clone_path="${OCA_BASE_DIR}/${repo_name}"

  echo ""
  echo "  ➡️  ${repo_name}"
  echo "      URL: ${repo_url}"
  echo "      Path: ${clone_path}"

  if [[ -d "${clone_path}/.git" ]]; then
    echo "      ✅ Already cloned — skipping."
    skipped_count=$((skipped_count + 1))
    continue
  fi

  # Try the versioned branch first; fall back to default branch
  if git clone --depth 1 --branch "${TARGET_BRANCH}" "${repo_url}" "${clone_path}" 2>/dev/null; then
    echo "      ✅ Cloned (branch ${TARGET_BRANCH})"
    cloned_count=$((cloned_count + 1))
  else
    echo "      ⚠️  Branch '${TARGET_BRANCH}' not found — trying default branch..."
    if git clone --depth 1 "${repo_url}" "${clone_path}" 2>/dev/null; then
      echo "      ✅ Cloned (default branch)"
      cloned_count=$((cloned_count + 1))
    else
      echo "      ❌ Failed to clone ${repo_name}. Skipping."
      continue
    fi
  fi

  # Install Python dependencies if present
  if [[ -f "${clone_path}/requirements.txt" ]]; then
    echo "      📦 Installing Python deps from requirements.txt..."
    if [[ -x "${VENV_PIP}" ]]; then
      "${VENV_PIP}" install -r "${clone_path}/requirements.txt" \
        || echo "      ⚠️  Warning: some pip packages failed for ${repo_name}"
    else
      echo "      ⚠️  Venv pip not found at ${VENV_PIP} — skipping pip install for ${repo_name}"
    fi
  fi

done <<< "${OCA_REPOS_LIST}"

echo ""
echo "🔐 Setting ownership on ${OCA_BASE_DIR}..."
chown -R "${ODOO_USER}:${ODOO_USER}" "${OCA_BASE_DIR}"
chmod -R 755 "${OCA_BASE_DIR}"

echo ""
echo "============================================================"
echo " OCA Clone Summary"
echo "============================================================"
echo "   Cloned:  ${cloned_count} repos"
echo "   Skipped: ${skipped_count} repos (already present)"
echo "   Location: ${OCA_BASE_DIR}/"
echo ""
echo "⚠️  NOTE: The odoo.conf addons_path was already updated"
echo "   by 07_odoo_config.sh using the OCA_ADDON_PATHS variable."
echo "   Verify with: grep addons_path /etc/odoo${ODOO_VERSION}.conf"
echo "============================================================"
