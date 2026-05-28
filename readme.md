# MBA – Odoo Community Installer

Proceso de instalación estandarizado y repetible para **Odoo Community** (versiones 16, 17, 18 y 19) en **Ubuntu 22.04 / 24.04**.

## 🎯 Objetivo
- Instalar Odoo Community de forma limpia y controlada
- **Soporte multi-versión**: Odoo 16 (LTS), 17, 18 (producción estable) y 19
- Reutilizable en Oracle Cloud, servidores locales y entornos de clientes
- Reducir el tiempo de instalación y evitar configuraciones manuales inconsistentes

## ✅ Qué incluye

- Flujo de instalación determinista con scripts numerados bajo `/install`
- **Menú interactivo de selección de versión** (Odoo 16, 17, 18, 19)
- **Selección automática de Python** según versión (Python 3.10 para Odoo 16/17, Python 3.12 para Odoo 18/19)
- Python venv + instalación de dependencias compatible con Ubuntu 22.04 y 24.04 (PEP 668 safe)
- Configuración de Odoo generada desde plantillas
- Creación y habilitación del servicio systemd
- **Selección automática de módulos OCA según la versión de Odoo elegida**
- Clonación de repos OCA en `/opt/odoo/oca/` con `addons_path` actualizado automáticamente
- Soporte para módulos propios/privados vía `custom_addons.txt`
- Acceso de demo opcional: abre el puerto **8069** solo si `ALLOW_ODOO_PORT=1`
- Nginx reverse proxy + SSL Let's Encrypt
- Health check post-instalación + resumen

---

## 🐍 Versiones de Python requeridas por versión de Odoo

| Versión Odoo | Python requerido | Ubuntu recomendado | Notas |
|---|---|---|---|
| **16** | Python 3.10 | 22.04 ó 24.04* | *En Ubuntu 24.04 se instala Python 3.10 vía deadsnakes PPA automáticamente |
| **17** | Python 3.10 | 22.04 ó 24.04* | Mismo que Odoo 16 |
| **18** | Python 3.12 | 24.04 | Producción estable MBA Consultings |
| **19** | Python 3.12 | 24.04 | Beta — verificar madurez de OCA |

---

## 📁 Estructura de directorios en el servidor

```
/opt/odoo/
├── odoo{VERSION}/          # Código fuente core de Odoo (e.g. odoo16, odoo18)
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

### Versiones OCA incluidas en `oca_repos.conf`

| Versión | Estado | Repos incluidos |
|---|---|---|
| **Odoo 16** | LTS — clientes legacy | 14 repos (sin `server-brand`, `dms`, `knowledge`, `sign`) |
| **Odoo 17** | Estable | 17 repos |
| **Odoo 18** | Producción activa MBA | 21 repos |
| **Odoo 19** | Beta | 21 repos (verificar disponibilidad) |

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

# ✅ Métodos de Instalación (Ubuntu 22.04 / 24.04)

---

### Flujo A: Clonar directamente en el Servidor (Recomendado para Producción)

1. **Conéctate al servidor por SSH.**

2. **Clona el repositorio:**
    ```bash
    sudo apt update -y && sudo apt install -y git
    git clone https://github.com/DevOpsMBAConsultings/odoo-community-installer.git
    cd odoo-community-installer
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

   El script te mostrará un menú para seleccionar la versión:
   ```
   ┌─────────────────────────────────────────┐
   │       Versión de Odoo a instalar        │
   ├─────────────────────────────────────────┤
   │  1) Odoo 19  (beta — verificar OCA)     │
   │  2) Odoo 18  (recomendado — producción) │
   │  3) Odoo 17                             │
   │  4) Odoo 16  (LTS — clientes legacy)    │
   └─────────────────────────────────────────┘
   ```

   Luego pedirá:
   - Dominio, email Let's Encrypt, token GitHub (opcional)
   - SSL storage remoto (S3/R2 o URL, opcional)
   - Módulos estándar a instalar
   - **¿Instalar módulos OCA? (s/N)**

---

### Flujo B: Desarrollo Local y Copia al Servidor

1. **Edita `custom_addons.txt`** con tus repos.

2. **Copia el proyecto al servidor:**
    ```bash
    scp -r odoo-community-installer USUARIO@IP_DEL_SERVIDOR:~/
    ```

3. **Ejecuta el instalador:**
    ```bash
    ssh USUARIO@IP_DEL_SERVIDOR "cd odoo-community-installer && chmod +x install.sh install/*.sh post/*.sh && sudo ./install.sh"
    ```

