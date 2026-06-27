# V2 reinject + compaction recovery — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Add long-session resilience to the hardened superpowers-flow: a periodic lightweight FLOW.md reinject (every N=40 prompts) and a forced full FLOW.md re-read after compaction.

**Architecture:** Extend `flowy-inject.sh` with a per-session prompt counter (sidecar file in the state dir) that appends a bundled `FLOW-compact.md` every Nth prompt. Add a new `flowy-recompact.sh` SessionStart hook that, on `source:compact`, resolves the active FLOW.md and injects a full-re-read instruction. Both fail-loud (always exit 0). Repo: `superpowers-flow-hardened` (becomes V2).

**Tech Stack:** POSIX sh (Git Bash on Windows), `bun test` (TypeScript test harness). No jq/node in the hooks — grep/sed only.

---

## File Structure
```
flows/superpowers-flow/FLOW-compact.md   # NEW — ~190-tok lightweight routing table
hooks/flowy-inject.sh                    # MODIFY — counter + conditional compact-table append (LIVE_NAMES branch)
hooks/flowy-recompact.sh                 # NEW — SessionStart(source:compact) full-re-read injector
hooks/hooks.json                         # MODIFY — register flowy-recompact.sh under SessionStart
hooks/flowy-gc.sh                        # MODIFY — sweep dead count-<sid> sidecars
tests/flowy-inject.test.ts               # MODIFY — periodic-reinject tests
tests/flowy-recompact.test.ts            # NEW — compaction-hook tests
```

---

### Task 1: The lightweight routing table

**Files:** Create `flows/superpowers-flow/FLOW-compact.md`

- [ ] **Step 1: Write the file** (one line per skill, derived from the FLOW.md decision tree)

```markdown
# superpowers-flow — compact routing (refresh)
Route to the matching skill BEFORE acting. Re-read the full FLOW.md if unsure.
- using-superpowers: session start / first message (bootstrap once)
- brainstorming: new idea / feature / project (design before code)
- writing-plans: design exists, no plan yet
- subagent-driven-development: plan with 3+ independent tasks
- executing-plans: plan with unchecked tasks (not 3+ independent)
- test-driven-development: about to write implementation code (failing test first)
- systematic-debugging: something broken / erroring (root cause first)
- verification-before-completion: about to claim done / fixed / passing
- requesting-code-review: code complete, needs review
- receiving-code-review: review feedback received
- finishing-a-development-branch: all tasks done, branch ready
- using-git-worktrees: need parallel isolated branches
- dispatching-parallel-agents: ad-hoc parallel research / fan-out
- writing-skills: authoring a custom skill
```

- [ ] **Step 2: Commit**

```bash
git add flows/superpowers-flow/FLOW-compact.md
git commit -m "feat(v2): bundle FLOW-compact.md lightweight routing table"
```

---

### Task 2: Periodic compact-table reinject in `flowy-inject.sh`

**Files:** Modify `hooks/flowy-inject.sh` (the `if [ -n "$LIVE_NAMES" ]; then` output branch). Test: `tests/flowy-inject.test.ts`.

- [ ] **Step 1: Write the failing test** (append inside the existing describe block; reuses `makeDirs`/`writeFlowMd`/`writeState`/`runHook`/`stdinFor` from the top of the file). Add a `writeCompact` helper mirroring `writeFlowMd`'s plugin path.

```ts
test("V2: compact table reinjects every Nth prompt, not before", () => {
  const dirs = makeDirs();
  writeFlowMd(dirs, "flows/superpowers-flow/FLOW.md");
  // Write the compact table next to the FLOW.md the fixture created.
  writeFileSync(
    join(dirs.pluginRootFs, "flows/superpowers-flow/FLOW-compact.md"),
    "# compact\n- brainstorming: new idea\n",
  );
  writeState(dirs, "cnt", {
    schema: "flowy-state-v1", sessionId: "cnt",
    activeFlows: [{ name: "superpowers-flow", flowRef: "flows/superpowers-flow/FLOW.md", location: "plugin" }],
  });
  const env = { ...dirs, stdin: stdinFor("cnt"), extraEnv: { FLOWY_REINJECT_EVERY_N: "2" } };
  const r1 = runHook(env);   // prompt 1 → no table
  const r2 = runHook(env);   // prompt 2 → table (2 % 2 == 0)
  expect(r1.stdout).not.toContain("routing refresh");
  expect(r2.stdout).toContain("routing refresh");
  expect(r2.stdout.toLowerCase()).toContain("brainstorming: new idea");
});
```

(If `runHook` does not yet forward `extraEnv`, extend it to pass extra env vars to the child — a one-line change in the helper.)

- [ ] **Step 2: Run it to verify it fails**

Run: `bun test tests/flowy-inject.test.ts -t "reinjects every Nth"`
Expected: FAIL (no counter logic yet; `r2.stdout` lacks "routing refresh").

- [ ] **Step 3: Implement** — inside `flowy-inject.sh`, in the `if [ -n "$LIVE_NAMES" ]; then` block, AFTER the existing banner `printf` (and before the closing `fi`):

