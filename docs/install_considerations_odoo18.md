# Guía de Instalación y Consideraciones para Odoo 18: Reemplazos Enterprise con la OCA

Esta guía detalla el proceso técnico **definitivo** de instalación, configuración y resolución de problemas críticos para desplegar las alternativas de la **Odoo Community Association (OCA)** en un entorno de producción utilizando **Odoo 18 Community** como línea base, adaptado específicamente para la infraestructura de **MBA Consultings**.

> [!IMPORTANT]
> **Versión Activa de Producción:** Esta guía corresponde a **Odoo 18.0**, que es la versión estable y completamente funcional en producción. La rama **18.0 de la OCA es madura y estable**, permitiendo sustituir las principales aplicaciones Enterprise sin adaptaciones manuales.

---

## 1. Prerrequisitos del Entorno (Odoo 18 Baseline)

Para garantizar la estabilidad de los módulos de la OCA y evitar conflictos de renderizado o autenticación, el entorno debe cumplir con la siguiente pila tecnológica activa:

- **Versión Base:** Odoo 18.0 Community.
- **Python:** Versión 3.12.
- **PostgreSQL:** Versión 16 o superior.
- **Proxy Inverso:** Nginx configurado con soporte para WebSockets (`longpolling`).
- **Archivo de Configuración:** `/etc/odoo18.conf`
- **Servicio del Sistema:** `odoo18.service`

### Estructura Real de Directorios en el Servidor

Los módulos comunitarios se aíslan dentro de un subdirectorio dedicado denominado `oca` para mantener el orden frente a los desarrollos a medida:

```bash
/opt/odoo/
├── odoo18/             # Código fuente core de Odoo 18
├── venv/               # Entorno virtual de Python (Python 3.12)
├── custom-addons/      # Desarrollos propios de MBA Consultings
└── oca/                # Repositorios oficiales de la OCA (Rama 18.0)
```

> [!NOTE]
> La ruta `/opt/odoo/oca/` es el estándar adoptado para esta infraestructura. **No mezclar** con `custom-addons` ni usar rutas ad-hoc como `oca-addons` o `temp_mis`.

---

## 2. Proceso General de Clonación y Permisos Masivos

Para evitar fallos de denegación de acceso (`Permission denied`) o discrepancias en la propiedad de los archivos, la descarga de los componentes debe realizarse bajo el usuario administrador (`root`) delegando inmediatamente los privilegios al usuario del demonio (`odoo:odoo`).

> [!CAUTION]
> **Error Común: `Permission denied` al hacer `cd` o `git clone`**
> Si al ingresar al directorio obtiene `-bash: cd: /opt/odoo/oca: Permission denied`, se debe a que el directorio es propiedad exclusiva del usuario `odoo`. Para resolverlo, ejecute los clones directamente como `root` y aplique `chown -R odoo:odoo` al final del bloque completo (ver Paso 1).

### Paso 1: Clonación limpia de la suite contable y visual (Rama 18.0)

Ejecute el siguiente bloque secuencial en su terminal para limpiar e instalar los repositorios necesarios con un historial optimizado (`--depth 1`):

