# Open WebUI YunoHost Package Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a YunoHost v2 package that installs Open WebUI via pip into a Python venv, with PostgreSQL, LDAP/SSO integration, and Ollama auto-detection — targeting Level 8+ for catalog submission.

**Architecture:** Standard YunoHost v2 package structure. Open WebUI is installed from PyPI into a Python virtual environment, configured via an `.env` template, served behind nginx as a reverse proxy, and managed by systemd. All configurable values are stored as YunoHost app settings and rendered into `.env` on install/upgrade.

**Tech Stack:** Bash (YunoHost helper scripts), TOML (manifest), nginx, systemd, Python venv, PostgreSQL, LDAP

**Spec:** `docs/superpowers/specs/DESIGN.md`

---

## File Map

| File | Purpose |
|------|---------|
| `manifest.toml` | Package metadata, install questions, resource declarations |
| `LICENSE` | AGPL-3.0 license |
| `tests.toml` | CI test scenarios for package_check |
| `scripts/_common.sh` | Shared variables (version pin, Ollama detection helper) |
| `scripts/install` | Create venv, pip install, configure, start service |
| `scripts/remove` | Stop service, remove system configs (resources auto-deprovisioned) |
| `scripts/upgrade` | Stop, upgrade pip package, regenerate config, restart |
| `scripts/backup` | Declare config files, data dir, and DB for backup |
| `scripts/restore` | Restore files, rebuild venv, restore DB, start service |
| `scripts/change_url` | Update nginx config, restart service |
| `conf/nginx.conf` | Reverse proxy with WebSocket support |
| `conf/systemd.service` | Service unit running open-webui via venv |
| `conf/.env` | Environment variable template for Open WebUI |
| `doc/DESCRIPTION.md` | English app description for catalog |
| `doc/DESCRIPTION_fr.md` | French app description |
| `doc/PRE_INSTALL.md` | Pre-install notes (Ollama recommendation) |
| `README.md` | Package readme |
| `README_fr.md` | French package readme |

---

## Chunk 1: Project Scaffolding and Configuration Templates

### Task 1: Initialize Git repo and create manifest.toml

**Files:**
- Create: `manifest.toml`
- Create: `LICENSE`

- [ ] **Step 1: Initialize git repo**

```bash
cd ~/code/yunohost-openwebui
git init
```

- [ ] **Step 2: Create LICENSE file**

Create `LICENSE` with the full AGPL-3.0 license text. Use:

```bash
curl -sL https://www.gnu.org/licenses/agpl-3.0.txt > LICENSE
```

- [ ] **Step 3: Create manifest.toml**

