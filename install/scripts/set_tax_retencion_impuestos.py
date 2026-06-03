#!/usr/bin/env python3
"""
Create retention taxes and group taxes for Panama:
Base taxes:
1. ITBMS 0% (Operacion Exento de Impuesto) (0%)
2. ITBMS 7% (Operaciones con Retención) (7%)
3. ITBMS 50% (Operaciones con Retención) (-3.5%)
4. ITBMS 100% (Operaciones con Retención) (-7.0%)

Group taxes:
1. Retención de impuestos 50% (contains 7% and -3.5%)
2. Retención de impuestos 100% (contains 7% and -7.0%)
3. Exento de Impuestos 100% (contains 0%)

And assign "Retención de impuestos 50%" to the fiscal position "Retención de impuestos" by default.

Run after set_fiscal_position_retencion.py and set_default_taxes_pa.py.
Uses ODOO_CONF, DB_NAME, ODOO_HOME, ODOO_COUNTRY_CODE (default PA).
"""
from __future__ import annotations

import contextlib
import os
import sys

ODOO_CONF = os.environ.get("ODOO_CONF")
DB_NAME = os.environ.get("DB_NAME")
COUNTRY_CODE = (os.environ.get("ODOO_COUNTRY_CODE") or "PA").strip().upper()
FP_NAME_50 = (os.environ.get("ODOO_FISCAL_POSITION_RETENCION_50_NAME") or "Retención 50% de impuestos").strip()
FP_NAME_100 = (os.environ.get("ODOO_FISCAL_POSITION_RETENCION_100_NAME") or "Retención 100% de Impuestos").strip()
TAX_GROUP_NAME = (os.environ.get("ODOO_TAX_GROUP_RETENCION_NAME") or "Retención de Impuestos").strip()

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

    # Check if account module is installed
    try:
        TaxModel = env["account.tax"]
        FiscalPositionModel = env["account.fiscal.position"]
    except KeyError as e:
        print(f"ERROR: account module not installed. Missing model: {e}", file=sys.stderr)
        print("Make sure 'account' module is installed before running this script.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)

    country = env["res.country"].search([("code", "=", COUNTRY_CODE)], limit=1)
    if not country:
        print(f"ERROR: Country {COUNTRY_CODE} not found. Make sure the country exists in Odoo.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)

    TaxGroup = env["account.tax.group"]
    Tax = env["account.tax"]
    FiscalPosition = env["account.fiscal.position"]
    companies = env["res.company"].search([])
    
    if not companies:
        print("ERROR: No companies found in the database.", file=sys.stderr)
        cr.rollback()
        sys.exit(1)
    
    print(f"DEBUG: Processing {len(companies)} company/companies for country {COUNTRY_CODE}...", file=sys.stderr)

    # Helper to check for existing fields to avoid crashes on different Odoo versions
    valid_tax_fields = set(env["account.tax"].fields_get().keys())
    
    def safe_tax_vals(vals):
        """Prepares a dictionary of vals, removing keys that do not exist in the model."""
        return {k: v for k, v in vals.items() if k in valid_tax_fields}

    for company in companies:
        fiscal_country = company.account_fiscal_country_id or company.country_id
        if fiscal_country and fiscal_country.code != COUNTRY_CODE:
            continue
        
        print(f"--- Processing Company: {company.name} ---")

        # ---------------------------------------------------------------------
        # Paso 1: Creación de grupo de impuestos (Tax Group) Category
        # ---------------------------------------------------------------------
        group = TaxGroup.search([
            ("company_id", "=", company.id),
            ("country_id", "=", country.id),
            ("name", "=", TAX_GROUP_NAME),
        ], limit=1)
        if not group:
            group = TaxGroup.create({
                "name": TAX_GROUP_NAME,
                "company_id": company.id,
                "country_id": country.id,
            })
            print(f"  [CREATE] Tax Group Category '{TAX_GROUP_NAME}'")
        else:
             print(f"  [EXISTS] Tax Group Category '{TAX_GROUP_NAME}'")

        # Grupo de impuestos para Exento
        exento_group_name = "Exento 0%"
        exento_group = TaxGroup.search([
            ("company_id", "=", company.id),
            ("country_id", "=", country.id),
            ("name", "=", exento_group_name),
        ], limit=1)
        if not exento_group:
            exento_group = TaxGroup.create({
                "name": exento_group_name,
                "company_id": company.id,
                "country_id": country.id,
            })
            print(f"  [CREATE] Tax Group Category '{exento_group_name}'")
        else:
             print(f"  [EXISTS] Tax Group Category '{exento_group_name}'")

        # ---------------------------------------------------------------------
        # Paso 2: Creación de Impuestos Base (Componentes)
        # ---------------------------------------------------------------------
        # Dictionary of taxes to ensure they exist
        base_taxes_data = {
            "ITBMS 0% (Operacion Exento de Impuesto)": {
                "amount": 0.0,
                "description": "ITBMS 0% Venta",
                "invoice_label": "ITBMS 0% Venta",
                "is_base_affected": False
            },
            "ITBMS 7% (Operaciones con Retención)": {
                "amount": 7.0,
                "description": "ITBMS 7% Venta",
                "invoice_label": "7%",  # Was '7%', could be ITBMS 7% Venta, sticking to previous script implementation
                "is_base_affected": True
            },
            "ITBMS 50% (Operaciones con Retención)": {
                "amount": -3.5,
                "description": "ITBMS -50% Venta",
                "invoice_label": "-3.5%",
                "is_base_affected": False
            },
            "ITBMS 100% (Operaciones con Retención)": {
                "amount": -7.0,
                "description": "ITBMS -100% Venta",
                "invoice_label": "-7.0%",
                "is_base_affected": False
            }
        }

        created_base_taxes = {}
        for b_name, b_data in base_taxes_data.items():
            tax = Tax.search([
                ("company_id", "=", company.id),
                ("type_tax_use", "=", "sale"),
                ("name", "=", b_name),
            ], limit=1)
            
            # Determine which group to use
            current_group_id = exento_group.id if b_name == "ITBMS 0% (Operacion Exento de Impuesto)" else group.id

            vals = {
                "name": b_name,
                "type_tax_use": "sale",
                "amount_type": "percent",
                "amount": b_data["amount"],
                "description": b_data["description"],
                "tax_group_id": current_group_id,
                "country_id": country.id,
                "company_id": company.id,
                "price_include": False,
                "include_base_amount": False,
                "is_base_affected": b_data["is_base_affected"],
                "invoice_label": b_data["invoice_label"],
            }
            vals = safe_tax_vals(vals)

            if not tax:
                tax = Tax.create(vals)
                print(f"  [CREATE] Base Tax: '{b_name}'")
            else:
                tax.write(vals)
                print(f"  [UPDATE] Base Tax: '{b_name}'")
            created_base_taxes[b_name] = tax


        # ---------------------------------------------------------------------
        # Paso 3. Creación de Objetos Grupo de Impuestos (Objects with children)
        # ---------------------------------------------------------------------
        group_taxes_data = {
            "Retención de impuestos 50%": {
                "children": ["ITBMS 7% (Operaciones con Retención)", "ITBMS 50% (Operaciones con Retención)"],
                "invoice_label": "ITBMS 7% (Operaciones con Retención)"
            },
            "Retención de impuestos 100%": {
                "children": ["ITBMS 7% (Operaciones con Retención)", "ITBMS 100% (Operaciones con Retención)"],
                "invoice_label": "ITBMS 7% (Operaciones con Retención)" # same label according to sheet
            },
            "Exento de Impuestos 100%": {
                "children": ["ITBMS 0% (Operacion Exento de Impuesto)"],
                "invoice_label": "ITBMS 7% (Operaciones con Exento)" # Requested from sheet
            }
        }
        
        main_tax_50 = None
        main_tax_100 = None

        for g_name, g_data in group_taxes_data.items():
            g_tax = Tax.search([
                ("company_id", "=", company.id),
                ("country_id", "=", country.id),
                ("name", "=", g_name),
                ("type_tax_use", "=", "sale"),
            ], limit=1)

            child_ids = [created_base_taxes[c_name].id for c_name in g_data["children"]]

            # Determine which group to use
            current_group_id = exento_group.id if g_name == "Exento de Impuestos 100%" else group.id

            vals = {
                "name": g_name,
                "type_tax_use": "sale",
                "amount_type": "group",
                "company_id": company.id,
                "country_id": country.id,
                "tax_group_id": current_group_id,
                "children_tax_ids": [(6, 0, child_ids)],
                "description": False,
                "invoice_label": g_data["invoice_label"],
            }
            vals = safe_tax_vals(vals)

            if not g_tax:
                g_tax = Tax.create(vals)
                print(f"  [CREATE] Group Tax Container: '{g_name}'")
            else:
                g_tax.write(vals)
                print(f"  [UPDATE] Group Tax Container: '{g_name}'")
            
            if g_name == "Retención de impuestos 50%":
                main_tax_50 = g_tax
            elif g_name == "Retención de impuestos 100%":
                main_tax_100 = g_tax

        # ---------------------------------------------------------------------
        # 4) Fiscal positions "Retención 50% de impuestos" and "Retención 100% de Impuestos"
        # In Odoo 19+: account.tax.original_tax_ids / fiscal_position_ids.
        # In Odoo 18: those fields were removed → use account.fiscal.position.tax lines.
        # ---------------------------------------------------------------------
        
        # Load the two fiscal positions
        fp_50 = FiscalPosition.search([
            ("company_id", "=", company.id),
            ("name", "=", FP_NAME_50),
        ], limit=1)
        if not fp_50:
            print(f"  [ERROR] Fiscal position '{FP_NAME_50}' not found. Run set_fiscal_positions_retencion.py first.", file=sys.stderr)
            fp_50 = FiscalPosition.create({
                "name": FP_NAME_50,
                "company_id": company.id,
                "country_id": country.id,
                "auto_apply": False,
            })
            print(f"  [CREATE] Fiscal position '{FP_NAME_50}' (fallback created)")

        fp_100 = FiscalPosition.search([
            ("company_id", "=", company.id),
            ("name", "=", FP_NAME_100),
        ], limit=1)
        if not fp_100:
            print(f"  [ERROR] Fiscal position '{FP_NAME_100}' not found. Run set_fiscal_positions_retencion.py first.", file=sys.stderr)
            fp_100 = FiscalPosition.create({
                "name": FP_NAME_100,
                "company_id": company.id,
                "country_id": country.id,
                "auto_apply": False,
            })
            print(f"  [CREATE] Fiscal position '{FP_NAME_100}' (fallback created)")

        # Source: 0% sale tax (Exento)
        tax_0_sale = Tax.search([
            ("company_id", "=", company.id),
            ("country_id", "=", country.id),
            ("type_tax_use", "=", "sale"),
            ("amount", "=", 0.0),
            ("amount_type", "=", "percent"),
        ], limit=1)

        if not tax_0_sale:
            tax_0_sale = Tax.search([
                ("company_id", "=", company.id),
                ("type_tax_use", "=", "sale"),
                "|",
                ("name", "ilike", "Exento"),
                ("name", "=", "0%"),
            ], limit=1)

        if not tax_0_sale:
            print(f"  [ERROR] source 0% sale tax not found. Cannot set mapping.", file=sys.stderr)
        else:
            # Helper to map tax on a specific FP
            def map_tax(fp_obj, dest_tax_obj):
                if not dest_tax_obj:
                    return
                print(f"  [MAPPING] {tax_0_sale.name} → {dest_tax_obj.name} in '{fp_obj.name}'...")
                
                if hasattr(Tax, "original_tax_ids") and "original_tax_ids" in valid_tax_fields:
                    if tax_0_sale.id not in dest_tax_obj.original_tax_ids.ids:
                        dest_tax_obj.write({"original_tax_ids": [(4, tax_0_sale.id)]})
                        print(f"    - Added {tax_0_sale.name} to original_tax_ids")
                    if fp_obj.id not in dest_tax_obj.fiscal_position_ids.ids:
                        dest_tax_obj.write({"fiscal_position_ids": [(4, fp_obj.id)]})
                        print(f"    - Added '{fp_obj.name}' to fiscal_position_ids")
                else:
                    FPTax = env["account.fiscal.position.tax"]
                    existing_line = FPTax.search([
                        ("position_id", "=", fp_obj.id),
                        ("tax_src_id", "=", tax_0_sale.id),
                    ], limit=1)
                    if not existing_line:
                        FPTax.create({
                            "position_id": fp_obj.id,
                            "tax_src_id": tax_0_sale.id,
                            "tax_dest_id": dest_tax_obj.id,
                        })
                        print(f"    - Created fiscal.position.tax line: {tax_0_sale.name} → {dest_tax_obj.name}")
                    elif existing_line.tax_dest_id.id != dest_tax_obj.id:
                        existing_line.write({"tax_dest_id": dest_tax_obj.id})
                        print(f"    - Updated fiscal.position.tax line: {tax_0_sale.name} → {dest_tax_obj.name}")
                    else:
                        print(f"    - fiscal.position.tax line already correct (no change)")
                print(f"  [MAPPING] Complete: {tax_0_sale.name} → {dest_tax_obj.name} in '{fp_obj.name}'")

            map_tax(fp_50, main_tax_50)
            map_tax(fp_100, main_tax_100)

    cr.commit()
    print("Done.")
