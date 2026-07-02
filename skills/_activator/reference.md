# Flowy Activator — reference (read on demand)

The lean execution path lives in `SKILL.md`. This file holds the detail the ACTIVATE
happy path does NOT need: enforcement mechanics, the out-of-repo STATE_DIR derivation,
the state-file contract, and the DEACTIVATE / STATUS / STACKING procedures. Read the
relevant section when `SKILL.md` points you here.

## How enforcement works
An auto-installed `UserPromptSubmit` hook (`hooks/flowy-inject.sh`) reads a per-session
state file each prompt and, if a Flow is active, injects the routing banner — that is
what makes routing survive turns + context compaction. You (a skill) do NOT see the
Claude Code `session_id`; only the hook does (on its stdin). So the activator writes
`state-PENDING.json` and the hook CLAIMS it by renaming → `state-<session_id>.json` on
the next prompt. Do not try to discover or invent a session id.

## Where state lives — OUT OF THE PROJECT REPO
State never lives in the project repo (a committed `$CLAUDE_PROJECT_DIR/.flowy/state-*.json`
could force attacker routing on cloners, so the hook ignores in-repo state). The hook, the
GC, and the activator all derive the dir from ONE script so they cannot disagree. For
DEACTIVATE / STATUS compute `<STATE_DIR>` once via the Bash tool — do NOT hand-compute the key:
```
sh -c '. "$1/hooks/flowy-paths.sh"; flowy_state_dir "${CLAUDE_PROJECT_DIR:-$2}" "$1"' _ "<plugin-root>" "<project-dir>"
```
- `<plugin-root>` = the wrapper's "Base directory" minus the trailing `skills/<flow-name>`.
- `<project-dir>` = the project root (KEEP the double-quotes; it may contain a space). The
  helper canonicalizes either path form to the same key. Empty output → unexpected layout;
  report and stop, never guess. NEVER write state under `$CLAUDE_PROJECT_DIR/.flowy/`.

## State-file contract — schema `flowy-state-v1`
`flowy-activate.sh` writes this for ACTIVATE; you only hand-edit it for DEACTIVATE / STACKING.
```json
{ "schema": "flowy-state-v1", "sessionId": "PENDING", "createdAtEpoch": 1749800000,
  "activeFlows": [ { "name": "<flow>", "flowRef": "flows/<flow>/FLOW.md", "location": "plugin" } ] }
```
- `flowRef` is plugin-root-relative (NEVER an absolute cache path). `location` = `plugin`
  (resolved `<plugin-root>/<flowRef>`) or `project` (resolved
  `$CLAUDE_PROJECT_DIR/.flowy/flows/<name>/FLOW.md`).
- The hook parses line-by-line with grep/sed: each `"name"`, `"flowRef"`, `"location"` on its
  OWN line; no escaped quotes inside values; the Nth name/flowRef/location pair positionally —
  emit `location` on EVERY entry.
- `createdAtEpoch` (unquoted int, `date +%s`) is REQUIRED on every PENDING — the hook deletes a
  PENDING that lacks it or is older than ~600s WITHOUT claiming. Claimed files don't need it.
- "active" = the file exists AND `activeFlows` has ≥1 entry; `"activeFlows": []` = deactivated.

## STACKING — a Flow is already active this session
`flowy-activate.sh` writes a fresh single-flow PENDING — correct when nothing is active yet. If
the ⚑ banner THIS turn already lists Flow(s) and you're ADDING one, the hook won't re-claim PENDING
while a claimed `state-<session_id>.json` exists, so merge model-side:
1. Get `<STATE_DIR>` (above). Read the claimed `state-<session_id>.json`.
2. If `<flow-name>` is already listed → print `Flow already active: <flow-name>.` and stop.
3. Else write the merged `activeFlows` (existing entries + your new one LAST) into BOTH the claimed
   `state-<session_id>.json` (enforces this turn) AND a fresh `state-PENDING.json` (new
   `createdAtEpoch`). Never drop a previously-active Flow.

## DEACTIVATE — `deactivate [<flow-name>]`
Edit state under `<STATE_DIR>` (above). You don't know the session_id → glob `<STATE_DIR>/state-*.json`
and handle BOTH `state-PENDING.json` AND any claimed `state-<id>.json` (cleaning only one leaves a
stale PENDING that silently re-activates). Do NOT touch `$CLAUDE_PROJECT_DIR/.flowy/`.
- `deactivate <flow-name>`: for each state file remove the `activeFlows` entry where `name == <flow-name>`.
  Others remain → write them back. Becomes empty → claimed file gets `"activeFlows": []`; `state-PENDING.json`
  is DELETED (or `[]` if undeletable). Process PENDING in the SAME pass. Print `Flow deactivated: <flow-name>`.
- `deactivate` (no arg): for EVERY `state-*.json` (incl. PENDING) delete it or set `"activeFlows": []`
  (prefer deleting PENDING, `[]` on claimed). Print `All Flows deactivated. Routing obligations cleared.`

## STATUS — `status`
Answers two things the user can't otherwise tell apart: what's active, and whether the hook is live.
1. Glob `<STATE_DIR>/state-*.json`. A claimed `state-<session_id>.json` is PROOF the hook ran (only the
   hook renames PENDING → claimed).
2. Report hook liveness — exactly one:
   - claimed file exists → `Enforcement is live ✓ — the hook claimed this session; the ⚑ banner fires each prompt.`
   - only `state-PENDING.json` → `⚠ Enforcement NOT confirmed — only PENDING exists; send one more prompt and re-check. If still unclaimed, restart Claude Code and re-activate.`
   - no state file → `No active Flows.` and stop.
3. For each active entry (deduped) print `Active Flow: <name>` + `  FLOW.md: <flowRef>`. If all empty →
   `No active Flows.` Name which state file(s) you read.
