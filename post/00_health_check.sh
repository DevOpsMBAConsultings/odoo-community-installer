#!/bin/bash
set -e

# ---------------------------------------------------------------------------
# Version-aware health check. Uses ODOO_VERSION env var (set by install.sh)
# or falls back to auto-detecting from running services.
# ---------------------------------------------------------------------------

# Detect version
if [[ -z "${ODOO_VERSION:-}" ]]; then
  # Try to detect from running systemd services
  for v in 18 19 17 16; do
    if systemctl list-units --type=service --all 2>/dev/null | grep -q "odoo${v}.service"; then
      ODOO_VERSION="$v"
      break
    fi
  done
fi
ODOO_VERSION="${ODOO_VERSION:-18}"

CONF="/etc/odoo${ODOO_VERSION}.conf"
SERVICE="odoo${ODOO_VERSION}"
PORT="8069"
CUSTOM_ADDONS="/opt/odoo/custom-addons"
OCA_DIR="/opt/odoo/oca"
VENV_BASE="/opt/odoo/odoo${ODOO_VERSION}/venv"

# Try to detect Odoo venv python from config, fallback to known path
VENV_PY="$(grep -E '^\s*python3\s*=' "$CONF" 2>/dev/null | cut -d'=' -f2 | xargs || true)"
if [ -z "$VENV_PY" ]; then
  VENV_PY="${VENV_BASE}/bin/python3"
fi

echo "==================================="
echo " ✅ Post-Install Health Check (Odoo ${ODOO_VERSION})"
echo " Time: $(date)"
echo "==================================="

echo ""
echo "1) Odoo service status:"
if systemctl is-active --quiet "$SERVICE"; then
  echo "✅ $SERVICE is running"
else
  echo "❌ $SERVICE is NOT running"
  echo "   Check: sudo journalctl -u $SERVICE -n 200 --no-pager"
fi

echo ""
echo "2) wkhtmltopdf version:"
if command -v wkhtmltopdf >/dev/null 2>&1; then
  wkhtmltopdf --version || true
else
  echo "❌ wkhtmltopdf not found"
fi

echo ""
echo "3) Listening ports (local):"
if ss -lntp 2>/dev/null | grep -Eq ":(${PORT})\s"; then
  echo "✅ Port $PORT is LISTENING locally"
  ss -lntp 2>/dev/null | grep "$PORT" || true
else
  echo "⚠️ Port $PORT is NOT listening locally"
  echo "   Tip: check bind in $CONF and logs: sudo journalctl -u $SERVICE -n 200 --no-pager"
fi

echo ""
echo "4) UFW status and port $PORT rule:"
if command -v ufw >/dev/null 2>&1; then
  ufw status | head -n 25
  if ufw status | grep -q "${PORT}/tcp"; then
    echo "✅ UFW rule found for ${PORT}/tcp"
  else
    echo "⚠️ No UFW rule for ${PORT}/tcp (may be intentional if Nginx is proxying)"
  fi
else
  echo "⚠️ ufw not installed"
fi

echo ""
echo "5) addons_path check:"
if [ -f "$CONF" ]; then
  ADDONS_LINE=$(grep -E "^addons_path" "$CONF" || true)
  echo "$ADDONS_LINE"
  if echo "$ADDONS_LINE" | grep -q "$CUSTOM_ADDONS"; then
    echo "✅ custom-addons is included in addons_path"
  else
    echo "❌ custom-addons is NOT in addons_path"
  fi
  if [ -d "$OCA_DIR" ] && [ -n "$(ls -A "$OCA_DIR" 2>/dev/null)" ]; then
    if echo "$ADDONS_LINE" | grep -q "$OCA_DIR"; then
      echo "✅ OCA dir is included in addons_path"
    else
      echo "⚠️ OCA dir exists but may not be in addons_path — run: grep addons_path $CONF"
    fi
  fi
else
  echo "❌ Config not found: $CONF"
fi

echo ""
echo "6) Addon directories status:"
for dir in "$CUSTOM_ADDONS" "$OCA_DIR"; do
  if [ -d "$dir" ]; then
    COUNT=$(find "$dir" -maxdepth 3 -name "__manifest__.py" 2>/dev/null | wc -l)
    echo "✅ $dir — ${COUNT} module(s) found"
  else
    echo "⚠️ $dir — directory not present (may be empty install)"
  fi
done

# Check addons_path entries are all real directories (no phantom paths)
echo ""
echo "7) addons_path directory existence check:"
if [ -f "$CONF" ]; then
  ADDONS_LINE=$(grep -E "^addons_path\s*=" "$CONF" | sed 's/addons_path\s*=\s*//' || true)
  if [ -n "$ADDONS_LINE" ]; then
    IFS=',' read -ra PATHS <<< "$ADDONS_LINE"
    ALL_OK=true
    for p in "${PATHS[@]}"; do
      p="$(echo "$p" | xargs)"  # trim whitespace
      if [ -d "$p" ]; then
        echo "  ✅ $p"
      else
        echo "  ❌ MISSING: $p"
        ALL_OK=false
      fi
    done
    if $ALL_OK; then
      echo "✅ All addons_path directories exist"
    else
      echo "❌ Some addons_path directories are missing — Odoo may fail to start"
    fi
  fi
fi

echo ""
echo "8) Odoo Master Password (admin_passwd):"
if [ -f "$CONF" ]; then
  ADMIN_PASSWD=$(grep -E "^\s*admin_passwd\s*=" "$CONF" | cut -d'=' -f2 | xargs || true)
  if [ -n "$ADMIN_PASSWD" ]; then
    echo "✅ Master password found:"
    echo "   admin_passwd = $ADMIN_PASSWD"
    echo "   (Stored in $CONF)"
  else
    echo "⚠️ admin_passwd not set in $CONF"
  fi
else
  echo "❌ Config not found: $CONF"
fi

echo ""
echo "9) Python venv and key dependencies:"
echo "   Using Python: $VENV_PY"
if [ -x "$VENV_PY" ]; then
  echo "   ✅ Python venv found"
  # Check Odoo itself is importable
  if PYTHONPATH="/opt/odoo/odoo${ODOO_VERSION}" "$VENV_PY" -c "import odoo" >/dev/null 2>&1; then
    echo "   ✅ odoo package importable"
  else
    echo "   ❌ odoo package NOT importable — venv may be incomplete"
  fi
  # Check wand (for sale_product_image)
  if "$VENV_PY" -c "import wand" >/dev/null 2>&1; then
    echo "   ✅ wand is installed"
  else
    echo "   ⚠️ wand not installed (needed by sale_product_image)"
    echo "      Fix: sudo ${VENV_BASE}/bin/pip install wand"
  fi
  # Check reportlab (for PDF reports)
  if "$VENV_PY" -c "import reportlab" >/dev/null 2>&1; then
    echo "   ✅ reportlab is installed"
  else
    echo "   ⚠️ reportlab not installed"
  fi
else
  echo "   ❌ Odoo venv python not found/executable at: $VENV_PY"
  echo "      Check your python path or re-run step 05_python_venv.sh"
fi

echo ""
echo "==================================="
echo " ✅ Health check finished"
echo "==================================="
