#!/bin/bash
# Reports whether Cling emits the AVX10 feature warning on this machine.
#
# Expects `root` to already be on PATH, so the same script can be pointed at an
# LCG view and at a conda-forge environment on the same runner.
#
# Deliberately injects nothing: no EXTRA_CLING_ARGS, no -march, no -m flags.
# Any warning it reports therefore comes from Cling's own host CPU detection.
set -uo pipefail

label="${1:?usage: probe.sh <label>}"
err=$(mktemp)

echo "=== ${label} ==="
echo "root:              $(command -v root || echo '<not found>')"
echo "ROOT version:      $(root-config --version 2>/dev/null || echo '?')"
echo "EXTRA_CLING_ARGS:  ${EXTRA_CLING_ARGS-<unset>}"

root -l -b -q -e 'return 0;' 2>"$err" >/dev/null
rc=$?

echo "exit code:         ${rc}"
echo "stderr bytes:      $(wc -c <"$err")"
echo "--- begin stderr ---"
cat "$err"
echo "--- end stderr ---"

# The marker is always printed, so a caller can tell "ran and was clean" from
# "never got this far" - grepping only for a hit would report a failed probe as
# clean.
if grep -q "invalid feature combination" "$err"; then
    echo "RESULT ${label} hit"
elif [[ $rc -ne 0 ]]; then
    echo "RESULT ${label} error"
else
    echo "RESULT ${label} clean"
fi