```toml
#:schema https://raw.githubusercontent.com/YunoHost/apps/main/schemas/manifest.v2.schema.json

packaging_format = 2

id = "openwebui"
name = "Open WebUI"
description.en = "User-friendly AI chat interface supporting Ollama and OpenAI-compatible APIs"
description.fr = "Interface de chat IA conviviale supportant Ollama et les API compatibles OpenAI"

version = "0.6.5~ynh1"

maintainers = []

[upstream]
license = "MIT"
website = "https://openwebui.com"
admindoc = "https://docs.openwebui.com"
userdoc = "https://docs.openwebui.com"
code = "https://github.com/open-webui/open-webui"

[integration]
yunohost = ">= 12.1.17"
helpers_version = "2.1"
architectures = "all"
multi_instance = true
ldap = true
sso = true
disk = "1000M"
ram.build = "1500M"
ram.runtime = "256M"

[install]
    [install.domain]
    type = "domain"

    [install.path]
    type = "path"
    default = "/"

    [install.admin]
    type = "user"

    [install.init_main_permission]
    type = "group"
    default = "visitors"
    help.en = "If set to 'visitors', anyone can access the login page. If set to a specific group, only those YunoHost users can access the app via SSO."
    help.fr = "Si défini sur 'visitors', tout le monde peut accéder à la page de connexion. Si défini sur un groupe spécifique, seuls ces utilisateurs YunoHost peuvent accéder à l'application via SSO."

    [install.ollama_connection]
    ask.en = "Ollama connection mode"
    ask.fr = "Mode de connexion Ollama"
    help.en = "Use 'local' if Ollama runs on this server (localhost:11434). Use 'remote' to specify a custom URL."
    help.fr = "Utilisez 'local' si Ollama fonctionne sur ce serveur (localhost:11434). Utilisez 'remote' pour spécifier une URL personnalisée."
    type = "select"
    choices = ["local", "remote"]
    default = "local"

    [install.ollama_url]
    ask.en = "Ollama API URL"
    ask.fr = "URL de l'API Ollama"
    help.en = "Full URL to the Ollama API. Only used when connection mode is 'remote'."
    help.fr = "URL complète de l'API Ollama. Utilisé uniquement quand le mode de connexion est 'remote'."
    type = "string"
    default = "http://localhost:11434"

    [install.openai_api_key]
    ask.en = "OpenAI API key (optional)"
    ask.fr = "Clé API OpenAI (optionnel)"
    help.en = "Leave blank if you only plan to use Ollama."
    help.fr = "Laissez vide si vous prévoyez d'utiliser uniquement Ollama."
    type = "string"
    default = ""
    optional = true

    [install.openai_api_base_url]
    ask.en = "OpenAI-compatible API base URL"
    ask.fr = "URL de base de l'API compatible OpenAI"
    help.en = "For OpenAI, use the default. For other providers, enter their API URL."
    help.fr = "Pour OpenAI, utilisez la valeur par défaut. Pour d'autres fournisseurs, entrez leur URL API."
    type = "string"
    default = "https://api.openai.com/v1"

[resources]
    [resources.system_user]

    [resources.install_dir]

    [resources.data_dir]

    [resources.permissions]
    main.url = "/"

    [resources.ports]

    [resources.apt]
    packages = "python3, python3-venv, python3-pip, python3-dev, build-essential, libffi-dev"

    [resources.database]
    type = "postgresql"
```

- [ ] **Step 4: Commit**

```bash
git add manifest.toml LICENSE
git commit -m "feat: add manifest.toml and LICENSE for openwebui_ynh package"
```

---

### Task 2: Create configuration templates

**Files:**
- Create: `conf/nginx.conf`
- Create: `conf/systemd.service`
- Create: `conf/.env`

- [ ] **Step 1: Create conf directory**

```bash
mkdir -p conf
```

- [ ] **Step 2: Create conf/nginx.conf**

```nginx
#sub_path_only rewrite ^__PATH__$ __PATH__/ permanent;
location __PATH__/ {

    proxy_pass http://127.0.0.1:__PORT__/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    # WebSocket support
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";

    # File upload size
    client_max_body_size 512M;

    # Timeout settings for long-running LLM requests
    proxy_read_timeout 300s;
    proxy_send_timeout 300s;
    proxy_connect_timeout 60s;

    # Disable buffering for streaming responses
    proxy_buffering off;

    # Include YunoHost panel
    include conf.d/yunohost_panel.conf.inc;
}
```

- [ ] **Step 3: Create conf/systemd.service**

```ini
[Unit]
Description=Open WebUI (__APP__)
After=network.target postgresql.service

[Service]
Type=simple
User=__APP__
Group=__APP__
WorkingDirectory=__INSTALL_DIR__
EnvironmentFile=__INSTALL_DIR__/.env
ExecStart=__INSTALL_DIR__/venv/bin/open-webui serve --host 127.0.0.1 --port __PORT__
Restart=on-failure
RestartSec=5

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=full
ProtectHome=yes
ProtectClock=yes
ProtectHostname=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictNamespaces=yes
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
```

- [ ] **Step 4: Create conf/.env**

