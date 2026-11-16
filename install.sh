#!/bin/sh
# Morche installer: writes .env with fresh secrets, starts the stack and waits
# until the panel answers. Safe to run again: an existing .env is kept.
#
#   curl -fsSL https://raw.githubusercontent.com/morcheh-cloud/.github/main/install.sh | sh
#   curl -fsSL https://raw.githubusercontent.com/morcheh-cloud/.github/main/install.sh | sh -s -- --quick-start
#
#   ./install.sh                                 # from a clone; asks for the address
#   ./install.sh --quick-start                   # try it on this machine (localhost)
#   MORCHE_HOST=panel.example.com ./install.sh   # no questions
#
# Run outside a clone (piped from curl), it puts compose.yml and .env in
# $MORCHE_DIR (default: ~/morche).
set -eu

REPO_RAW=${MORCHE_RAW_URL:-https://raw.githubusercontent.com/morcheh-cloud/.github/${MORCHE_REF:-main}}

# ---------------------------------------------------------------- arguments --
quick=0
dir=${MORCHE_DIR:-}
while [ $# -gt 0 ]; do
  case $1 in
    --quick-start|--quickstart|-q) quick=1 ;;
    --dir) [ $# -ge 2 ] || { echo "--dir needs a path" >&2; exit 2; }; dir=$2; shift ;;
    --dir=*) dir=${1#--dir=} ;;
    -h|--help)
      cat <<'EOF'
Morche installer

Usage: install.sh [--quick-start] [--dir PATH]

  --quick-start   Run Morche on this machine only: http://localhost, ports
                  bound to 127.0.0.1, no questions. Best way to try it out.
  --dir PATH      Where to keep compose.yml and .env when not run from a
                  clone (default: ~/morche).
  -h, --help      Show this help.

Environment: MORCHE_HOST, PANEL_PORT, BACKEND_PORT, MORCHE_VERSION, MORCHE_DIR
EOF
      exit 0 ;;
    *) echo "unknown option: $1 (try --help)" >&2; exit 2 ;;
  esac
  shift
done

# ------------------------------------------------------------------- styling --
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
  e=$(printf '\033')
  R="$e[0m" B="$e[1m" D="$e[2m"
  C1="$e[38;5;51m" C2="$e[38;5;45m" C3="$e[38;5;39m" C4="$e[38;5;33m" C5="$e[38;5;63m" C6="$e[38;5;99m"
  GRN="$e[38;5;42m" YEL="$e[38;5;214m" RED="$e[38;5;203m" CYA="$e[38;5;45m" GRY="$e[38;5;244m"
else
  R='' B='' D='' C1='' C2='' C3='' C4='' C5='' C6='' GRN='' YEL='' RED='' CYA='' GRY=''
fi

say()  { printf '%s\n' "$*"; }
step() { printf '\n  %s›%s %s%s%s\n' "$CYA" "$R" "$B" "$*" "$R"; }
ok()   { printf '    %s✓%s %s\n' "$GRN" "$R" "$*"; }
info() { printf '    %s·%s %s\n' "$GRY" "$R" "$*"; }
warn() { printf '    %s!%s %s\n' "$YEL" "$R" "$*"; }
die()  { printf '\n  %s✗ %s%s\n\n' "$RED" "$*" "$R" >&2; exit 1; }

banner() {
  say ""
  say "  ${C1}███╗   ███╗ ██████╗ ██████╗  ██████╗██╗  ██╗███████╗${R}"
  say "  ${C2}████╗ ████║██╔═══██╗██╔══██╗██╔════╝██║  ██║██╔════╝${R}"
  say "  ${C3}██╔████╔██║██║   ██║██████╔╝██║     ███████║█████╗  ${R}"
  say "  ${C4}██║╚██╔╝██║██║   ██║██╔══██╗██║     ██╔══██║██╔══╝  ${R}"
  say "  ${C5}██║ ╚═╝ ██║╚██████╔╝██║  ██║╚██████╗██║  ██║███████╗${R}"
  say "  ${C6}╚═╝     ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝${R}"
  say "  ${GRY}Your servers, one panel. Nothing to install on them.${R}"
  if [ "$quick" = 1 ]; then say "  ${YEL}quick start${R} ${GRY}· local only${R}"; fi
}

