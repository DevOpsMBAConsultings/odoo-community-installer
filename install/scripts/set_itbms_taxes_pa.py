#!/usr/bin/env python3
"""
Create ITBMS 10% and 15% taxes for Panama (Ventas and Compras) if missing.

For each company with fiscal country PA:
1. Find or create tax groups "ITBMS 10%" and "ITBMS 15%".
2. Find or create 10% tax for Ventas (ITBMS 10% Venta) and Compras (ITBMS 10% Compra).
3. Find or create 15% tax for Ventas (ITBMS 15% Venta) and Compras (ITBMS 15% Compra).

Run after accounting and l10n_pa are installed. Uses same env as set_default_taxes_pa.py.
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

# (amount, group_name, sale_desc, purchase_desc)
ITBMS_SPECS = [
    (7.0, "ITBMS 7%", "ITBMS 7% Venta", "ITBMS 7% Compra"),
    (10.0, "ITBMS 10%", "ITBMS 10% Venta", "ITBMS 10% Compra"),
    (15.0, "ITBMS 15%", "ITBMS 15% Venta", "ITBMS 15% Compra"),
]

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "account.tax" not in env:
        print("WARNING: account module not installed. Skipping ITBMS taxes.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"WARNING: Country {COUNTRY_CODE} not found. Skipping ITBMS taxes.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    TaxGroup = env["account.tax.group"]
    Tax = env["account.tax"]
    companies = env["res.company"].search([])

    for company in companies:
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue

        for amount, group_name, sale_desc, purchase_desc in ITBMS_SPECS:
            domain = [("name", "=", group_name)]
            if "company_id" in TaxGroup._fields:
                domain.append(("company_id", "=", company.id))
            if "country_id" in TaxGroup._fields:
                domain.append(("country_id", "=", country.id))
            group = TaxGroup.search(domain, limit=1)
            if not group:
                create_vals = {"name": group_name}
                if "company_id" in TaxGroup._fields:
                    create_vals["company_id"] = company.id
                if "country_id" in TaxGroup._fields:
                    create_vals["country_id"] = country.id
                group = TaxGroup.create(create_vals)
                print(f"Created tax group '{group.name}' for company {company.name}.")

            for type_tax_use, desc in [("sale", sale_desc), ("purchase", purchase_desc)]:
                tax = Tax.search(
                    [
                        ("company_id", "=", company.id),
                        ("country_id", "=", country.id),
                        ("type_tax_use", "=", type_tax_use),
                        ("amount", "=", amount),
                        ("name", "=", f"{int(amount)}%"),
                        ("tax_group_id", "=", group.id),
                    ],
                    limit=1,
                )
                if not tax:
                    Tax.create(
                        {
                            "name": f"{int(amount)}%",
                            "description": desc,
                            "type_tax_use": type_tax_use,
                            "amount_type": "percent",
                            "amount": amount,
                            "company_id": company.id,
                            "country_id": country.id,
                            "tax_group_id": group.id,
                        }
                    )
                    print(f"Created {int(amount)}% tax ({desc}) for company {company.name}.")
                else:
                    print(f"{int(amount)}% tax ({desc}) already exists for company {company.name}.")

    cr.commit()
    print("Done. ITBMS 10% and 15% taxes (Ventas and Compras) are available for Panama.")
