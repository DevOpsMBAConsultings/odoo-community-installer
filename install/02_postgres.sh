#!/bin/bash
set -e

DB_USER="odoo"
DB_NAME="${DB_NAME:-odoo${ODOO_VERSION}}"

echo "Installing PostgreSQL..."
apt update -y
apt install -y postgresql postgresql-contrib

echo "Ensuring PostgreSQL service is running..."
systemctl enable postgresql
systemctl start postgresql

echo "Checking for existing PostgreSQL role '$DB_USER'..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${DB_USER}'" | grep -q 1; then
  echo "Role '$DB_USER' already exists — skipping role creation."
else
  echo "Creating PostgreSQL role '$DB_USER' with CREATEDB..."
  sudo -u postgres psql -c "CREATE ROLE ${DB_USER} WITH LOGIN CREATEDB;"
fi

echo "Checking for existing database '${DB_NAME}'..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" | grep -q 1; then
  echo "Database '${DB_NAME}' already exists — skipping creation."
else
  echo "Creating database '${DB_NAME}' owned by '${DB_USER}'..."
  sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER};"
fi

echo "PostgreSQL role + database ready."