# A box around "label<TAB>value" lines. Everything inside is ASCII, so byte
# counts (what printf pads by) match the columns on screen.
box() { # box COLOR MARK TITLE "label<TAB>value"...
  K=$1 mark=$2 title=$3; shift 3
  w=$((${#title} + 2))
  for line in "$@"; do
    v=${line#*"	"}
    n=$((14 + ${#v})); [ "$n" -gt "$w" ] && w=$n
  done
  w=$((w + 4))
  bar=$(printf '%*s' "$w" '' | sed 's/ /─/g')
  say ""
  printf '  %s╭%s╮%s\n' "$K" "$bar" "$R"
  printf '  %s│%s  %s%s %-*s%s%s│%s\n' "$K" "$R" "$B$K" "$mark" "$((w - 4))" "$title" "$R" "$K" "$R"
  printf '  %s├%s┤%s\n' "$K" "$bar" "$R"
  for line in "$@"; do
    l=${line%%"	"*}; v=${line#*"	"}
    printf '  %s│%s  %s%-12s%s%s%-*s%s%s│%s\n' "$K" "$R" "$GRY" "$l" "$R" "$B" "$((w - 14))" "$v" "$R" "$K" "$R"
  done
  printf '  %s╰%s╯%s\n' "$K" "$bar" "$R"
}

spin_wait() { # spin_wait "message" timeout_seconds command...
  msg=$1 limit=$2; shift 2
  i=0 t=0
  while ! "$@" >/dev/null 2>&1; do
    if [ "$t" -ge "$limit" ]; then
      [ -t 1 ] && printf '\r\033[K'
      return 1
    fi
    if [ -t 1 ]; then
      case $i in 0) f=⠋ ;; 1) f=⠙ ;; 2) f=⠹ ;; 3) f=⠸ ;; 4) f=⠼ ;;
                 5) f=⠴ ;; 6) f=⠦ ;; 7) f=⠧ ;; 8) f=⠇ ;; *) f=⠏ ;; esac
      printf '\r    %s%s%s %s %s(%ss)%s' "$CYA" "$f" "$R" "$msg" "$GRY" "$t" "$R"
    fi
    i=$(((i + 1) % 10)); t=$((t + 1)); sleep 1
  done
  [ -t 1 ] && printf '\r\033[K'
  return 0
}

fetch() { # fetch URL FILE
  if command -v curl >/dev/null 2>&1; then curl -fsSL "$1" -o "$2"
  elif command -v wget >/dev/null 2>&1; then wget -qO "$2" "$1"
  else die "need curl or wget to download $1"; fi
}

http_up() { # any HTTP answer at all counts
  if command -v curl >/dev/null 2>&1; then
    code=$(curl -s -o /dev/null -m 3 -w '%{http_code}' "$1" || true)
    [ "${code:-000}" != 000 ]
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 3 -t 1 -O /dev/null "$1" 2>/dev/null; [ $? -ne 4 ]
  else
    return 0
  fi
}

secret_hex() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -hex 24
  else head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n'; fi
}
secret_b64() {
  if command -v openssl >/dev/null 2>&1; then openssl rand -base64 32
  else head -c 32 /dev/urandom | base64 | tr -d '\n'; fi
}

# --------------------------------------------------------------------- start --
umask 077 # .env holds secrets: create it (and the folder) private from the start
banner

step "Checking requirements"
command -v docker >/dev/null 2>&1 || die "Docker is not installed: https://docs.docker.com/engine/install/"
docker compose version >/dev/null 2>&1 || die "The Docker Compose plugin is missing (docker compose)."
docker info >/dev/null 2>&1 || die "Can't talk to Docker. Is it running, and is $(id -un) allowed to use it? (sudo, or the docker group)"
ok "Docker $(docker version --format '{{.Server.Version}}' 2>/dev/null || echo '?') · Compose $(docker compose version --short 2>/dev/null || echo '?')"

