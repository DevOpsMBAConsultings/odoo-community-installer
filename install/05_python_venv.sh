#!/usr/bin/env bash
set -euo pipefail

: "${ODOO_VERSION:?ODOO_VERSION not set}"

ODOO_USER="odoo"
ODOO_BASE="/opt/odoo/odoo${ODOO_VERSION}"
ODOO_SRC="${ODOO_BASE}/odoo"
VENV_DIR="${ODOO_BASE}/venv"

echo "Setting up Python virtual environment for Odoo ${ODOO_VERSION}..."

# -------------------------------------------------------------------
# Función auxiliar: compilar Python 3.10 desde fuente
# Se usa como fallback cuando el PPA deadsnakes no tiene binarios
# para la arquitectura actual (ej: arm64 en Ubuntu 24.04).
# -------------------------------------------------------------------
_install_python310_from_source() {
  local PY_VERSION="3.10.14"
  local PY_SRC="/tmp/Python-${PY_VERSION}"
  local PY_TARBALL="/tmp/Python-${PY_VERSION}.tgz"

  echo "  → Instalando dependencias de compilación..."
  apt-get install -y \
    build-essential libssl-dev zlib1g-dev \
    libncurses5-dev libncursesw5-dev libreadline-dev \
    libsqlite3-dev libgdbm-dev libdb5.3-dev libbz2-dev \
    libexpat1-dev liblzma-dev libffi-dev uuid-dev

  echo "  → Descargando Python ${PY_VERSION}..."
  curl -fsSL "https://www.python.org/ftp/python/${PY_VERSION}/Python-${PY_VERSION}.tgz" \
    -o "${PY_TARBALL}"

  echo "  → Extrayendo y compilando (esto puede tardar varios minutos)..."
  tar -xf "${PY_TARBALL}" -C /tmp
  cd "${PY_SRC}"
  ./configure --enable-optimizations --with-ensurepip=install \
    --prefix=/usr/local --enable-shared \
    LDFLAGS="-Wl,-rpath /usr/local/lib" \
    2>&1 | tail -5
  make -j"$(nproc)" 2>&1 | tail -5
  make altinstall 2>&1 | tail -5

  # make altinstall ya coloca el binario en /usr/local/bin/python3.10
  echo "  → Verificando: $(/usr/local/bin/python3.10 --version)"

  # Instalar venv y setuptools
  python3.10 -m ensurepip --upgrade
  python3.10 -m pip install --upgrade pip setuptools wheel

  # Limpiar
  rm -rf "${PY_SRC}" "${PY_TARBALL}"
  echo "✅ Python 3.10 compilado e instalado desde fuente."
}


case "${ODOO_VERSION}" in
  16|17)
    PYTHON_BIN="python3.10"
    if ! command -v python3.10 &>/dev/null; then
      echo "⚠️  Odoo ${ODOO_VERSION} requiere Python 3.10. Intentando instalar desde deadsnakes PPA..."

      # Asegurarse de que software-properties-common está instalado
      if ! command -v add-apt-repository &>/dev/null; then
        echo "  → Instalando software-properties-common..."
        apt-get install -y software-properties-common
      fi

      # Intentar añadir el PPA
      add-apt-repository -y ppa:deadsnakes/ppa
      apt-get update -y

      # Comprobar si el PPA ofrece python3.10 para esta arquitectura
      ARCH=$(dpkg --print-architecture)
      if apt-cache show python3.10 &>/dev/null; then
        apt-get install -y python3.10 python3.10-venv python3.10-dev
        # python3.10-distutils puede no existir en Ubuntu 24.04; ignorar si falla
        apt-get install -y python3.10-distutils 2>/dev/null || true
        echo "✅ Python 3.10 instalado desde PPA."
      else
        echo "⚠️  PPA no tiene python3.10 para la arquitectura ${ARCH}. Compilando Python 3.10 desde fuente..."
        _install_python310_from_source
      fi
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

# ------------------------------------------------------------------
# Odoo 16: gevent==21.8.0 falla al compilar con Cython>=3.x porque
# el tipo 'long' fue eliminado. Solución: fijar Cython<3 y pre-instalar
# una versión de gevent compatible antes de leer requirements.txt.
# Esto no afecta a Odoo 18/19, que usan gevent>=22 ya compatible.
# ------------------------------------------------------------------
if [[ "${ODOO_VERSION}" == "16" ]]; then
  echo "  ⚙️  Odoo 16: aplicando workaround para gevent (Cython<3)..."
  sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install "Cython<3" setuptools
  sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install \
    --no-build-isolation \
    "gevent==21.8.0"
  echo "  ✅ gevent instalado correctamente con Cython<3"
fi

sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install -r "${ODOO_SRC}/requirements.txt"

echo "Instalando dependencias extras para módulos propios..."
sudo -u "${ODOO_USER}" "${VENV_DIR}/bin/pip" install qifparse

echo "✅ Entorno virtual Python listo en: ${VENV_DIR}"