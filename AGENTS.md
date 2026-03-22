# AGENTS.md

## Project

YunoHost v2 package (`openwebui_ynh`) for self-hosting [Open WebUI](https://openwebui.com) — a ChatGPT-like AI chat interface.

- **Repo:** https://github.com/remoun/yunohost-openwebui
- **Target:** Level 8+ quality for [YunoHost app catalog](https://github.com/YunoHost/apps) submission
- **Spec:** `docs/superpowers/specs/DESIGN.md`
- **Plan:** `docs/superpowers/plans/2026-03-22-yunohost-openwebui.md`

## Architecture

- Open WebUI installed from PyPI into a Python venv (`$install_dir/venv`)
- PostgreSQL database, auto-provisioned by YunoHost
- nginx reverse proxy with WebSocket support for streaming
- systemd service binding to `127.0.0.1` (never `0.0.0.0` — SSOwat enforces access control)
- LDAP integration for YunoHost user authentication
- SSO trusted header auth (`YNH_USER_EMAIL`, `YNH_USER_FULLNAME`)
- Ollama auto-detection via `ynh_app_setting_get --app=ollama --key=domain`
- Multi-instance supported (always use `$app`, never hardcode `openwebui`)

## Key Decisions

| Decision | Choice | Why |
|----------|--------|-----|
| Deployment | pip into venv | Standard YunoHost pattern, clean isolation |
| Database | PostgreSQL | Auto-provisioned, robust for multi-user |
| LLM backends | Ollama + OpenAI-compatible | Maximize optionality |
| Ollama connection | local/remote toggle | Works with `ollama_ynh` out of the box, overridable |
| Backup strategy | Exclude venv, rebuild on restore | Saves hundreds of MB in backup archives |
| Access control | Admin-configurable (SSO-private or public) | Flexibility |

## Conventions

- **YunoHost v2 helpers only** — use `ynh_*` functions, never raw `yunohost` CLI commands in scripts
- **Backup scripts** use `ynh_print_info`, not `ynh_script_progression` (linter requirement)
- **All config** goes through `.env` template rendered by `ynh_config_add` — manual `.env` edits are not preserved on upgrade
- **Settings persistence** — custom values (ollama_url, admin_email, enable_login_form) are stored via `ynh_app_setting_set` so they survive upgrades
- **Version pinning** — `OPENWEBUI_VERSION` is set in `scripts/_common.sh`, used everywhere

## Lint & Test Requirements

Before committing or opening a PR, run:

### Lint (required)

```bash
# TOML syntax
python3 -c "import tomllib; tomllib.load(open('manifest.toml', 'rb'))"
python3 -c "import tomllib; tomllib.load(open('tests.toml', 'rb'))"

# Shell syntax
bash -n scripts/_common.sh scripts/install scripts/remove scripts/upgrade scripts/backup scripts/restore scripts/change_url

# ShellCheck (install: apt install shellcheck / brew install shellcheck)
bash tests/run_shellcheck.sh
```

### Tests (required)

```bash
# Bats unit tests (install: apt install bats / brew install bats-core)
bats tests/
```

### Optional (YunoHost catalog submission)

- **package_linter** — Linux only (crashes on macOS due to `grep -P` / `du -sb`). Clone https://github.com/YunoHost/package_linter and run `package_linter.py`.
- **package_check** — Full integration test (requires Debian with LXC). Clone https://github.com/YunoHost/package_check and run `package_check.sh`.

## Status

All package files created and linter-validated. Not yet tested on a real YunoHost server.

### Future Enhancements
- Model management helpers beyond Open WebUI's built-in UI
