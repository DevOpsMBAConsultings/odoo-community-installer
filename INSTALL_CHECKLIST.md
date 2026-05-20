# Odoo Community Install – Qué hace el script (Checklist)

Usa esta lista para ver todo lo que hace el script y verificar que nada falta tras una instalación limpia.

> **Versión por defecto: Odoo 18** (estable en producción). Puedes instalar Odoo 19 indicándolo al inicio del script.

---

## Antes de ejecutar

| Ítem | Requerido | Notas |
|------|-----------|-------|
| Ubuntu 24.04 server | ✅ | VM limpia o bare metal |
| Nombre de dominio | ✅ | e.g. `erp.example.com` (para Nginx + SSL) |
| Email para Let's Encrypt | ✅ | Notificaciones y renovación SSL |
| (Opcional) SSL storage remoto | — | S3/R2 o URL para backup/restore de certificados |
| (Opcional) `ALLOW_ODOO_PORT=1` | — | Solo si quieres el puerto 8069 abierto (sin Nginx) |

---

## Pasos de instalación (en orden)

| Paso | Script | Qué hace |
|------|--------|----------|
| 00 | `00_system_update.sh` | `apt update` / `apt upgrade` |
| 01 | `01_dependencies.sh` | Paquetes del sistema: git, wget, unzip, python3, build-essential, libpq-dev, libxml2-dev, libjpeg-dev, **libmagickwand-dev**, nodejs, npm, rtlcss, etc. |
| 02 | `02_postgres.sh` | Instalar PostgreSQL, crear usuario `odoo` |
| 02 | `02_wkhtmltopdf.sh` | Instalar wkhtmltopdf (versión parcheada para reportes PDF) |
| 03 | `03_odoo_user_and_folders.sh` | Crear usuario `odoo`, `/opt/odoo/`, `/opt/odoo/oca/`, `/var/lib/odoo`, `/var/log/odoo` |
| 04 | `04_clone_odoo.sh` | Clonar fuente de Odoo (e.g. 18) en `/opt/odoo/odoo18/odoo` |
| 05 | `05_python_venv.sh` | Python venv en `/opt/odoo/odoo18/venv` |
| 06 | `06_python_dependencies.sh` | Instalar `requirements.txt` de Odoo + **wand** |
| 07 | `07_odoo_config.sh` | Generar `/etc/odoo18.conf` desde template (DB, admin password, addons_path con rutas OCA incluidas) |
| 07 | `07_systemd_service.sh` | Crear y habilitar el servicio systemd `odoo18` |
| **08a** | **`08_clone_oca_addons.sh`** | **Ver OCA Addons (08a) abajo** |
| 08b | `08_clone_custom_addons.sh` | **Ver Custom Addons (08b) abajo** |
| 09 | `09_init_database.sh` | **Ver Init database (09) abajo** |
| 10 | `10_ufw_firewall.sh` | UFW: permitir OpenSSH, 80, 443; opcionalmente 8069 si `ALLOW_ODOO_PORT=1` |
| 11 | `11_ngnix.sh` | Nginx reverse proxy, SSL Let's Encrypt (certbot), proxy a Odoo en 127.0.0.1:8069 |
| — | `post/00_health_check.sh` | Verificar servicio, wkhtmltopdf, puertos, addons_path, addons |
| — | `post/10_summary.sh` | Resumen de instalación |

---

## OCA Addons (08a) – en detalle

**Script:** `install/08_clone_oca_addons.sh`

Este script se ejecuta **solo si el usuario confirmó instalar módulos OCA** durante las preguntas iniciales de `install.sh`.

| Ítem | Detalle |
|------|---------|
| **Fuente** | Variable `OCA_REPOS_LIST` (URLs, una por línea) calculada por `install.sh` desde `config/oca_repos.conf` |
| **Rama** | `{ODOO_VERSION}.0` (e.g. `18.0`). Si no existe, usa la rama por defecto |
| **Destino** | `/opt/odoo/oca/<repo-name>/` — separado de los addons propios |
| **addons_path** | Cada `/opt/odoo/oca/<repo>` ya fue inyectado en `/etc/odoo{VERSION}.conf` por el paso 07 vía `{{OCA_ADDON_PATHS}}` |
| **Python deps** | Instala `requirements.txt` de cada repo usando el venv de Odoo |
| **Permisos** | `chown -R odoo:odoo /opt/odoo/oca && chmod -R 755 /opt/odoo/oca` |

