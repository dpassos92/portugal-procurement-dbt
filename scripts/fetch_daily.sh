#!/usr/bin/env bash
set -euo pipefail

CUTOFF="2026-12-31"
TODAY=$(date +%F)
if [[ "$TODAY" > "$CUTOFF" ]]; then
  echo "Past cutoff date ($CUTOFF) — skipping fetch."
  exit 0
fi

DEST_DIR="$HOME/Projects/portugal-procurement-dbt/data/raw/$(date +%F)"
mkdir -p "$DEST_DIR"
curl -L -o "$DEST_DIR/contratos2024.zip" "https://dados.gov.pt/s/resources/contratos-publicos-portal-base-impic-contratos-de-2012-a-2026/20260816-091146-634a2431/contratos2024.zip"