# Matriz Completa: Módulos Odoo Enterprise vs Community / OCA

> **Propósito de este documento:** Referencia centralizada para saber, por cada módulo de Odoo Enterprise, si está disponible en Community, qué repositorio OCA lo reemplaza, y si ya está incluido en `config/oca_repos.conf` para instalación automática.

---

## Cómo leer esta tabla

| Ícono | Significado |
|:---:|:---|
| ✅ **Community** | El módulo está incluido en Odoo Community sin costo adicional |
| 🔵 **OCA** | Existe un repositorio OCA que lo reemplaza parcial o totalmente |
| ⚠️ **OCA Parcial** | Hay alternativa OCA pero con funcionalidad reducida frente a Enterprise |
| ❌ **Sin alternativa** | No existe reemplazo open-source equivalente conocido |
| 📦 **En conf** | El repo OCA ya está en `config/oca_repos.conf` (instalación automática) |
| ➕ **Falta en conf** | El repo OCA existe pero **no está en `oca_repos.conf`** — considerar añadir |

---

## 1. Finanzas y Contabilidad

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Accounting** (contabilidad completa) | 🔵 OCA | `account_usability`, `account_asset_management`, `account_tax_balance` | `account-financial-tools` | 📦 Sí |
| **Invoicing** (facturación básica) | ✅ Community | — incluido en core — | — | — |
| **Financial Reports** (P&L, Balance) | 🔵 OCA | `mis_builder`, `mis_builder_summary` | `mis-builder` | 📦 Sí |
| **Bank Reconciliation Widget** | 🔵 OCA | `account_reconciliation_widget` | `account-reconcile` | 📦 Sí |
| **Asset Management** (activos fijos) | 🔵 OCA | `account_asset_management` | `account-financial-tools` | 📦 Sí |
| **Account Reports (xlsx)** | 🔵 OCA | `report_xlsx`, `account_financial_report` | `reporting-engine`, `account-financial-reporting` | 📦 Sí |
| **Lock Dates Contables** | ✅ Community | — incluido en core — | — | — |
| **Seguimiento de cheques** | ⚠️ OCA Parcial | `account_check_printing` | `account-financial-tools` | 📦 Sí |
| **Intrastat** | ⚠️ OCA Parcial | `account_intrastat_product` | `account-financial-tools` | 📦 Sí |
| **SEPA / Transferencias bancarias** | ⚠️ OCA Parcial | `account_banking_sepa_credit_transfer` | `bank-payment` | 📦 Sí |
| **Pagos en lote (batch payments)** | 🔵 OCA | `account_batch_payment_oca` | `bank-payment` | 📦 Sí |
| **Spreadsheet / BI** | ❌ Sin alternativa | — Odoo Spreadsheet es código cerrado — | — | — |
| **Expenses** (Gastos) | ✅ Community | — incluido en core — | — | — |

---

## 2. Ventas y CRM

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **CRM** | ✅ Community | — incluido en core — | — | — |
| **Sales** (Ventas) | ✅ Community | — incluido en core — | — | — |
| **Subscriptions** (Suscripciones) | 🔵 OCA | `contract`, `contract_sale` | `contract` | 📦 Sí |
| **Rental** (Alquiler) | ⚠️ OCA Parcial | `rental_base`, `rental_product_pack` | `vertical-rental` | 📦 Sí |
| **Point of Sale (POS)** | ✅ Community | — incluido en core — | — | — |
| **POS Restaurant** | ✅ Community | — incluido en core — | — | — |
| **Aprobaciones de ventas multi-nivel** | 🔵 OCA | `sale_tier_validation` | `sale-workflow` | 📦 Sí |
| **Sale Order portals** | ✅ Community | — incluido en core — | — | — |
| **Pricelists avanzadas** | ✅ Community | — incluido en core — | — | — |
| **Sale Commission** | ➕ OCA extra | `sale_commission` | `sale-workflow` | 📦 Sí |

---

