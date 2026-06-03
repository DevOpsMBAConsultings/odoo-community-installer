# Guía de Instalación Automatizada — MBA Consultings

Guía rápida para instalar **Odoo 18 Community** usando el script automatizado, incluyendo módulos OCA y módulos propios como Digifact.

**Repositorio:** [odoo-community-installer](https://github.com/DevOpsMBAConsultings/odoo-community-installer.git)

---

## Prerequisitos

- Servidor Ubuntu 24.04 LTS (o Ubuntu 22.04 LTS) limpio
- Acceso root o sudo
- Nombre de dominio (para el certificado SSL)
- Dirección de email (para Let's Encrypt)

---

## Paso 1: Clonar el repositorio de instalación

```bash
cd ~
sudo apt update -y && sudo apt install -y git
git clone -b 18.0 https://github.com/DevOpsMBAConsultings/odoo-community-installer.git odoo-community-installer-18
cd odoo-community-installer-18
```

---

## Paso 2: Configurar módulos propios (opcional)

Si tienes repositorios propios o privados (ej. `facturacion_electronica`), agrégalos a `custom_addons.txt` **antes** de correr el instalador:

```bash
nano custom_addons.txt
```

Agrega tus URLs (una por línea). Los módulos OCA **no** van aquí — el instalador los maneja automáticamente:

```text
# Módulos privados de MBA Consultings
git@github.com:DevOpsMBAConsultings/facturacion_electronica.git

# Módulos públicos de terceros
# https://github.com/OCA/web.git  ← NO es necesario, el instalador lo maneja
```

---

## Paso 3: Ejecutar el instalador

```bash
chmod +x install.sh install/*.sh post/*.sh
sudo ./install.sh
```

### Preguntas del instalador

El script te hará estas preguntas en orden:

| Pregunta | Por defecto | Notas |
|---|---|---|
| Domain name | — | e.g. `erp.tuempresa.com` |
| Email for Let's Encrypt | — | Para notificaciones de SSL |
| GitHub Token | — | Opcional. Solo si tienes repos privados HTTPS en `custom_addons.txt` |
| Use remote SSL storage? | `no` | `s3`, `url`, o `no` |
| Odoo standard modules | `sale,purchase,crm,stock,contacts,account` | Enter para aceptar los por defecto |
| **¿Instalar módulos OCA para Odoo 18?** | `N` | Escribe **`s`** para instalar automáticamente los módulos OCA para Odoo 18 |

### ¿Qué instala?

- ✅ Todas las dependencias del sistema
- ✅ PostgreSQL
- ✅ Odoo Community 18
- ✅ Python 3 con entorno virtual
- ✅ wkhtmltopdf (versión parcheada para PDFs)
- ✅ Nginx reverse proxy
- ✅ Certificado SSL Let's Encrypt
- ✅ Configuración de firewall (UFW)
- ✅ Servicio systemd (`odoo18.service`)
- ✅ **Módulos OCA en `/opt/odoo/oca/`** (si respondiste `s`)
- ✅ Módulos propios de `custom_addons.txt` en `/opt/odoo/custom-addons/`

### Resultado de la instalación

- **URL de Odoo:** `https://tu-dominio.com`
- **Master Password:** Se muestra al final (¡guárdala!)
- **Base de datos:** `odoo18`
- **Config:** `/etc/odoo18.conf`
- **Logs:** `/var/log/odoo/odoo18.log`

---

## Estructura de directorios resultante

```
/opt/odoo/
├── odoo18/                         # Código fuente core de Odoo 18
│   └── venv/                       # Python virtual environment
├── auto-addons/                    # Symlinks a módulos detectados en custom-addons
├── custom-addons/                  # Tus módulos propios (de custom_addons.txt)
│   ├── facturacion_electronica/
│   └── ...
└── oca/                            # Repositorios OCA (si se instalaron)
    ├── account-financial-reporting/
    ├── account-financial-tools/
    ├── mis-builder/
    └── ...
```

**`addons_path` en `/etc/odoo18.conf` (con OCA):**
```ini
addons_path = /opt/odoo/auto-addons,/opt/odoo/odoo18/odoo/addons,/opt/odoo/oca/account-financial-reporting,/opt/odoo/oca/account-financial-tools,...,/opt/odoo/custom-addons
```

---

## Paso 4: Instalar módulos OCA desde la interfaz de Odoo

Los módulos OCA están **disponibles** en el servidor pero deben **activarse desde la UI** de Odoo.

1. Accede a `https://tu-dominio.com`
2. Ve a **Ajustes → Activar modo desarrollador**
3. Ve al menú **Apps (Aplicaciones)**
4. Haz clic en **"Update Apps List"** (Actualizar lista de aplicaciones)
5. Limpia el filtro de búsqueda por defecto
6. Instala los módulos en el orden recomendado:

| Orden | Módulo | Repositorio OCA |
|---|---|---|
| 1 | `report_xlsx` | `reporting-engine` |
| 2 | `date_range` | `server-ux` |
| 3 | `mis_builder` | `mis-builder` |
| 4 | `account_usability` | `account-financial-tools` |
| 5 | `account_reconciliation_widget` | `account-reconcile` |
| 6 | `server_brand` | `server-brand` (no en v16) |
| 7 | `base_technical_features` | `server-ux` |
| 8+ | Módulos adicionales según necesidad | Ver checklist en la doc |

---

## Paso 5: Instalar módulos Digifact (si aplica)

1. Ve a **Apps** → quita el filtro "Apps" → busca "Panama" o "Digifact"
2. **Primero:** Instala `l10n_pa_edi_digifact_company` (Configuración FE de Empresa)
3. **Segundo:** Instala `l10n_pa_edi_digifact` (Panama EDI Digifact)

---

## Paso 6: Configurar la empresa (Panamá / Facturación Electrónica)

1. Ve a **Ajustes** → **Empresas** → Selecciona tu empresa
2. Pestaña **Facturación Electrónica**
3. Completa:

| Campo | Descripción |
|---|---|
| RUC | RUC de tu empresa |
| DV (DGI) | Clic en "Validar RUC" para auto-completar |
| Código de la sucursal | e.g. `0001` |
| Punto de facturación | e.g. `001` |
| Provincia / Distrito / Corregimiento | Seleccionar de la lista |
| Coordenadas Sucursal | e.g. `+8.9213,-79.7068` |
| Usuario Digifact | Tu usuario Digifact |
| Password Digifact | Tu contraseña Digifact |
| Digifact Api Base Url Mode | `Sandbox` para pruebas / `Production` para producción |

4. Clic en **"Test PAC Connection"** → debe mostrar éxito
5. Clic en **"Get PAC Token"** → token guardado automáticamente
6. **Guardar**

---

## Verificación post-instalación

```bash
# Estado del servicio
sudo systemctl status odoo18

# Logs en tiempo real
sudo tail -f /var/log/odoo/odoo18.log

# Verificar addons_path (debe incluir rutas OCA si se instalaron)
grep addons_path /etc/odoo18.conf

# Verificar que los repos OCA están clonados
ls /opt/odoo/oca/

# Verificar que no hay rutas fantasma (ninguna línea con "No such file")
grep addons_path /etc/odoo18.conf | tr ',' '\n' | xargs -I{} ls -d {} 2>&1
```

---

## Comandos útiles

### Gestión del servicio

```bash
sudo systemctl start odoo18
sudo systemctl stop odoo18
sudo systemctl restart odoo18
sudo systemctl status odoo18
sudo journalctl -u odoo18 -f
```

### Actualizar un módulo desde la terminal

```bash
sudo -u odoo /opt/odoo/odoo18/venv/bin/python3 /opt/odoo/odoo18/odoo/odoo-bin   -c /etc/odoo18.conf   -d odoo18   -u nombre_del_modulo   --stop-after-init
sudo systemctl start odoo18
```

### Actualizar repos OCA a la última versión de la rama

```bash
sudo -u odoo git -C /opt/odoo/oca/account-financial-reporting pull
sudo systemctl restart odoo18
```

### Health check

```bash
cd /path/to/odoo-community-installer-18
sudo ./post/00_health_check.sh
```

---

## Solución de problemas

### Módulo no encontrado en UI

```bash
# Verificar que el path está en addons_path
grep addons_path /etc/odoo18.conf

# Verificar que el directorio existe físicamente
ls /opt/odoo/oca/<nombre-repo>

# Reiniciar Odoo y actualizar lista de apps
sudo systemctl restart odoo18
# Luego en UI: Apps → Update Apps List
```

### Iconos rotos tras instalar un módulo OCA

1. Modo desarrollador → ícono del Escarabajo → **"Regenerate Assets Bundles"**
2. Limpiar caché del navegador: `Ctrl+Shift+R` / `Cmd+Shift+R`

### Errores de importación Python

```bash
sudo su - odoo
source /opt/odoo/odoo18/venv/bin/activate
pip install nombre_del_paquete
exit
sudo systemctl restart odoo18
```

### Problemas de conexión con Digifact

```bash
curl https://testnucpa.digifact.com/api/login/get_token
sudo ufw status
```

---

## Próximos pasos

1. ✅ Completar la configuración FE de la empresa
2. ✅ Probar la creación de facturas y la reserva de número fiscal
3. ✅ Probar el envío a Digifact en modo Sandbox
4. ✅ Cambiar a entorno de Producción cuando esté listo
5. ✅ Capacitar a los usuarios en el flujo FE

---

## Documentación relacionada

- **Checklist completo:** [`INSTALL_CHECKLIST.md`](INSTALL_CHECKLIST.md)
- **Equivalencias Enterprise vs OCA:** [`docs/oca_modules.md`](docs/oca_modules.md)
- **Repos OCA por versión:** [`config/oca_repos.conf`](config/oca_repos.conf)
