# root-avx10-probe

Finds out how often GitHub Actions runners reproduce this, with nothing injected:

```
warning: invalid feature combination:  +avx10.1-256; will be promoted to avx10.1-512 [-Winvalid-feature-combination]
```

Context: [root-project/root#23542](https://github.com/root-project/root/issues/23542),
upstream fix [llvm/llvm-project#172350](https://github.com/llvm/llvm-project/pull/172350),
same symptom from another JIT in [NVIDIA/warp#1426](https://github.com/NVIDIA/warp/issues/1426).

## What it does

The warning comes from LLVM's `getHostCPUFeatures()`, so it depends entirely on
which machine the job lands on. GitHub's pool is mixed, so the workflow takes
many samples and records what each one got.

Every sample runs the **same check twice on the same machine**:

| | ROOT from | runs |
|---|---|---|
| `conda-forge` | `pixi exec --spec root_base` | directly on the Ubuntu runner |
| `lcg` | an LCG view over CVMFS | in an `almalinux:9` container, `/cvmfs` bind mounted |

That pairing is the point. A hit on both is an LLVM problem; a hit on only one
points at how that ROOT was built.

`probe.sh` injects nothing — no `EXTRA_CLING_ARGS`, no `-march`, no `-m` flags —
and prints `EXTRA_CLING_ARGS` so the logs show it was unset. This matters because
the reproducer originally filed on the ROOT issue *did* force the feature
combination, which made it look like the reporter was setting it themselves.

## Running it

Actions → **probe** → Run workflow. Inputs:

- `samples` — how many runners to sample (default 20)
- `lcg_view` — which view to source (default `LCG_110a/x86_64-el9-gcc15-opt`)

It also runs weekly, since the runner pool changes.

Results land in the run summary as a table:

| # | archspec | CPU | avx10 flags | conda-forge | LCG |
|---|---|---|---|---|---|

with a count of how many runners reproduced it on each side.

## Reading the results

- **`avx10` flags present and both sides hit** — confirms the CPU genuinely
  reports AVX10 and that LLVM's own consistency check then objects to it.
- **`archspec` says `sapphirerapids` but no `avx10` flags** — then the label is
  approximate and the trigger is something else. Worth knowing: Sapphire Rapids
  has no AVX10 at all, so the label on the affected CI runners is probably the
  nearest microarchitecture archspec recognises rather than the real part.
- **One side hits and the other doesn't** — the interesting outcome, and the
  reason both are run.

## Reproducing on any machine

If you just want to see the warning on hardware that isn't affected, force the
combination that LLVM's host detection produces on affected hardware:

```bash
EXTRA_CLING_ARGS="-march=sapphirerapids -mavx10.1-256" \
  root -l -b -q -e 'return 0;' 2>&1 >/dev/null
```

This is a demonstration of the diagnostic, **not** the bug: on real affected
hardware nothing needs to be set.