## 3. Sitio Web y eCommerce

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Website Builder** | ✅ Community | — incluido en core — | — | — |
| **eCommerce** | ✅ Community | — incluido en core — | — | — |
| **Blog** | ✅ Community | — incluido en core — | — | — |
| **Forum** | ✅ Community | — incluido en core — | — | — |
| **Live Chat** | ✅ Community | — incluido en core — | — | — |
| **eLearning** | ✅ Community | — incluido en core — | — | — |
| **Appointments** (Citas) | ⚠️ OCA Parcial | `resource_booking` | `resource` | 📦 Sí |

---

## 4. Cadena de Suministro e Inventario

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Inventory** (Inventario básico) | ✅ Community | — incluido en core — | — | — |
| **Stock Barcode** (App de código de barras) | 🔵 OCA | `stock_barcode`, `barcodes_generator_abstract` | `stock-logistics-barcode` | 📦 Sí |
| **Multi-almacén avanzado** | ✅ Community | — incluido en core — | — | — |
| **Lots y Números de Serie** | ✅ Community | — incluido en core — | — | — |
| **Delivery Routes** | ✅ Community | — incluido en core — | — | — |
| **Purchase** (Compras) | ✅ Community | — incluido en core — | — | — |
| **Aprobaciones de compra multi-nivel** | 🔵 OCA | `purchase_tier_validation` | `purchase-workflow` | 📦 Sí |
| **Dropshipping** | ✅ Community | — incluido en core — | — | — |
| **Rutas de stock avanzadas** | ✅ Community | — incluido en core — | — | — |
| **Gestión de transportistas** | ⚠️ OCA Parcial | `delivery_carrier_label` | `delivery-carrier` | 📦 Sí |

---

## 5. Manufactura y PLM

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Manufacturing** (MRP básico) | ✅ Community | — incluido en core — | — | — |
| **PLM** (Ciclo de vida del producto) | 🔵 OCA | `mrp_bom_tracking`, `mrp_bom_change_instruction` | `manufacture` | 📦 Sí |
| **Quality Control** (Control de calidad) | 🔵 OCA | `quality_control_oca` | `manufacture` | 📦 Sí |
| **Maintenance** (Mantenimiento) | ✅ Community | — incluido en core — | — | — |
| **Work Centers avanzados** | ✅ Community | — incluido en core — | — | — |
| **Shop Floor (Tablet App)** | ❌ Sin alternativa | — App propietaria Enterprise — | — | — |
| **MRP II / Scheduling** | ⚠️ OCA Parcial | `mrp_multi_level` | `manufacture` | 📦 Sí |
| **MRP Subcontratación** | ✅ Community | — incluido en core — | — | — |

---

## 6. Recursos Humanos

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Employees** (Empleados) | ✅ Community | — incluido en core — | — | — |
| **Payroll** (Nómina) | 🔵 OCA | `hr_payroll_community`, `payroll` | `payroll` | 📦 Sí |
| **Recruitment** (Reclutamiento) | ✅ Community | — incluido en core — | — | — |
| **Time Off** (Ausentismo/Vacaciones) | ✅ Community | — incluido en core — | — | — |
| **Appraisals** (Evaluaciones) | 🔵 OCA | `hr_appraisal_oca` | `hr` | 📦 Sí |
| **Fleet** (Flota vehicular) | ✅ Community | — incluido en core — | — | — |
| **Referrals** (Referidos) | ❌ Sin alternativa | — módulo Enterprise propietario — | — | — |
| **Attendances** (Asistencia) | ✅ Community | — incluido en core — | — | — |
| **Expenses** (Gastos empleados) | ✅ Community | — incluido en core — | — | — |
| **Skills Management** | ✅ Community | — incluido en core — | — | — |
| **HR Contrato** | ✅ Community | — incluido en core — | — | — |

---

