#!/usr/bin/env bash
# Puts the demo back: the database from the snapshot (keeping the charts'
# history), the cache emptied, every lab server rebuilt from its image.
source "$(dirname "$0")/lib.sh"

log "reset: saving history"
dump_args=()
for t in "${HISTORY_TABLES[@]}"; do dump_args+=(-t "public.$t"); done
pg_dump -d morche --data-only --no-owner "${dump_args[@]}" > /tmp/history.sql

backend_stop
psql_q -d postgres -c "DROP DATABASE morche WITH (FORCE)"
psql_q -d postgres -c "CREATE DATABASE morche TEMPLATE morche_golden"

log "reset: putting history back"
tables=$(IFS=,; echo "${HISTORY_TABLES[*]}")
{
  echo "SET session_replication_role = replica;"
  echo "TRUNCATE ${tables};"
  cat /tmp/history.sql
  echo "SET session_replication_role = DEFAULT;"
  cat <<SQL
-- Rows about things a visitor made (and the reset removed) go too.
DO \$\$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT c.conrelid::regclass AS child, a.attname AS col,
           c.confrelid::regclass AS parent, pa.attname AS pcol
    FROM pg_constraint c
    JOIN pg_attribute a ON a.attrelid = c.conrelid AND a.attnum = c.conkey[1]
    JOIN pg_attribute pa ON pa.attrelid = c.confrelid AND pa.attnum = c.confkey[1]
    WHERE c.contype = 'f' AND array_length(c.conkey, 1) = 1
      AND c.conrelid::regclass::text = ANY (string_to_array('${tables}', ','))
  LOOP
    EXECUTE format(
      'DELETE FROM %s t WHERE t.%I IS NOT NULL AND NOT EXISTS (SELECT 1 FROM %s p WHERE p.%I = t.%I)',
      r.child, r.col, r.parent, r.pcol, r.col);
  END LOOP;
  -- Ids handed out after the snapshot mustn't be handed out again.
  FOR r IN
    SELECT s.relname AS seq, t.relname AS tbl, a.attname AS col
    FROM pg_class s
    JOIN pg_depend d ON d.objid = s.oid AND d.deptype IN ('a', 'i')
    JOIN pg_class t ON t.oid = d.refobjid
    JOIN pg_attribute a ON a.attrelid = t.oid AND a.attnum = d.refobjsubid
    WHERE s.relkind = 'S'
      AND t.relname = ANY (string_to_array('${tables}', ','))
  LOOP
    EXECUTE format('SELECT setval(%L, GREATEST((SELECT max(%I) FROM %I), 1))',
      r.seq, r.col, r.tbl);
  END LOOP;
END
\$\$;
SQL
} | psql_q -d morche
rm -f /tmp/history.sql

redis-cli -h redis -a "$REDIS_PASSWORD" --no-auth-warning FLUSHALL >/dev/null

log "reset: rebuilding lab servers"
lab up -d --force-recreate --remove-orphans || log "lab didn't fully start"
backend_start
log "reset done"
