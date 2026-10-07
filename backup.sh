#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p backups
pg_dump -Fc -f "backups/capstone_$(date +%F).dump" "${PGDATABASE:-capstone}"
ls -lh backups/capstone_*.dump | tail -1
