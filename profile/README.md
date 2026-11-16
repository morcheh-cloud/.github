# Morche

Self-hosted server management and monitoring over SSH. Terminals, files,
services, containers, databases, backups, reverse proxies and alerts for all
your servers, in one panel. Nothing is installed on the servers you manage.

## Get started

```bash
git clone https://github.com/morcheh-cloud/morche.git
cd morche
./install.sh
```

Needs Linux with Docker and the Compose plugin. The full guide (settings,
HTTPS, updates, backups) is in **[morche](https://github.com/morcheh-cloud/morche)**.

## Repositories

| Repository | What it is |
|---|---|
| [morche](https://github.com/morcheh-cloud/morche) | Docker Compose setup and install guide: start here |
| [backend](https://github.com/morcheh-cloud/backend) | API server (Go) |
| [frontend](https://github.com/morcheh-cloud/frontend) | Web panel (Next.js) |

Images: `ghcr.io/morcheh-cloud/backend` and `ghcr.io/morcheh-cloud/frontend`
(`linux/amd64`, `linux/arm64`).
