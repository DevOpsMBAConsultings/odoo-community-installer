#!/usr/bin/env bash
# install/09_init_database.sh
set -euo pipefail

# ---------------------------------------------------------------------------
# RUN LOG — every invocation appends to a timestamped log so you can audit
# what worked and what didn't across multiple runs.
# ---------------------------------------------------------------------------
LOG_DIR="/var/log/odoo"
RUN_TS="$(date '+%Y%m%d_%H%M%S')"
RUN_LOG="${LOG_DIR}/init_db_${RUN_TS}.log"

_setup_run_log() {
  sudo mkdir -p "${LOG_DIR}"
  sudo touch "${RUN_LOG}"
  sudo chmod 644 "${RUN_LOG}"
  # Tee all stdout+stderr to the log file for the remainder of this script
  exec > >(sudo tee -a "${RUN_LOG}") 2>&1
  echo "=== init_database run: $(date) ==="
  echo "    ODOO_VERSION=${ODOO_VERSION}  DB_NAME=${DB_NAME:-odoo${ODOO_VERSION}}"
}
_setup_run_log

: "${ODOO_VERSION:?ODOO_VERSION not set}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"
ODOO_USER="odoo"
ODOO_HOME="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_BIN="${ODOO_HOME}/odoo/odoo-bin"
ODOO_PY="${ODOO_HOME}/venv/bin/python3"
ODOO_CONF="/etc/odoo${ODOO_VERSION}.conf"
ODOO_SERVICE="odoo${ODOO_VERSION}"
ODOO_DATA_DIR="/var/lib/odoo"
CUSTOM_ADDONS="/opt/odoo/custom-addons"
SET_COUNTRY_SCRIPT="${SCRIPT_DIR}/scripts/set_default_country.py"
SET_LANGUAGE_SCRIPT="${SCRIPT_DIR}/scripts/set_default_language.py"
SET_TAXES_SCRIPT="${SCRIPT_DIR}/scripts/set_default_taxes_pa.py"
SET_SALES_JOURNAL_SCRIPT="${SCRIPT_DIR}/scripts/set_default_sales_journal.py"
SET_CREDIT_NOTES_JOURNAL_SCRIPT="${SCRIPT_DIR}/scripts/set_default_credit_notes_journal.py"
SET_FISCAL_POSITION_SCRIPT="${SCRIPT_DIR}/scripts/set_fiscal_position_exento.py"
SET_FISCAL_POSITION_RETENCION_SCRIPT="${SCRIPT_DIR}/scripts/set_fiscal_position_retencion.py"
SET_TAX_RETENCION_SCRIPT="${SCRIPT_DIR}/scripts/set_tax_retencion_impuestos.py"
SET_PANAMA_STATES_SCRIPT="${SCRIPT_DIR}/scripts/set_panama_states.py"
SET_ITBMS_TAXES_SCRIPT="${SCRIPT_DIR}/scripts/set_itbms_taxes_pa.py"
SET_PAYMENT_TERMS_SCRIPT="${SCRIPT_DIR}/scripts/set_payment_terms_pa.py"
SET_PARTNER_TAGS_SCRIPT="${SCRIPT_DIR}/scripts/set_partner_tags.py"
SET_CONTACTS_VIEW_SCRIPT="${SCRIPT_DIR}/scripts/set_contacts_default_view_kanban.py"
SET_SALE_UOM_SCRIPT="${SCRIPT_DIR}/scripts/set_sale_uom_packaging.py"
SET_PRODUCTS_SCRIPT="${SCRIPT_DIR}/scripts/set_default_products_pa.py"
SET_PAPERFORMAT_SCRIPT="${SCRIPT_DIR}/scripts/set_default_paperformat.py"

# Defaults (es_PA = Spanish Panama; override with ODOO_LANG=es_ES etc. if needed)
LANG_CODE="${ODOO_LANG:-es_PA}"
WITHOUT_DEMO="${ODOO_WITHOUT_DEMO:-1}"
# Default country by ISO code (PA = Panama); override with ODOO_COUNTRY_CODE=US etc.
COUNTRY_CODE="${ODOO_COUNTRY_CODE:-PA}"
# Modules to install after base: if ODOO_INIT_MODULES is set, use it; otherwise install ALL add-ons
# present in custom-addons (so first login has everything from assets/oca-zips already installed).
if [[ -n "${ODOO_INIT_MODULES:-}" ]]; then
  INIT_MODULES="${ODOO_INIT_MODULES}"
