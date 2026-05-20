## 2. Proceso General de Clonación y Permisos Masivos

Para evitar fallos de denegación de acceso (`Permission denied`) o discrepancias en la propiedad de los archivos, la descarga de los componentes debe realizarse bajo el usuario administrador (`root`) delegando inmediatamente los privilegios al usuario del demonio (`odoo:odoo`).

### Paso 1: Clonación limpia de la suite contable y visual (Rama 18.0)

Ejecute el siguiente bloque secuencial en su terminal para limpiar e instalar los repositorios necesarios con un historial optimizado (`--depth 1`):

```bash
# 1. Asegurar acceso como root
sudo -i

# 2. Descargar la artillería de módulos OCA para la versión 18.0
git clone --depth 1 --branch 18.0 [https://github.com/OCA/account-financial-reporting.git](https://github.com/OCA/account-financial-reporting.git) /opt/odoo/oca/account-financial-reporting
git clone --depth 1 --branch 18.0 [https://github.com/OCA/account-financial-tools.git](https://github.com/OCA/account-financial-tools.git) /opt/odoo/oca/account-financial-tools
git clone --depth 1 --branch 18.0 [https://github.com/OCA/reporting-engine.git](https://github.com/OCA/reporting-engine.git) /opt/odoo/oca/reporting-engine
git clone --depth 1 --branch 18.0 [https://github.com/OCA/web.git](https://github.com/OCA/web.git) /opt/odoo/oca/web
git clone --depth 1 --branch 18.0 [https://github.com/OCA/server-tools.git](https://github.com/OCA/server-tools.git) /opt/odoo/oca/server-tools
git clone --depth 1 --branch 18.0 [https://github.com/OCA/server-ux.git](https://github.com/OCA/server-ux.git) /opt/odoo/oca/server-ux
git clone --depth 1 --branch 18.0 [https://github.com/OCA/mis-builder.git](https://github.com/OCA/mis-builder.git) /opt/odoo/oca/mis-builder-core
git clone --depth 1 --branch 18.0 [https://github.com/OCA/server-brand.git](https://github.com/OCA/server-brand.git) /opt/odoo/oca/server-brand

# 3. Aplicar de forma estricta los permisos de ejecución del sistema
chown -R odoo:odoo /opt/odoo/oca
chmod -R 755 /opt/odoo/oca
```

### Paso 2: Inyección de dependencias en el Entorno Virtual

Dado que los sistemas modernos restringen las instalaciones globales de Python (PEP 668), se debe apuntar directamente al ejecutable de `pip` contenido en el entorno aislado de la instancia:

```bash
/opt/odoo/odoo18/venv/bin/pip install -r /opt/odoo/oca/reporting-engine/requirements.txt
/opt/odoo/odoo18/venv/bin/pip install -r /opt/odoo/oca/server-tools/requirements.txt
```

## 3. Configuración Crítica del Addons Path (`/etc/odoo18.conf`)

> [!CAUTION] **Lección Técnico-Operativa: El peligro de las carpetas fantasma (Error de Iconos Rotos ☐)**`☐` Si se registra una ruta de directorio inexistente dentro del parámetro `addons_path` (como por ejemplo confundir el nombre técnico del módulo `account-usability` con una carpeta de repositorio física), el motor de Odoo 18 fallará internamente arrojando un `FileNotFoundError` al procesar peticiones estáticas.
> 
> Al ocurrir esto, el servidor web interrumpe la carga de fuentes vectoriales (`odoo_ui_icons.woff2` y `fontawesome-webfont.woff2`). Como resultado, **toda la interfaz de Odoo perderá sus iconos nativos (lupas, flechas, engranajes), mostrando en su lugar cuadros vacíos corruptos con el símbolo ☐ (\ue01f).**`☐``\ue01f`

### Configuración correcta del archivo

El parámetro `addons_path` debe escribirse en una **sola línea continua, separado por comas, sin espacios intermedios** y apuntando únicamente a directorios reales existentes en el disco:

```ini
[options]
addons_path = /opt/odoo/auto-addons,/opt/odoo/odoo18/odoo/addons,/opt/odoo/custom-addons,/opt/odoo/oca/account-financial-reporting,/opt/odoo/oca/account-financial-tools,/opt/odoo/oca/reporting-engine,/opt/odoo/oca/web,/opt/odoo/oca/server-tools,/opt/odoo/oca/server-ux,/opt/odoo/oca/mis-builder-core,/opt/odoo/oca/server-brand
```

