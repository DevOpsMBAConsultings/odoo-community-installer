#!/usr/bin/env python3
"""
Set the system default language to es_PA (or the configured ODOO_LANG) and
apply it to the Administrator user and all existing users.

In Odoo 18, --load-language only installs the language pack but does NOT set
it as the active language for any user. This script fixes that:

1. Activates the language in res.lang (marks it active).
2. Sets the language on the Administrator user (uid=1).
3. Optionally sets the language on all existing internal users (if ODOO_LANG_ALL_USERS=1).
4. Sets ir.default for res.partner.lang so new contacts default to this language.

Run after base + l10n modules are installed (step 09).
Uses: ODOO_CONF, DB_NAME, ODOO_HOME, ODOO_LANG (default es_PA),
      ODOO_LANG_ALL_USERS (default 1 = set for all users).
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
LANG_CODE = (os.environ.get("ODOO_LANG") or "es_PA").strip()
SET_ALL_USERS = (os.environ.get("ODOO_LANG_ALL_USERS", "1") == "1")

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

    # ------------------------------------------------------------------
    # 1) Ensure the language is active in res.lang
    # ------------------------------------------------------------------
    Lang = env["res.lang"]
    lang = Lang.search([("code", "=", LANG_CODE)], limit=1)

    if not lang:
        # Language not loaded yet — try to activate it
        # Odoo 18 NOTE: --load-language at both base init AND module install
        # is the reliable way. This block is a belt-and-suspenders fallback.
        try:
            # Odoo 18/19: _activate_lang or load_lang
            if hasattr(Lang, "_activate_lang"):
                Lang._activate_lang(LANG_CODE)
            elif hasattr(Lang, "load_lang"):
                # Odoo 16/17 method name
                Lang.load_lang(LANG_CODE)
            else:
                # Fallback: search inactive then write active=True
                lang_inactive = Lang.with_context(active_test=False).search(
                    [("code", "=", LANG_CODE)], limit=1
                )
                if lang_inactive:
                    lang_inactive.active = True
                    lang = lang_inactive
            lang = Lang.search([("code", "=", LANG_CODE)], limit=1)
        except Exception as e:
            print(f"WARNING: Could not activate language {LANG_CODE}: {e}", file=sys.stderr)

    if lang:
        if not lang.active:
            lang.active = True
        print(f"Language '{lang.name}' ({LANG_CODE}) is active.")
    else:
        print(
            f"WARNING: Language '{LANG_CODE}' not found in res.lang. "
            f"Make sure --load-language={LANG_CODE} was used during base init.",
            file=sys.stderr,
        )

    # ------------------------------------------------------------------
    # 2) Set language on the Administrator user (uid=1)
    # ------------------------------------------------------------------
    admin_user = env["res.users"].browse(odoo.SUPERUSER_ID)
    if admin_user.exists():
        admin_user.write({"lang": LANG_CODE})
        print(f"Set language '{LANG_CODE}' on Administrator user.")
    else:
        print("WARNING: Administrator user (uid=1) not found.", file=sys.stderr)

    # ------------------------------------------------------------------
    # 3) Optionally set language on all internal users
    # ------------------------------------------------------------------
    if SET_ALL_USERS:
        users = env["res.users"].search([
            ("share", "=", False),   # internal users only (not portal/public)
            ("active", "=", True),
        ])
        count = 0
        for user in users:
            if user.lang != LANG_CODE:
                user.write({"lang": LANG_CODE})
                count += 1
        print(f"Set language '{LANG_CODE}' on {count} internal user(s).")

    # ------------------------------------------------------------------
    # 4) Set ir.default for res.partner.lang (new contacts default lang)
    # ------------------------------------------------------------------
    try:
        env["ir.default"].set(
            "res.partner",
            "lang",
            LANG_CODE,
            user_id=False,
            company_id=False,
        )
        print(f"Set ir.default for res.partner.lang = '{LANG_CODE}' (new contacts).")
    except Exception as e:
        print(f"WARNING: Could not set ir.default for res.partner.lang: {e}", file=sys.stderr)

    # ------------------------------------------------------------------
    # 5) Set the company language (res.company doesn't have lang directly,
    #    but the partner linked to the company does)
    # ------------------------------------------------------------------
    companies = env["res.company"].search([])
    for company in companies:
        if hasattr(company, "partner_id") and company.partner_id:
            company.partner_id.write({"lang": LANG_CODE})
    print(f"Set language on {len(companies)} company partner(s).")

    cr.commit()
    print(f"Done. Default language set to '{LANG_CODE}'.")