**Qué ocurre si el usuario dice NO a OCA:**
- `OCA_REPOS_LIST` queda vacío → el script detecta esto y sale limpiamente sin hacer nada
- `OCA_ADDON_PATHS` queda vacío → el template genera `addons_path` sin rutas OCA

**addons_path resultante en `/etc/odoo18.conf` (con OCA):**
```ini
addons_path = /opt/odoo/auto-addons,/opt/odoo/odoo18/odoo/addons,/opt/odoo/oca/account-financial-reporting,/opt/odoo/oca/account-financial-tools,...,/opt/odoo/custom-addons
```

**Repos OCA disponibles para Odoo 18** (definidos en `config/oca_repos.conf`):

| Repositorio OCA | Equivalente Enterprise |
|---|---|
| `account-financial-reporting` | Reportes financieros (trial balance, etc.) |
| `account-financial-tools` | Dashboard contable, activos fijos, `account_usability` |
| `account-reconcile` | Widget de conciliación bancaria |
| `reporting-engine` | Exportación Excel (`report_xlsx`) |
| `web` | Herramientas web adicionales |
| `server-tools` | Herramientas técnicas del servidor |
| `server-ux` | `date_range`, `base_tier_validation`, UX |
| `server-brand` | Elimina banners y advertencias Enterprise |
| `mis-builder` | P&L y Balance dinámico con fórmulas de cuentas |
| `contract` | Suscripciones y facturación recurrente |
| `helpdesk` | Mesa de soporte con SLA |
| `dms` | Sistema de gestión documental |
| `sign` | Firma electrónica simple |
| `stock-logistics-barcode` | App de código de barras para inventario |
| `manufacture` | PLM y Control de Calidad MRP |
| `purchase-workflow` | Aprobaciones multi-nivel en compras |
| `sale-workflow` | Aprobaciones multi-nivel en ventas |

Para añadir repos o soportar otra versión: edita `config/oca_repos.conf`.

---

## Custom Addons (08b) – en detalle

**Script:** `install/08_clone_custom_addons.sh`

| Ítem | Detalle |
|------|---------|
| **Fuente** | `custom_addons.txt` en la raíz del repo (para repos propios/privados) |
| **Destino** | `/opt/odoo/custom-addons/` |
| **Proceso** | Lee `custom_addons.txt` línea por línea, clona cada repo, escanea módulos (`__manifest__.py`), crea symlinks en `/opt/odoo/auto-addons/`, instala `requirements.txt` si existe |
| **Autenticación** | Usa `GITHUB_TOKEN` si se proporcionó, o SSH para repos privados |
| **Permisos** | `chown -R odoo:odoo /opt/odoo/custom-addons` |

**Separación de responsabilidades:**

| Directorio | Propósito |
|---|---|
| `/opt/odoo/oca/` | Repos oficiales OCA — gestionados automáticamente por `install.sh` + `08_clone_oca_addons.sh` |
| `/opt/odoo/custom-addons/` | Tus módulos propios/privados — gestionados vía `custom_addons.txt` |
| `/opt/odoo/auto-addons/` | Symlinks a módulos individuales detectados en `custom-addons` (generado automáticamente) |

---

## Init database (09) – en detalle

**Script:** `install/09_init_database.sh`

**Variables de entorno:**

| Variable | Por defecto | Significado |
|----------|-----------|-----------  |
| `DB_NAME` | `odoo${ODOO_VERSION}` | e.g. `odoo18` |
| `ODOO_LANG` | `es_PA` | Idioma cargado con base |
| `ODOO_COUNTRY_CODE` | `PA` | País por defecto de la empresa |
| `ODOO_WITHOUT_DEMO` | `1` | Sin datos de demo |
| `ODOO_INIT_MODULES` | *(vacío)* | Si se define: solo estos módulos. Si no: ver abajo. |
| `ODOO_EXTRA_MODULES` | `sale,purchase,crm,stock,contacts,account` | Módulos estándar de Odoo siempre añadidos. |

**Cómo se construye `INIT_MODULES`:**

1. Escanea `/opt/odoo/custom-addons/`: cada directorio con `__manifest__.py` se agrega.
2. Si la lista queda vacía → `INIT_MODULES=l10n_pa`.
3. Agrega `,${ODOO_EXTRA_MODULES}` (si no está vacío).

> Los módulos OCA **no** se instalan automáticamente en este paso — se hacen disponibles vía `addons_path` y el usuario los instala desde la UI de Odoo (Apps → Update Apps List).

**Flow A – Base de datos ya existe:**

