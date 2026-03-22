# YunoHost Package for Open WebUI — Design Spec

## Overview

A YunoHost v2 package (`openwebui_ynh`) that installs Open WebUI as a self-hosted AI chat interface. The package targets Level 8+ quality for submission to the YunoHost app catalog.

Open WebUI connects to LLM backends (Ollama, OpenAI-compatible APIs) and provides a ChatGPT-like interface for self-hosted AI usage.

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Deployment method | pip install into Python venv | Standard YunoHost pattern, clean isolation, simple upgrades via PyPI |
| Database | PostgreSQL | Auto-provisioned by YunoHost, robust for multi-user |
| LLM backends | Both Ollama + OpenAI-compatible | Maximizes optionality; both configurable at install time |
| Access control | Admin-configurable (SSO-private or public) | Flexibility for different use cases |
| Ollama integration | Configurable URL field (default `http://localhost:11434`) | Works with `ollama_ynh` out of the box, overridable for remote servers |
| Multi-instance | Supported | Nearly free if scripts use `$app` variables consistently |

## Package Structure

```
openwebui_ynh/
├── manifest.toml
├── LICENSE (AGPL-3.0)
├── README.md / README_fr.md
├── tests.toml
├── scripts/
│   ├── _common.sh
│   ├── install
│   ├── remove
│   ├── upgrade
│   ├── backup
│   ├── restore
│   └── change_url
├── conf/
│   ├── nginx.conf
│   ├── systemd.service
│   └── .env
└── doc/
    ├── DESCRIPTION.md
    ├── DESCRIPTION_fr.md
    ├── PRE_INSTALL.md
    └── screenshots/
```

## manifest.toml

### Metadata

- `id = "openwebui"`
- `name = "Open WebUI"`
- `version` — tracks upstream Open WebUI version + `~ynh1` suffix
- `multi_instance = true`

### Install Questions

| Question | Type | Default | Notes |
|----------|------|---------|-------|
| Domain | domain | — | Standard YunoHost domain picker |
| Path | path | `/` | Open WebUI works best at root |
| Admin | user | — | Becomes Open WebUI admin |
| Is public | boolean | false | Whether unauthenticated users can see the login page |
| Ollama connection | select: `local` / `remote` | `local` | `local` uses `http://localhost:11434`; `remote` shows the URL field |
| Ollama URL | string | auto-detected `ollama_ynh` domain, or `http://localhost:11434` | Only shown when connection = `remote` |
| OpenAI API key | string | (blank) | Optional |
| OpenAI API base URL | string | `https://api.openai.com/v1` | For custom OpenAI-compatible endpoints |

### Resources

| Resource | Config |
|----------|--------|
| `system_user` | Default (username = app id) |
| `install_dir` | `/var/www/__APP__` |
| `data_dir` | `/home/yunohost.app/__APP__` |
| `port` | Default `8080` |
| `apt` | `python3`, `python3-venv`, `python3-pip`, `python3-dev`, `build-essential`, `libffi-dev` |
| `database` | PostgreSQL |
| `permissions` | Main URL, configurable public/private |

## Installation Flow