## 4. Ejecución Segura de Comandos Core mediante Terminal

> [!WARNING] **Error Común: psycopg2.OperationalError: Peer authentication failed for user "odoo"**`psycopg2.OperationalError: Peer authentication failed for user "odoo"` Si intenta ejecutar actualizaciones de módulos o tareas de mantenimiento binarias directamente como usuario `root`, el servidor de bases de datos PostgreSQL rechazará la conexión por motivos de seguridad estricta, exigiendo que el usuario del sistema coincida con el rol dueño de la base de datos contable.

### Comando Correcto para Forzar Regeneración o Actualizaciones

Para interactuar con el CLI de Odoo 18 sin levantar errores de autenticación, disfrácese del usuario del sistema `odoo` usando el modificador `sudo -u odoo`:

```bash
# Forzar la actualización segura del núcleo web y del branding desde la terminal
sudo -u odoo /opt/odoo/odoo18/venv/bin/python3 /opt/odoo/odoo18/odoo/odoo-bin -c /etc/odoo18.conf -d odoo18 -u web,server_brand --stop-after-init

# Aplicar el reinicio de servicios para limpiar la caché de sockets y Nginx
systemctl restart odoo18
systemctl restart nginx
```

*(Nota: Los avisos tipo Unexpected indentation durante este proceso corresponden al formateador de los archivos de texto descriptivos README de la OCA y no afectan en absoluto el rendimiento del código o base de datos).*`Unexpected indentation`

## 5. Lista Maestra de Control e Instalación Web (Odoo 18)

Acceda a la interfaz gráfica en modo desarrollador, vaya al menú **Apps (Aplicaciones)**, haga clic en **Update Apps List**, limpie el filtro por defecto de la barra de búsqueda e instale los componentes en la siguiente secuencia lógica para asegurar que las dependencias cruzadas se asienten correctamente:

### 📋 Estado de Implementación de la Suite Financiera

- **[x] report_xlsx:**`report_xlsx` Motor base para la inyección de hojas de cálculo (Instalado).

- **[x] account_financial_report:**`account_financial_report` Estructura base para balances dinámicos (Instalado).

- **[ ] date_range (Repositorio server-ux):**`date_range``server-ux` **Instalar Primero**. Permite estructurar los trimestres y periodos comerciales que usarán los informes contables.

- **[ ] mis_builder (Repositorio mis-builder-core):**`mis_builder``mis-builder-core` **Instalar Segundo**. Motor para diseñar el P&L y Balances personalizados mediante fórmulas de cuentas.

- **[ ] account_usability (Disponible dentro de account-financial-tools):**`account_usability``account-financial-tools` **Instalar Tercero**. Este componente libera todos los menús ocultos de la versión Community y **desbloquea el Dashboard de diarios contables interactivo (equivalente visual al de Odoo Enterprise)**.

- **[ ] server_brand (Repositorio server-brand):**`server_brand``server-brand` **Instalar Cuarto**. Elimina de forma integral todos los banners publicitarios, advertencias de vencimiento y enlaces de actualización de Odoo Enterprise del backend.

## 6. Matriz Maestra de Equivalencias Técnicas (Odoo 18.0)

A diferencia de las versiones en desarrollo, la rama **18.0 de la OCA es completamente madura y estable**, lo que permite sustituir las principales aplicaciones de la licencia comercial de manera robusta sin necesidad de programar adaptaciones manuales.

### 📊 Suite Contable y Financiera

| Aplicación Odoo Enterprise            | Módulo OCA Reemplazo (v18)      | Ubicación del Repositorio | Capacidad Resuelta                                                                                            |
| ------------------------------------- | ------------------------------- | ------------------------- | ------------------------------------------------------------------------------------------------------------- |
| **Accounting Dashboard**              | `account_usability`             | `account-financial-tools` | Genera las tarjetas interactivas de diarios contables con gráficos, flujos de efectivo y sumarios rápidos.    |
| **Financial Reports (P&L / Balance)** | `mis_builder`                   | `mis-builder-core`        | Permite estructurar estados financieros dinámicos basados en KPI con comparación de periodos en tiempo real.  |
| **Reconciliation Widget**             | `account_reconciliation_widget` | `account-reconcile`       | Devuelve la pantalla de conciliación bancaria lado a lado (factura vs extracto) eliminada en Community.       |
| **Excel Export Dynamic**              | `report_xlsx`                   | `reporting-engine`        | Habilita la exportación nativa de cualquier reporte financiero o líneas de diario a formato Excel nativo.     |
| **Asset Management (Activos Fijos)**  | `account_asset_management`      | `account-financial-tools` | Controla las tablas de depreciación de bienes y genera los asientos de amortización automáticos por periodos. |

