# Morche live demo

A public Morche panel anyone can try without an account, with throwaway
servers to manage. Visitors press **Enter the live demo** and land in the
panel as a shared Engineer account. Every `DEMO_RESET_MINUTES`, counted from
midnight UTC, everything goes back to the seeded state. The charts keep their
history through resets.

Link to it from the website as `https://<DEMO_DOMAIN>/login?demo=1`. That
address signs the visitor in at once.

## What's in it

| Service | Role |
|---|---|
| `frontend`, `backend` | Morche, the backend with `DEMO_MODE=true` |
| `postgres`, `redis` | Morche's own data |
| `reset` (`ghcr.io/morcheh-cloud/demo-reset`) | Seeds the demo on first start, resets it on the clock, and runs the lab below as its own compose project `morche-demo-lab` (`reset/lab.yml`) |
| `lab-web-1`, `lab-web-2` (`ghcr.io/morcheh-cloud/demo-lab`) | Debian servers: SSH, systemd, nginx, a small `shop-api` service, fail2ban, ufw |
| `lab-docker-1` | Debian with Docker and a compose project (`shop`), images baked in |
| `lab-postgres`, `lab-mariadb`, `lab-redis` | Databases for the Databases section |
| `lab-s3` | S3 storage (RustFS) for Storage and backups |

## How visitors are kept in the sandbox

- **No way out.** The backend and lab servers sit on Docker `internal`
  networks with no route to the internet. Anything a visitor points Morche
  at (a server address, a webhook, a monitor URL, a storage) can only reach
  the lab. Your reverse proxy joins the core network to reach the panel; it
  keeps its own network for the way out.
- **No way to Morche's data.** A root shell on a lab server reaches the
  other lab containers and nothing of Morche's: the database, Redis and the
  reset job are on another network.
- **The API isn't on the lab side.** The backend joins the lab network only
  to reach the lab servers; its API listens on its core address alone. So a
  lab shell can't call it directly, or fake `X-Forwarded-For` to dodge the
  sign-in limits. And with `TRUST_PROXY` the backend reads only the last
  `X-Forwarded-For` entry, the one your proxy appended. Headers a visitor
  sends are ignored.
- **Morche's own Postgres and Redis.** The backend does reach them, and a
  visitor can point some connections anywhere. But checking a private
  address from Morche itself is for system admins only: monitors, direct
  databases, webhooks, DNS. What's left speaks the wrong protocol to
  Postgres and Redis and can't sign in to either, since both have long
  random passwords.
- **Root without the host's root.** The lab servers run under
  [Sysbox](https://github.com/nestybox/sysbox). Visitors get root and Docker
  in them, but on the host they are an unprivileged user. Each lab server is
  capped in memory, CPU and processes.
- **The shared account is locked down.** With `DEMO_MODE`, the backend
  refuses these for anyone but an admin:
  - its password, profile, sessions and sign-in history (one visitor's
    address would show to the rest);
  - granting access;
  - running Ansible.

  Terminals belong to each visitor's own session, not the shared account.
  The audit log keeps no visitor addresses. The account is an Engineer, so
  Owner-only actions are closed too: seeing saved passwords, deleting
  servers, notification channels.

## Requirements

- A Linux host with Docker, plus Sysbox
  ([install](https://github.com/nestybox/sysbox/blob/master/docs/user-guide/install-package.md)).
- About 4 GB of RAM and 20 GB of disk.
- A reverse proxy in Docker, such as Nginx Proxy Manager, and two DNS names
  pointing at it.

## Run it

`compose.yml` uses only prebuilt images (`.github/workflows/demo-images.yml`
builds the two demo ones), so a stack manager such as Arcane or Portainer
needs just that file and the values from `.env.example`. By hand:

```sh
cp .env.example .env    # fill in the domains and every secret
docker compose up -d
docker compose logs -f reset   # watch the first seed (a few minutes)
```

Then connect the reverse proxy to `morche-demo-core`. In its compose file,
add the network as `external: true` to the proxy's `networks`, or run
`docker network connect morche-demo-core <proxy container>`. A plain
`network connect` is lost when the proxy container is recreated. Then add
two hosts. In Nginx Proxy Manager these are Proxy Hosts, each with an SSL
certificate and *Force SSL*:

| Domain | Forward to | Websockets |
|---|---|---|
| `DEMO_DOMAIN` | `http://morche-demo-frontend:3200` | on |
| `DEMO_API_DOMAIN` | `http://morche-demo-backend:8080` | **on** (terminals, live charts) |

On first start, `reset` seeds the panel through the API: the admin, the demo
account, servers, databases, storage, monitors, alert rules, services and
scripts. It then keeps that database as `morche_golden`. Every reset:

1. saves the history tables;
2. stops the backend;
3. recreates `morche` from `morche_golden`;
4. puts the history back, minus rows about things visitors made;
5. empties Redis;
6. rebuilds every lab container from its image;
7. starts the backend again.

**Change the seed:** edit `reset/seed.sh`, then
`docker compose exec postgres dropdb -U morche morche_golden` and
`docker compose restart reset`. With no snapshot, `reset` seeds again.
Start from an empty database:
`docker compose down -v && docker compose up -d`.

**Remove it:** `docker compose down -v`, then
`docker compose -p morche-demo-lab down`. The lab is a project of its own.

**Sign in as admin:** on the sign-in page, press
*Running this demo? Sign in with an account*, then use `admin` and
`ADMIN_PASSWORD`.

## Limits worth knowing

- Lab servers can't download anything, so these fail with a network error:
  package installs, `docker pull`, git deploys and Fetch from URL. The baked-in
  images are `nginx`, `redis`, `whoami` and `adminer`. Add more in
  `lab/Dockerfile`.
- The core network is `172.29.10.0/24`, and the backend sits at
  `172.29.10.10`. If that subnet is taken on the host, change both in
  `compose.yml`.
- Charts start empty and fill up over the days the demo runs.
- Not seeded yet: DNS (Technitium), Proxmox, cloud accounts.