```bash
# 1. Asegurar acceso como root
sudo -i

# 2. Descargar los módulos OCA para la versión 18.0
git clone --depth 1 --branch 18.0 https://github.com/OCA/account-financial-reporting.git /opt/odoo/oca/account-financial-reporting
git clone --depth 1 --branch 18.0 https://github.com/OCA/account-financial-tools.git     /opt/odoo/oca/account-financial-tools
git clone --depth 1 --branch 18.0 https://github.com/OCA/reporting-engine.git             /opt/odoo/oca/reporting-engine
git clone --depth 1 --branch 18.0 https://github.com/OCA/web.git                         /opt/odoo/oca/web
git clone --depth 1 --branch 18.0 https://github.com/OCA/server-tools.git                /opt/odoo/oca/server-tools
git clone --depth 1 --branch 18.0 https://github.com/OCA/server-ux.git                   /opt/odoo/oca/server-ux
git clone --depth 1 --branch 18.0 https://github.com/OCA/mis-builder.git                 /opt/odoo/oca/mis-builder-core
git clone --depth 1 --branch 18.0 https://github.com/OCA/server-brand.git                /opt/odoo/oca/server-brand

# Repositorios adicionales por área funcional
git clone --depth 1 --branch 18.0 https://github.com/OCA/contract.git                    /opt/odoo/oca/contract
git clone --depth 1 --branch 18.0 https://github.com/OCA/helpdesk.git                   /opt/odoo/oca/helpdesk
git clone --depth 1 --branch 18.0 https://github.com/OCA/dms.git                        /opt/odoo/oca/dms
git clone --depth 1 --branch 18.0 https://github.com/OCA/sign.git                       /opt/odoo/oca/sign
git clone --depth 1 --branch 18.0 https://github.com/OCA/account-reconcile.git          /opt/odoo/oca/account-reconcile
git clone --depth 1 --branch 18.0 https://github.com/OCA/stock-logistics-barcode.git    /opt/odoo/oca/stock-logistics-barcode
git clone --depth 1 --branch 18.0 https://github.com/OCA/manufacture.git                /opt/odoo/oca/manufacture
git clone --depth 1 --branch 18.0 https://github.com/OCA/purchase-workflow.git          /opt/odoo/oca/purchase-workflow
git clone --depth 1 --branch 18.0 https://github.com/OCA/sale-workflow.git              /opt/odoo/oca/sale-workflow

# 3. Aplicar de forma estricta los permisos de ejecución del sistema
chown -R odoo:odoo /opt/odoo/oca
chmod -R 755 /opt/odoo/oca
```

### Paso 2: Inyección de dependencias en el Entorno Virtual

Dado que los sistemas modernos restringen las instalaciones globales de Python (PEP 668), se debe apuntar directamente al ejecutable de `pip` contenido en el entorno aislado de la instancia:

```bash
/opt/odoo/odoo18/venv/bin/pip install -r /opt/odoo/oca/reporting-engine/requirements.txt
/opt/odoo/odoo18/venv/bin/pip install -r /opt/odoo/oca/server-tools/requirements.txt
/opt/odoo/odoo18/venv/bin/pip install -r /opt/odoo/oca/mis-builder-core/requirements.txt

# Dependencias adicionales para reportes Excel
/opt/odoo/odoo18/venv/bin/pip install pandas numpy xlsxwriter xlwt num2words python-magic
```

---

## 3. Configuración Crítica del Addons Path (`/etc/odoo18.conf`)

> [!CAUTION]
> **Lección Técnico-Operativa: El peligro de las carpetas fantasma (Error de Iconos Rotos)**
>
> Si se registra una ruta de directorio **inexistente** dentro del parámetro `addons_path` (por ejemplo, confundir el nombre técnico del módulo `account-usability` con una carpeta de repositorio física), el motor de Odoo 18 fallará internamente arrojando un `FileNotFoundError` al procesar peticiones estáticas.
>
> Al ocurrir esto, el servidor web interrumpe la carga de fuentes vectoriales. Como resultado, **toda la interfaz de Odoo perderá sus iconos nativos (lupas, flechas, engranajes), mostrando en su lugar cuadros vacíos corruptos**.
>
> **Regla de oro:** Antes de agregar una ruta al `addons_path`, verifique que el directorio existe físicamente con `ls /opt/odoo/oca/<nombre-repositorio>`.

### Configuración correcta del archivo

El parámetro `addons_path` debe escribirse en una **sola línea continua, separado por comas, sin espacios intermedios** y apuntando únicamente a directorios reales existentes en el disco:

```ini
[options]
addons_path = /opt/odoo/auto-addons,/opt/odoo/odoo18/odoo/addons,/opt/odoo/custom-addons,/opt/odoo/oca/account-financial-reporting,/opt/odoo/oca/account-financial-tools,/opt/odoo/oca/reporting-engine,/opt/odoo/oca/web,/opt/odoo/oca/server-tools,/opt/odoo/oca/server-ux,/opt/odoo/oca/mis-builder-core,/opt/odoo/oca/server-brand,/opt/odoo/oca/account-reconcile,/opt/odoo/oca/contract,/opt/odoo/oca/helpdesk,/opt/odoo/oca/dms,/opt/odoo/oca/sign,/opt/odoo/oca/manufacture,/opt/odoo/oca/stock-logistics-barcode
```

