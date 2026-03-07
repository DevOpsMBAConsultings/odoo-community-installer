# install/02_wkhtmltopdf.sh
#!/usr/bin/env bash
set -euo pipefail

echo "Installing wkhtmltopdf (patched Qt) for Odoo..."

ARCH="$(dpkg --print-architecture)"
if [[ "${ARCH}" == "amd64" ]]; then
  DEB="wkhtmltox_0.12.6.1-3.jammy_amd64.deb"
elif [[ "${ARCH}" == "arm64" ]]; then
  DEB="wkhtmltox_0.12.6.1-3.jammy_arm64.deb"
else
  echo "ERROR: Patched wkhtmltopdf package is only supported on amd64 and arm64 architectures. Detected: ${ARCH}"
  exit 1
fi

TMP_DIR="/tmp/wkhtmltopdf"
URL="https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/${DEB}"

sudo rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
cd "${TMP_DIR}"

echo "Downloading: ${URL}"
curl -fL --retry 5 --retry-delay 2 -o "${DEB}" "${URL}"

# Sanity check size
SIZE_BYTES="$(stat -c%s "${DEB}")"
if (( SIZE_BYTES < 1000000 )); then
  echo "ERROR: Downloaded file is too small (${SIZE_BYTES} bytes). Not a valid .deb."
  echo "First 200 bytes:"
  head -c 200 "${DEB}" || true
  exit 1
fi

# Sanity check the deb structure
if ! dpkg-deb -I "${DEB}" >/dev/null 2>&1; then
  echo "ERROR: Downloaded file is not a valid Debian package."
  exit 1
fi

echo "Installing dependencies..."
sudo apt-get update -y
sudo apt-get install -y xfonts-75dpi xfonts-base fontconfig

echo "Installing wkhtmltopdf package..."
# 1) Try dpkg
if ! sudo dpkg -i "${DEB}"; then
  echo "dpkg reported dependency issues; fixing with apt-get -f install..."
  sudo apt-get install -f -y
  # 2) Re-try dpkg to ensure package is actually configured
  sudo dpkg -i "${DEB}"
fi

echo "Verifying..."
command -v wkhtmltopdf >/dev/null 2>&1 || { echo "ERROR: wkhtmltopdf not found after install."; exit 1; }

wkhtmltopdf --version

if ! wkhtmltopdf --version 2>/dev/null | grep -qi "patched qt"; then
  echo "ERROR: wkhtmltopdf installed but NOT showing patched Qt."
  exit 1
fi

echo "✅ wkhtmltopdf installed (patched Qt)."
