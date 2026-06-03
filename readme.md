# MBA – Odoo 19 Community Installer

Proceso de instalación estandarizado y repetible para **Odoo 19 Community** en **Ubuntu 24.04 LTS** (Beta — verificar madurez de OCA).

## 🎯 Objetivo
- Instalar Odoo 19 Community de forma limpia, controlada y automatizada.
- Reutilizable en Oracle Cloud, servidores locales y entornos de clientes.
- Reducir el tiempo de instalación y evitar configuraciones manuales inconsistentes.

## ✅ Qué incluye
- Flujo de instalación determinista con scripts numerados bajo `/install`.
- **Entorno aislado exclusivo para Odoo 19**: usando Python 3.12 (instalado por defecto en Ubuntu 24.04) y un entorno virtual (`venv`) PEP 668 safe.
- Configuración de Odoo generada desde plantillas.
- Creación y habilitación del servicio systemd (`odoo19.service`).
- **Instalación automática de módulos OCA para Odoo 19**:
  - Lee los repositorios OCA compatibles en `config/oca_repos.conf`.
  - Clona cada repo en `/opt/odoo/oca/` (rama `19.0`).
  - Agrega automáticamente cada ruta al `addons_path` en `/etc/odoo19.conf`.
- Soporte para módulos propios/privados vía `custom_addons.txt` en `/opt/odoo/custom-addons/`.
- Acceso de demo opcional: abre el puerto **8069** solo si `ALLOW_ODOO_PORT=1`.
- Nginx reverse proxy + SSL Let's Encrypt.
- Health check post-instalación + resumen.

---

## 🐍 Requisitos de Sistema

- **Sistema Operativo**: Ubuntu 24.04 LTS
- **Python**: Python 3.12 (instalado por defecto en Ubuntu 24.04)

---

## 📁 Estructura de directorios en el servidor

```
/opt/odoo/
├── odoo19/                 # Código fuente core de Odoo 19
│   └── venv/               # Entorno virtual de Python
├── auto-addons/            # Symlinks a módulos individuales (generado automáticamente)
├── custom-addons/          # Tus desarrollos propios y módulos privados
└── oca/                    # Repositorios oficiales de la OCA (rama 19.0)
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

## 📦 Módulos OCA para Odoo 19

El instalador detecta los módulos OCA configurados para Odoo 19 en `config/oca_repos.conf` y te ofrece instalarlos automáticamente.

1. Clona cada repo configurado en `/opt/odoo/oca/<repo-name>/` (rama `19.0`).
2. Agrega cada ruta al `addons_path` en `/etc/odoo19.conf`.
3. Instala las dependencias Python (`requirements.txt`) correspondientes de cada repositorio.

Para modificar la lista de repositorios, edita [`config/oca_repos.conf`](config/oca_repos.conf).

---

## 🗂 Gestión de módulos propios (`custom_addons.txt`)

El archivo `custom_addons.txt` es para tus **repositorios propios o privados** (no OCA).

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

# ✅ Métodos de Instalación

---

### Flujo de Instalación en el Servidor (Recomendado)

1. **Conéctate al servidor por SSH.**

2. **Clona el repositorio e ingresa a él:**
    ```bash
    sudo apt update -y && sudo apt install -y git
    git clone -b 19.0 https://github.com/DevOpsMBAConsultings/odoo-community-installer.git odoo-community-installer-19
    cd odoo-community-installer-19
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

   El script se ejecutará **exclusivamente para Odoo 19** y te pedirá:
   - Dominio, email Let's Encrypt, token GitHub (opcional).
   - SSL storage remoto (S3/R2 o URL, opcional).
   - Módulos estándar a instalar.
   - **¿Instalar módulos OCA para Odoo 19? (s/N)**.
