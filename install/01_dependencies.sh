#!/bin/bash
set -e

echo "Installing system dependencies..."

apt update -y

apt install -y \
  git \
  wget \
  curl \
  unzip \
  openssl \
  software-properties-common \
  python3 \
  python3-pip \
  python3-dev \
  python3-venv \
  build-essential \
  libxslt-dev \
  libzip-dev \
  libldap2-dev \
  libsasl2-dev \
  libpq-dev \
  libxml2-dev \
  libjpeg-dev \
  zlib1g-dev \
  libfreetype6-dev \
  liblcms2-dev \
  libblas-dev \
  libatlas-base-dev \
  libffi-dev \
  libssl-dev \
  fontconfig \
  xfonts-75dpi \
  xfonts-base \
  libmagickwand-dev \
  nodejs \
  npm \
  qml-module-qtquick2 \
  qml-module-qtquick-controls \
  qml-module-qtquick-layouts

echo "Installing rtlcss (Odoo asset requirement)..."
npm install -g rtlcss

echo "Dependencies installed."