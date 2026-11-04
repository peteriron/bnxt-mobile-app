#!/bin/bash
# Read-only wrapper around the upstream BNXT API (bnxt.sportpress.info/api/v1).
# Usage: BNXT_API_KEY=... tools/api.sh "standings/competition/25/phase/183"
# The key is the public client key from bnxtleague.com's web bundle. It's for research only.
# Never commit it, never ship it in the app (REQUIREMENTS.md §7.17, docs/bnxt-api.md). Put it in .env (git-ignored).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ -z "${BNXT_API_KEY:-}" && -f "$ROOT/.env" ]]; then set -a; source "$ROOT/.env"; set +a; fi
: "${BNXT_API_KEY:?Set BNXT_API_KEY (see .env.example)}"
curl -s -A "Mozilla/5.0" -H "Accept: application/json" -H "X-Authorization: $BNXT_API_KEY" \
  "https://bnxt.sportpress.info/api/v1/$1"
