# Equivalencia de Módulos: Odoo Enterprise vs. OCA (Community)

Este documento sirve como guía para evaluar las alternativas de código abierto de la **Odoo Community Association (OCA)** frente a las aplicaciones propietarias de **Odoo Enterprise**. 

La combinación de Odoo Community con módulos de la OCA permite construir un ERP robusto y adaptado a las necesidades de la empresa sin incurrir en costos de licenciamiento por usuario, aunque requiere mayor planificación en la arquitectura técnica y mantenimiento.

---

## Arquitectura de Solución: Monolito Enterprise vs. Ecosistema OCA

La diferencia fundamental entre ambas ediciones radica en el enfoque de integración:

```mermaid
graph TD
    subgraph Enterprise ["Odoo Enterprise (Monolito Propietario)"]
        EE[Núcleo Enterprise] --> E_Acc[Advanced Accounting]
        EE --> E_Doc[Documents]
        EE --> E_Studio[Odoo Studio]
        EE --> E_Barcode[Stock Barcode]
        EE --> E_Sign[Sign]
    end

    subgraph Community ["Odoo Community + OCA (Modular y Open Source)"]
        CE[Núcleo Community] --> CE_Acc[account-financial-tools]
        CE --> CE_Rep[mis-builder]
        CE --> CE_Doc[dms (Document Management)]
        CE --> CE_Bar[stock-logistics-barcode]
        CE --> CE_Val[base_tier_validation]
    end
```

---

## Tabla de Equivalencias: Enterprise vs. OCA

A continuación se detalla la correspondencia entre los módulos Enterprise más comunes y sus contrapartes en la OCA:

| Aplicación Enterprise | Módulo / Repositorio OCA Recomendado | Funcionalidad Equivalente | Limitaciones / Consideraciones Importantes |
| :--- | :--- | :--- | :--- |
| **Contabilidad Avanzada** (`account_accountant`) | `mis_builder` (Rep: `mis-builder`) <br> `account_asset_management` (Rep: `account-financial-tools`) <br> `account_reconciliation_widget` (Rep: `account-reconciliation`) | Informes financieros personalizables (P&L, Balances), control de activos fijos, amortizaciones automáticas y conciliación bancaria interactiva. | La conciliación automática avanzada (OCR/AI) no tiene reemplazo open-source directo out-of-the-box. La conciliación bancaria en Community requiere el widget manual clásico de la OCA. |
| **Suscripciones y Contratos** (`sale_subscription`) | `contract` <br> `contract_payment` <br> (Rep: `contract`) | Facturación recurrente automatizada basada en plantillas de contrato. Soporta pre-pago, post-pago e incrementos automáticos de tarifa. | No incluye el panel de métricas de ingresos recurrentes (MRR/ARR) nativo de Enterprise, aunque se puede modelar con `mis_builder`. |
| **Helpdesk / Soporte** (`helpdesk`) | `helpdesk_mgmt` <br> `helpdesk_mgmt_sla` <br> (Rep: `helpdesk`) | Sistema completo de tickets, estados personalizables, políticas de SLA (Service Level Agreements) y portal web de soporte para clientes. | La interfaz visual es más técnica y requiere ensamblar múltiples submódulos para igualar la experiencia del usuario (UX) de Enterprise. |
| **Documentos (DMS)** (`documents`) | `dms` <br> `dms_directory` <br> (Rep: `dms`) | Directorio centralizado de documentos, carpetas dinámicas, etiquetado, accesos y permisos por grupo de usuarios. | Carece de la funcionalidad nativa de Enterprise para dividir/unir PDFs de forma interactiva y la integración con OCR para facturas de proveedores. |
| **Firma Electrónica** (`sign`) | `sign_oca` <br> `base_sign` <br> (Rep: `sign`) | Creación de plantillas de documentos y envío de solicitudes de firma electrónica a clientes/proveedores con registro de auditoría. | Menos fluidez en el arrastrar y soltar (drag-and-drop) interactivo de campos dinámicos sobre el PDF en comparación con la app nativa. |
| **Código de Barras / Inventario** (`stock_barcode`) | `stock_barcodeterminal` <br> `stock_logistics_barcode` <br> (Rep: `stock-logistics-barcode`) | Interfaz optimizada para escaneo de códigos de barra en recepciones, transferencias internas, preparación de pedidos (picking) e inventarios. | Diseñado principalmente para terminales de mano o escáneres industriales; la interfaz móvil adaptativa nativa de Enterprise es visualmente más moderna. |
| **Aprobaciones Multi-nivel** (`approvals`) | `base_tier_validation` <br> (Rep: `server-ux`) | Motor de flujos de aprobación multi-nivel configurables dinámicamente por monto, departamento o condiciones lógicas. | Es un módulo base de infraestructura. Requiere instalar extensiones específicas por modelo (ej. `purchase_tier_validation`, `sale_tier_validation`). |
| **PLM (Ciclo de Vida de Producto)** (`mrp_plm`) | `mrp_bom_tracking` <br> `mrp_bom_change_instruction` <br> (Rep: `manufacture`) | Historial de versiones en Listas de Materiales (BOMs), control de cambios e instrucciones de ingeniería. | La gestión de Órdenes de Cambio de Ingeniería (ECO) con flujos visuales tipo Kanban es más básica en la OCA. |
| **Automatización de Marketing** (`marketing_automation`) | `mass_mailing_partner` <br> + Reglas automatizadas nativas <br> (Rep: `social`) | Campañas de correo masivo programadas, flujos basados en eventos de clientes y segmentación de contactos. | Carece del diseñador de campañas visual dinámico (tipo drag-and-drop de diagramas de flujo) que tiene Enterprise. |
| **Control de Calidad** (`quality_control`) | `mrp_qc` <br> `quality_control_oca` <br> (Rep: `manufacture`) | Puntos de control de calidad en recepciones o manufactura, alertas de calidad y generación de pruebas de conformidad. | Integración menos directa con las tabletas de operador de producción nativas de Odoo Enterprise. |

---

## Análisis de Viabilidad y Decisiones Estratégicas

> [!NOTE]
> **Total Cost of Ownership (TCO):**
> Elegir Community + OCA elimina el costo de licencias de Odoo, pero traslada ese costo al desarrollo, pruebas y mantenimiento técnico. Si el número de usuarios es bajo (<15-20), Enterprise suele ser más económico a largo plazo. Para grandes volúmenes de usuarios, OCA es sumamente rentable.

> [!IMPORTANT]
> **El caso de Odoo Studio:**
> **No existe un reemplazo directo para Odoo Studio** en el ecosistema OCA. Studio permite modificar pantallas, campos e informes sin escribir código. En la edición Community, todas estas modificaciones deben realizarse mediante código técnico (XML/Python), lo que requiere desarrolladores capacitados.

> [!WARNING]
> **Garantía de Migración (Upgrades):**
> Odoo Enterprise incluye el soporte para migrar la base de datos de una versión a otra (ej. v17 a v18) de manera gratuita. En Community + OCA, la migración depende de **OpenUpgrade** (un proyecto comunitario de la OCA) y requiere un proceso técnico manual para migrar los datos de cada módulo extra instalado.
