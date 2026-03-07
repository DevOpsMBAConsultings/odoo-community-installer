#!/usr/bin/env python3
"""
Create partner tags (res.partner.category) from a list of names.

Edit the list TAG_NAMES below; the script creates any tag that does not exist.
Tags appear in Contact form under "Etiquetas" and can be used for filtering/segmentation.

Run after base/contacts. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")

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

# Edit this list: add or remove tag names. Each will be created if missing.
TAG_NAMES = [
    "Cliente",
    "Proveedor",
    "Persona Natural",
    "Persona Jurídica",
    "Extranjero",
    "Contribuyente",
    "Gobierno",
    "Retenedor 50% de Impuestos",
    "Retenedor 100% de Impuestos",
    "Exento de Impuestos",
    "Efectivo(contado)",
    "Tarjeta de Crédito",
    "Tarjeta de Débito",
    "Tarjeta de Fidelización",
    "Vale",
    "Tarjeta de Regalo",
    "Transf. / Deposito a cta. Bancaria",
    "Cheque",
    "Punto de Pago",
    "Método de Pago Otro",
    "Crédito a 30 días",
    "Crédito a 60 días",
    "Crédito a 90 días",
    "Crédito Otro"
    # Add more as needed:
    # "Contador",
    # "Legal",
]

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})
    
    # Debug: list available models (optional, can be removed later)
    # print(f"DEBUG: Available models: {sorted(env.keys())[:10]}...", file=sys.stderr)

    # Check if model exists by trying to access it
    try:
        Category = env["res.partner.category"]
        print(f"DEBUG: Found res.partner.category model. Total tags before: {Category.search_count([])}", file=sys.stderr)
    except KeyError:
        print("ERROR: res.partner.category model not found. Make sure 'contacts' or 'base' module is installed.", file=sys.stderr)
        print(f"DEBUG: Available models containing 'partner': {[m for m in env.keys() if 'partner' in m.lower()]}", file=sys.stderr)
        cr.rollback()
        sys.exit(1)
    except Exception as e:
        print(f"ERROR: Failed to access res.partner.category: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr)
        cr.rollback()
        sys.exit(1)

    created = 0
    skipped = 0
    errors = 0
    
    for name in TAG_NAMES:
        name = (name or "").strip()
        if not name:
            continue
        
        try:
            existing = Category.search([("name", "=", name)], limit=1)
            if existing:
                skipped += 1
                continue
            
            Category.create({"name": name})
            created += 1
            print(f"Created tag '{name}'.")
        except Exception as e:
            errors += 1
            print(f"ERROR: Failed to create tag '{name}': {e}", file=sys.stderr)

    if errors > 0:
        print(f"WARNING: {errors} tag(s) failed to create.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)
    
    cr.commit()
    print(f"Done. {created} new tag(s) created, {skipped} already existed.")
