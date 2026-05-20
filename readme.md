# MBA – Odoo Community Install Process

Proceso de instalación estandarizado y repetible para **Odoo Community** (versiones 18 y 19) en **Ubuntu 24.04**.

## 🎯 Objetivo
- Instalar Odoo Community de forma limpia y controlada
- Soporte multi-versión: Odoo 18 (producción estable) y Odoo 19
- Reutilizable en Oracle Cloud, servidores locales y entornos de clientes
- Reducir el tiempo de instalación y evitar configuraciones manuales inconsistentes

## ✅ Qué incluye

- Flujo de instalación determinista con scripts numerados bajo `/install`
- Python venv + instalación de dependencias compatible con Ubuntu 24.04 (PEP 668 safe)
- Configuración de Odoo generada desde plantillas
- Creación y habilitación del servicio systemd
- **Selección automática de módulos OCA según la versión de Odoo elegida**
- Clonación de repos OCA en `/opt/odoo/oca/` con `addons_path` actualizado automáticamente
- Soporte para módulos propios/privados vía `custom_addons.txt`
- Acceso de demo opcional: abre el puerto **8069** solo si `ALLOW_ODOO_PORT=1`
- Nginx reverse proxy + SSL Let's Encrypt
- Health check post-instalación + resumen

---

## 📁 Estructura de directorios en el servidor

```
/opt/odoo/
├── odoo{VERSION}/          # Código fuente core de Odoo (e.g. odoo18)
│   └── venv/               # Entorno virtual de Python
├── auto-addons/            # Symlinks a módulos individuales (generado automáticamente)
├── custom-addons/          # Tus desarrollos propios y módulos privados
└── oca/                    # Repositorios oficiales de la OCA (rama {VERSION}.0)
    ├── account-financial-reporting/
    ├── account-financial-tools/
    └── ...
```

---

## 🌐 Idioma, país y módulos (opcional)

Al inicializar la base de datos (`09_init_database.sh`) se pueden usar estas variables de entorno:

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `ODOO_LANG` | `es_PA` | Código de idioma (ej. `es_ES`, `en_US`). |
| `ODOO_COUNTRY_CODE` | `PA` | País por defecto de la empresa (código ISO, ej. `PA`, `US`). |
| `ODOO_INIT_MODULES` | *(auto)* | Si no se define: se instalan **todos** los add-ons detectados. Si se define: solo esa lista (separada por comas). |
| `ODOO_EXTRA_MODULES` | `sale,purchase,crm,stock,contacts,account` | Módulos **estándar de Odoo** a instalar además. Definir vacío para no instalar ninguno. |

---

## 📦 Módulos OCA — Selección automática por versión

El instalador detecta qué versión de Odoo seleccionaste y te ofrece instalar automáticamente los módulos OCA correspondientes.

### ¿Cómo funciona?

1. `install.sh` lee `config/oca_repos.conf`
2. Muestra los repos OCA configurados para tu versión
3. Pregunta si deseas instalarlos
4. Si confirmas:
   - Clona cada repo en `/opt/odoo/oca/<repo-name>/` (rama `{VERSION}.0`)
   - Agrega cada ruta al `addons_path` en `/etc/odoo{VERSION}.conf`
   - Instala las dependencias Python (`requirements.txt`) de cada repo

### Repositorios OCA incluidos (Odoo 18)

> Fuente de verdad: `docs/install_considerations_odoo18.md`

| Repositorio | Reemplaza en Enterprise |
|---|---|
| `account-financial-reporting` | Reportes financieros avanzados |
| `account-financial-tools` | Dashboard contable, activos fijos, ITBMS |
| `account-reconcile` | Widget de conciliación bancaria |
| `reporting-engine` | Exportación nativa a Excel (`report_xlsx`) |
| `web` | Herramientas web adicionales |
| `server-tools` | Herramientas técnicas de servidor |
| `server-ux` | `date_range`, `base_tier_validation`, UX mejorada |
| `server-brand` | Elimina banners Enterprise del backend |
| `mis-builder` | P&L y Balances dinámicos con fórmulas contables |
| `contract` | Suscripciones y contratos recurrentes |
| `helpdesk` | Mesa de soporte con SLA |
| `dms` | Gestión documental (DMS) |
| `sign` | Firma electrónica simple |
| `stock-logistics-barcode` | App de código de barras para inventario |
| `manufacture` | PLM y Control de Calidad |
| `purchase-workflow` | `purchase_tier_validation` |
| `sale-workflow` | `sale_tier_validation` |

Para modificar la lista o agregar soporte a otra versión, edita [`config/oca_repos.conf`](config/oca_repos.conf).

---

## 🗂 Gestión de módulos propios (`custom_addons.txt`)

El archivo `custom_addons.txt` es para tus **repositorios propios o privados** (no OCA). Los módulos OCA los gestiona el instalador automáticamente.

- **Repositorios Públicos:**
  ```
  https://github.com/your-org/my_module.git
  ```
- **Repositorios Privados (SSH):**
  ```
  git@github.com:DevOpsMBAConsultings/facturacion_electronica.git
  ```

Los repos en `custom_addons.txt` se clonan en `/opt/odoo/custom-addons/`.

---

# ✅ Métodos de Instalación (Ubuntu 24.04)

---

### Flujo A: Clonar directamente en el Servidor (Recomendado para Producción)

1. **Conéctate al servidor por SSH.**

2. **Clona el repositorio:**
    ```bash
    sudo apt update -y && sudo apt install -y git
    git clone https://github.com/DevOpsMBAConsultings/MBA-Odoo19-Community-install-process.git
    cd MBA-Odoo19-Community-install-process
    ```

3. **Configura tus módulos propios (opcional):**
    ```bash
    nano custom_addons.txt
    ```

4. **Ejecuta el instalador:**
    ```bash
    chmod +x install.sh install/*.sh post/*.sh
    sudo ./install.sh
    ```

   El script te preguntará:
   - Versión de Odoo (por defecto: **18**)
   - Dominio, email Let's Encrypt, token GitHub (opcional)
   - SSL storage remoto (S3/R2 o URL, opcional)
   - Módulos estándar a instalar
   - **¿Instalar módulos OCA? (s/N)**

---

### Flujo B: Desarrollo Local y Copia al Servidor

1. **Edita `custom_addons.txt`** con tus repos.

2. **Copia el proyecto al servidor:**
    ```bash
    scp -r MBA-Odoo19-Community-install-process USUARIO@IP_DEL_SERVIDOR:~/
    ```

3. **Ejecuta el instalador:**
    ```bash
    ssh USUARIO@IP_DEL_SERVIDOR "cd MBA-Odoo19-Community-install-process && chmod +x install.sh install/*.sh post/*.sh && sudo ./install.sh"
    ```