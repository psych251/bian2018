#!/usr/bin/env bash
# Anonymize the private Qualtrics export, then render the report.
#   ./render.sh                      anonymize the Phase 1 export, then render
#   ./render.sh replication-phase2   anonymize whatever is in private/qualtrics_export.csv
#                                    as Phase 2, then render
# Both phases read private/qualtrics_export.csv, so drop in the right export first.
set -euo pipefail
cd "$(dirname "$0")"

if [ -f ../private/qualtrics_export.csv ]; then
  Rscript anonymize.R "${1:-replication}"
else
  echo "No private/qualtrics_export.csv found; rendering from the existing public data."
fi

quarto render replication-report.qmd