```bash
# Open WebUI configuration — managed by YunoHost
# Do not edit manually. Changes will be overwritten on upgrade.
# Use `yunohost app setting openwebui <key> -v <value>` to change settings.

# Database
DATABASE_URL=postgresql://__DB_USER__:__DB_PWD__@localhost:5432/__DB_NAME__

# Data directory
DATA_DIR=__DATA_DIR__

# Ollama
OLLAMA_BASE_URL=__OLLAMA_URL__

# OpenAI-compatible API
OPENAI_API_KEY=__OPENAI_API_KEY__
OPENAI_API_BASE_URL=__OPENAI_API_BASE_URL__

# Admin
WEBUI_ADMIN_EMAIL=__ADMIN_EMAIL__

# Registration and login
ENABLE_SIGNUP=false
ENABLE_LOGIN_FORM=__ENABLE_LOGIN_FORM__

# LDAP
ENABLE_LDAP=true
LDAP_SERVER_HOST=localhost
LDAP_SERVER_PORT=389
LDAP_USE_TLS=false
LDAP_SEARCH_BASE=ou=users,dc=yunohost,dc=org
LDAP_ATTRIBUTE_FOR_USERNAME=uid
LDAP_ATTRIBUTE_FOR_MAIL=mail
LDAP_APP_DN=
LDAP_APP_PASSWORD=
LDAP_SEARCH_FILTER=(objectClass=posixAccount)
LDAP_SERVER_LABEL=YunoHost LDAP

# SSO trusted headers
WEBUI_AUTH_TRUSTED_EMAIL_HEADER=YNH_USER_EMAIL
WEBUI_AUTH_TRUSTED_NAME_HEADER=YNH_USER_FULLNAME
```

- [ ] **Step 5: Commit**

```bash
git add conf/
git commit -m "feat: add nginx, systemd, and .env configuration templates"
```

---

### Task 3: Create _common.sh with shared variables and helpers

**Files:**
- Create: `scripts/_common.sh`

- [ ] **Step 1: Create scripts directory**

```bash
mkdir -p scripts
```

- [ ] **Step 2: Create scripts/_common.sh**

```bash
#!/bin/bash

#=================================================
# COMMON VARIABLES
#=================================================

OPENWEBUI_VERSION="0.6.5"

#=================================================
# COMMON HELPERS
#=================================================

# Detect ollama_ynh and return its domain, or empty string
detect_ollama_domain() {
    yunohost app setting ollama domain 2>/dev/null || echo ""
}

# Resolve the Ollama URL based on connection mode and detection
resolve_ollama_url() {
    local connection_mode="$1"
    local user_url="$2"

    if [ "$connection_mode" = "local" ]; then
        echo "http://localhost:11434"
    elif [ -n "$user_url" ] && [ "$user_url" != "http://localhost:11434" ]; then
        echo "$user_url"
    else
        local detected_domain
        detected_domain=$(detect_ollama_domain)
        if [ -n "$detected_domain" ]; then
            echo "https://${detected_domain}"
        else
            echo "http://localhost:11434"
        fi
    fi
}
```

- [ ] **Step 3: Commit**

```bash
git add scripts/_common.sh
git commit -m "feat: add _common.sh with version pin and Ollama detection helpers"
```

---

## Chunk 2: Lifecycle Scripts — Install and Remove

### Task 4: Create install script

**Files:**
- Create: `scripts/install`

- [ ] **Step 1: Create scripts/install**

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source _common.sh
source /usr/share/yunohost/helpers

#=================================================
# RESOLVE OLLAMA URL
#=================================================
ynh_script_progression "Configuring Ollama connection..."

ollama_url=$(resolve_ollama_url "$ollama_connection" "$ollama_url")
ynh_app_setting_set --key=ollama_url --value="$ollama_url"

# Log Ollama detection status
ollama_domain=$(detect_ollama_domain)
if [ -n "$ollama_domain" ]; then
    ynh_print_info "Detected ollama_ynh at ${ollama_domain}"
