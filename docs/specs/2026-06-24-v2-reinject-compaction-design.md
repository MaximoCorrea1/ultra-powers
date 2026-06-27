# V2 — long-session reinject + compaction recovery (design)

**Date:** 2026-06-24
**Repo:** `superpowers-flow-hardened` (this becomes the **V2** arm; `flowy-flows` stays **V1**)
**Status:** design (brainstorming output, pending founder review → writing-plans)

## Goal
Make the hardened superpowers-flow hold its routing over **long, multi-turn sessions** — where V1 only injects a per-prompt banner and otherwise decays. Two mechanisms:
1. **Periodic refresh** — every ~40 prompts, inject a lightweight FLOW.md routing table.
2. **Compaction recovery** — after a `/compact`, force a full FLOW.md re-read.

## Background
The banner pilot proved **reading the FLOW.md is the lever** (38%→100% adherence; adherence == flowMdRead in 32/32 runs) — but that was *single-prompt*. Long sessions add two failure modes this design targets: (a) routing detail fades from attention over many turns; (b) a compaction **deletes the FLOW.md content** from context, and V1's banner only passively *mentions* "re-read after compaction" without forcing it.

**Principled split:** periodic = *lightweight* (content's still in context, just refresh attention); compaction = *full re-read* (content's gone, reload the real file).

## Mechanism 1 — periodic compact-table reinject
- **Trigger:** a per-session prompt **counter**. When a flow is live, `flowy-inject.sh` increments a sidecar file `<state_dir>/count-<session_id>` each prompt; when `count % N == 0` (and `count > 0`), it appends the compact table to its stdout (after the banner — additive, same injection channel).
- **N** = `FLOWY_REINJECT_EVERY_N` env (default **40**).
- **Payload:** a bundled `flows/superpowers-flow/FLOW-compact.md` — a ~190-token routing table, one line per skill (`<skill>: <when-to-use>`), derived from the FLOW.md decision tree. Resolved next to the live FLOW.md (`<dir-of-FLOW.md>/FLOW-compact.md`); absent → skip (fail-loud no-op).
- **Counter sidecar (not the state file):** keeps the grep/sed-parsed `state-*.json` untouched. The SessionStart GC must also sweep `count-*` files for dead sessions.
- **Honest flag:** the compact table was **null in the v4 single-prompt test** — but that test had no long-session decay to fix. This mechanism is the *untested hypothesis* the V1-vs-V2 experiment exists to measure.

## Mechanism 2 — compaction recovery
- **New hook `hooks/flowy-recompact.sh`**, registered in `hooks.json` under `SessionStart` (alongside the existing `flowy-gc.sh`).
- Reads stdin `source`; if `source != "compact"` → `exit 0` (no-op for startup/resume). If `compact`: resolve the active flow's FLOW.md (reuse `flowy-paths.sh` for the state dir + the same state-read + resolution as `flowy-inject.sh`) and emit:
  > `⚑ Flowy: context was just compacted. RE-READ the FLOW.md at <resolved-path> IN FULL now, before your next routing decision.`
- `SessionStart(source:compact)` is the verified post-compaction injector (`PostCompact` cannot inject).
- After firing, reset the periodic counter to 0 (post-compaction starts a fresh 40-cycle) — optional, keeps the two mechanisms from stacking right after a compaction.

## Files
- `hooks/flowy-inject.sh` — add counter increment + conditional compact-table append (inside the `LIVE_NAMES` branch only, so no-flow repos never count).
- `hooks/flowy-recompact.sh` — **NEW** (the compaction re-read injector).
- `hooks/hooks.json` — add `SessionStart` → `flowy-recompact.sh`.
- `flows/superpowers-flow/FLOW-compact.md` — **NEW** (the lightweight 14-skill table).
- `hooks/flowy-gc.sh` — also sweep `count-*` sidecars.
- `tests/` — counter-fires-every-Nth test (reuse the v4 `inject-table` pattern); recompact-hook test (compact→emits re-read+path; startup/resume→no-op).

## Shared resolution
Both `flowy-inject.sh` and `flowy-recompact.sh` need "state → resolved FLOW.md path." Factor that into a sourced helper (e.g. `hooks/flowy-resolve.sh`) to avoid drift, OR duplicate the minimal read. Prefer the helper.

## Invariants preserved
Fail-loud (always `exit 0`, never block) in both hooks. Out-of-repo state. Symlink/charset guards unchanged. The banner itself is unchanged from the hardened V2 banner (READ + YES/NO).

## Metric / experiment (separate spec)
V2 (this) vs V1 (`flowy-flows`): scripted ~16-prompt labeled sequence, manual `/compact` at a fixed index, deterministic **pre vs post-compaction** adherence scoring. Hypothesis: **V1 decays post-compaction, V2 holds.** That harness is its own spec; this spec is the V2 *build*.

## Risks / open
- Compact table may be null even long-session → that's what the experiment measures (not assumed).
- `count-*` sidecar accumulation → GC sweep covers it.
- N=40 is a guess → `FLOWY_REINJECT_EVERY_N` makes it tunable.

## Out of scope
The experiment harness; the plugin rename/version-bump to de-collide with `flowy` (separate small task).