else
  INIT_MODULES=""
  # Use AUTO_ADDONS if it exists (new method), otherwise fallback to CUSTOM_ADDONS (legacy/manual)
  AUTO_ADDONS="/opt/odoo/auto-addons"
  SCAN_DIR=""
  
  if [[ -d "${AUTO_ADDONS}" ]] && [[ -n "$(ls -A "${AUTO_ADDONS}")" ]]; then
      SCAN_DIR="${AUTO_ADDONS}"
  elif [[ -d "${CUSTOM_ADDONS}" ]]; then
      SCAN_DIR="${CUSTOM_ADDONS}"
  fi

  if [[ -n "${SCAN_DIR}" ]]; then
    for dir in "${SCAN_DIR}"/*/; do
      # In auto-addons, everything is a symlink to a module root, so check for manifest
      # In custom-addons (legacy), we also check for manifest
      [[ -f "${dir}__manifest__.py" ]] || continue
      name="$(basename "$dir")"
      [[ -n "${INIT_MODULES}" ]] && INIT_MODULES="${INIT_MODULES},"
      INIT_MODULES="${INIT_MODULES}${name}"
    done
  fi
  [[ -z "${INIT_MODULES}" ]] && INIT_MODULES="l10n_pa"
fi
# Default Odoo standard modules to install (sale, purchase, crm, stock, contacts, account). Override with ODOO_EXTRA_MODULES or set empty to install none.
ODOO_EXTRA_MODULES="${ODOO_EXTRA_MODULES:-sale,purchase,crm,stock,contacts,account}"
if [[ -n "${ODOO_EXTRA_MODULES}" ]]; then
  INIT_MODULES="${INIT_MODULES},${ODOO_EXTRA_MODULES}"
fi

# Reporting arrays
declare -a R_TASK
declare -a R_STATUS
declare -a R_MSG

record_result() {
  R_TASK+=("$1")
  R_STATUS+=("$2")
  R_MSG+=("$3")
}

# Helper function to run post-install configuration scripts
run_config_script() {
  local script_path="$1"
  local description="$2"
  local require_pa="${3:-0}" # 0=Always run, 1=Run only if COUNTRY_CODE is PA
  local script_name="$(basename "${script_path}")"

  if [[ "${require_pa}" == "1" ]] && [[ "${COUNTRY_CODE}" != "PA" ]]; then
    record_result "$script_name" "SKIPPED" "Country not PA"
    return 0
  fi

  if [[ ! -f "${script_path}" ]]; then
    record_result "$script_name" "MISSING" "File not found"
    return 0
  fi

  echo "${description}"
  local run_path="/tmp/${script_name%.*}_odoo.py"
  sudo cp "${script_path}" "${run_path}"
  sudo chown "${ODOO_USER}:${ODOO_USER}" "${run_path}"

  local log_file="/tmp/odoo_script_${script_name}.log"
  set +e
  sudo -u "${ODOO_USER}" env \
      ODOO_HOME="${ODOO_HOME}" \
      ODOO_CONF="${ODOO_CONF}" \
      DB_NAME="${DB_NAME}" \
      ODOO_COUNTRY_CODE="${COUNTRY_CODE}" \
      ODOO_LANG="${LANG_CODE}" \
      "${ODOO_PY}" "${run_path}" > "$log_file" 2>&1
  local ret=$?
  set -e

  sudo rm -f "${run_path}"

  if [[ $ret -eq 0 ]]; then
    record_result "$script_name" "SUCCESS" ""
    # Show output on success too (already tee'd to terminal via exec above)
  else
    local err_msg=$(grep -v "^$" "$log_file" | tail -n 1 | cut -c1-100)
    record_result "$script_name" "FAILED" "$err_msg"
    echo "⚠️  Failed: $script_name"
    # Append failure details to run log
    echo "--- FAILED: $script_name ---" >> "${RUN_LOG}" 2>/dev/null || true
    cat "$log_file" >> "${RUN_LOG}" 2>/dev/null || true
  fi
  rm -f "$log_file"
}

echo "Initializing database '${DB_NAME}' for Odoo ${ODOO_VERSION}..."
echo "Defaults: LANG=${LANG_CODE}, COUNTRY=${COUNTRY_CODE}, WITHOUT_DEMO=${WITHOUT_DEMO}, INIT_MODULES=${INIT_MODULES}"

# Sanity checks
[[ -f "${ODOO_CONF}" ]] || { echo "Missing ${ODOO_CONF}"; exit 1; }
[[ -x "${ODOO_PY}" ]] || { echo "Missing venv python"; exit 1; }
[[ -x "${ODOO_BIN}" ]] || { echo "Missing odoo-bin"; exit 1; }

# ---------------------------------------------------------------------------
# DEFENSIVE CLEANUP: Stop service and kill any orphaned CLI processes
# targeting this specific database. This releases all PostgreSQL locks
# and prevents the script from hanging during DB checks or installations.
# ---------------------------------------------------------------------------
echo "Stopping Odoo service and cleaning up any active processes for ${DB_NAME}..."
sudo systemctl stop "${ODOO_SERVICE}" > /dev/null 2>&1 || true
sudo pkill -9 -f "odoo-bin.*-d ${DB_NAME}" > /dev/null 2>&1 || true

# Data dir
sudo mkdir -p "${ODOO_DATA_DIR}"
sudo chown -R "${ODOO_USER}:${ODOO_USER}" "${ODOO_DATA_DIR}"
sudo chmod 750 "${ODOO_DATA_DIR}"

# DB exists?
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database '${DB_NAME}' already exists."
else
  sudo -u postgres createdb -O "${ODOO_USER}" "${DB_NAME}"
fi

# Already initialized?
INIT_OK="$(
  sudo -u postgres psql -d "${DB_NAME}" -tAc \
  "SELECT 1 FROM information_schema.tables WHERE table_name='ir_module_module'" \
  2>/dev/null || true
)"

if [[ "${INIT_OK}" == "1" ]]; then
  echo "Database already initialized. Applying default country, installing any missing modules, and (if PA) 0% taxes + journals + fiscal position."

  # Detect version-aware demo flag (same logic as fresh-install path)
  if [[ "${ODOO_VERSION}" == "18" ]]; then
    WITHOUT_DEMO_FLAG="--without-demo"
  else
    WITHOUT_DEMO_FLAG="--without-demo=all"
  fi

  run_config_script "${SET_COUNTRY_SCRIPT}" "Setting default country to ${COUNTRY_CODE}..." 0
  # NOTE: language is set AFTER modules are installed so all translations are already loaded

  # Install any missing modules (standard + custom) so first login has apps already installed
  if [[ -n "${INIT_MODULES}" ]]; then
    echo "Installing any missing modules: ${INIT_MODULES}..."
    echo "This may take several minutes. You can monitor the live log in another terminal with:"
    echo "  tail -f /var/log/odoo/odoo${ODOO_VERSION}.log"
    install_log="/tmp/odoo_install_update.log"
    set +e
    sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
      -c "${ODOO_CONF}" \
      -d "${DB_NAME}" \
      -i "${INIT_MODULES}" \
      --load-language="${LANG_CODE}" \
      ${WITHOUT_DEMO_FLAG} \
      --stop-after-init > "$install_log" 2>&1
    ret=$?
    set -e

    if [[ $ret -eq 0 ]]; then
      record_result "Install Modules (Update)" "SUCCESS" ""
    else
      err=$(grep -i "error" "$install_log" | tail -n 1 | cut -c1-100)
      record_result "Install Modules (Update)" "FAILED" "$err"
      echo "⚠️  Module update failed. Continuing..."
    fi
    cat "$install_log" >> "${RUN_LOG}" 2>/dev/null || true
    rm -f "$install_log"
  fi

  # Set language AFTER modules are installed (all translations from l10n_pa, etc. are now loaded)
  run_config_script "${SET_LANGUAGE_SCRIPT}" "Setting default language to ${LANG_CODE}..." 0

  # Run all post-install configuration scripts
  run_config_script "${SET_TAXES_SCRIPT}" "Setting 0% taxes for Panama..." 1
  run_config_script "${SET_ITBMS_TAXES_SCRIPT}" "Setting ITBMS 10% and 15% taxes for Panama..." 1
  run_config_script "${SET_SALES_JOURNAL_SCRIPT}" "Setting default sales journal (Facturación electrónica)..." 1
  run_config_script "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "Setting default credit notes journal (Notas de Crédito)..." 1
  run_config_script "${SET_FISCAL_POSITION_SCRIPT}" "Setting fiscal position Exento de impuestos (Detectar de forma automática)..." 1
  run_config_script "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "Setting fiscal position Retención de impuestos..." 1
  run_config_script "${SET_TAX_RETENCION_SCRIPT}" "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..." 1
  run_config_script "${SET_PANAMA_STATES_SCRIPT}" "Loading Panama provinces/comarcas (PA-01 .. PA-13)..." 1
  run_config_script "${SET_PAYMENT_TERMS_SCRIPT}" "Setting default payment terms (Efectivo, Crédito, etc.)..." 1
  
  run_config_script "${SET_PARTNER_TAGS_SCRIPT}" "Creating partner tags (Etiquetas)..." 0
  run_config_script "${SET_CONTACTS_VIEW_SCRIPT}" "Setting Contacts default view to Kanban..." 0
  run_config_script "${SET_SALE_UOM_SCRIPT}" "Enabling Units of measure and packaging in Sales..." 0
  run_config_script "${SET_PRODUCTS_SCRIPT}" "Creating default service products (0% tax)..." 1
  run_config_script "${SET_PAPERFORMAT_SCRIPT}" "Configuring default paper format (US Letter, 5mm margins)..." 0

  echo ""
  echo "=== INSTALLATION SUMMARY ==="
  printf "%-45s | %-10s | %s\n" "Task" "Status" "Details"
  echo "-------------------------------------------------------------------------------------------"
  for i in "${!R_TASK[@]}"; do
    printf "%-45s | %-10s | %s\n" "${R_TASK[$i]}" "${R_STATUS[$i]}" "${R_MSG[$i]}"
  done
  echo "============================"
  echo ""
  echo "📋 Full run log saved to: ${RUN_LOG}"

  sudo systemctl start "${ODOO_SERVICE}" 2>/dev/null || true
  exit 0
fi

# ---------------------------------------------------------------------------
# ODOO 18 vs 19+ flag differences:
#   --without-demo   : Odoo 17/18 uses bare flag (no value)
#   --without-demo=all : Odoo 19+ also accepts this form but 18 rejects it
# We detect which form to use based on ODOO_VERSION.
# ---------------------------------------------------------------------------
if [[ "${ODOO_VERSION}" == "18" ]]; then
  WITHOUT_DEMO_FLAG="--without-demo"
else
  WITHOUT_DEMO_FLAG="--without-demo=all"
fi

# INIT BASE — installs base + loads language pack into res.lang
base_log="/tmp/odoo_base_install.log"
echo "[Init Base DB] Running: ${WITHOUT_DEMO_FLAG} --load-language=${LANG_CODE}"
echo "This may take a minute. You can monitor the live log in another terminal with:"
echo "  tail -f /var/log/odoo/odoo${ODOO_VERSION}.log"
set +e
sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
  -c "${ODOO_CONF}" \
  -d "${DB_NAME}" \
  -i base \
  ${WITHOUT_DEMO_FLAG} \
  --load-language="${LANG_CODE}" \
  --stop-after-init > "$base_log" 2>&1
ret=$?
set -e

if [[ $ret -eq 0 ]]; then
  record_result "Init Base DB" "SUCCESS" ""
else
  err=$(grep -i "error" "$base_log" | tail -n 1 | cut -c1-100)
  record_result "Init Base DB" "FAILED" "$err"
  echo "⚠️  Base install failed. Continuing..."
fi
cat "$base_log" >> "${RUN_LOG}" 2>/dev/null || true
rm -f "$base_log"

# Set default country for all companies (by ISO code, e.g. PA = Panama)
run_config_script "${SET_COUNTRY_SCRIPT}" "Setting default country to ${COUNTRY_CODE}..." 0
# NOTE: set_default_language runs AFTER module install so all translations are loaded first

# Install extra modules (e.g. l10n_pa, sale, purchase, custom add-ons)
# IMPORTANT: --load-language is repeated here so that any new translation strings
# introduced by l10n_pa and other localisation modules are also loaded into res.lang.
# Without this, Odoo 18 installs the modules but leaves the UI in English.
if [[ -n "${INIT_MODULES}" ]]; then
  echo "Installing modules: ${INIT_MODULES}..."
  echo "(RST/docstring warnings during load are usually harmless.)"
  echo "This will take 3-5 minutes. You can monitor the live log in another terminal with:"
  echo "  tail -f /var/log/odoo/odoo${ODOO_VERSION}.log"
  mod_log="/tmp/odoo_mod_install.log"
  set +e
  sudo -u "${ODOO_USER}" "${ODOO_PY}" "${ODOO_BIN}" \
    -c "${ODOO_CONF}" \
    -d "${DB_NAME}" \
    -i "${INIT_MODULES}" \
    --load-language="${LANG_CODE}" \
    ${WITHOUT_DEMO_FLAG} \
    --stop-after-init > "$mod_log" 2>&1
  ret=$?
  set -e

  if [[ $ret -eq 0 ]]; then
    record_result "Install Extra Modules" "SUCCESS" ""
  else
    err=$(grep -i "error" "$mod_log" | tail -n 1 | cut -c1-100)
    record_result "Install Extra Modules" "FAILED" "$err"
    echo "⚠️  Module install failed. Continuing..."
  fi
  cat "$mod_log" >> "${RUN_LOG}" 2>/dev/null || true
  rm -f "$mod_log"
fi

# Set default language AFTER modules are installed (so all translations from l10n_pa, etc. are loaded)
run_config_script "${SET_LANGUAGE_SCRIPT}" "Setting default language to ${LANG_CODE} (all users)..." 0

# Run all post-install configuration scripts
run_config_script "${SET_TAXES_SCRIPT}" "Setting 0% taxes for Panama..." 1
run_config_script "${SET_ITBMS_TAXES_SCRIPT}" "Setting ITBMS 10% and 15% taxes for Panama..." 1
run_config_script "${SET_SALES_JOURNAL_SCRIPT}" "Setting default sales journal (Facturación electrónica)..." 1
run_config_script "${SET_CREDIT_NOTES_JOURNAL_SCRIPT}" "Setting default credit notes journal (Notas de Crédito)..." 1
run_config_script "${SET_FISCAL_POSITION_SCRIPT}" "Setting fiscal position Exento de impuestos (Detectar de forma automática)..." 1
run_config_script "${SET_FISCAL_POSITION_RETENCION_SCRIPT}" "Setting fiscal position Retención de impuestos..." 1
run_config_script "${SET_TAX_RETENCION_SCRIPT}" "Setting tax Retención de Impuestos (group 7%) and fiscal position mapping..." 1
run_config_script "${SET_PANAMA_STATES_SCRIPT}" "Loading Panama provinces/comarcas (PA-01 .. PA-13)..." 1
run_config_script "${SET_PAYMENT_TERMS_SCRIPT}" "Setting default payment terms (Efectivo, Crédito, etc.)..." 1

run_config_script "${SET_PARTNER_TAGS_SCRIPT}" "Creating partner tags (Etiquetas)..." 0
run_config_script "${SET_CONTACTS_VIEW_SCRIPT}" "Setting Contacts default view to Kanban..." 0
run_config_script "${SET_SALE_UOM_SCRIPT}" "Enabling Units of measure and packaging in Sales..." 0
run_config_script "${SET_PRODUCTS_SCRIPT}" "Creating default service products (0% tax)..." 1
run_config_script "${SET_PAPERFORMAT_SCRIPT}" "Configuring default paper format (US Letter, 5mm margins)..." 0

echo ""
echo "=== INSTALLATION SUMMARY ==="
printf "%-45s | %-10s | %s\n" "Task" "Status" "Details"
echo "-------------------------------------------------------------------------------------------"
for i in "${!R_TASK[@]}"; do
  printf "%-45s | %-10s | %s\n" "${R_TASK[$i]}" "${R_STATUS[$i]}" "${R_MSG[$i]}"
done
echo "============================"
echo ""
echo "📋 Full run log saved to: ${RUN_LOG}"

# Start service
sudo systemctl start "${ODOO_SERVICE}"

echo "✅ Database '${DB_NAME}' initialized successfully."
echo "📋 Full run log saved to: ${RUN_LOG}"
