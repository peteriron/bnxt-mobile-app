#!/bin/bash
# Local CI: lint + unit + UI tests on this Mac, reported to GitHub as the `local-tests` commit status
# that `main` requires before merging (REQUIREMENTS.md §7.22, ios/SETUP.md "Local CI").
#
# Usage:  ios/scripts/ci-local.sh            test HEAD (must be committed and pushed) and post the status
#         ios/scripts/ci-local.sh --no-post  run the same checks on the working tree without posting
# Env:    SIM="iPhone 18 Pro" (simulator name; newest runtime that has it)
#
# The status always describes the exact commit that was tested: the script refuses to post for a dirty tree
# or for a commit GitHub doesn't have yet.
set -uo pipefail

CONTEXT="local-tests"
SIM="${SIM:-iPhone 18 Pro}"
POST=1
[[ "${1:-}" == "--no-post" ]] && POST=0

REPO_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_DIR"
SHA="$(git rev-parse HEAD)"
SHORT="${SHA:0:7}"
OUT="$REPO_DIR/.tmp/ci-local/$SHORT"
LOG="$OUT/run.log"

say() { printf '\033[1m▸ %s\033[0m\n' "$*"; }
die() { printf '\033[31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

if [[ $POST == 1 ]]; then
  command -v gh >/dev/null || die "gh (GitHub CLI) is required to post the status"
  [[ -z "$(git status --porcelain)" ]] || die "Working tree has uncommitted changes; commit them, or use --no-post"
  NWO="$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || die "Can't resolve the GitHub repo (gh auth status?)"
  gh api "repos/$NWO/commits/$SHA" --silent 2>/dev/null || die "Commit $SHORT isn't on GitHub yet; push first"
fi

post() { # state description
  [[ $POST == 1 ]] || return 0
  gh api "repos/$NWO/statuses/$SHA" -f state="$1" -f context="$CONTEXT" -f description="$2" --silent \
    || echo "warning: couldn't post the '$1' status" >&2
}

rm -rf "$OUT" && mkdir -p "$OUT"
START=$(date +%s)
post pending "Running on $(scutil --get ComputerName 2>/dev/null || hostname)…"
trap 'post error "Interrupted"; exit 130' INT TERM

fail() { # step
  local secs=$(( $(date +%s) - START ))
  post failure "$1 failed after ${secs}s"
  die "$1 failed. Log: $LOG"
}

say "Lint"
swiftlint --strict --quiet 2>&1 | tee -a "$LOG" || fail "Lint"

say "Generate project"
(cd ios && xcodegen generate) >>"$LOG" 2>&1 || fail "xcodegen"

[[ -f ios/Config/Secrets.xcconfig ]] || echo "note: no ios/Config/Secrets.xcconfig; building without an API key" | tee -a "$LOG"

say "Boot simulator ($SIM)"
UDID="$(xcrun simctl list devices available -j | python3 -I -c "
import json, re, sys
name = sys.argv[1]
best = None
for runtime, devices in json.load(sys.stdin)['devices'].items():
    m = re.search(r'iOS-(\d+)-(\d+)', runtime)
    for d in devices:
        if m and d['name'] == name:
            v = (int(m.group(1)), int(m.group(2)))
            if best is None or v > best[0]:
                best = (v, d['udid'])
print(best[1] if best else '')" "$SIM")"
[[ -n "$UDID" ]] || fail "No simulator named '$SIM'"
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true   # already booted is fine
xcrun simctl bootstatus "$UDID" -b >>"$LOG" 2>&1 || fail "Simulator boot"

say "Unit + UI tests"
(cd ios && xcodebuild -project BNXT.xcodeproj -scheme BNXT \
  -destination "id=$UDID" \
  -skip-testing:BNXTUITests/AppStoreScreenshotUITests \
  -collect-test-diagnostics never \
  -resultBundlePath "$OUT/TestResults.xcresult" \
  CODE_SIGNING_ALLOWED=NO test) >>"$LOG" 2>&1
STATUS=$?
PASSED=$(grep -cE "^Test Case .* passed" "$LOG")
FAILED=$(grep -cE "^Test Case .* failed" "$LOG")
echo "  $PASSED test cases passed, $FAILED failed"
grep -E "error:|^Test Case .* failed" "$LOG" | sort -u | head -12
[[ $STATUS == 0 ]] || fail "Tests"

SECS=$(( $(date +%s) - START ))
post success "Lint + $PASSED tests passed in ${SECS}s"
printf '\033[32m✓ %s passed in %ss%s\033[0m\n' "$([[ $POST == 1 ]] && echo "$SHORT" || echo "working tree")" "$SECS" "$([[ $POST == 1 ]] && echo ", '$CONTEXT' posted" || echo " (not posted)")"
rm -rf "$OUT/TestResults.xcresult"   # keep the log, drop the bulky bundle on success
