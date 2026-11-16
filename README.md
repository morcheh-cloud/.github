# Morche — self-hosted

Morche manages and monitors your servers over SSH: terminals, files, services,
containers, databases, backups, reverse proxies, alerts and more, from one
panel. Nothing is installed on the servers you manage.

This repository holds what you need to run it with Docker Compose. The images
are built from [backend](https://github.com/morcheh-cloud/backend) and
[frontend](https://github.com/morcheh-cloud/frontend):

| Image | What it is |
|---|---|
| `ghcr.io/morcheh-cloud/backend` | API server, plus the tools it drives (ssh, Ansible, database clients) |
| `ghcr.io/morcheh-cloud/frontend` | the web panel |

Postgres and Redis run beside them. Images are published for `linux/amd64`
and `linux/arm64`.

## Requirements

- Linux with Docker Engine 24+ and the Compose plugin (`docker compose`)
- 2 GB RAM, 10 GB disk
- Two open ports: the panel (3200) and the backend (8080). Browsers talk to
  both.

## Install

```bash
git clone https://github.com/morcheh-cloud/morche.git
cd morche
./install.sh
```

The script asks for the address people will use to reach this machine, writes
`.env` with fresh secrets and starts everything. Then open the panel address it
prints, create the first admin, and paste the setup token it showed.

Doing it by hand instead:

```bash
cp .env.example .env    # fill in the addresses and the secrets
docker compose up -d
```

> **Keep a copy of `SECRETS_KEY`.** Every saved password and key is sealed with
> it; without it they can't be read again.

## Settings (`.env`)

| Setting | Meaning |
|---|---|
| `MORCHE_VERSION` | Image tag: `latest`, a release (`0.1.0`), or `edge` (main branch) |
| `PANEL_URL` | Where people open the panel. Also used for links in alerts |
| `API_URL` | Where people's browsers reach the backend. Applied when the panel container starts |
| `PANEL_PORT`, `BACKEND_PORT` | Ports on this machine |
| `PANEL_BIND`, `BACKEND_BIND` | `0.0.0.0` = everyone, `127.0.0.1` = only this machine (behind your own proxy) |
| `POSTGRES_PASSWORD`, `REDIS_PASSWORD` | Internal passwords |
| `SECRETS_KEY` | Seals stored credentials (`openssl rand -base64 32`) |
| `SETUP_TOKEN` | Asked for by the first-run form, so nobody else claims the panel first |
| `COOKIE_INSECURE` | `true` on plain http, `false` behind https |
| `TRUST_PROXY` | `true` only behind a proxy that sets `X-Forwarded-For` |
| `ANSIBLE_SANDBOX` | `auto`, `bwrap` or `off` (see below) |
| `TZ` | Time zone, e.g. `Europe/Berlin` |

After changing `.env`: `docker compose up -d`.

## HTTPS

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

The proxy must pass WebSockets and must not buffer responses (terminals and
live views use WebSockets and server-sent events). Caddy does both by default;
with nginx add `proxy_http_version 1.1`, the `Upgrade`/`Connection` headers
and `proxy_buffering off` on the backend's site.

## Update

```bash
docker compose pull
docker compose up -d
```

Database migrations run by themselves when the backend starts. Pin
`MORCHE_VERSION` to a release if you want to choose when to move.

## Back up

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

## Troubleshooting

- **Signing in doesn't stick**: on plain http `COOKIE_INSECURE` must be `true`;
  behind https it must be `false`.
- **The panel says it can't reach the server**: `API_URL` must be reachable
  from the browser (not `localhost` unless you browse on this machine), and
  `PANEL_URL` must match the address in the browser's address bar exactly
  (scheme, host and port), or the backend refuses the requests.
- **Locked out of every admin account**:
  `docker compose exec backend server reset-admin`
- **Only admins can run Ansible playbooks**: the playbook sandbox needs user
  namespaces, which Docker's default profiles refuse. Uncomment the
  `security_opt` lines in `compose.yml` to allow it.
- **Logs**: `docker compose logs -f backend` (or `frontend`).

## Uninstall

```bash
docker compose down        # keeps the data
docker compose down -v     # also deletes the database and archives
```
