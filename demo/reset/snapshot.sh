#!/usr/bin/env bash
# Keeps the seeded database as morche_golden, what every reset goes back to.
source "$(dirname "$0")/lib.sh"
dc stop backend
psql_q -d postgres -c "DROP DATABASE IF EXISTS morche_golden"
psql_q -d postgres -c "CREATE DATABASE morche_golden TEMPLATE morche"
dc start backend
log "snapshot kept"
