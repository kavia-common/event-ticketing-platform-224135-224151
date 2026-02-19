#!/bin/bash
set -euo pipefail

# Tickety migration runner (PostgreSQL)
# - Uses db_connection.txt as the authoritative connection string.
# - Applies all .sql files under migrations/ in lexical order.
# - Records applied migrations in schema_migrations.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${BASE_DIR}/db_connection.txt"
MIGRATIONS_DIR="${BASE_DIR}/migrations"

if [ ! -f "${CONN_FILE}" ]; then
  echo "db_connection.txt not found at ${CONN_FILE}"
  exit 1
fi

PSQL_CMD="$(cat "${CONN_FILE}")"

echo "Ensuring schema_migrations exists..."
${PSQL_CMD} -v ON_ERROR_STOP=1 -c "CREATE TABLE IF NOT EXISTS schema_migrations (version TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now());"

if [ ! -d "${MIGRATIONS_DIR}" ]; then
  echo "No migrations directory found at ${MIGRATIONS_DIR}; nothing to do."
  exit 0
fi

echo "Applying migrations from ${MIGRATIONS_DIR}..."
for f in $(ls -1 "${MIGRATIONS_DIR}"/*.sql 2>/dev/null | sort); do
  version="$(basename "${f}")"
  applied="$(${PSQL_CMD} -tA -c "SELECT 1 FROM schema_migrations WHERE version='${version}' LIMIT 1;")"
  if [ "${applied}" = "1" ]; then
    echo "✓ Skipping already applied: ${version}"
    continue
  fi

  echo "→ Applying: ${version}"
  # Run the SQL file as a whole (migration files manage their own BEGIN/COMMIT).
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -f "${f}"
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -c "INSERT INTO schema_migrations(version) VALUES ('${version}');"
  echo "✓ Applied: ${version}"
done

echo "Migrations complete."
