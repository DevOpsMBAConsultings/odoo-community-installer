#!/usr/bin/env python3
"""
Set default journal for customer credit notes (Notas de Crédito).

1. For each company: find or create a sales journal with name "Notas de Crédito" (type sale),
   code "NC" (sequence prefix NC-), and "Secuencia de notas de crédito dedicada" (refund_sequence) enabled.
   If none exists, create one using the company's first income account.
2. Set ir.default for account.move, journal_id, with condition move_type=out_refund,
   so new customer credit notes use this journal by default (per company).

Run after accounting (and ideally l10n) is installed. Uses same env as set_default_country.py:
ODOO_CONF, DB_NAME, ODOO_HOME.
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
JOURNAL_CODE = (os.environ.get("ODOO_CREDIT_NOTES_JOURNAL_CODE") or "NC").strip()
JOURNAL_NAME = (os.environ.get("ODOO_CREDIT_NOTES_JOURNAL_NAME") or "Notas de Crédito").strip()

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

    if "account.journal" not in env:
        print("WARNING: account module not installed. Skipping default credit notes journal.", file=sys.stderr)
        cr.rollback()
        sys.exit(0)

    Journal = env["account.journal"]
    Account = env["account.account"]
    companies = env["res.company"].search([])
    condition = "move_type=out_refund"

    # Odoo 18 changed account.account.company_id → company_ids (Many2many).
    # Detect which field exists so the script works on both 18 and 19.
    account_fields = set(Account.fields_get().keys())
    if "company_ids" in account_fields:
        account_company_domain = lambda cid: ("company_ids", "in", [cid])
    else:
        account_company_domain = lambda cid: ("company_id", "=", cid)

    # Odoo 18 removed refund_sequence (dedicated sequence is now always on).
    has_refund_sequence = "refund_sequence" in set(Journal.fields_get().keys())

    for company in companies:
        journal = Journal.search(
            [
                ("company_id", "=", company.id),
                ("type", "=", "sale"),
                "|",
                ("code", "=", JOURNAL_CODE),
                ("name", "ilike", JOURNAL_NAME),
            ],
            limit=1,
        )
        if not journal:
            income = (
                company.income_account_id
                if hasattr(company, "income_account_id") and company.income_account_id
                else None
            )
            if not income:
                income = Account.search(
                    [
                        account_company_domain(company.id),
                        ("account_type", "=", "income"),
                    ],
                    limit=1,
                )
            if not income:
                print(
                    f"WARNING: No income account for company {company.name}. "
                    f"Install chart of accounts (e.g. l10n_pa) first. Skipping company.",
                    file=sys.stderr,
                )
                continue
            create_vals = {
                "name": JOURNAL_NAME,
                "code": JOURNAL_CODE,
                "type": "sale",
                "company_id": company.id,
                "default_account_id": income.id,
            }
            if has_refund_sequence:
                create_vals["refund_sequence"] = True
            journal = Journal.create(create_vals)
            print(f"Created journal '{journal.name}' (code {journal.code}) for company {company.name}.")
        else:
            if has_refund_sequence and not journal.refund_sequence:
                journal.refund_sequence = True
                print(f"Enabled 'Secuencia de notas de crédito dedicada' for existing journal '{journal.name}' in company {company.name}.")
            else:
                print(f"Using existing journal '{journal.name}' (code {journal.code}) for company {company.name}.")

        env["ir.default"].set(
            "account.move",
            "journal_id",
            journal.id,
            user_id=False,
            company_id=company.id,
            condition=condition,
        )
        print(f"Set default credit notes (notas de crédito) journal to '{journal.name}' for company {company.name} (condition: {condition}).")

    cr.commit()
    print("Done. New customer credit notes will use the 'Notas de crédito' journal by default.")