> [!IMPORTANT]
> Odoo lee cada directorio de forma secuencial. Incluya **únicamente** los repositorios que ya haya clonado. Agregue nuevas rutas a medida que incorpore más repositorios OCA, nunca antes de clonarlos.

---

## 4. Ejecución Segura de Comandos Core mediante Terminal

> [!WARNING]
> **Error Común: `psycopg2.OperationalError: Peer authentication failed for user "odoo"`**
>
> Si intenta ejecutar actualizaciones de módulos o tareas de mantenimiento directamente como usuario `root`, el servidor de bases de datos PostgreSQL rechazará la conexión por motivos de seguridad estricta (autenticación `peer`), exigiendo que el usuario del sistema coincida con el rol dueño de la base de datos.

### Comando correcto para forzar regeneración o actualizaciones

Para interactuar con el CLI de Odoo 18 sin levantar errores de autenticación, ejecute siempre bajo el usuario `odoo`:

```bash
# Forzar actualización del núcleo web y del branding desde la terminal
sudo -u odoo /opt/odoo/odoo18/venv/bin/python3 /opt/odoo/odoo18/odoo/odoo-bin \
  -c /etc/odoo18.conf \
  -d odoo18 \
  -u web,server_brand \
  --stop-after-init

# Reiniciar servicios para limpiar caché de sockets y Nginx
systemctl restart odoo18
systemctl restart nginx
```

### Monitoreo de logs en caliente

Siempre que realice cambios o instale nuevos módulos, mantenga una terminal secundaria con:

```bash
sudo tail -f /var/log/odoo/odoo18.log
```

---

## 5. Lista Maestra de Control e Instalación Web (Odoo 18)

Acceda a la interfaz gráfica en modo desarrollador (**Ajustes → Activar modo desarrollador**), vaya al menú **Apps (Aplicaciones)**, haga clic en **Update Apps List**, limpie el filtro por defecto de la barra de búsqueda e instale los componentes en la siguiente secuencia lógica:

### ✅ Base instalada y activa

- **[x] `report_xlsx`** (`reporting-engine`): Motor base para la inyección de hojas de cálculo. *(Instalado)*
- **[x] `account_financial_report`** (`account-financial-reporting`): Estructura base para balances dinámicos. *(Instalado)*

### 🚀 Prioridad Alta — Núcleo Financiero y de Conciliación

- **[ ] `date_range`** (`server-ux`): **Instalar Primero.** Permite estructurar trimestres y periodos comerciales que usarán los informes contables.
- **[ ] `mis_builder`** (`mis-builder-core`): **Instalar Segundo.** Motor para diseñar P&L y Balances personalizados mediante fórmulas de cuentas.
- **[ ] `account_usability`** (`account-financial-tools`): **Instalar Tercero.** Libera todos los menús ocultos de la versión Community y **desbloquea el Dashboard de diarios contables interactivo** (equivalente visual al de Odoo Enterprise).
- **[ ] `account_reconciliation_widget`** (`account-reconcile`): Restaura la pantalla de conciliación bancaria lado a lado (factura vs extracto) eliminada en Community.
- **[ ] `account_tax_balance`** (`account-financial-tools`): Añade vistas avanzadas de auditoría fiscal.
- **[ ] `account_asset_management`** (`account-financial-tools`): Controla las tablas de depreciación de bienes y genera asientos de amortización automáticos.

### ⚙️ Fase 2 — Framework del Sistema y Optimizadores de UX

- **[ ] `server_brand`** (`server-brand`): **Instalar Cuarto.** Elimina todos los banners publicitarios, advertencias de vencimiento y enlaces de actualización Enterprise del backend.
- **[ ] `base_technical_features`** (`server-ux`): Otorga mayor visibilidad y opciones técnicas directamente en la interfaz de usuario.

