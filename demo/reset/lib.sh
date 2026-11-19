#!/usr/bin/env bash
# Shared bits for the demo's seed and reset scripts.
set -euo pipefail

: "${PGPASSWORD:?}" "${LAB_PASSWORD:?}"
export PGHOST=postgres PGUSER=morche
BACKEND=${BACKEND_CONTAINER:-morche-demo-backend}

# Sysbox gives the lab systemd and Docker with visitors kept off the host's
# root. Without it the lab runs under plain runc: its own small supervisor,
# no systemd units, no Docker.
LAB_RUNTIME=${LAB_RUNTIME:-sysbox-runc}
if ! docker info --format '{{json .Runtimes}}' | grep -q "\"$LAB_RUNTIME\""; then
  printf '%s %s\n' "$(date -u +%H:%M:%S)" "runtime $LAB_RUNTIME isn't installed: the lab runs under runc, without systemd or Docker"
  LAB_RUNTIME=runc
fi
export LAB_RUNTIME
API=${API:-http://backend:8080}
JAR=/tmp/admin.cookies

# History the charts draw from. It survives resets (the servers keep their ids
# from the snapshot), so the demo's graphs fill up over the days it runs.
# Numbers only: event, incident and status-change tables hold text visitors
# can shape (names, messages), so those go back to the snapshot.
HISTORY_TABLES=(server_samples server_check_buckets storage_checks
  monitor_checks monitor_days database_samples docker_project_stats)

log() { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*"; }

# The lab's own compose project, baked into this image.
lab() { docker compose -f /etc/morche-demo/lab.yml "$@"; }

backend_stop() { docker stop -t 20 "$BACKEND" >/dev/null; }
backend_start() { docker start "$BACKEND" >/dev/null; }

psql_q() { psql -v ON_ERROR_STOP=1 -qAt "$@"; }

wait_backend() {
  for _ in $(seq 1 120); do
    curl -fs "$API/health" >/dev/null 2>&1 && return 0
    sleep 2
  done
  log "backend didn't come up"; return 1
}

# api METHOD PATH [JSON] — as the admin, failing loudly.
api() {
  local method=$1 path=$2 body=${3:-}
  local args=(-sS -b "$JAR" -c "$JAR" -X "$method" -H 'Content-Type: application/json'
    -w '\n%{http_code}')
  [ -n "${WS:-}" ] && args+=(-H "X-Workspace-Id: $WS")
  [ -n "$body" ] && args+=(--data "$body")
  local out code
  out=$(curl "${args[@]}" "$API$path")
  code=${out##*$'\n'}
  out=${out%$'\n'*}
  if [ "$code" -ge 300 ]; then
    log "$method $path -> $code: $out" >&2
    return 1
  fi
  printf '%s' "$out"
}

# Seconds until the next reset: the next multiple of the interval since
# midnight UTC, the same sum the backend shows the countdown from.
seconds_to_reset() {
  local now day step
  now=$(date -u +%s)
  day=$(( now - now % 86400 ))
  step=$1
  local next=$(( day + ((now - day) / step + 1) * step ))
  (( next > day + 86400 )) && next=$(( day + 86400 ))
  echo $(( next - now ))
}