else
    ynh_print_info "ollama_ynh not detected. Install ollama_ynh for local AI models, or configure a remote Ollama URL."
fi

#=================================================
# DETERMINE LOGIN FORM SETTING
#=================================================

# Get the permission value to determine if app is public
if [ "$init_main_permission" = "visitors" ]; then
    enable_login_form="true"
else
    enable_login_form="false"
fi
ynh_app_setting_set --key=enable_login_form --value="$enable_login_form"

#=================================================
# GET ADMIN EMAIL
#=================================================

admin_email=$(yunohost user info "$admin" --output-as json | python3 -c "import sys,json; print(json.load(sys.stdin)['mail'])")
ynh_app_setting_set --key=admin_email --value="$admin_email"

#=================================================
# CREATE PYTHON VENV AND INSTALL OPEN WEBUI
#=================================================
ynh_script_progression "Setting up Python virtual environment..."

python3 -m venv "$install_dir/venv"
"$install_dir/venv/bin/pip" install --upgrade pip
"$install_dir/venv/bin/pip" install "open-webui==$OPENWEBUI_VERSION"

chown -R "$app:$app" "$install_dir"

#=================================================
# ADD CONFIGURATION FILES
#=================================================
ynh_script_progression "Adding configuration files..."

ynh_config_add --template=".env" --destination="$install_dir/.env"
chmod 400 "$install_dir/.env"
chown "$app:$app" "$install_dir/.env"

#=================================================
# SYSTEM CONFIGURATION
#=================================================
ynh_script_progression "Adding system configurations..."

ynh_config_add_nginx

ynh_config_add_systemd

yunohost service add "$app" --description="Open WebUI AI chat interface"

#=================================================
# START SYSTEMD SERVICE
#=================================================
ynh_script_progression "Starting $app's systemd service..."

ynh_systemctl --service="$app" --action="start" --wait_until="Uvicorn running" --timeout=120

#=================================================
# END OF SCRIPT
#=================================================

ynh_script_progression "Installation of $app completed"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/install
```

- [ ] **Step 3: Commit**

```bash
git add scripts/install
git commit -m "feat: add install script with venv setup, LDAP/SSO config, and Ollama detection"
```

---

### Task 5: Create remove script

**Files:**
- Create: `scripts/remove`

- [ ] **Step 1: Create scripts/remove**

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source _common.sh
source /usr/share/yunohost/helpers

#=================================================
# REMOVE SYSTEM CONFIGURATION
#=================================================
ynh_script_progression "Removing system configurations related to $app..."

if ynh_hide_warnings yunohost service status "$app" >/dev/null; then
    yunohost service remove "$app"
fi
ynh_config_remove_systemd

ynh_config_remove_nginx

#=================================================
# END OF SCRIPT
#=================================================

ynh_script_progression "Removal of $app completed"
```

- [ ] **Step 2: Make executable**

```bash
chmod +x scripts/remove
```

- [ ] **Step 3: Commit**

```bash
git add scripts/remove
git commit -m "feat: add remove script"
```

---

## Chunk 3: Lifecycle Scripts — Upgrade, Backup, Restore, Change URL

### Task 6: Create upgrade script

**Files:**
- Create: `scripts/upgrade`

- [ ] **Step 1: Create scripts/upgrade**

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source _common.sh
source /usr/share/yunohost/helpers

#=================================================
# STOP SYSTEMD SERVICE
#=================================================
ynh_script_progression "Stopping $app's systemd service..."

ynh_systemctl --service="$app" --action="stop"

#=================================================
# ENSURE DOWNWARD COMPATIBILITY
#=================================================
ynh_script_progression "Ensuring downward compatibility..."

# Ensure ollama_connection setting exists (for upgrades from versions before this was added)
ynh_app_setting_set_default --key=ollama_connection --value="local"
ynh_app_setting_set_default --key=enable_login_form --value="true"