### 💼 Fase 3 — Operaciones Comerciales y Automatización

- **[ ] `contract`** (`contract`): Gestiona la facturación recurrente, suscripciones y renovaciones automáticas de contratos.
- **[ ] `dms`** (`dms`): Activa un sistema de gestión documental (DMS) para almacenar directorios, expedientes y documentos legales.

### 🎫 Fase 4 — Soporte y Mesa de Ayuda

- **[ ] `helpdesk_mgmt`** (`helpdesk`): Gestor de tickets y soporte independiente de las limitaciones de la versión Enterprise.
- **[ ] `helpdesk_mgmt_sla`** (`helpdesk`): Añade acuerdos de nivel de servicio (SLA) a los tickets.

### 📦 Fase 5 — Logística Especializada y Manufactura (Dejar para el final)

- **[ ] `stock_barcode`** (`stock-logistics-barcode`): Activar solo si utiliza lectores físicos de códigos de barras para procesar operaciones de almacén.
- **[ ] `base_tier_validation`** (`server-ux`): Motor base para aprobaciones multi-nivel en compras, ventas o facturas.
- **[ ] Extensiones MRP** (`manufacture`): Activar solo si requiere personalización profunda en listas de materiales (BOM) y rutas de producción.

> [!TIP]
> **Consejo Profesional durante la Instalación:**
> Si algún módulo da una advertencia de dependencia faltante, tome nota de su nombre técnico. Seguramente se encuentra en los repositorios `server-ux` o `account-financial-tools` que ya tiene en el servidor. Búsquelo en la lista de Apps, instálelo primero y reanude la secuencia.

---

## 6. Matriz Maestra de Equivalencias Técnicas (Odoo 18.0)

A diferencia de las versiones en desarrollo, la rama **18.0 de la OCA es completamente madura y estable**, lo que permite sustituir las principales aplicaciones de la licencia comercial de manera robusta sin necesidad de programar adaptaciones manuales.

### Suite Contable y Financiera

| Aplicación Odoo Enterprise | Módulo OCA Reemplazo (v18) | Repositorio | Capacidad Resuelta |
| :--- | :--- | :--- | :--- |
| **Accounting Dashboard** | `account_usability` | `account-financial-tools` | Genera las tarjetas interactivas de diarios contables con gráficos, flujos de efectivo y sumarios rápidos. |
| **Financial Reports (P&L / Balance)** | `mis_builder` | `mis-builder-core` | Permite estructurar estados financieros dinámicos basados en KPI con comparación de periodos en tiempo real. |
| **Reconciliation Widget** | `account_reconciliation_widget` | `account-reconcile` | Devuelve la pantalla de conciliación bancaria lado a lado (factura vs extracto) eliminada en Community. |
| **Excel Export Dynamic** | `report_xlsx` | `reporting-engine` | Habilita la exportación nativa de cualquier reporte financiero a formato Excel nativo. |
| **Asset Management (Activos Fijos)** | `account_asset_management` | `account-financial-tools` | Controla las tablas de depreciación de bienes y genera asientos de amortización automáticos por periodos. |

### Logística, Manufactura e Inventarios

| Aplicación Odoo Enterprise | Módulo OCA Reemplazo (v18) | Repositorio | Capacidad Resuelta |
| :--- | :--- | :--- | :--- |
| **Barcode App** | `stock_barcode` | `stock-logistics-barcode` | Transforma cualquier smartphone en un escáner para recepciones, pickings y conteos de stock. |
| **PLM (Product Lifecycle)** | `mrp_bom_tracking` + `mrp_bom_change_instruction` | `manufacture` | Control de órdenes de cambio de ingeniería (ECO) y versionamiento histórico de BOM. |
| **Quality Control** | `quality_control_oca` | `manufacture` | Añade puntos de control de calidad obligatorios u opcionales en operaciones de inventario o manufactura. |

### Servicios, Comercial y Automatización

