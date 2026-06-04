#!/usr/bin/env python3
"""
Create two 0% taxes for Panama (Ventas and Compras) if missing.

1. For each company (with fiscal country PA): find or create tax group "Exento 0%".
2. Find or create 0% tax for Ventas (type_tax_use=sale), description "Exento 0% Venta".
3. Find or create 0% tax for Compras (type_tax_use=purchase), description "Exento 0% Compra".

Run after accounting and l10n_pa (or localisation) are installed. Uses same env
as set_default_country.py: ODOO_CONF, DB_NAME, ODOO_HOME, ODOO_COUNTRY_CODE (default PA).
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
COUNTRY_CODE = (os.environ.get("ODOO_COUNTRY_CODE") or "PA").strip().upper()

if not ODOO_CONF or not DB_NAME:
    print("ERROR: ODOO_CONF and DB_NAME must be set.", file=sys.stderr)
    sys.exit(1)

ODOO_HOME = os.environ.get("ODOO_HOME")
if ODOO_HOME:
    odoo_src = os.path.join(ODOO_HOME, "odoo")
    if os.path.isdir(odoo_src):
        sys.path.insert(0, odoo_src)
    else:
        sys.path.insert(0, ODOO_HOME)

import odoo
from odoo import api, sql_db

odoo.tools.config.parse_config(["-c", ODOO_CONF])

# Get registry: Odoo 19 may not expose odoo.registry on main module; try submodule then sql_db
try:
    import odoo.registry as _regmod
    _registry = getattr(_regmod, "registry", None) or getattr(_regmod, "Registry", None)
    if callable(_registry):
        registry = _registry(DB_NAME)
        cr_context = registry.cursor()
    else:
        raise AttributeError("registry")
except (AttributeError, ImportError):
    cr_context = contextlib.closing(sql_db.db_connect(DB_NAME).cursor())

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "account.tax" not in env:
        print("WARNING: account module not installed. Skipping Panama 0% taxes.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"WARNING: Country {COUNTRY_CODE} not found. Skipping 0% taxes.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    TaxGroup = env["account.tax.group"]
    Tax = env["account.tax"]
    companies = env["res.company"].search([])

    for company in companies:
        # Only create taxes for companies whose fiscal country is PA (or all if single company)
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue

        # 1) Tax group "Exento 0%" for this company/country
        domain = []
        if "company_id" in TaxGroup._fields:
            domain.append(("company_id", "=", company.id))
        if "country_id" in TaxGroup._fields:
            domain.append(("country_id", "=", country.id))
        domain.extend([
            "|",
            ("name", "ilike", "Exento"),
            ("name", "ilike", "Excento"),
        ])
        group = TaxGroup.search(domain, limit=1)
        if not group:
            create_vals = {"name": "Exento 0%"}
            if "company_id" in TaxGroup._fields:
                create_vals["company_id"] = company.id
            if "country_id" in TaxGroup._fields:
                create_vals["country_id"] = country.id
            group = TaxGroup.create(create_vals)
            print(f"Created tax group '{group.name}' for company {company.name}.")

        # 2) 0% tax Ventas
        tax_sale = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "sale"),
                ("amount", "=", 0.0),
                ("name", "=", "0%"),
            ],
            limit=1,
        )
        if not tax_sale:
            tax_sale = Tax.create(
                {
                    "name": "0%",
                    "description": "Exento 0% Venta",
                    "type_tax_use": "sale",
                    "amount_type": "percent",
                    "amount": 0.0,
                    "company_id": company.id,
                    "country_id": country.id,
                    "tax_group_id": group.id,
                }
            )
            print(f"Created 0% tax (Ventas) for company {company.name}.")
        else:
            print(f"0% tax (Ventas) already exists for company {company.name}.")

        # 3) 0% tax Compras
        tax_purchase = Tax.search(
            [
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("type_tax_use", "=", "purchase"),
                ("amount", "=", 0.0),
                ("name", "=", "0%"),
            ],
            limit=1,
        )
        if not tax_purchase:
            tax_purchase = Tax.create(
                {
                    "name": "0%",
                    "description": "Exento 0% Compra",
                    "type_tax_use": "purchase",
                    "amount_type": "percent",
                    "amount": 0.0,
                    "company_id": company.id,
                    "country_id": country.id,
                    "tax_group_id": group.id,
                }
            )
            print(f"Created 0% tax (Compras) for company {company.name}.")
        else:
            print(f"0% tax (Compras) already exists for company {company.name}.")

    cr.commit()
    print("Done. Two 0% taxes (Ventas and Compras) are available for Panama.")