#=================================================
# RESOLVE OLLAMA URL
#=================================================
ynh_script_progression "Configuring Ollama connection..."

ollama_url=$(resolve_ollama_url "$ollama_connection" "$ollama_url")
ynh_app_setting_set --key=ollama_url --value="$ollama_url"

# Log Ollama detection status
ollama_domain=$(detect_ollama_domain)
if [ -n "$ollama_domain" ]; then
    ynh_print_info "Detected ollama_ynh at ${ollama_domain}"
fi

#=================================================
# UPGRADE PYTHON PACKAGE
#=================================================
ynh_script_progression "Upgrading Open WebUI..."

"$install_dir/venv/bin/pip" install --upgrade "open-webui==$OPENWEBUI_VERSION"

#=================================================
# UPDATE CONFIGURATION FILES
#=================================================
ynh_script_progression "Updating configuration files..."

ynh_config_add --template=".env" --destination="$install_dir/.env"
chmod 400 "$install_dir/.env"
chown "$app:$app" "$install_dir/.env"

#=================================================
# REAPPLY SYSTEM CONFIGURATION
#=================================================
ynh_script_progression "Upgrading system configurations..."

ynh_config_add_nginx

ynh_config_add_systemd

yunohost service add "$app" --description="Open WebUI AI chat interface"

#=================================================
# START SYSTEMD SERVICE
#=================================================
ynh_script_progression "Starting $app's systemd service..."

ynh_systemctl --service="$app" --action="start" --wait_until="Uvicorn running" --timeout=120

#=================================================
# END OF SCRIPT
#=================================================

ynh_script_progression "Upgrade of $app completed"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/upgrade
git add scripts/upgrade
git commit -m "feat: add upgrade script with pip upgrade and config regeneration"
```

---

### Task 7: Create backup script

**Files:**
- Create: `scripts/backup`

- [ ] **Step 1: Create scripts/backup**

Note: backup does NOT include the venv directory — it is rebuilt on restore. Only the `.env` config file from `$install_dir` is backed up.

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source ../settings/scripts/_common.sh
source /usr/share/yunohost/helpers

ynh_script_progression "Declaring files to be backed up..."

#=================================================
# BACKUP THE APP CONFIGURATION
#=================================================

# Only back up the config file, not the full venv (rebuilt on restore)
ynh_backup "$install_dir/.env"

#=================================================
# BACKUP THE DATA DIR
#=================================================

ynh_backup "$data_dir"

#=================================================
# BACKUP SYSTEM CONFIGURATION
#=================================================

ynh_backup "/etc/nginx/conf.d/$domain.d/$app.conf"

ynh_backup "/etc/systemd/system/$app.service"

#=================================================
# BACKUP THE POSTGRESQL DATABASE
#=================================================
ynh_print_info "Backing up the PostgreSQL database..."

ynh_psql_dump_db > db.sql

#=================================================
# END OF SCRIPT
#=================================================

ynh_print_info "Backup script completed for $app."
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/backup
git add scripts/backup
git commit -m "feat: add backup script (excludes venv, backs up config + data + DB)"
```

---

### Task 8: Create restore script

**Files:**
- Create: `scripts/restore`

- [ ] **Step 1: Create scripts/restore**

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source ../settings/scripts/_common.sh
source /usr/share/yunohost/helpers

#=================================================
# RESTORE THE APP CONFIGURATION
#=================================================
ynh_script_progression "Restoring the app configuration..."

ynh_restore "$install_dir/.env"
chown "$app:$app" "$install_dir/.env"
chmod 400 "$install_dir/.env"

#=================================================
# REBUILD PYTHON VENV
#=================================================
ynh_script_progression "Rebuilding Python virtual environment..."

python3 -m venv "$install_dir/venv"
"$install_dir/venv/bin/pip" install --upgrade pip
"$install_dir/venv/bin/pip" install "open-webui==$OPENWEBUI_VERSION"

chown -R "$app:$app" "$install_dir"

