#!/usr/bin/env bash
# First start: seed the demo and keep a snapshot of it. Then, at every reset
# time, put that snapshot back.
source "$(dirname "$0")/lib.sh"

STEP=$(( ${DEMO_RESET_MINUTES:-60} * 60 ))

log "lab: starting"
lab up -d --remove-orphans || log "lab didn't fully start; seeding anyway"

if [ "$(psql_q -d postgres -c "SELECT 1 FROM pg_database WHERE datname='morche_golden'")" != 1 ]; then
  log "no snapshot yet: seeding"
  wait_backend
  seed.sh
  log "letting the first checks run"
  sleep "${SEED_SETTLE_SECONDS:-120}"
  snapshot.sh
fi

while true; do
  wait=$(seconds_to_reset "$STEP")
  log "next reset in ${wait}s"
  sleep "$wait"
  reset.sh || log "reset failed; trying again at the next one"
done
