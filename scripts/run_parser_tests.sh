#!/usr/bin/env bash
#
#  scripts/run_parser_tests.sh -- Parser regression test
#
#  Runs the stC compiler on every *.stc file under stc-code/ and reports
#  pass/fail for each one.  Exits with status 0 if all files parse cleanly,
#  or 1 if any file produces an error.
#
#  Usage (from the repo root):
#    scripts/run_parser_tests.sh
#
#  Run 'alr build' first to ensure bin/stcc is up to date.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STCC="$REPO_ROOT/bin/stcc"
STC_CODE_DIR="$REPO_ROOT/stc-code"

# Verify the compiler binary exists
if [[ ! -x "$STCC" ]]; then
    echo "ERROR: stcc compiler not found at $STCC"
    echo "       Run 'alr build' first."
    exit 1
fi

PASS=0
FAIL=0
FAILURES=()

while IFS= read -r -d '' file; do
    output="$("$STCC" "$file" 2>&1)"
    if echo "$output" | grep -qi "error"; then
        FAIL=$((FAIL + 1))
        FAILURES+=("$file")
        echo "FAIL  $file"
        echo "$output" | grep -i "error" | sed 's/^/      /'
    else
        PASS=$((PASS + 1))
        echo "ok    $file"
    fi
done < <(find "$STC_CODE_DIR" -name "*.stc" -print0 | sort -z)

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [[ $FAIL -gt 0 ]]; then
    echo ""
    echo "Failing files:"
    for f in "${FAILURES[@]}"; do
        echo "  $f"
    done
    exit 1
fi