#=================================================
# RESTORE THE DATA DIRECTORY
#=================================================
ynh_script_progression "Restoring the data directory..."

ynh_restore "$data_dir"
chown -R "$app:$app" "$data_dir"

#=================================================
# RESTORE THE POSTGRESQL DATABASE
#=================================================
ynh_script_progression "Restoring the PostgreSQL database..."

ynh_psql_db_shell < ./db.sql

#=================================================
# RESTORE SYSTEM CONFIGURATION
#=================================================
ynh_script_progression "Restoring system configurations..."

ynh_restore "/etc/nginx/conf.d/$domain.d/$app.conf"

ynh_restore "/etc/systemd/system/$app.service"
systemctl enable "$app.service" --quiet

yunohost service add "$app" --description="Open WebUI AI chat interface"

#=================================================
# START SYSTEMD SERVICE
#=================================================
ynh_script_progression "Starting $app's systemd service..."

ynh_systemctl --service="$app" --action="start" --wait_until="Uvicorn running" --timeout=120

#=================================================
# END OF SCRIPT
#=================================================

ynh_script_progression "Restoration completed for $app"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/restore
git add scripts/restore
git commit -m "feat: add restore script with venv rebuild from pip"
```

---

### Task 9: Create change_url script

**Files:**
- Create: `scripts/change_url`

- [ ] **Step 1: Create scripts/change_url**

```bash
#!/bin/bash

#=================================================
# IMPORT GENERIC HELPERS
#=================================================

source _common.sh
source /usr/share/yunohost/helpers

#=================================================
# STOP SYSTEMD SERVICE
#=================================================
ynh_script_progression "Stopping $app's systemd service..."

ynh_systemctl --service="$app" --action="stop"

#=================================================
# MODIFY URL IN NGINX CONF
#=================================================
ynh_script_progression "Updating NGINX web server configuration..."

ynh_config_change_url_nginx

#=================================================
# START SYSTEMD SERVICE
#=================================================
ynh_script_progression "Starting $app's systemd service..."

ynh_systemctl --service="$app" --action="start" --wait_until="Uvicorn running" --timeout=120

#=================================================
# END OF SCRIPT
#=================================================

ynh_script_progression "Change of URL completed for $app"
```

- [ ] **Step 2: Make executable and commit**

```bash
chmod +x scripts/change_url
git add scripts/change_url
git commit -m "feat: add change_url script"
```

---

## Chunk 4: Documentation, Tests, and README

### Task 10: Create documentation files

**Files:**
- Create: `doc/DESCRIPTION.md`
- Create: `doc/DESCRIPTION_fr.md`
- Create: `doc/PRE_INSTALL.md`
- Create: `doc/screenshots/.gitkeep`

- [ ] **Step 1: Create doc directory**

```bash
mkdir -p doc/screenshots
```

- [ ] **Step 2: Create doc/DESCRIPTION.md**

```markdown
Open WebUI is a user-friendly, self-hosted AI chat interface. It supports multiple LLM backends including Ollama for local models and OpenAI-compatible APIs.

**Features:**

- ChatGPT-like interface for interacting with AI models
- Support for Ollama (local models) and OpenAI-compatible APIs
- RAG (Retrieval-Augmented Generation) with document uploads
- Multi-user support with role-based access control
- Conversation history and model management
- Integrated with YunoHost LDAP and SSO for seamless authentication
```

- [ ] **Step 3: Create doc/DESCRIPTION_fr.md**

```markdown
Open WebUI est une interface de chat IA conviviale et auto-hébergée. Elle supporte plusieurs backends LLM, dont Ollama pour les modèles locaux et les API compatibles OpenAI.

**Fonctionnalités :**