## 7. Servicios y Proyectos

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Project** (Proyectos) | ✅ Community | — incluido en core — | — | — |
| **Timesheets** (Hojas de tiempo) | ✅ Community | — incluido en core — | — | — |
| **Field Service** (Servicio en campo) | ⚠️ OCA Parcial | `fieldservice` | `field-service` | 📦 Sí |
| **Helpdesk** (Mesa de soporte) | 🔵 OCA | `helpdesk_mgmt`, `helpdesk_mgmt_sla` | `helpdesk` | 📦 Sí |
| **Planning** (Planificación de turnos) | ⚠️ OCA Parcial | `resource_planning` | `resource` | 📦 Sí |
| **Appointments** (Citas) | ⚠️ OCA Parcial | `resource_booking` | `resource` | 📦 Sí |
| **Facturación por proyecto/tiempo** | ✅ Community | — incluido en core — | — | — |

---

## 8. Marketing y Comunicaciones

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Email Marketing** | ✅ Community | — incluido en core (mass_mailing) — | — | — |
| **SMS Marketing** | ✅ Community | — incluido en core — | — | — |
| **Marketing Automation** | ⚠️ OCA Parcial | `mass_mailing_partner` | `social` | 📦 Sí |
| **Social Marketing** | ❌ Sin alternativa | — módulo Enterprise propietario — | — | — |
| **Events** (Eventos) | ✅ Community | — incluido en core — | — | — |
| **Surveys** (Encuestas) | ✅ Community | — incluido en core — | — | — |
| **WhatsApp Integration** | ❌ Sin alternativa | — módulo Enterprise propietario — | — | — |

---

## 9. Productividad y Plataforma

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Discuss** (Chat interno) | ✅ Community | — incluido en core — | — | — |
| **Knowledge** (Wiki / Base de conocimiento) | 🔵 OCA | `document_page`, `document_knowledge` | `knowledge` | 📦 Sí |
| **Documents (DMS)** | 🔵 OCA | `dms`, `dms_directory` | `dms` | 📦 Sí |
| **Sign** (Firma electrónica) | 🔵 OCA | `sign_oca` | `sign` | 📦 Sí |
| **Odoo Studio** | ❌ Sin alternativa | — No existe reemplazo open-source — | — | — |
| **IoT Box** | ❌ Sin alternativa | — Módulo propietario Enterprise — | — | — |
| **VoIP** | ❌ Sin alternativa | — Módulo propietario Enterprise — | — | — |
| **Artificial Intelligence (OCR/IA)** | ❌ Sin alternativa | — Servicio en la nube Enterprise — | — | — |
| **Mobile App** | ❌ Sin alternativa | — App nativa solo Enterprise — | — | — |

---

## 10. Automatización y Configuración del Sistema

| Módulo Enterprise | Estado | Módulo(s) OCA | Repositorio OCA | En oca_repos.conf |
|:---|:---:|:---|:---|:---:|
| **Automation** (Reglas de acción automatizadas) | 🔵 OCA | `base_automation_oca` | `automation` | 📦 Sí |
| **Aprobaciones (Approvals)** | 🔵 OCA | `base_tier_validation` | `server-ux` | 📦 Sí |
| **Server Brand** (sin banners Enterprise) | 🔵 OCA | `server_brand` | `server-brand` | 📦 Sí |
| **Menús técnicos ocultos** | 🔵 OCA | `base_technical_features` | `server-ux` | 📦 Sí |
| **Date Ranges (periodos contables)** | 🔵 OCA | `date_range` | `server-ux` | 📦 Sí |
| **Campos personalizados UI** | ⚠️ OCA Parcial | `base_custom_info` | `server-tools` | 📦 Sí |
| **OpenUpgrade** (migración de versiones) | 🔵 OCA | motor de migración comunitario | `OpenUpgrade` | — especial — |

---

## 11. Resumen de Repos OCA por Categoría

### Repos YA en `oca_repos.conf` (instalación automática)