| Aplicación Odoo Enterprise | Módulo OCA Reemplazo (v18) | Repositorio | Capacidad Resuelta |
| :--- | :--- | :--- | :--- |
| **Subscription Management** | `contract` + `contract_sale` | `contract` | Automatiza los ciclos de facturación recurrentes, contratos de servicios y control de renovaciones. |
| **Helpdesk (Mesa de Soporte)** | `helpdesk_mgmt` | `helpdesk` | Gestión completa de incidencias con SLA, asignación por equipos y portal de clientes. |
| **Studio App** | `web_edit_view` + `base_custom_fields` | `web` / `server-tools` | Edición visual interactiva de formularios y adición de campos desde el cliente web. |
| **Document Management (DMS)** | `dms` | `dms` | Sistema jerárquico de carpetas para almacenar facturas fiscales, contratos firmados y expedientes. |
| **Digital Sign (Firma Electrónica)** | `sign_oca` | `sign` | Recolección de firmas digitales simples mediante validación por correo electrónico y bitácora por IP. |
| **Approvals Multi-nivel** | `base_tier_validation` | `server-ux` | Motor base para aprobaciones escalonadas en compras, ventas y facturas. |

---

## 7. Consideraciones e Instalación Específica por Reemplazo

---

### A. Contabilidad Avanzada (`account_accountant` equivalent)

Este reemplazo requiere clonar repositorios adicionales de la OCA:

- **Repositorios:** `account-financial-reporting`, `account-financial-tools`, `account-reconcile`, `server-tools`, `reporting-engine`, `mis-builder-core`.

```bash
# Verificar que los repos ya están clonados (deben existir desde el Paso 1)
ls /opt/odoo/oca/

# Si falta alguno, clonar individualmente:
sudo -i
git clone --depth 1 --branch 18.0 https://github.com/OCA/account-reconcile.git /opt/odoo/oca/account-reconcile
chown -R odoo:odoo /opt/odoo/oca/account-reconcile
```

- **Módulos clave a instalar en Odoo (en orden):**
  1. `date_range` — prerrequisito de mis_builder.
  2. `mis_builder` — informes dinámicos avanzados.
  3. `account_asset_management` — gestión de activos fijos.
  4. `account_reconciliation_widget` — widget interactivo de conciliación bancaria.

- **Consideración:** `mis_builder` no viene pre-configurado. El contador debe configurar las fórmulas para los estados financieros de Panamá (P&L y Balance General) desde la interfaz de Odoo.

---

### B. Suscripciones y Contratos (`sale_subscription` equivalent)

- **Repositorio:** `OCA/contract`
- **Módulos clave:** `contract`, `contract_sale`.
- **Consideración:** Debe enlazar las plantillas de contrato con productos marcados como "Servicio". Depende de un Cron automático de Odoo para generar los borradores de factura según la frecuencia definida (mensual, semanal, etc.).

---

### C. Helpdesk / Soporte (`helpdesk` equivalent)

- **Repositorio:** `OCA/helpdesk`
- **Módulos clave:** `helpdesk_mgmt`, `helpdesk_mgmt_sla`.
- **Consideración:** Requiere configurar alias de correo electrónico corporativos (ej. `soporte@mbaconsultings.com`) para que los correos entrantes se conviertan automáticamente en tickets de soporte.

---

### D. Documentos / DMS (`documents` equivalent)

- **Repositorio:** `OCA/dms`
- **Módulos clave:** `dms`, `dms_directory`.
- **Dependencias de Python:**
  ```bash
  /opt/odoo/odoo18/venv/bin/pip install python-magic
  ```
- **Consideración:** Se debe configurar el almacenamiento físico de los adjuntos en el filestore del servidor de Odoo, o configurar un conector S3 si el volumen de archivos es excesivamente grande.

---

### E. Firma Electrónica (`sign` equivalent)

- **Repositorio:** `OCA/sign`
- **Módulo clave:** `sign_oca`.
- **Consideración:** La validez legal de las firmas en Panamá requiere cumplimiento de normativas de firma electrónica simple o calificada (Dirección de Firma Electrónica del Registro Público de Panamá). `sign_oca` proporciona una firma simple basada en logs de auditoría por IP/Email.

