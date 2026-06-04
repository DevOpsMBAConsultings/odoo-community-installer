#!/usr/bin/env python3
"""
Create default payment terms for Panama (Términos de pago).

- Creates any term from PAYMENT_TERMS that does not exist.
- Removes any payment term that is NOT in PAYMENT_TERMS (only terms in the list are kept).

Default terms (in order): Efectivo(contado), Crédito, Crédito a 30/60/90 días, Crédito Otro,
  Tarjeta Crédito/Débito/Fidelización, Vale, Tarjeta de Regalo, Transf./Depósito a cta. Bancaria,
  Cheque, Punto de Pago, otro.

Due dates: balance due after N days (0 = immediate). Credit terms use 30/60/90 days.
Run after account module is installed. Uses ODOO_CONF, DB_NAME, ODOO_HOME.
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

# (name, days): balance due after N days (0 = immediate). Order = sequence.
PAYMENT_TERMS = [
    ("Efectivo(Contado)", 0),
    ("Crédito a 30 días", 30),
    ("Crédito a 60 días", 60),
    ("Crédito a 90 días", 90),
    ("Crédito Otro", 0),
    ("Tarjeta Crédito", 0),
    ("Tarjeta Débito", 0),
    ("Tarjeta Fidelización", 0),
    ("Vale", 0),
    ("Tarjeta de Regalo", 0),
    ("Transf./Depósito a cta. Bancaria", 0),
    ("Cheque", 0),
    ("Punto de Pago", 0),
    ("otro", 0),
]

def _line_balance_days(env, days: int) -> dict:
    """One line: 100% due after N days. Dynamically handles Odoo 19+ (percent) vs older (balance)."""
    LineModel = env["account.payment.term.line"]
    fields = LineModel._fields
    vals = {}
    if "delay_type" in fields:
        vals["delay_type"] = "days_after"
    if "nb_days" in fields:
        vals["nb_days"] = days
    elif "days" in fields:
        vals["days"] = days

    if "value" in fields:
        if "delay_type" in fields:
            vals["value"] = "percent"
            vals["value_amount"] = 100.0
        else:
            vals["value"] = "balance"
            if "value_amount" in fields:
                vals["value_amount"] = 0.0
    return vals

with cr_context as cr:
    env = api.Environment(cr, odoo.SUPERUSER_ID, {})

    if "account.payment.term" not in env:
        print("WARNING: account module not installed. Skipping payment terms.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    PaymentTerm = env["account.payment.term"]
    allowed_names = {name for name, _ in PAYMENT_TERMS}

    # Remove any payment terms that are NOT in PAYMENT_TERMS (only keep terms from the list)
    deleted = 0
    skipped_deletions = 0
    extra = PaymentTerm.search([("name", "not in", list(allowed_names))])
    for term in extra:
        term_name = term.name  # capture before unlink (record may be deleted)
        try:
            term.unlink()
            deleted += 1
            print(f"Removed payment term '{term_name}'.")
        except Exception as e:
            skipped_deletions += 1
            print(f"WARNING: Could not remove '{term_name}' (may be in use on invoices/partners): {e}", file=sys.stderr)

    created = 0
    for seq, (name, days) in enumerate(PAYMENT_TERMS, start=1):
        existing = PaymentTerm.search([("name", "=", name)], limit=1)
        if existing:
            if hasattr(existing, "sequence"):
                existing.sequence = seq
            continue
        PaymentTerm.create({
            "name": name,
            "sequence": seq,
            "line_ids": [(0, 0, _line_balance_days(env, days))],
        })
        created += 1
        due = f"due in {days} days" if days else "immediate"
        print(f"Created payment term '{name}' (sequence {seq}, {due}).")

    cr.commit()
    msg = f"Done. {created} new term(s) added."
    if deleted:
        msg += f" {deleted} extra term(s) removed."
    if skipped_deletions:
        msg += f" {skipped_deletions} term(s) could not be removed (in use)."
    msg += " Only payment terms from PAYMENT_TERMS list remain."
    print(msg)
