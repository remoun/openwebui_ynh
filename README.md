# Open WebUI for YunoHost

[![Install Open WebUI with YunoHost](https://install-app.yunohost.org/install-with-yunohost.svg)](https://install-app.yunohost.org/?app=openwebui)

> *This package allows you to install [Open WebUI](https://openwebui.com) quickly and simply on a YunoHost server.*
> *If you don't have YunoHost, please consult [the guide](https://yunohost.org/install) to learn how to install it.*

## Overview

Open WebUI is a user-friendly, self-hosted AI chat interface. It supports multiple LLM backends including Ollama for local models and OpenAI-compatible APIs.

**Shipped version:** 0.8.8~ynh1

### Features

- ChatGPT-like interface for interacting with AI models
- Support for **Ollama** (local models) and **OpenAI-compatible APIs**
- RAG (Retrieval-Augmented Generation) with document uploads
- Multi-user support with role-based access control
- Conversation history and model management

### YunoHost Integration

- **LDAP** — YunoHost users can log in directly (SSO mode)
- **SSO** — Seamless single sign-on via trusted headers (SSO mode)
- **Open registration** — Let anyone create their own account (open mode)
- **Multi-instance** — Run multiple Open WebUI instances on the same server

## Install

```bash
sudo yunohost app install https://github.com/remoun/openwebui_ynh
```

## Configuration

During install, you'll be asked:

| Setting | Description |
|---------|-------------|
| Domain | Which domain to serve on |
| Path | URL path (default: `/`) |
| Admin | YunoHost user who becomes the Open WebUI admin |
| Auth mode | **SSO** (YunoHost users only) or **Open** (anyone can register) |
| Access | Public (anyone sees login page) or SSO-restricted |

LLM connections (Ollama, OpenAI, OpenRouter, etc.) are configured through the Open WebUI admin panel after install — no API keys needed during setup.

All settings are stored as YunoHost app settings and can be changed after install:

```bash
sudo yunohost app setting openwebui <key> -v <value>
```

## Documentation and resources

- Official app website: <https://openwebui.com>
- Official admin documentation: <https://docs.openwebui.com>
- Upstream app code repository: <https://github.com/open-webui/open-webui>
- YunoHost packaging docs: <https://yunohost.org/packaging_apps>
- Report a bug: <https://github.com/remoun/openwebui_ynh/issues>

## Design

The package architecture and key decisions are documented in [`docs/superpowers/specs/DESIGN.md`](docs/superpowers/specs/DESIGN.md).

## Developer info

```bash
# Install from this repo (testing)
sudo yunohost app install https://github.com/remoun/openwebui_ynh --debug

# Validate locally
python3 -c "import tomllib; tomllib.load(open('manifest.toml', 'rb'))"
bash -n scripts/_common.sh scripts/install scripts/remove scripts/upgrade scripts/backup scripts/restore scripts/change_url
```

**More info regarding app packaging:** <https://yunohost.org/packaging_apps>