step "Preparing files"
here=''
case $0 in */*) [ -f "$0" ] && here=$(cd "$(dirname "$0")" && pwd) ;; esac
if [ -z "$dir" ] && [ -n "$here" ] && [ -f "$here/compose.yml" ]; then
  dir=$here
else
  dir=${dir:-$HOME/morche}
  mkdir -p "$dir"
  for f in compose.yml .env.example; do
    if [ -f "$dir/$f" ]; then info "$f already there: keeping it"
    else fetch "$REPO_RAW/$f" "$dir/$f" && ok "Downloaded $f"; fi
  done
fi
cd "$dir"
case $dir in "$HOME"/*) where="~${dir#"$HOME"}" ;; *) where=$dir ;; esac
ok "Working in $where"

panel_port=${PANEL_PORT:-3200}
backend_port=${BACKEND_PORT:-8080}

if [ -f .env ]; then
  info ".env already exists: keeping it as it is"
  [ "$quick" = 1 ] && warn "--quick-start settings are not applied over an existing .env"
else
  if [ "$quick" = 1 ]; then
    host=localhost bind=127.0.0.1
  else
    bind=0.0.0.0
    host=${MORCHE_HOST:-}
    if [ -z "$host" ]; then
      guess=$(hostname -I 2>/dev/null | awk '{print $1}')
      guess=${guess:-localhost}
      if [ -r /dev/tty ] && { : </dev/tty; } 2>/dev/null; then
        printf '\n    %s?%s Address people will use to reach this machine (IP or domain) %s[%s]%s: ' \
          "$CYA" "$R" "$GRY" "$guess" "$R"
        read -r host </dev/tty || host=''
      fi
      host=${host:-$guess}
    fi
  fi

  sed \
    -e "s|^MORCHE_VERSION=.*|MORCHE_VERSION=${MORCHE_VERSION:-latest}|" \
    -e "s|^PANEL_URL=.*|PANEL_URL=http://$host:$panel_port|" \
    -e "s|^API_URL=.*|API_URL=http://$host:$backend_port|" \
    -e "s|^PANEL_PORT=.*|PANEL_PORT=$panel_port|" \
    -e "s|^BACKEND_PORT=.*|BACKEND_PORT=$backend_port|" \
    -e "s|^PANEL_BIND=.*|PANEL_BIND=$bind|" \
    -e "s|^BACKEND_BIND=.*|BACKEND_BIND=$bind|" \
    -e "s|^POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$(secret_hex)|" \
    -e "s|^REDIS_PASSWORD=.*|REDIS_PASSWORD=$(secret_hex)|" \
    -e "s|^SECRETS_KEY=.*|SECRETS_KEY=$(secret_b64)|" \
    -e "s|^SETUP_TOKEN=.*|SETUP_TOKEN=$(secret_hex)|" \
    .env.example >.env.tmp
  mv .env.tmp .env
  ok "Wrote .env with fresh secrets"
fi

env_get() { sed -n "s/^$1=//p" .env | tail -n 1; }
panel=$(env_get PANEL_URL)
api=$(env_get API_URL)
token=$(env_get SETUP_TOKEN)
if [ -z "$token" ] && grep -q '^SETUP_TOKEN=' .env; then
  token=$(secret_hex)
  sed "s|^SETUP_TOKEN=.*|SETUP_TOKEN=$token|" .env >.env.tmp && mv .env.tmp .env
  ok "Added a setup token to .env, so nobody else can claim the panel first"
fi
version=$(env_get MORCHE_VERSION)
panel_port=$(env_get PANEL_PORT); panel_port=${panel_port:-3200}
backend_port=$(env_get BACKEND_PORT); backend_port=${backend_port:-8080}

step "Pulling images ${GRY}(${version:-latest})${R}"
docker compose pull
ok "Images are up to date"

step "Starting Morche"
docker compose up -d --remove-orphans
ok "Containers started"

step "Waiting for Morche to answer"
ready=1
if spin_wait "Backend starting (migrations run on first start)" 180 http_up "http://127.0.0.1:$backend_port/"; then
  ok "Backend is up"
else
  ready=0
  warn "Backend didn't answer within 3 minutes: docker compose logs -f backend"
fi
if spin_wait "Panel starting" 90 http_up "http://127.0.0.1:$panel_port/"; then
  ok "Panel is up"
else
  ready=0
  warn "Panel didn't answer yet: docker compose logs -f frontend"
fi

# -------------------------------------------------------------------- report --
TAB=$(printf '\t')
set -- "Panel${TAB}$panel" "API${TAB}$api"
[ -n "$token" ] && set -- "$@" "Setup token${TAB}$token"
set -- "$@" "Folder${TAB}$where"
if [ "$ready" = 1 ]; then box "$GRN" "✓" "Morche is ready" "$@"
else box "$YEL" "…" "Morche is still starting (see the warnings above)" "$@"; fi

say ""
say "  ${B}Next${R}"
say "    ${CYA}1${R}  Open ${B}$panel${R}"
say "    ${CYA}2${R}  Create the first admin account"
[ -n "$token" ] && say "    ${CYA}3${R}  Paste the setup token above when the form asks for it"
say ""
case $panel in
  http://localhost:*|http://127.0.0.1:*) ;;
  http://*)
    say "  ${YEL}!${R} The panel is served over ${B}plain http${R}: passwords and SSH keys cross the"
    say "    network unencrypted. Put HTTPS in front before real use (README › HTTPS)."
    say "" ;;
esac
say "  ${YEL}!${R} Keep a copy of ${B}SECRETS_KEY${R} from ${B}$where/.env${R}: every saved password"
say "    and key is sealed with it."
say ""
say "  ${B}Handy commands${R} ${GRY}(run in $where)${R}"
say "    ${GRY}logs     ${R} docker compose logs -f backend"
say "    ${GRY}update   ${R} docker compose pull && docker compose up -d"
say "    ${GRY}stop     ${R} docker compose down"
say "    ${GRY}reset    ${R} docker compose exec backend server reset-admin"
say ""
