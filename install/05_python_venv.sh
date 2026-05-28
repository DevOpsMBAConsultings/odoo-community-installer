#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_VERSION:?ODOO_VERSION not set}"

ODOO_USER="odoo"
ODOO_BASE="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_SRC="${ODOO_BASE}/odoo"
VENV_DIR="${ODOO_BASE}/venv"

echo "Setting up Python virtual environment for Odoo ${ODOO_VERSION}..."

# -------------------------------------------------------------------
# Selección de intérprete Python según versión de Odoo
#   Odoo 16 → Python 3.10  (requiere deadsnakes PPA en Ubuntu 24.04)
#   Odoo 17 → Python 3.10  (recomendado; 3.11 también soportado)
#   Odoo 18 → Python 3.12
#   Odoo 19 → Python 3.12
# -------------------------------------------------------------------
case "${ODOO_VERSION}" in
  16|17)
    PYTHON_BIN="python3.10"
    if ! command -v python3.10 &>/dev/null; then
      echo "⚠️  Odoo ${ODOO_VERSION} requiere Python 3.10. Instalando desde deadsnakes PPA..."
      add-apt-repository -y ppa:deadsnakes/ppa
      apt-get update -y
      apt-get install -y python3.10 python3.10-venv python3.10-dev python3.10-distutils
      echo "✅ Python 3.10 instalado."
    else
      echo "✅ Python 3.10 disponible: $(python3.10 --version)"
    fi
    ;;
  18|19)
    PYTHON_BIN="python3.12"
    if ! command -v python3.12 &>/dev/null; then
      echo "⚠️  Python 3.12 no encontrado. Instalando..."
      apt-get install -y python3.12 python3.12-venv python3.12-dev
    else
      echo "✅ Python 3.12 disponible: $(python3.12 --version)"
    fi
    ;;
  *)
    PYTHON_BIN="python3"
    echo "ℹ️  Usando python3 genérico para Odoo ${ODOO_VERSION}: $(python3 --version)"
    ;;
esac

echo "Intérprete seleccionado: ${PYTHON_BIN}"

mkdir -p "${ODOO_BASE}"
chown -R "${ODOO_USER}:${ODOO_USER}" "${ODOO_BASE}"

echo "Creando entorno virtual Python con ${PYTHON_BIN}..."
sudo -u "${ODOO_USER}" "${PYTHON_BIN}" -m venv "${VENV_DIR}"

echo "Actualizando pip, wheel, setuptools..."
sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install --upgrade pip wheel setuptools

if [[ ! -f "${ODOO_SRC}/requirements.txt" ]]; then
  echo "❌ No se encontró requirements.txt en ${ODOO_SRC}"
  exit 1
fi

echo "Instalando dependencias Python de Odoo ${ODOO_VERSION}..."
sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install -r "${ODOO_SRC}/requirements.txt"

echo "Instalando dependencias extras para módulos propios..."
sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install qifparse

echo "✅ Entorno virtual Python listo en: ${VENV_DIR}"