```sh
  # V2: periodic lightweight FLOW.md reinject (every Nth prompt). Counter is a
  # sidecar (NOT the state file) so the grep/sed state parse stays clean. Only
  # increments when a flow is live, so no-flow repos never accumulate counters.
  REINJECT_N="${FLOWY_REINJECT_EVERY_N:-40}"
  COUNT_FILE="$STATE_DIR/count-$SESSION_ID"
  CUR="$(cat "$COUNT_FILE" 2>/dev/null || echo 0)"
  case "$CUR" in *[!0-9]*|'' ) CUR=0 ;; esac
  CUR=$((CUR + 1))
  printf '%s' "$CUR" > "$COUNT_FILE" 2>/dev/null || true
  if [ "$REINJECT_N" -gt 0 ] 2>/dev/null && [ "$((CUR % REINJECT_N))" -eq 0 ]; then
    FIRST_REF="$(printf '%s' "$LIVE_REFS" | sed 's/,.*//')"          # first resolved FLOW.md path
    COMPACT="$(dirname "$FIRST_REF")/FLOW-compact.md"
    if [ -f "$COMPACT" ] && [ ! -L "$COMPACT" ]; then
      printf '%s\n' "--- Flowy routing refresh (every $REINJECT_N prompts) — re-read the full FLOW.md if unsure ---"
      cat "$COMPACT" 2>/dev/null || true
    fi
  fi
```

- [ ] **Step 4: Run to verify it passes**

Run: `bun test tests/flowy-inject.test.ts` → Expected: PASS (incl. the new test; the prior 90 stay green).

- [ ] **Step 5: Commit**

```bash
git add hooks/flowy-inject.sh tests/flowy-inject.test.ts
git commit -m "feat(v2): periodic compact-table reinject every N prompts (sidecar counter)"
```

---

### Task 3: `flowy-recompact.sh` compaction re-read hook

**Files:** Create `hooks/flowy-recompact.sh`; modify `hooks/hooks.json`. Test: `tests/flowy-recompact.test.ts` (NEW).

- [ ] **Step 1: Write the failing test**

```ts
import { test, expect } from "bun:test";
import { makeDirs, writeFlowMd, writeState } from "./helpers"; // or inline the same helpers used by flowy-inject.test.ts
import { execFileSync } from "node:child_process";

function runRecompact(dirs: any, stdin: string) {
  try {
    const out = execFileSync("sh", [join(dirs.pluginRootFs, "hooks/flowy-recompact.sh")], {
      input: stdin, env: { ...process.env, CLAUDE_PROJECT_DIR: dirs.projectDirEnv, CLAUDE_PLUGIN_ROOT: dirs.pluginRootEnv },
      encoding: "utf8",
    });
    return { stdout: out };
  } catch (e: any) { return { stdout: e.stdout?.toString() ?? "" }; }
}

test("recompact: source=compact → forces full FLOW.md re-read with path", () => {
  const dirs = makeDirs();
  writeFlowMd(dirs, "flows/superpowers-flow/FLOW.md");
  writeState(dirs, "cmp", { schema: "flowy-state-v1", sessionId: "cmp",
    activeFlows: [{ name: "superpowers-flow", flowRef: "flows/superpowers-flow/FLOW.md", location: "plugin" }] });
  const r = runRecompact(dirs, JSON.stringify({ source: "compact", session_id: "cmp" }));
  expect(r.stdout.toLowerCase()).toContain("re-read the flow.md");
  expect(r.stdout).toContain(`${dirs.pluginRootEnv}/flows/superpowers-flow/FLOW.md`);
});

test("recompact: source=startup → no-op", () => {
  const dirs = makeDirs();
  writeFlowMd(dirs, "flows/superpowers-flow/FLOW.md");
  writeState(dirs, "cmp", { schema: "flowy-state-v1", sessionId: "cmp",
    activeFlows: [{ name: "superpowers-flow", flowRef: "flows/superpowers-flow/FLOW.md", location: "plugin" }] });
  const r = runRecompact(dirs, JSON.stringify({ source: "startup", session_id: "cmp" }));
  expect(r.stdout.trim()).toBe("");
});
```

- [ ] **Step 2: Run to verify it fails**

Run: `bun test tests/flowy-recompact.test.ts` → Expected: FAIL (script does not exist).

- [ ] **Step 3: Create `hooks/flowy-recompact.sh`**

