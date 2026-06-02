#!/usr/bin/env bash
# Run set_fiscal_positions_retencion.py: create fiscal positions for retención.
# Run after accounting (and ideally l10n) is installed. From repo root:
#   sudo -E bash install/scripts/run_set_fiscal_positions_retencion.sh
# Optional: ODOO_FISCAL_POSITION_RETENCION_AUTO_APPLY=1 to enable automatic detection.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODOO_VERSION="${ODOO_VERSION:-19}"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
SET_FP_SCRIPT="${SCRIPT_DIR}/set_fiscal_positions_retencion.py"

[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing ${ODOO_PY}"; exit 1; }
[[ -f "${SET_FP_SCRIPT}" ]] || { echo "Missing ${SET_FP_SCRIPT}"; exit 1; }

RUN_SCRIPT="/tmp/set_fiscal_positions_retencion_odoo.py"
sudo cp "${SET_FP_SCRIPT}" "${RUN_SCRIPT}"
sudo chown "${ODOO_USER}:${ODOO_USER}" "${RUN_SCRIPT}"
sudo -u "${ODOO_USER}" env \
  ODOO_HOME="${ODOO_HOME}" \
  ODOO_CONF="${ODOO_CONF}" \
  DB_NAME="${DB_NAME}" \
  "${ODOO_PY}" "${RUN_SCRIPT}"
sudo rm -f "${RUN_SCRIPT}"
echo "Done. Fiscal positions for retención are set."
