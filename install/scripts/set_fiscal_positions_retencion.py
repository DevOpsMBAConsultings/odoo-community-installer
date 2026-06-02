#!/usr/bin/env python3
"""
Create fiscal positions for tax withholding:
- "Retención 50% de impuestos"
- "Retención 100% de Impuestos"

1. For each company: find or create both account.fiscal.position.
2. auto_apply is configurable via ODOO_FISCAL_POSITION_RETENCION_AUTO_APPLY (default 0 = False;
   set to 1 to enable Detectar de forma automática).

Run after accounting (and l10n if needed) is installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
AUTO_APPLY = os.environ.get("ODOO_FISCAL_POSITION_RETENCION_AUTO_APPLY", "1").strip() in ("1", "true", "yes")

FP_NAMES = [
    "Retención 50% de impuestos",
    "Retención 100% de Impuestos",
]

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

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "account.fiscal.position" not in env:
        print("WARNING: account module not installed. Skipping fiscal position.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    FiscalPosition = env["account.fiscal.position"]
    companies = env["res.company"].search([])

    for company in companies:
        for fp_name in FP_NAMES:
            fp = FiscalPosition.search(
                [
                    ("company_id", "=", company.id),
                    ("name", "=", fp_name),
                ],
                limit=1,
            )
            if fp:
                if fp.auto_apply != AUTO_APPLY:
                    fp.auto_apply = AUTO_APPLY
                    print(f"Updated '{fp_name}' auto_apply={AUTO_APPLY} in company {company.name}.")
                else:
                    print(f"Fiscal position '{fp_name}' already exists in company {company.name}.")
            else:
                FiscalPosition.create(
                    {
                        "name": fp_name,
                        "company_id": company.id,
                        "auto_apply": AUTO_APPLY,
                    }
                )
                print(f"Created fiscal position '{fp_name}' for company {company.name} (auto_apply={AUTO_APPLY}).")

        # Archive old 'Retención de impuestos' if it exists
        old_fp = FiscalPosition.search([
            ("company_id", "=", company.id),
            ("name", "=", "Retención de impuestos"),
        ], limit=1)
        if old_fp and getattr(old_fp, "active", True):
            old_fp.active = False
            print(f"Archived old fiscal position 'Retención de impuestos' in company {company.name}.")

    cr.commit()
    print("Done. Fiscal positions for retención are available.")
