#!/bin/bash
set -e

ODOO_USER="odoo"
ODOO_HOME="/opt/odoo"
ODOO_DIR="/opt/odoo/odoo${ODOO_VERSION}"
CUSTOM_ADDONS="/opt/odoo/custom-addons"
OCA_REPO_DIR="/opt/odoo/oca"

echo "Creating Odoo system user (if not exists)..."
id -u $ODOO_USER >/dev/null 2>&1 || adduser --system --home=$ODOO_HOME --group $ODOO_USER

echo "Creating directories..."
mkdir -p "$ODOO_HOME"
mkdir -p "$ODOO_DIR"
mkdir -p "$CUSTOM_ADDONS"
mkdir -p "$OCA_REPO_DIR"
mkdir -p /var/log/odoo

echo "Setting ownership..."
chown -R $ODOO_USER:$ODOO_USER "$ODOO_HOME"
chown -R $ODOO_USER:$ODOO_USER /var/log/odoo

echo "Odoo user and folders ready."
echo "Created:"
echo " • $ODOO_HOME"
echo " • $ODOO_DIR"
echo " • $CUSTOM_ADDONS"
echo " • $OCA_REPO_DIR"
echo " • /var/log/odoo"
