<div align="center">

<img src=".github/assets/banner.svg" alt="Morche: your servers, one panel" width="100%">

<br>

**Manage and monitor your servers over SSH: terminals, files, services, containers,<br>databases, backups, reverse proxies and alerts, from one panel.**

<br>

[![Backend image](https://img.shields.io/badge/ghcr.io-backend-3b82f6?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/morcheh-cloud/backend/pkgs/container/backend)
[![Frontend image](https://img.shields.io/badge/ghcr.io-frontend-8b5cf6?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/morcheh-cloud/frontend/pkgs/container/frontend)
[![Platforms](https://img.shields.io/badge/linux-amd64%20%7C%20arm64-22d3ee?style=for-the-badge&logo=linux&logoColor=white)](#requirements)
[![Docker Compose](https://img.shields.io/badge/docker-compose-0db7ed?style=for-the-badge&logo=docker&logoColor=white)](#configuration)

[**Quick start**](#quick-start) &nbsp;·&nbsp;
[**Install on a server**](#install) &nbsp;·&nbsp;
[**Configure**](#configuration) &nbsp;·&nbsp;
[**HTTPS**](#https) &nbsp;·&nbsp;
[**Update**](#update) &nbsp;·&nbsp;
[**Troubleshooting**](#troubleshooting)

</div>

<br>

<a id="quick-start"></a>

## ⚡ Quick start

Try Morche on your own machine with one command. All you need is Docker.

```bash
curl -fsSL https://raw.githubusercontent.com/morcheh-cloud/morche/main/install.sh | sh -s -- --quick-start
```

That's it. The installer checks Docker, writes `~/morche/.env` with fresh
secrets, pulls the images, starts everything and waits until it answers. Then
it tells you where to go:

```text
  ╭──────────────────────────────────────────────────────────────────╮
  │  ✓ Morche is ready                                               │
  ├──────────────────────────────────────────────────────────────────┤
  │  Panel       http://localhost:3200                               │
  │  API         http://localhost:8080                               │
  │  Setup token 2bc35807bed489555eb2fff00227bcc2c0ccba0e48bc9bad    │
  │  Folder      ~/morche                                            │
  ╰──────────────────────────────────────────────────────────────────╯

  Next
    1  Open http://localhost:3200
    2  Create the first admin account
    3  Paste the setup token above when the form asks for it
```

> [!NOTE]
> `--quick-start` binds both ports to `127.0.0.1`, so only this machine can
> reach the panel. To give other people access, use the server install below.

<a id="features"></a>

## ✨ What you get

<table>
<tr>
<td width="33%" valign="top">

**🖥️ Servers**<br>
Web terminals that keep running when you close the tab, a file manager,
services, live CPU, memory, disk and network insights.

</td>
<td width="33%" valign="top">

**📦 Workloads**<br>
Docker containers, databases, Ansible playbooks in a sandbox, cron schedules,
installed software and updates.

</td>
<td width="33%" valign="top">

**🛡️ Operations**<br>
Backups, reverse proxies, DNS, storage, Proxmox and cloud accounts, uptime
monitors, alerts and log archives.

</td>
</tr>
</table>

- **Agentless.** Morche talks to your servers over SSH. Nothing to install on them.
- **Yours.** Runs on your own machine with Docker Compose: Postgres, Redis, the backend and the panel.
- **Sealed secrets.** Every SSH key, password and token you save is encrypted with your own `SECRETS_KEY`.
- **Multi-arch.** Images for `linux/amd64` and `linux/arm64`.

<a id="requirements"></a>

## 📋 Requirements

| | |
|---|---|
| **OS** | Linux with Docker Engine 24+ and the Compose plugin (`docker compose`) |
| **Hardware** | 2 GB RAM, 10 GB disk |
| **Ports** | The panel (`3200`) and the backend (`8080`). Browsers talk to both |

<a id="install"></a>

## 🚀 Install on a server

On the machine that will run Morche:

```bash
curl -fsSL https://raw.githubusercontent.com/morcheh-cloud/morche/main/install.sh | sh
```

The installer asks for the address people will use to reach this machine (IP
or domain), writes `~/morche/.env` with fresh secrets and starts everything.
Open the panel address it prints, create the first admin, and paste the setup
token it showed.

<details>
<summary><b>Installer options</b></summary>

<br>

| Option | What it does |
|---|---|
| `--quick-start` | Local only: `http://localhost`, ports bound to `127.0.0.1`, no questions |
| `--dir PATH` | Where to keep `compose.yml` and `.env` (default `~/morche`) |
| `-h`, `--help` | Show help |

Environment variables it reads: `MORCHE_HOST` (skip the question),
`PANEL_PORT`, `BACKEND_PORT`, `MORCHE_VERSION`, `MORCHE_DIR`.

```bash
curl -fsSL https://raw.githubusercontent.com/morcheh-cloud/morche/main/install.sh | MORCHE_HOST=panel.example.com sh
```

Running it again is safe: an existing `.env` is kept as it is.

</details>

<details>
<summary><b>From a clone</b></summary>

<br>

```bash
git clone https://github.com/morcheh-cloud/morche.git
cd morche
./install.sh            # or ./install.sh --quick-start
```

</details>

<details>
<summary><b>By hand</b></summary>

<br>

```bash
cp .env.example .env    # fill in the addresses and the secrets
docker compose up -d
```

</details>

> [!IMPORTANT]
> **Keep a copy of `SECRETS_KEY`** (in `.env`). Every saved password and key is
> sealed with it; without it they can't be read again.

<a id="configuration"></a>

## ⚙️ Configuration

The installer writes `.env` for you. These are the values in it; Compose puts
them into `compose.yml`.

| Setting | Meaning |
|---|---|
| `MORCHE_VERSION` | Image tag: `latest` (newest build of main) or a release like `0.1.0` |
| `PANEL_URL` | Where people open the panel. Also used for links in alerts |
| `API_URL` | Where people's browsers reach the backend. Applied when the panel container starts |
| `PANEL_PORT`, `BACKEND_PORT` | Ports on this machine |
| `PANEL_BIND`, `BACKEND_BIND` | `0.0.0.0` = everyone, `127.0.0.1` = only this machine (behind your own proxy) |
| `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | Internal passwords |
| `SECRETS_KEY` | Seals stored credentials (`openssl rand -base64 32`) |
| `SETUP_TOKEN` | Asked for by the first-run form, so nobody else claims the panel first |
| `COOKIE_INSECURE` | `true` on plain http, `false` behind https |
| `TRUST_PROXY` | `true` only behind a proxy that sets `X-Forwarded-For` |
| `TZ` | Time zone, e.g. `Europe/Berlin` |

After changing `.env`, apply it with `docker compose up -d`.

<details>
<summary><b>The compose file</b></summary>

<br>

This is `compose.yml` as shipped. Required variables are set; optional ones
are commented out with their default, so uncomment a line to change it. The
`${...}` values come from `.env`.

```yaml
# Morche, self-hosted: Postgres, Redis, the backend and the panel.
#
#   ./install.sh                                    # first time: writes .env, starts everything
#   docker compose pull && docker compose up -d     # update
#   docker compose exec backend server reset-admin  # locked out of every admin
#
# Values in ${...} come from .env next to this file (see .env.example).
# Lines starting with "# " under environment are optional: they show the
# default; uncomment one to change it. Every variable is explained in README.md.
name: morche

x-restart: &restart
  restart: unless-stopped
  logging:
    driver: json-file
    options: { max-size: "10m", max-file: "3" }

services:
  postgres:
    <<: *restart
    image: postgres:18-alpine
    environment:
      POSTGRES_USER: morche
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:?set POSTGRES_PASSWORD in .env}
      POSTGRES_DB: morche
    volumes:
      - pgdata:/var/lib/postgresql
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U morche -d morche"]
      interval: 5s
      timeout: 3s
      retries: 20

  redis:
    <<: *restart
    image: redis:8-alpine
    command: ["sh", "-c", 'exec redis-server --requirepass "$$REDIS_PASSWORD" --appendonly yes']
    environment:
      REDIS_PASSWORD: ${REDIS_PASSWORD:?set REDIS_PASSWORD in .env}
    volumes:
      - redisdata:/data
    healthcheck:
      test: ["CMD-SHELL", 'redis-cli -a "$$REDIS_PASSWORD" --no-auth-warning ping']
      interval: 5s
      timeout: 3s
      retries: 20

  backend:
    <<: *restart
    image: ghcr.io/morcheh-cloud/backend:${MORCHE_VERSION:-latest}
    depends_on:
      postgres: { condition: service_healthy }
      redis: { condition: service_healthy }
    environment:
      # --- Required ---
      DATABASE_URL: postgres://morche:${POSTGRES_PASSWORD}@postgres:5432/morche?sslmode=disable
      REDIS_URL: redis://:${REDIS_PASSWORD}@redis:6379/0
      SECRETS_KEY: ${SECRETS_KEY:?set SECRETS_KEY in .env (openssl rand -base64 32)}
      PANEL_URL: ${PANEL_URL:?set PANEL_URL in .env}
      CORS_ALLOWED_ORIGINS: ${PANEL_URL}
      COOKIE_INSECURE: ${COOKIE_INSECURE:-false}
      LOG_ARCHIVE_DIR: /home/morche/log-archives

      # --- Recommended ---
      SETUP_TOKEN: ${SETUP_TOKEN:-}
      TRUST_PROXY: ${TRUST_PROXY:-false}
      TZ: ${TZ:-UTC}

      # --- Optional (defaults shown) ---
      # ANSIBLE_SANDBOX: auto
      # ANSIBLE_RUN_TIMEOUT: 2h
      # ANSIBLE_PLAYBOOK: ansible-playbook
      # TERMINAL_DETACHED_TIMEOUT: 15m
      # SERVER_CHECK_INTERVAL: 15s
      # SERVER_SAMPLE_INTERVAL: 1m
      # SERVER_HISTORY: 744h
      # STORAGE_CHECK_INTERVAL: 30s
      # STORAGE_SCAN_INTERVAL: 24h
      # STORAGE_HISTORY: 744h
      # DNS_CHECK_INTERVAL: 30s
      # PVE_CHECK_INTERVAL: 30s
      # CLOUD_CHECK_INTERVAL: 5m
      # PROXY_CHECK_INTERVAL: 60s
      # SOFTWARE_CHECK_INTERVAL: 6h
      # MONITOR_HISTORY: 336h
      # SCHEDULE_TICK: 15s
    volumes:
      # Log archives kept on Morche's own machine (Settings › Logs & archives).
      - logarchives:/home/morche/log-archives
    ports:
      - "${BACKEND_BIND:-0.0.0.0}:${BACKEND_PORT:-8080}:8080"
    # Playbook runs go in a bubblewrap sandbox, which needs user namespaces
    # and its own /proc. Docker's default profiles refuse both, so without the
    # lines below the sandbox is off and only system admins can run
    # playbooks. They loosen this container's own confinement; leave them out
    # if only admins run playbooks.
    # security_opt:
    #   - seccomp=unconfined
    #   - apparmor=unconfined
    #   - systempaths=unconfined

  frontend:
    <<: *restart
    image: ghcr.io/morcheh-cloud/frontend:${MORCHE_VERSION:-latest}
    depends_on: [backend]
    environment:
      # --- Required ---
      # Where people's browsers reach the backend (written into the panel
      # when the container starts).
      API_URL: ${API_URL:?set API_URL in .env}
    ports:
      - "${PANEL_BIND:-0.0.0.0}:${PANEL_PORT:-3200}:3200"

volumes:
  pgdata:
  redisdata:
  logarchives:
```

</details>

<details>
<summary><b>All environment variables</b></summary>

<br>

Every variable the containers read. You set them under `environment:` in
`compose.yml` (the ones from `.env` are already wired up). Durations are
written like `30s`, `15m`, `6h` (no days: one week is `168h`); `0` turns a
background job off.

| Variable | Container | Required | Default | What it does |
|---|---|---|---|---|
| `DATABASE_URL` | backend | yes | — | Postgres connection string |
| `REDIS_URL` | backend | yes | — | Redis connection string |
| `SECRETS_KEY` | backend | yes | — | Key that seals every stored password and SSH key |
| `API_URL` | frontend | yes | — | Address browsers use to reach the backend |
| `PANEL_URL` | backend | yes* | first CORS origin | Address of the panel, used in links |
| `CORS_ALLOWED_ORIGINS` | backend | yes* | `http://localhost:3200` | Panel addresses allowed to call the backend |
| `COOKIE_INSECURE` | backend | on http | `false` | Send the sign-in cookie over plain http |
| `LOG_ARCHIVE_DIR` | backend | set | `data/log-archives` | Folder for log archives kept on this machine |
| `SETUP_TOKEN` | backend | recommended | empty | Code the first-run form asks for |
| `TRUST_PROXY` | backend | no | `false` | Believe `X-Forwarded-For` / `X-Real-IP` |
| `TZ` | backend | no | `UTC` | Time zone for schedules and reports |
| `ANSIBLE_SANDBOX` | backend | no | `auto` | Playbook sandbox: `auto`, `bwrap` or `off` |
| `ANSIBLE_RUN_TIMEOUT` | backend | no | `2h` | A playbook still running after this is stopped |
| `ANSIBLE_PLAYBOOK` | backend | no | `ansible-playbook` | The `ansible-playbook` command to use |
| `TERMINAL_DETACHED_TIMEOUT` | backend | no | `15m` | Close a web terminal nobody has open after this |
| `SERVER_CHECK_INTERVAL` | backend | no | `15s` | How often each server's connection is checked |
| `SERVER_SAMPLE_INTERVAL` | backend | no | `1m` | How often CPU, memory, disk and network are read |
| `SERVER_HISTORY` | backend | no | `744h` | How long server checks and samples are kept |
| `STORAGE_CHECK_INTERVAL` | backend | no | `30s` | How often each storage is checked |
| `STORAGE_SCAN_INTERVAL` | backend | no | `24h` | How often each storage's size is measured |
| `STORAGE_HISTORY` | backend | no | `744h` | How long storage checks are kept |
| `DNS_CHECK_INTERVAL` | backend | no | `30s` | How often each DNS server is checked |
| `PVE_CHECK_INTERVAL` | backend | no | `30s` | How often each Proxmox cluster is checked |
| `CLOUD_CHECK_INTERVAL` | backend | no | `5m` | How often cloud accounts are read again |
| `PROXY_CHECK_INTERVAL` | backend | no | `60s` | How often each reverse proxy is checked |
| `SOFTWARE_CHECK_INTERVAL` | backend | no | `6h` | How often servers are scanned for applications and updates |
| `MONITOR_HISTORY` | backend | no | `336h` | How long single uptime checks are kept |
| `SCHEDULE_TICK` | backend | no | `15s` | How often Morche looks for cron jobs that are due |

\* Not enforced by the backend, but the panel won't work without them in this
setup: `compose.yml` fills both from `PANEL_URL`.

#### Details

**`DATABASE_URL`, `REDIS_URL`.** Built in `compose.yml` from
`POSTGRES_PASSWORD` and `REDIS_PASSWORD`, pointing at the bundled containers.
Change them only to use your own Postgres (16 or newer) or Redis. Migrations
run by themselves when the backend starts.

**`SECRETS_KEY`.** Base64 of 32 random bytes (`openssl rand -base64 32`). Every
SSH key, password and token you save is encrypted with it. Changing or losing
it makes them unreadable: back it up with the database, and never change it on
a running install.

**`API_URL`.** Read only by the panel container, which writes it into the
panel's files when it starts. It must be reachable from people's browsers, not
just from this machine, so use the machine's IP or a domain, not `localhost`
or `backend`. After changing it, `docker compose up -d` recreates the panel.

**`PANEL_URL`, `CORS_ALLOWED_ORIGINS`.** `PANEL_URL` must match the browser's
address bar exactly (scheme, host and port), or the backend refuses the
panel's requests. If people reach the panel under several addresses, list them
all in `CORS_ALLOWED_ORIGINS`, separated by commas. `*` is refused.

**`COOKIE_INSECURE`.** The sign-in cookie is marked Secure, so browsers send it
only over https. On plain http set it to `true`, or signing in won't stick.
Behind https set it to `false`.

**`LOG_ARCHIVE_DIR`.** Where Settings › Logs & archives writes archives kept on
this machine. `compose.yml` points it at the `logarchives` volume. Keep the two
in step if you change it.

**`SETUP_TOKEN`.** A fresh install lets the first visitor create the admin
account. With this set, the form also asks for the token, so a stranger who
finds the panel first can't take it over. It's unused once the admin exists.

**`TRUST_PROXY`.** Turn it on only behind a reverse proxy that sets
`X-Forwarded-For`. Otherwise anyone can fake their address, which defeats the
sign-in limits, the address allowlist and the audit log.

**`TZ`.** Used for cron schedules, daily reports and log times, for example
`Asia/Tehran` or `Europe/Berlin`.

**`ANSIBLE_SANDBOX`.** Playbooks run in a bubblewrap sandbox so they can't read
Morche's own files. `auto` uses it when it works; without it only system admins
can run playbooks. `bwrap` refuses to run without it, `off` never uses it. In
Docker the sandbox needs the `security_opt` lines in `compose.yml`.

**`ANSIBLE_RUN_TIMEOUT`, `ANSIBLE_PLAYBOOK`.** The longest a playbook may run,
and the command used to run it. The image ships Ansible, so leave the command
as it is.

**`TERMINAL_DETACHED_TIMEOUT`.** A terminal keeps running on the backend when
its tab is closed, so you can come back to it. After this long with nobody
attached, it's closed.

**Check intervals** (`SERVER_`, `STORAGE_`, `DNS_`, `PVE_`, `CLOUD_`,
`PROXY_`, `SOFTWARE_CHECK_INTERVAL`). Morche checks everything in the
background, so statuses and alerts stay current. Shorter means quicker news and
more SSH and API traffic. `0` turns the background check off; pressing Check
still works. Storage checks sign in to the remote service each time, and cloud
checks list every region, so keep those slower.

**`SERVER_SAMPLE_INTERVAL`.** Feeds Servers › Insights, metrics and alert rules.
Each sample is about a second of work on the server. `0` turns it off, which
also stops CPU, memory and disk alerts.

**`STORAGE_SCAN_INTERVAL`.** Measuring a storage walks every file in it. Large
buckets take a while, and on paid S3 each list request costs money. `0` means
only when someone presses Measure.

**History** (`SERVER_HISTORY`, `STORAGE_HISTORY`, `MONITOR_HISTORY`). How long
detailed checks and samples stay in the database for charts. `744h` is 31 days
and `336h` is 14 days. Uptime monitors' daily totals are kept for good.

**`SCHEDULE_TICK`.** How often due cron jobs are started. `0` means they never
run on time, though Run now still works.

</details>

<a id="https"></a>

## 🔒 HTTPS

Put any reverse proxy you like in front, with one name for the panel and one
for the backend, and bind the ports to `127.0.0.1`. For example with Caddy:

```caddy
panel.example.com {
	reverse_proxy 127.0.0.1:3200
}

api.example.com {
	reverse_proxy 127.0.0.1:8080
}
```

```dotenv
PANEL_URL=https://panel.example.com
API_URL=https://api.example.com
PANEL_BIND=127.0.0.1
BACKEND_BIND=127.0.0.1
COOKIE_INSECURE=false
TRUST_PROXY=true
```

> [!TIP]
> The proxy must pass WebSockets and must not buffer responses (terminals and
> live views use WebSockets and server-sent events). Caddy does both by
> default; with nginx add `proxy_http_version 1.1`, the `Upgrade`/`Connection`
> headers and `proxy_buffering off` on the backend's site.

<a id="update"></a>

## 🔄 Update

```bash
cd ~/morche
docker compose pull
docker compose up -d
```

Database migrations run by themselves when the backend starts. `latest`
follows the main branch; pin `MORCHE_VERSION` to a release if you want to
choose when to move.

<a id="backup"></a>

## 💾 Back up

Two things matter: the database and `SECRETS_KEY` (in `.env`).

```bash
docker compose exec -T postgres pg_dump -U morche morche | gzip > morche-$(date +%F).sql.gz
cp .env /somewhere/safe/
```

Restore into a fresh install (same `.env`):

```bash
docker compose up -d postgres
gunzip -c morche-2026-01-01.sql.gz | docker compose exec -T postgres psql -U morche morche
docker compose up -d
```

<a id="troubleshooting"></a>

## 🩺 Troubleshooting

| Symptom | Fix |
|---|---|
| Signing in doesn't stick | On plain http `COOKIE_INSECURE` must be `true`; behind https it must be `false` |
| The panel says it can't reach the server | `API_URL` must be reachable from the browser (not `localhost` unless you browse on this machine), and `PANEL_URL` must match the address bar exactly (scheme, host and port) |
| Locked out of every admin account | `docker compose exec backend server reset-admin` |
| Only admins can run Ansible playbooks | The playbook sandbox needs user namespaces, which Docker's default profiles refuse. Uncomment the `security_opt` lines in `compose.yml` |
| Something else | `docker compose logs -f backend` (or `frontend`) |

<a id="uninstall"></a>

## 🧹 Uninstall

```bash
docker compose down        # keeps the data
docker compose down -v     # also deletes the database and archives
```

<br>

<div align="center">

Built from [**backend**](https://github.com/morcheh-cloud/backend) and [**frontend**](https://github.com/morcheh-cloud/frontend)
&nbsp;·&nbsp; images on `ghcr.io/morcheh-cloud`

</div>