- Interface de type ChatGPT pour interagir avec des modèles IA
- Support d'Ollama (modèles locaux) et des API compatibles OpenAI
- RAG (Génération Augmentée par Récupération) avec téléchargement de documents
- Support multi-utilisateurs avec contrôle d'accès basé sur les rôles
- Historique des conversations et gestion des modèles
- Intégré au LDAP et SSO YunoHost pour une authentification transparente
```

- [ ] **Step 4: Create doc/PRE_INSTALL.md**

```markdown
### Ollama for local AI models

Open WebUI works best with [Ollama](https://ollama.com) for running AI models locally. You can install Ollama on your YunoHost server using the **ollama_ynh** package:

```bash
yunohost app install ollama
```

This is **optional** — Open WebUI can also connect to:

- A remote Ollama instance on another server
- OpenAI or any OpenAI-compatible API (Anthropic, Mistral, etc.)

### Resource requirements

Open WebUI itself is relatively lightweight, but running local AI models via Ollama requires significant resources (RAM, GPU). If you only plan to use remote APIs, the server requirements are modest.
```

- [ ] **Step 5: Create screenshots placeholder and commit**

```bash
touch doc/screenshots/.gitkeep
git add doc/
git commit -m "feat: add documentation (descriptions, pre-install notes, Ollama recommendation)"
```

---

### Task 11: Create tests.toml

**Files:**
- Create: `tests.toml`

- [ ] **Step 1: Create tests.toml**

```toml
#:schema https://raw.githubusercontent.com/YunoHost/apps/main/schemas/tests.v1.schema.json

test_format = 1.0

[default]

    args.init_main_permission = "visitors"
    args.ollama_connection = "local"
    args.ollama_url = "http://localhost:11434"
    args.openai_api_key = ""
    args.openai_api_base_url = "https://api.openai.com/v1"

[install.root]
    args_format = "domain=__DOMAIN__&path=/&admin=__USERNAME__&init_main_permission=visitors&ollama_connection=local&ollama_url=http://localhost:11434&openai_api_key=&openai_api_base_url=https://api.openai.com/v1"

[install.subpath]
    args_format = "domain=__DOMAIN__&path=__PATH__&admin=__USERNAME__&init_main_permission=visitors&ollama_connection=local&ollama_url=http://localhost:11434&openai_api_key=&openai_api_base_url=https://api.openai.com/v1"

[upgrade]

[backup_restore]

[change_url]
```

- [ ] **Step 2: Commit**

```bash
git add tests.toml
git commit -m "feat: add tests.toml for CI package_check"
```

---

### Task 12: Create README files

**Files:**
- Create: `README.md`
- Create: `README_fr.md`

- [ ] **Step 1: Create README.md**

```markdown
# Open WebUI for YunoHost

[![Integration level](https://apps.yunohost.org/badge/integration/openwebui)](https://ci-apps.yunohost.org/ci/apps/openwebui/)
[![Install Open WebUI with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=openwebui)

> *This package allows you to install Open WebUI quickly and simply on a YunoHost server.*
> *If you don't have YunoHost, please consult [the guide](https://yunohost.org/install) to learn how to install it.*

## Overview

Open WebUI is a user-friendly, self-hosted AI chat interface. It supports multiple LLM backends including Ollama for local models and OpenAI-compatible APIs.

**Shipped version:** 0.6.5~ynh1

## Documentation and resources

- Official app website: <https://openwebui.com>
- Official admin documentation: <https://docs.openwebui.com>
- Upstream app code repository: <https://github.com/open-webui/open-webui>
- YunoHost documentation for this app: <https://yunohost.org/app_openwebui>
- Report a bug: <https://github.com/YunoHost-Apps/openwebui_ynh/issues>

## Developer info

Please send your pull request to the [`testing` branch](https://github.com/YunoHost-Apps/openwebui_ynh/tree/testing).

To try the `testing` branch:

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/openwebui_ynh/tree/testing --debug
```

**More info regarding app packaging:** <https://yunohost.org/packaging_apps>
```

- [ ] **Step 2: Create README_fr.md**

```markdown
# Open WebUI pour YunoHost

[![Niveau d'intégration](https://apps.yunohost.org/badge/integration/openwebui)](https://ci-apps.yunohost.org/ci/apps/openwebui/)
[![Installer Open WebUI avec YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=openwebui)

> *Ce package vous permet d'installer Open WebUI rapidement et simplement sur un serveur YunoHost.*
> *Si vous n'avez pas YunoHost, consultez [le guide](https://yunohost.org/install) pour apprendre comment l'installer.*

## Vue d'ensemble

Open WebUI est une interface de chat IA conviviale et auto-hébergée. Elle supporte plusieurs backends LLM, dont Ollama pour les modèles locaux et les API compatibles OpenAI.

**Version incluse :** 0.6.5~ynh1

## Documentations et ressources

- Site officiel de l'app : <https://openwebui.com>
- Documentation officielle de l'admin : <https://docs.openwebui.com>
- Dépôt de code de l'app : <https://github.com/open-webui/open-webui>
- Documentation YunoHost pour cette app : <https://yunohost.org/app_openwebui>
- Signaler un bug : <https://github.com/YunoHost-Apps/openwebui_ynh/issues>

## Informations pour les développeurs

Merci d'envoyer vos pull requests sur la [branche `testing`](https://github.com/YunoHost-Apps/openwebui_ynh/tree/testing).

Pour essayer la branche `testing` :

```bash
sudo yunohost app install https://github.com/YunoHost-Apps/openwebui_ynh/tree/testing --debug
```

**Plus d'informations sur le packaging d'applications :** <https://yunohost.org/packaging_apps>
```

- [ ] **Step 3: Commit**

```bash
git add README.md README_fr.md
git commit -m "feat: add README files in English and French"
```

---

## Chunk 5: Final Review

### Task 13: Verify completeness and make final commit

- [ ] **Step 1: Verify all files exist**

```bash
ls -R
```

Expected structure:
```
LICENSE
README.md
README_fr.md
manifest.toml
tests.toml
conf/
    .env
    nginx.conf
    systemd.service
doc/
    DESCRIPTION.md
    DESCRIPTION_fr.md
    PRE_INSTALL.md
    screenshots/
scripts/
    _common.sh
    backup
    change_url
    install
    remove
    restore
    upgrade
```

- [ ] **Step 2: Verify all scripts are executable**

```bash
ls -la scripts/
```

All scripts (install, remove, upgrade, backup, restore, change_url) should have execute permission.

- [ ] **Step 3: Verify manifest.toml has no syntax errors**

```bash
python3 -c "import tomllib; tomllib.load(open('manifest.toml', 'rb')); print('manifest.toml OK')"
python3 -c "import tomllib; tomllib.load(open('tests.toml', 'rb')); print('tests.toml OK')"
```

Expected: Both print `OK`

- [ ] **Step 3b: Validate shell script syntax**

```bash
bash -n scripts/_common.sh scripts/install scripts/remove scripts/upgrade scripts/backup scripts/restore scripts/change_url
```

Expected: No output (no syntax errors)

- [ ] **Step 4: Check all __VARIABLE__ placeholders in templates are valid**

Verify that every `__PLACEHOLDER__` in conf/ templates corresponds to either a YunoHost built-in variable or a variable set in the install script:

Built-in: `__APP__`, `__INSTALL_DIR__`, `__PORT__`, `__PATH__`, `__DB_USER__`, `__DB_PWD__`, `__DB_NAME__`, `__DATA_DIR__`
Custom (set via `ynh_app_setting_set`): `__OLLAMA_URL__`, `__OPENAI_API_KEY__`, `__OPENAI_API_BASE_URL__`, `__ADMIN_EMAIL__`, `__ENABLE_LOGIN_FORM__`

```bash
grep -rho '__[A-Z_]*__' conf/ | sort -u
```

- [ ] **Step 5: Tag as ready for testing**

```bash
git tag v0.6.5~ynh1
```
