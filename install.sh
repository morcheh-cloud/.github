#!/bin/sh
# First-time setup for Morche: writes .env with fresh secrets and starts the
# stack. Safe to run again: an existing .env is kept as it is.
#
#   ./install.sh                         # asks for the address
#   MORCHE_HOST=panel.example.com ./install.sh   # no questions
set -eu
cd "$(dirname "$0")"

say() { printf '%s\n' "$*"; }
die() { say "error: $*" >&2; exit 1; }

command -v docker >/dev/null || die "Docker is not installed (https://docs.docker.com/engine/install/)"
docker compose version >/dev/null 2>&1 || die "the Docker Compose plugin is missing (docker compose)"

secret_hex() {
  if command -v openssl >/dev/null; then openssl rand -hex 24
  else head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
}
secret_b64() {
  if command -v openssl >/dev/null; then openssl rand -base64 32
  else head -c 32 /dev/urandom | base64 | tr -d '\n'; fi
}

if [ -f .env ]; then
  say ".env already exists: keeping it."
else
  host=${MORCHE_HOST:-}
  if [ -z "$host" ]; then
    guess=$(hostname -I 2>/dev/null | awk '{print $1}')
    guess=${guess:-localhost}
    if [ -t 0 ]; then
      printf 'Address people will use to reach this machine (IP or domain) [%s]: ' "$guess"
      read -r host
    fi
    host=${host:-$guess}
  fi
  panel_port=${PANEL_PORT:-3200}
  backend_port=${BACKEND_PORT:-8080}
  setup_token=$(secret_hex)

  sed \
    -e "s|^PANEL_URL=.*|PANEL_URL=http://$host:$panel_port|" \
    -e "s|^API_URL=.*|API_URL=http://$host:$backend_port|" \
    -e "s|^PANEL_PORT=.*|PANEL_PORT=$panel_port|" \
    -e "s|^BACKEND_PORT=.*|BACKEND_PORT=$backend_port|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(secret_hex)|" \
    -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$(secret_hex)|" \
    -e "s|^SECRETS_KEY=.*|SECRETS_KEY=$(secret_b64)|" \
    -e "s|^SETUP_TOKEN=.*|SETUP_TOKEN=$setup_token|" \
    .env.example >.env
  chmod 600 .env
  say "Wrote .env (keep a copy of SECRETS_KEY somewhere safe)."
fi

docker compose pull
docker compose up -d

panel=$(sed -n 's/^PANEL_URL=//p' .env)
token=$(sed -n 's/^SETUP_TOKEN=//p' .env)
say ""
say "Morche is starting. Open $panel"
[ -n "$token" ] && say "The first-run form asks for the setup token: $token"
