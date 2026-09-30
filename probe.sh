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

# Every outcome gets its own marker. Reporting only hit-vs-clean hides the case
# that matters most: a probe whose environment is broken produces no warning for
# reasons that have nothing to do with the CPU, and must not be counted as
# evidence that the CPU is unaffected.
if grep -q "invalid feature combination" "$err"; then
    echo "RESULT ${label} hit"
elif [[ $rc -ne 0 ]]; then
    echo "RESULT ${label} error"
elif [[ -s "$err" ]]; then
    echo "RESULT ${label} other-stderr"
else
    echo "RESULT ${label} clean"
fi