1. YunoHost auto-provisions resources (user, dirs, port, PostgreSQL DB)
2. Create Python venv at `$install_dir/venv`
3. `pip install open-webui==$OPENWEBUI_VERSION` into the venv
4. Generate `.env` config file from template with:
   - `DATABASE_URL=postgresql://$db_user:$db_pwd@localhost:5432/$db_name`
   - `OLLAMA_BASE_URL` (from install question)
   - `OPENAI_API_KEY` and `OPENAI_API_BASE_URL` (from install questions)
   - `DATA_DIR=$data_dir`
   - LDAP and SSO settings (see below)
   - `WEBUI_ADMIN_EMAIL` (admin user's email from YunoHost)
   - `ENABLE_SIGNUP=false` (users are managed via LDAP/SSO)
   - `ENABLE_LOGIN_FORM` — `true` when public, `false` when private (SSO handles auth)
5. Configure Ollama connection:
   - Detect `ollama_ynh` via `yunohost app setting ollama domain`
   - If `local` mode: set `OLLAMA_BASE_URL=http://localhost:11434`
   - If `remote` mode: use the admin-provided URL (defaulted to `https://<detected_ollama_domain>` if found)
   - If Ollama not detected: log a recommendation to install `ollama_ynh` or configure a remote URL
6. Install systemd service and nginx config via `ynh_` helpers
7. Start the service

## Runtime Configuration

### systemd Service

- Runs as the dedicated system user
- `ExecStart=$install_dir/venv/bin/open-webui serve --host 127.0.0.1 --port $port`
- `EnvironmentFile=$install_dir/.env`
- `WorkingDirectory=$install_dir`
- Restart on failure with backoff

### Nginx Reverse Proxy

- Reverse proxy to `127.0.0.1:$port`
- WebSocket support (`Upgrade` / `Connection` headers) for streaming responses
- Proxy headers: `Host`, `X-Real-IP`, `X-Forwarded-For`, `X-Forwarded-Proto`
- `client_max_body_size 512M` for file uploads (RAG documents)

## LDAP & SSO Integration

### LDAP Configuration (in `.env`)

```
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
```

Anonymous bind is used for LDAP search (YunoHost's slapd allows read access). Open WebUI automatically appends the username filter, so `LDAP_SEARCH_FILTER` only specifies additional conditions. Permission enforcement is handled at the nginx level by SSOwat.

### SSO Trusted Header Auth

```
WEBUI_AUTH_TRUSTED_EMAIL_HEADER=YNH_USER_EMAIL
WEBUI_AUTH_TRUSTED_NAME_HEADER=YNH_USER_FULLNAME
```

YunoHost's SSOwat sets `YNH_USER_EMAIL` and `YNH_USER_FULLNAME` headers for authenticated users. When behind the SSO portal, users are automatically logged in without seeing a login page.

### Admin Mapping

The YunoHost user selected as admin during install is mapped to Open WebUI's admin role via `WEBUI_ADMIN_EMAIL` set to that user's email address.

### Behavior by Access Mode

- **Private**: SSO handles auth, LDAP backs user creation, only permitted YunoHost users can access
- **Public**: Login page is accessible, both LDAP and local Open WebUI accounts work

## Lifecycle Scripts

### Upgrade (`scripts/upgrade`)

1. Stop the service
2. Upgrade pip package: `pip install --upgrade open-webui==$OPENWEBUI_VERSION` (version pinned in `_common.sh`)
3. Re-generate `.env` from template using stored YunoHost settings (`ynh_app_setting`). Manual `.env` edits are not preserved — all configurable values are stored as YunoHost settings.
4. Update nginx and systemd configs
5. Restart the service
6. Open WebUI handles its own DB migrations on startup

### Backup (`scripts/backup`)

- `$install_dir` (config files only — venv is excluded and rebuilt on restore)
- `$data_dir` (uploaded files)
- PostgreSQL database dump via `ynh_backup` helpers

### Restore (`scripts/restore`)

1. Restore config files to `$install_dir` and data to `$data_dir`
2. Recreate Python venv and `pip install open-webui==$OPENWEBUI_VERSION`
3. Restore PostgreSQL database
4. Reinstall systemd service and nginx config
5. Start the service

### Remove (`scripts/remove`)

1. Stop and remove systemd service
2. Remove nginx config
3. YunoHost auto-deprovisions resources (DB, user, dirs, port)

### Change URL (`scripts/change_url`)

1. Update nginx config with new domain/path
2. Update any URLs in `.env` if applicable
3. Reload nginx, restart service

### `_common.sh`

- Pins `OPENWEBUI_VERSION` (e.g., `"0.6.5"`)
- Shared variables and helper functions used across scripts

## Testing (`tests.toml`)

Test scenarios for YunoHost CI (package_check):

- Install on root path (`/`)
- Install on subpath (`/openwebui`)
- Upgrade from current version
- Backup and restore
- Change URL (domain and path)

Default test values provided for all install questions.

## Quality Targets (Level 8+)

- All lifecycle scripts pass CI
- LDAP integration works
- SSO trusted header auth works
- Backup/restore preserves data and database
- `change_url` works across domain and path changes
- App starts reliably after install and reboot
- Multi-instance: two instances coexist without conflict

## Documentation

`doc/DESCRIPTION.md` and `doc/PRE_INSTALL.md` should mention the `ollama_ynh` companion:

- **DESCRIPTION.md**: Note that Open WebUI supports both Ollama and OpenAI-compatible APIs for LLM access
- **PRE_INSTALL.md**: Recommend installing `ollama_ynh` for local AI model support; note that it's optional and Open WebUI can also connect to remote Ollama instances or OpenAI-compatible endpoints
