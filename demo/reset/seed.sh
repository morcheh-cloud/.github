#!/usr/bin/env bash
# Fills a fresh demo through the API, as its admin: the shared demo account,
# the lab servers, databases, a storage, monitors, alert rules, services,
# scripts and notes. Runs once; resets go back to what this made.
source "$(dirname "$0")/lib.sh"
: "${SETUP_TOKEN:?}" "${ADMIN_PASSWORD:?}" "${LAB_PASSWORD:?}"
rm -f "$JAR"

j() { jq -nc "$@"; }
id() { jq -r .id; }

log "seed: admin"
api POST /auth/setup "$(j --arg p "$ADMIN_PASSWORD" --arg t "$SETUP_TOKEN" \
  '{username:"admin", password:$p, setup_token:$t, email:"admin@demo.invalid",
    first_name:"Demo", full_name:"Demo Admin"}')" >/dev/null

WS=$(api GET /workspaces | jq -r ".items[0].id")
export WS
api PATCH "/workspaces/$WS" "$(j '{name:"Acme Co", color:"indigo", logo_kind:"letter"}')" >/dev/null

log "seed: demo account"
# Nobody signs in with this password: visitors enter with the demo button.
demo_pw=$(head -c 24 /dev/urandom | base64)
api POST /admin/users "$(j --arg p "$demo_pw" --arg ws "$WS" --arg u "${DEMO_USER:-demo}" \
  '{username:$u, password:$p, role:"member", email:"demo@demo.invalid",
    first_name:"Demo", full_name:"Demo visitor",
    grants:[{workspace_id:$ws, level:"engineer", can_create:true}]}')" >/dev/null

log "seed: servers"
prod=$(api POST /folders "$(j '{name:"Production"}')" | id)
stage=$(api POST /folders "$(j '{name:"Staging"}')" | id)
server() { # name host folder tags...
  local name=$1 host=$2 folder=$3; shift 3
  api POST /servers "$(j --arg n "$name" --arg h "$host" --arg f "$folder" \
    --arg pw "$LAB_PASSWORD" --args \
    '{name:$n, host:$h, port:22, username:"ant", auth_method:"password",
      password:$pw, folder_id:$f, tags:$ARGS.positional}' "$@")" | id
}
web1=$(server web-1 lab-web-1 "$prod" web shop)
web2=$(server web-2 lab-web-2 "$stage" web shop)
dock=$(server docker-1 lab-docker-1 "$prod" docker)
for s in "$web1" "$web2" "$dock"; do api POST "/servers/$s/check" >/dev/null || true; done
api PUT "/servers/$web1/favorite" "$(j "{favorite:true}")" >/dev/null

api POST "/servers/$web1/notes" "$(j '{title:"Runbook", pinned:true,
  body:"## When the shop is slow\n\n1. Check **Metrics** for CPU.\n2. Restart `shop-api` in **Services**.\n3. Read its logs before closing the incident."}')" >/dev/null

log "seed: databases"
database() { # name engine host port user password dbname
  api POST /databases "$(j --arg n "$1" --arg e "$2" --arg h "$3" --argjson p "$4" \
    --arg u "$5" --arg pw "$6" --arg d "$7" \
    '{name:$n, engine:$e, mode:"direct", host:$h, port:$p, username:$u,
      password:$pw, dbname:$d, tls:"disable", allow_internal:true}')" >/dev/null
}
database "Shop orders" postgres lab-postgres 5432 shop "$LAB_PASSWORD" shop
database "Blog" mysql lab-mariadb 3306 root "$LAB_PASSWORD" blog
database "Sessions cache" redis lab-redis 6379 "" "$LAB_PASSWORD" ""

log "seed: storage"
st=$(api POST /storages "$(j --arg pw "$LAB_PASSWORD" \
  '{name:"Backups (RustFS)", protocol:"s3", host:"lab-s3",
    port:9000, tls:"none", path_style:true, region:"us-east-1",
    username:"morche", secret:$pw}')" | id)
# The S3 server may still be starting: try for a minute.
for b in backups media; do
  for _ in $(seq 1 12); do
    api POST "/storages/$st/buckets" "$(j --arg b "$b" '{name:$b}')" >/dev/null 2>&1 && break
    sleep 5
  done
done

log "seed: monitors"
monitor() { # name kind config
  api POST /monitors "$(j --arg n "$1" --arg k "$2" --argjson c "$3" \
    '{name:$n, kind:$k, config:$c, secrets:{}, retries:1, interval_seconds:60,
      allow_internal:true}')" >/dev/null
}
monitor "Shop website" http '{"url":"http://lab-web-1/","method":"GET","keyword":"Acme Shop"}'
monitor "Shop API" http '{"url":"http://lab-web-1/api/health","method":"GET"}'
monitor "Staging website" http '{"url":"http://lab-web-2/","method":"GET"}'
monitor "Orders database port" tcp '{"host":"lab-postgres","port":5432}'

log "seed: alert rules"
rule() { api POST /alert-rules "$1" >/dev/null; }
rule "$(j '{name:"CPU busy", metric:"cpu", op:"above", threshold:85, for_minutes:5, scope:"all", severity:"warning", enabled:true}')"
rule "$(j '{name:"Disk almost full", metric:"disk", op:"above", threshold:90, for_minutes:10, scope:"all", severity:"critical", enabled:true}')"
rule "$(j '{name:"Server offline", metric:"offline", op:"above", threshold:0, for_minutes:2, scope:"all", severity:"critical", enabled:true}')"
rule "$(j '{name:"Shop API stopped", metric:"service", unit:"shop-api.service", op:"above", threshold:0, for_minutes:1, scope:"tags", tags:["shop"], severity:"critical", enabled:true}')"

log "seed: services"
app() { # name address icon color note
  api POST /apps "$(j --arg n "$1" --arg a "$2" --arg i "$3" --arg c "$4" --arg note "$5" \
    '{name:$n, address:$a, logo_kind:"icon", logo_icon:$i, color:$c, note:$note}')" >/dev/null
}
app "Grafana" "https://grafana.acme.example" "chart-line" "orange" "Dashboards for the shop"
app "GitLab" "https://git.acme.example" "git-branch" "red" "Code and CI"
app "Shop admin" "https://shop.acme.example/admin" "store" "indigo" "Orders and refunds"
app "Status page" "https://status.acme.example" "activity" "green" ""

log "seed: scripts"
script() { # name content
  api POST "/workspaces/$WS/scripts" "$(j --arg n "$1" --arg c "$2" \
    '{name:$n, interpreter:"bash", content:$c, run_as:"user", timeout_seconds:120, params:[]}')" >/dev/null
}
script "Disk report" $'#!/usr/bin/env bash\ndf -h /\ndu -sh /var/log 2>/dev/null'
script "Who is logged in" $'#!/usr/bin/env bash\nuptime\nwho'

log "seed: done"