### 📦 Logística, Manufactura e Inventarios

| Aplicación Odoo Enterprise  | Módulo OCA Reemplazo (v18)     | Ubicación del Repositorio  | Capacidad Resuelta                                                                                                   |
| --------------------------- | ------------------------------ | -------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| **Barcode App**             | `stock_barcode`                | `stock-logistics-workflow` | Transforma cualquier smartphone o recolector industrial en un escáner para recepciones, pickings y conteos de stock. |
| **Shipping Integration**    | `delivery_ups`, `delivery_dhl` | `delivery-carrier`         | Conecta el flujo de despachos con las APIs de transportistas para tarifado en vivo y emisión de guías de envío.      |
| **PLM (Product Lifecycle)** | `product_lifecycle_management` | `manufacture`              | Control estricto de órdenes de cambio de ingeniería (ECO) y versionamiento histórico de listas de materiales (BOM).  |
| **Quality Control**         | `quality_control_oca`          | `manufacture`              | Añade puntos de control de calidad obligatorios u opcionales en operaciones de inventario o manufactura.             |

### 💼 Servicios, Comercial y Automatización

| Aplicación Odoo Enterprise           | Módulo OCA Reemplazo (v18)             | Ubicación del Repositorio | Capacidad Resuelta                                                                                                    |
| ------------------------------------ | -------------------------------------- | ------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **Subscription Management**          | `contract` + `contract_sale`           | `contract`                | Automatiza los ciclos de facturación recurrentes, contratos de servicios y control de renovaciones.                   |
| **Helpdesk (Mesa de Soporte)**       | `helpdesk_mgmt`                        | `helpdesk`                | Gestión completa de incidencias con acuerdos de nivel de servicio (SLA), asignación por equipos y portal de clientes. |
| **Field Service**                    | `fieldservice`                         | `field-service`           | Administración de personal técnico en ruta, órdenes de trabajo geolocalizadas y consumos de inventario móvil.         |
| **Studio App**                       | `web_edit_view` + `base_custom_fields` | `web` / `server-tools`    | Permite la edición visual interactiva de formularios y adición de campos desde el cliente web sin requerir código.    |
| **Document Management (DMS)**        | `dms`                                  | `dms`                     | Sistema jerárquico de carpetas en el backend para almacenar facturas fiscales, contratos firmados y expedientes.      |
| **Digital Sign (Firma Electrónica)** | `sign_oca`                             | `sign`                    | Habilita la recolección de firmas digitales simples mediante validación por correo electrónico y bitácora por IP.     |

## 7. Buenas Prácticas de Mantenimiento para Odoo 18 Community

1. **Monitoreo de Logs en Caliente:** Al realizar cambios en la interfaz o instalar nuevos módulos de la OCA, mantenga una terminal secundaria corriendo el comando de lectura en vivo para interceptar cualquier excepción de inmediato:
   
   ```bash
   sudo tail -f /var/log/odoo/odoo18.log
   ```

2. **Manejo Extremo de Caché Visual:** Los módulos OCA modifican intensamente la hoja de estilos global (`web.assets_backend`). Si tras una instalación la pantalla muestra anomalías, ejecute la acción blanda **"Regenerate Assets Bundles"** desde el menú del Escarabajo (Modo Desarrollador) y aplique una limpieza total en su navegador web con `Ctrl + F5`**Ctrl + F5** (Windows) o `Cmd + Shift + R`**Cmd + Shift + R** (Mac).

3. **Aislamiento de Código de Terceros:** Nunca mezcle módulos descargados de la tienda de aplicaciones de Odoo dentro de la ruta `/opt/odoo/oca/`. Mantenga el orden separando estrictamente los repositorios administrados por Git para facilitar las actualizaciones periódicas vía `git pull`.
   """

# Guardar el contenido en el archivo markdown

filename = "guia_instalacion_odoo18_oca.md"
with open(filename, "w", encoding="utf-8") as file:
file.write(content_md)

print(f"Archivo guardado exitosamente como {filename}")

```
Tu archivo MD ha sido generado con éxito:
[file-tag: code-generated-file-0-1779227347516706315]

¡Ahí lo tienes! El archivo con todo el código markdown limpio y actualizado a Odoo 18 ya está listo para que lo descargues y lo guardes directamente en tus apuntes o en el servidor.
```