1. `set_default_country.py`: país de empresa + default en `res.partner`.
2. Detiene Odoo; instala módulos faltantes con `odoo-bin -i "$INIT_MODULES"`.
3. Si `ODOO_COUNTRY_CODE=PA`: ejecuta scripts de impuestos PA (Exento 0%, ITBMS 10%/15%).
4. Si PA: diarios FE/NC, posiciones fiscales, provincias PA, términos de pago PA.
5. Inicia Odoo.

**Flow B – Base de datos nueva (primera vez):**

1. Verifica `/var/lib/odoo`, propiedad y permisos.
2. Si no existe la BD: `createdb -O odoo $DB_NAME`.
3. Detiene Odoo.
4. Init base: `odoo-bin -i base --without-demo --load-language=$LANG_CODE`.
5. `set_default_country.py`.
6. Instala todos los módulos: `odoo-bin -i "$INIT_MODULES"`.
7. Si PA: scripts de impuestos, diarios, provincias, términos de pago.
8. Inicia Odoo.

**Scripts en `install/scripts/`:**

- `set_default_country.py` — país empresa + default `res.partner.country_id`
- `set_default_taxes_pa.py` — Exento 0% (venta + compra) para PA
- `set_default_sales_journal.py` — Diario FE para PA
- `set_default_credit_notes_journal.py` — Diario NC para PA
- `set_fiscal_position_exento.py` — Posición fiscal Exento de impuestos
- `set_fiscal_position_retencion.py` — Posición fiscal Retención de impuestos
- `set_tax_retencion_impuestos.py` — Impuesto Retención (7%)
- `set_panama_states.py` — Provincias/comarcas PA-01 .. PA-13
- `set_itbms_taxes_pa.py` — ITBMS 10% y 15% Ventas/Compras
- `set_payment_terms_pa.py` — Términos de pago estándar de Panamá

---

## Verificación post-instalación

| Verificación | Cómo hacerlo |
|---|---|
| Servicio Odoo activo | `sudo systemctl status odoo18` |
| Login funciona | Abrir `https://TU_DOMINIO` |
| Apps instaladas | Menú Apps: Ventas, Compras, CRM, Inventario, Contactos, Facturación |
| País por defecto (PA) | Ajustes / Empresa / País; nuevo contacto: país por defecto |
| Impuestos 0% (si PA) | Facturación → Configuración → Impuestos: "Exento 0% Venta", "Exento 0% Compra" |
| addons_path incluye OCA | `grep addons_path /etc/odoo18.conf` debe mostrar rutas `/opt/odoo/oca/*` |
| OCA repos clonados | `ls /opt/odoo/oca/` debe listar todos los repos seleccionados |
| Rutas no fantasma | `grep addons_path /etc/odoo18.conf \| tr ',' '\n' \| xargs -I{} ls -d {} 2>&1` — ninguna línea con "No such file" |
| UFW | `sudo ufw status`: 22, 80, 443 (y 8069 solo si `ALLOW_ODOO_PORT=1`) |
| Nginx + SSL | HTTPS funciona; certificado de Let's Encrypt |

---

## Opcional (ejecutar manualmente si se necesita)

| Ítem | Cuándo / Cómo |
|------|---------------|
| Instalar módulos OCA en UI | Apps → Update Apps List → buscar e instalar en el orden recomendado en `docs/install_considerations_odoo18.md` |
| Actualizar repos OCA | `sudo -u odoo git -C /opt/odoo/oca/<repo> pull && systemctl restart odoo18` |
| Diario FE, NC, posiciones fiscales PA | Si PA: el paso 09 los ejecuta automáticamente. Para BD existente: correr scripts en `install/scripts/`. |
| Actualizar lista de Apps en UI | Apps → Update Apps List (si añades nuevos addons después) |

---

## Si algo falla

- **No se puede llegar a Odoo**: Abrir 8069 en UFW si no usas Nginx: `sudo ufw allow 8069/tcp && sudo ufw reload`.
- **Módulo no encontrado**: Verificar que el repo está en `/opt/odoo/oca/` o `/opt/odoo/custom-addons/` y que su ruta está en `addons_path`.
- **Error de instalación de módulo**: Ver output del paso 09 o volver a correr `09_init_database.sh`.
- **Iconos rotos en Odoo (después de instalar OCA)**: Ejecutar "Regenerate Assets Bundles" desde el modo desarrollador y limpiar caché del navegador (Ctrl+Shift+R).
- **Health check**: Correr `post/00_health_check.sh` y corregir los problemas reportados.

---

*Documentación actualizada para reflejar el soporte de módulos OCA con selección automática por versión.*