---

### F. Código de Barras / Inventario (`stock_barcode` equivalent)

- **Repositorio:** `OCA/stock-logistics-barcode`
- **Módulo clave:** `stock_barcode`.
- **Consideración:** Requiere configurar formatos de GS1 o códigos de barras sencillos en las fichas de los productos y ubicaciones de inventario.

---

### G. Aprobaciones Multi-nivel (`approvals` equivalent)

- **Repositorio:** `OCA/server-ux`
- **Módulo base:** `base_tier_validation`.

> [!IMPORTANT]
> `base_tier_validation` es el motor base. Para aplicarlo a compras, ventas o facturas, también se deben instalar los módulos específicos:
> - `purchase_tier_validation` → `OCA/purchase-workflow`
> - `sale_tier_validation` → `OCA/sale-workflow`
>
> Todos deben estar en la rama `18.0`.

---

### H. PLM - Ciclo de Vida del Producto (`mrp_plm` equivalent)

- **Repositorio:** `OCA/manufacture`
- **Módulos clave:** `mrp_bom_tracking`, `mrp_bom_change_instruction`.
- **Consideración:** Recomendado para procesos de manufactura discretos donde los ingenieros necesitan documentar los cambios en recetas industriales sin perder el histórico.

---

### I. Control de Calidad (`quality_control` equivalent)

- **Repositorio:** `OCA/manufacture` *(mismo repositorio del Paso H — no clonar nuevamente)*.
- **Módulo clave:** `quality_control_oca`.
- **Consideración:** Requiere configurar los Puntos de Medida de Calidad asociados a las operaciones de ruta de producción o de recepciones de almacén.

---

### J. Branding y Eliminación de Banners Enterprise

- **Repositorio:** `OCA/server-brand`
- **Módulo clave:** `server_brand`.

```bash
# Forzar actualización del branding desde la terminal (como usuario odoo)
sudo -u odoo /opt/odoo/odoo18/venv/bin/python3 /opt/odoo/odoo18/odoo/odoo-bin \
  -c /etc/odoo18.conf \
  -d odoo18 \
  -u web,server_brand \
  --stop-after-init

systemctl restart odoo18
systemctl restart nginx
```

---

## 8. Buenas Prácticas de Mantenimiento para Odoo 18 Community

1. **Monitoreo de Logs en Caliente:** Al realizar cambios en la interfaz o instalar nuevos módulos, mantenga una terminal secundaria corriendo:
   ```bash
   sudo tail -f /var/log/odoo/odoo18.log
   ```

2. **Manejo de Caché Visual:** Los módulos OCA modifican la hoja de estilos global (`web.assets_backend`). Si tras una instalación la pantalla muestra anomalías de iconos o estilos:
   - Ejecute **"Regenerate Assets Bundles"** desde el menú del Escarabajo (Modo Desarrollador).
   - Aplique una limpieza total del caché en el navegador web (Ctrl+Shift+R / Cmd+Shift+R).

3. **Aislamiento de Código de Terceros:** Nunca mezcle módulos descargados de la tienda de Odoo dentro de la ruta `/opt/odoo/oca/`. Mantenga el orden separando estrictamente los repositorios administrados por Git para facilitar las actualizaciones periódicas vía `git pull`.

4. **Actualización de Repositorios OCA:** Para actualizar un repositorio OCA a la última versión de la rama `18.0`:
   ```bash
   sudo -u odoo git -C /opt/odoo/oca/account-financial-reporting pull
   systemctl restart odoo18
   ```

5. **Verificación de módulos activos:** Antes de arrancar Odoo con nuevas rutas en `addons_path`, verifique que todos los directorios listados existen:
   ```bash
   grep addons_path /etc/odoo18.conf | tr ',' '\n' | xargs -I{} ls -d {} 2>&1
   ```
   Cualquier línea con error `No such file or directory` indica una ruta fantasma que causará el error de iconos rotos.
