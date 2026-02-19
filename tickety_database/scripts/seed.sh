#!/bin/bash
set -euo pipefail

# Tickety seed runner (PostgreSQL)
# - Uses db_connection.txt as the authoritative connection string.
# - Runs all .sql files under seeds/ in lexical order.

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONN_FILE="${BASE_DIR}/db_connection.txt"
SEEDS_DIR="${BASE_DIR}/seeds"

if [ ! -f "${CONN_FILE}" ]; then
  echo "db_connection.txt not found at ${CONN_FILE}"
  exit 1
fi

PSQL_CMD="$(cat "${CONN_FILE}")"

if [ ! -d "${SEEDS_DIR}" ]; then
  echo "No seeds directory found at ${SEEDS_DIR}; nothing to do."
  exit 0
fi

echo "Applying seeds from ${SEEDS_DIR}..."
for f in $(ls -1 "${SEEDS_DIR}"/*.sql 2>/dev/null | sort); do
  echo "→ Seeding: $(basename "${f}")"
  ${PSQL_CMD} -v ON_ERROR_STOP=1 -f "${f}"
  echo "✓ Seeded: $(basename "${f}")"
done

echo "Seeding complete."