```sh
#!/usr/bin/env sh
# flowy-recompact.sh — SessionStart(source:compact) hook. After a compaction the
# FLOW.md content is gone from context; force a full re-read. No-op for startup/
# resume. Fail-loud: always exit 0, never block. Minimal self-contained FLOW.md
# resolution (mirrors flowy-inject.sh; if that resolution changes, update here).
trap 'exit 0' EXIT
set -u 2>/dev/null || true
STDIN="$(head -c 32768 2>/dev/null || true)"
SOURCE="$(printf '%s' "$STDIN" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
[ "$SOURCE" = "compact" ] || exit 0
SESSION_ID="$(printf '%s' "$STDIN" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//' | tr -d '\r')"
case "$SESSION_ID" in ''|*[!A-Za-z0-9_-]* ) exit 0 ;; esac
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"; PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$PROJECT_DIR" ] && [ -n "$PLUGIN_ROOT" ] || exit 0
. "$(dirname "$0")/flowy-paths.sh" 2>/dev/null || exit 0
STATE_DIR="$(flowy_state_dir "$PROJECT_DIR" "$PLUGIN_ROOT")"; [ -n "$STATE_DIR" ] || exit 0
STATE="$STATE_DIR/state-$SESSION_ID.json"
{ [ -f "$STATE" ] && [ ! -L "$STATE" ]; } || exit 0
SC="$(cat "$STATE" 2>/dev/null || true)"
NAME="$(printf '%s' "$SC" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
REF="$(printf '%s' "$SC" | grep -o '"flowRef"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
LOC="$(printf '%s' "$SC" | grep -o '"location"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
case "$NAME" in ''|*[!A-Za-z0-9_.-]*|*..* ) exit 0 ;; esac
RESOLVED=""
if [ "$LOC" = "project" ]; then
  P="$PROJECT_DIR/.flowy/flows/$NAME/FLOW.md"; { [ -f "$P" ] && [ ! -L "$P" ]; } && RESOLVED="$P"
else
  case "$REF" in *[!A-Za-z0-9_./-]*|*..* ) REF="" ;; esac
  if [ -n "$REF" ] && [ -f "$PLUGIN_ROOT/$REF" ] && [ ! -L "$PLUGIN_ROOT/$REF" ]; then
    RESOLVED="$PLUGIN_ROOT/$REF"
  else
    C="$PLUGIN_ROOT/flows/$NAME/FLOW.md"; { [ -f "$C" ] && [ ! -L "$C" ]; } && RESOLVED="$C"
  fi
fi
[ -n "$RESOLVED" ] || exit 0
printf '%s\n' "⚑ Flowy: context was just compacted. RE-READ the FLOW.md at $RESOLVED IN FULL now, before your next routing decision."
exit 0
```

- [ ] **Step 4: Register in `hooks/hooks.json`** — change the `SessionStart` array to include both hooks:

```json
    "SessionStart": [
      { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/flowy-gc.sh\"" } ] },
      { "hooks": [ { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/flowy-recompact.sh\"" } ] }
    ]
```

- [ ] **Step 5: Run tests** — `bun test` → Expected: PASS (the 2 new recompact tests + all prior).

- [ ] **Step 6: Commit**

```bash
git add hooks/flowy-recompact.sh hooks/hooks.json tests/flowy-recompact.test.ts
git commit -m "feat(v2): flowy-recompact.sh — force full FLOW.md re-read on SessionStart(compact)"
```

---

### Task 4: GC sweeps dead `count-*` sidecars

**Files:** Modify `hooks/flowy-gc.sh`. Test: add to its test (or `tests/flowy-gc.test.ts`).

- [ ] **Step 1:** Read `hooks/flowy-gc.sh` to find where it removes stale `state-*.json`. In the same sweep, for each removed/stale session id `<sid>`, also `rm -f "$STATE_DIR/count-<sid>"`. If the GC iterates `state-*.json`, derive the matching `count-` name from the same id.

- [ ] **Step 2: Write a failing test** — create a `count-deadsid` file with no matching live `state-deadsid.json`, run the GC, assert the `count-deadsid` file is gone.

- [ ] **Step 3: Implement** the `rm -f` of orphan `count-*` (a `count-<sid>` whose `state-<sid>.json` is absent) inside the GC's existing sweep loop; keep it fail-soft (`|| true`).

- [ ] **Step 4: Run** `bun test` → all green.

- [ ] **Step 5: Commit**

```bash
git add hooks/flowy-gc.sh tests/
git commit -m "fix(v2): GC sweeps orphan count-* reinject sidecars"
```

---

## Self-review
- **Spec coverage:** periodic reinject (Mechanism 1) → Tasks 1+2; compaction recovery (Mechanism 2) → Task 3; `FLOW-compact.md` bundle → Task 1; counter sidecar (not state file) → Task 2; GC sweep → Task 4; `SessionStart(compact)` registration → Task 3 Step 4; fail-loud preserved → both hooks `trap 'exit 0'` / no-op paths. Experiment harness correctly OUT of scope (separate spec).
- **Placeholder scan:** the hook code is complete; the one soft spot is test-helper signatures (`makeDirs`/`writeFlowMd`/`runHook`/`extraEnv`) which mirror the existing `flowy-inject.test.ts` — execution reads that file and matches them (noted inline), not a logic placeholder.
- **Type/name consistency:** `FLOWY_REINJECT_EVERY_N`, `count-<session_id>`, `FLOW-compact.md`, `flowy-recompact.sh` used identically across spec, tasks, and tests. `LIVE_REFS`/`STATE_DIR`/`SESSION_ID` are the real variables from `flowy-inject.sh`.

## Verification
`bun test` green after each task (≥92 tests: prior 90 + reinject + 2 recompact + GC). The reinject test proves Nth-prompt firing via `FLOWY_REINJECT_EVERY_N=2`; the recompact tests prove compact→re-read+path and startup→no-op.