| Repositorio | Categoría | Equivalente Enterprise Principal |
|:---|:---|:---|
| `account-financial-reporting` | Finanzas | Financial Reports |
| `account-financial-tools` | Finanzas | Advanced Accounting |
| `account-reconcile` | Finanzas | Bank Reconciliation |
| `reporting-engine` | Infraestructura | Excel/PDF Reports |
| `web` | Infraestructura | UI Framework |
| `server-tools` | Infraestructura | Utilidades técnicas |
| `server-ux` | Infraestructura | Approvals, Date Ranges |
| `server-brand` | Infraestructura | Eliminar banners Enterprise |
| `mis-builder` | Finanzas | P&L, Balance General |
| `contract` | Ventas | Subscriptions |
| `helpdesk` | Servicios | Helpdesk |
| `dms` | Productividad | Documents |
| `knowledge` | Productividad | Knowledge |
| `sign` | Productividad | Sign |
| `stock-logistics-barcode` | Inventario | Stock Barcode App |
| `manufacture` | Manufactura | PLM, Quality, MRP II |
| `purchase-workflow` | Compras | Aprobaciones multi-nivel |
| `sale-workflow` | Ventas | Aprobaciones, comisiones |
| `partner-contact` | CRM | Datos enriquecidos de socios |
| `automation` | Sistema | Automation (reglas de acción) |
| `bank-payment` | Finanzas | Batch Payments / SEPA |
| `payroll` | RRHH | Payroll (Nómina) |
| `resource` | Servicios | Planning / Appointments |
| `vertical-rental` | Ventas | Rental (Alquiler) |
| `delivery-carrier` | Inventario | Delivery Carriers |
| `hr` | RRHH | Appraisals / HR avanzado |
| `field-service` | Servicios | Field Service |
| `social` | Marketing | Marketing Automation |

> [!NOTE]
> Todos los repos OCA con equivalencia Enterprise relevante están ahora configurados en `oca_repos.conf`.
> No quedan repos pendientes de alta prioridad fuera de la configuración automática.

---

## 12. Módulos sin alternativa OCA (solo Enterprise)

> [!WARNING]
> Las siguientes funcionalidades **no tienen reemplazo directo** en el ecosistema OCA. Si son críticas para el negocio, se debe evaluar licenciar Odoo Enterprise o buscar alternativas SaaS independientes.

| Módulo Enterprise | Por qué no tiene alternativa |
|:---|:---|
| **Odoo Studio** | Es un generador de código propietario de Odoo; requiere acceso al repositorio cerrado |
| **IoT Box** | Firmware + drivers propietarios para la caja de hardware física |
| **VoIP** | Integración propietaria con proveedores como Axivox |
| **AI / OCR** (Digitization) | Requiere el servicio cloud de Odoo IAP (In-App Purchase) |
| **Mobile App** | Aplicación nativa (iOS/Android) desarrollada por Odoo S.A. |
| **Odoo Spreadsheet/BI** | Motor de hojas de cálculo integrado con backend, código cerrado |
| **Social Marketing** | APIs de Facebook/LinkedIn/Instagram gestionadas por Odoo |
| **WhatsApp Business** | Integración oficial con la API de Meta, gestionada por Odoo |
| **Referrals** | Sistema gamificado propietario |
| **Shop Floor App** | Tablet UI propietaria para órdenes de manufactura |

---

## 13. Notas de Mantenimiento

- **Actualizado:** 2026-05-21 (v2 — todos los repos confirmados y en `oca_repos.conf`)
- **Versión Odoo de referencia:** 18.0 (producción) / 19.0 (en evaluación)
- **Fuente principal OCA:** https://github.com/OCA
- **Configuración activa:** `config/oca_repos.conf`
- **Guía de instalación:** `docs/install_considerations_odoo18.md`

> [!NOTE]
> Este documento debe actualizarse cada vez que se agregue un nuevo repo a `oca_repos.conf`.
> Para validar que un repo OCA tiene rama `18.0` activa:
> ```bash
> git ls-remote --heads https://github.com/OCA/<repo>.git | grep 18.0
> ```
