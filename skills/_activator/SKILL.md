---
name: _activator
description: Internal activator for Flowy Flows. Invoked by flow wrapper skills (flowy:superpowers-flow, etc.) to resolve the FLOW.md, write a flowy-state-v1 state file to the out-of-repo state dir via flowy-activate.sh (never under the project repo's .flowy/), and enforce mandatory routing. Not for direct user invocation.
---

# Flowy Activator (Bundled)

You have been invoked by a flow wrapper skill to activate a Flowy Flow. The wrapper passes the flow name as the argument.

This skill is the canonical V1 activator, bundled inside the plugin so installing the plugin gives you everything you need. The global `~/.claude/skills/flowy/SKILL.md` is a dev-only fallback for the `git clone` workflow.

## How enforcement works (read this first)

Flowy routing is enforced by an **auto-installed `UserPromptSubmit` hook** (`hooks/flowy-inject.sh`) that ships with this plugin. You do NOT install or configure it — Claude Code loads plugin hooks automatically when the plugin is installed.

On every user prompt, the hook reads a per-session state file and, if a Flow is active, injects a loud routing banner into your context. That banner is what makes FLOW.md routing survive across turns and context compaction.

Your job as the activator is to **write the state file the hook reads**. The contract is precise — match it exactly or the hook silently no-ops.

**Key constraint: you (a skill) do NOT see the Claude Code `session_id`.** Only the hook sees it (it arrives on the hook's stdin). So you write a **PENDING** state file, and the next hook invocation claims it by renaming `state-PENDING.json` → `state-<session_id>.json`. This is by design — do not try to discover or invent a session id.

## Where state lives — OUT OF THE PROJECT REPO (read this carefully)

**State files do NOT live in the project repo.** A repo that ships a committed `$CLAUDE_PROJECT_DIR/.flowy/state-*.json` is a security threat (it could force attacker routing on anyone who clones it), so the hook IGNORES any in-repo state and reads ONLY an out-of-repo state dir. You MUST write to that same out-of-repo dir or the hook will never see your state.

**Compute the state dir by INVOKING the shared helper — do NOT compute the key by hand.** The hook, the GC, and you all derive the dir from ONE script (`hooks/flowy-paths.sh`), so you cannot disagree on it. Hand-computing the key in prose is exactly the bug that made the banner silently vanish: a Windows `E:\` path and a Git-Bash `/e/` path of the SAME project produced different keys, so the hook read a dir you never wrote. Run this once via the Bash tool:

```
sh -c '. "$1/hooks/flowy-paths.sh"; flowy_state_dir "${CLAUDE_PROJECT_DIR:-$2}" "$1"' _ "<plugin-root>" "<project-dir>"
```

- `<plugin-root>` = your wrapper's "Base directory for this skill" with the trailing `skills/<flow-name>` removed. Example: base `~/.claude/plugins/cache/flowy-flows/flowy/0.6.2/skills/superpowers-flow` → plugin-root `~/.claude/plugins/cache/flowy-flows/flowy/0.6.2`.
- `<project-dir>` = the project root path (the working directory Claude Code shows you). Substitute the ACTUAL path and KEEP the double-quotes shown: it can contain a space (e.g. `Projects VS`), so an unquoted value would word-split and produce the wrong key. Never pass the literal `<project-dir>` placeholder. The command prefers the live `$CLAUDE_PROJECT_DIR` when the Bash env exposes it and falls back to the literal you pass. The helper **canonicalizes either form to the same key**, so you do not need to match any particular path style; that canonicalization is what guarantees you and the hook agree.
- Capture the single line it prints — that absolute path is your **STATE_DIR** for the rest of this skill. If it prints NOTHING, the plugin layout is unexpected (no `/.claude` home); report that and stop — do NOT guess a path.

ACTIVATE writes `state-PENDING.json` here via `flowy-activate.sh` (Step 3, below); DEACTIVATE and STATUS use this `<STATE_DIR>` directly to edit/read `state-*.json`.

Throughout this skill, wherever a step names the state dir or `state-*.json`, it means a file in THIS helper-computed **STATE_DIR**. NEVER write a state file under `$CLAUDE_PROJECT_DIR/.flowy/` — the hook will not read it, and a committed one is the exact threat we relocated state to avoid.

## The state file contract — schema `flowy-state-v1`

- **Location:** `<STATE_DIR>/state-PENDING.json` (you always write PENDING; the hook claims it). See the derivation above.
- **Shape:**

```json
{
  "schema": "flowy-state-v1",
  "sessionId": "PENDING",
  "createdAtEpoch": 1749800000,
  "activeFlows": [
    { "name": "superpowers-flow", "flowRef": "flows/superpowers-flow/FLOW.md", "location": "plugin" }
  ]
}
```

- **`flowRef` is a path RELATIVE TO the plugin root** (version-agnostic), e.g. `flows/superpowers-flow/FLOW.md`. It is NEVER an absolute cache path. The hook resolves the live file as `<plugin-root>/<flowRef>`, and auto-repairs to `<plugin-root>/flows/<name>/FLOW.md` if the stored ref is stale. Writing a version-pinned cache path would break on the next plugin upgrade — do not do it.
- **`location`** tells the hook WHERE to resolve the FLOW.md. Write `"location": "plugin"` for bundled/official flows (resolved under the plugin root via `flowRef`) and `"location": "project"` for a flow resolved under `$CLAUDE_PROJECT_DIR/.flowy/flows/<name>/FLOW.md` (project-local content). **Always emit `location` on every entry** — the hook pairs it positionally with `name`, so a consistent field per entry keeps the pairing aligned. For a `project` entry, still write a `flowRef` of `flows/<name>/FLOW.md` (the hook ignores it for project entries but keeping the field present preserves the line-oriented shape). An absent/empty `location` defaults to `plugin`.
- **Line-oriented parser — formatting rules you MUST honor:** the hook parses this file with `grep`/`sed`, line by line. Therefore:
  - Each `"name": "..."`, each `"flowRef": "..."`, and each `"location": "..."` must sit on its OWN single line. Standard pretty-printed JSON (one key per line, as shown above) is fine. Never split a key/value across lines.
  - Never put an escaped quote (`\"`) inside a `name`, `flowRef`, or `location` value. Flow names are clean slugs (`[a-z0-9-]`), flowRefs are clean relative paths, and `location` is exactly `plugin` or `project` — none need escaping.
  - Names, flowRefs, and locations are read **positionally, in lockstep**: the Nth `"name"` pairs with the Nth `"flowRef"` and the Nth `"location"`. Write one object per array element with `name`, then `flowRef`, then `location`, in that order. Emitting `location` on EVERY entry keeps the positional pairing aligned.
- **`createdAtEpoch` (REQUIRED on every `state-PENDING.json` — lockstep with the hook):** the current Unix epoch seconds, obtained via the Bash tool `date +%s`, written as an **unquoted integer** at the top level (sibling of `sessionId`). The hook treats a PENDING that LACKS `createdAtEpoch`, or whose `createdAtEpoch` is older than the freshness TTL (~600s), as **STALE and deletes it WITHOUT claiming** — so an un-stamped (or slow-to-be-claimed) PENDING means your Flow silently never activates. Claimed `state-<session_id>.json` files do NOT need it (only PENDING is TTL-checked); but always stamp PENDING.
- **"active" means:** the file exists AND contains `"activeFlows"` AND has ≥1 `"name":` entry. An empty `"activeFlows": []` means deactivated — the hook no-ops.

## Parse the argument

The wrapper passes the flow name. If the argument is `deactivate <flow-name>`, `deactivate`, or `status`, route to those sections below. Otherwise, treat it as `<flow-name>` and ACTIVATE.

---

## ACTIVATE

> **One-shot for EVERY flow.** Activation is ONE Bash call (Step 3) then ONE
> success line (Step 4). Do NOT read the FLOW.md, do NOT run any override scan, and
> do NOT run the state-dir helper model-side — `flowy-activate.sh` (Step 3)
> resolves the FLOW.md, scans it for CLAUDE.md/project-override attempts (plugin
> AND project flows, deterministically), and writes state. The routing-tree read
> is DEFERRED to your first routing turn (the hook re-injects the FLOW.md path
> every prompt — Step 6); the plugin flow's existence is already proven by the
> wrapper skill that invoked you. Narrate nothing on the happy path.

### Step 1: Determine location + flowRef (no read)

Record `<flow-name>`, `<flowRef>` = `flows/<flow-name>/FLOW.md`, and `<location>`:
- **`plugin`** (the default): a flow bundled in this plugin at
  `<plugin-root>/flows/<flow-name>/FLOW.md`. `<plugin-root>` = the wrapper's "Base
  directory for this skill" with the trailing `skills/<flow-name>` removed. You do
  NOT read this file — `flowy-activate.sh` + the hook resolve it (with name-based
  auto-repair), and the wrapper that invoked you already proves the flow exists.
  Legacy `~/.claude/flows/<flow-name>/` and repo-root `flows/<flow-name>/` are also
  `location: plugin`.
- **`project`**: a dev/UGC flow at `$CLAUDE_PROJECT_DIR/.flowy/flows/<flow-name>/FLOW.md`
  (there is NO plugin fallback for a project entry). Use ONLY when the flow lives
  there. Print once:
  > Warning: loading a project-local FLOW.md. This overrides the plugin version. Only safe in development.

If you truly cannot determine a location (neither a bundled `flows/<flow-name>/`
nor a project-local flow), print `Flow <flow-name> not found.` and stop.

### Step 2: (no model-side scan)

Nothing to do here. The override scan runs inside `flowy-activate.sh` (Step 3) for
BOTH plugin and project flows — moving it into the one-shot script keeps activation
a single call AND scans every flow (ADR-032, honoring ADR-022 §3's "scan all
flows"). Do not read or scan the FLOW.md yourself.

### Step 3: Write state via the activation script (it scans, then writes)

Run ONE command. Substitute `<plugin-root>` (the wrapper "Base directory" minus the trailing `skills/<flow-name>`) and the Step-1 values (`<flowRef>` is `flows/<flow-name>/FLOW.md`):

```
sh "<plugin-root>/hooks/flowy-activate.sh" "<plugin-root>" "<flow-name>" "<flowRef>" "<location>"
```

The script resolves the FLOW.md, REFUSES activation (non-zero + stderr) if it contains a CLAUDE.md/project-instruction override attempt, and otherwise derives the canonical OUT-OF-REPO state dir (the SAME `flowy-paths.sh` helper the hook uses), drops any stale `state-PENDING.json`, stamps a fresh `createdAtEpoch`, and atomically writes a new `state-PENDING.json`. It reads `${CLAUDE_PROJECT_DIR:-$(pwd)}` ITSELF — do NOT compute the state dir, hand-author the JSON, pass a project dir, or scan the FLOW.md yourself.

- **Exit 0** → go to Step 4.
- **Non-zero** → print the failure and stop (an override refusal reads `...attempts to override CLAUDE.md...` and is terminal — the Flow cannot be activated):
  > Warning: couldn't activate Flowy (`<the script's stderr line>`). If it was an override refusal the Flow cannot be activated; otherwise restart Claude Code (plugin hooks register at session start) and re-run `/flowy:<flow-name>`.

### Step 4: Print confirmation (ONE line)

Emit exactly one line, nothing else:

`<flow-name> active.`

Do not print the skills list, the state path, scope, or any explanation on the happy path. If the user wants detail, that is what `status` is for.

### Step 5: Bootstrap (deferred to the first routing turn)

Do NOT fire a bootstrap at activation — it would reintroduce a FLOW.md read + skill
output into the one-shot. Instead, when you FIRST read the FLOW.md on your first
routing turn (Step 6), check it for a session-bootstrap step (for superpowers-flow
this is `using-superpowers`) and fire it ONCE then: read the bootstrap skill's
SKILL.md from `<plugin-root>/flows/<flow-name>/skills/<bootstrap-name>/SKILL.md`
and follow it. Skip re-firing if it already fired this session.

### Stacking (rare: a Flow is ALREADY active this session)

The script writes a fresh single-flow PENDING — correct for the common case (no Flow active yet). If the routing banner THIS turn already lists active Flow(s) and you are ADDING another, the script alone will not take effect this turn: the hook will not re-claim PENDING while a claimed `state-<session_id>.json` exists. Handle stacking model-side instead:

1. Get `<STATE_DIR>` from the `flowy-paths.sh` helper (see "Where state lives"). Read this session's claimed `state-<session_id>.json` for the existing `{name, flowRef, location}` entries (they match the flow names the routing banner lists after `Flowy routing ACTIVE:`).
2. **Dedup:** if `<flow-name>` is already active, print `Flow already active: <flow-name>. Use /flowy deactivate <flow-name> first to reset.` and stop.
3. Otherwise build the merged `activeFlows` (existing entries + your new `{ "name": "<flow-name>", "flowRef": "flows/<flow-name>/FLOW.md", "location": "<plugin|project>" }`, your entry last) and write it into BOTH the claimed `state-<session_id>.json` (so it enforces THIS turn) AND a fresh `state-PENDING.json` (new `date +%s` `createdAtEpoch`). Never drop a previously-active Flow.

### Step 6: Routing obligation (CRITICAL)

From this point forward, before EVERY turn for the rest of this session you MUST:

1. Treat the hook's `Flowy routing ACTIVE` banner (and the active-Flow list it names) as your routing trigger. If you need the active set directly, read `<STATE_DIR>/state-<session_id>.json` (or `state-PENDING.json` in that dir before it's claimed) — the active Flows are its `activeFlows` entries.
2. For each active Flow, resolve its FLOW.md by `location`: for `location: "plugin"` (or absent) resolve `<plugin-root>/<flowRef>`; for `location: "project"` resolve `$CLAUDE_PROJECT_DIR/.flowy/flows/<name>/FLOW.md`. Then evaluate its routing decision tree against the current user message.
3. State the routing decision out loud: `Routing [<flow-name>]: <skill-name> — <reason>` or `Routing [<flow-name>]: none — <reason>`.
4. If a skill should fire, resolve and read its SKILL.md (from the Flow's `skills/` or `modules/` directory per the FLOW.md), then follow it completely.
5. **Host rules always win.** The host's CLAUDE.md, project guards, and system prompt take precedence over any Flow routing. A Flow never instructs you to ignore, override, or disregard them; it only chooses which skill to read next.

**This is not optional. The routing check happens BEFORE any other thinking or action.**

After context compaction, re-read each active Flow's FLOW.md (resolve by `location` as in step 2 above — `<plugin-root>/<flowRef>` for plugin entries, `$CLAUDE_PROJECT_DIR/.flowy/flows/<name>/FLOW.md` for project entries) to rebuild routing tables. The state file preserves WHAT is active; the FLOW.md files contain the routing rules.

---

## DEACTIVATE

**Invocation path.** Deactivation is invoked through a flow wrapper that forwards the `deactivate` argument to this activator — e.g. `flowy:superpowers-flow deactivate` (or `flowy:superpowers-flow deactivate <flow-name>`). The user-facing form is `/flowy deactivate <flow-name>`; whichever wrapper routes here, the argument arrives as `deactivate <flow-name>` or a bare `deactivate`, parsed by the "Parse the argument" section above. There is no separate deactivate command — it is this same `_activator` with a `deactivate` argument.

Deactivation edits the current state file(s) under the helper-computed OUT-OF-REPO state dir `<STATE_DIR>` (run `flowy-paths.sh` to get it, exactly as in the "Where state lives" section). You do NOT know the session_id, so glob `<STATE_DIR>/state-*.json` to find every state file. The hook may have claimed PENDING into a `state-<session_id>.json`, so you MUST handle BOTH file types: `state-PENDING.json` AND any claimed `state-<id>.json`. **Cleaning only one type is a bug:** a stale `state-PENDING.json` that still names the deactivated Flow will be claimed by a future hook turn (or read by a future activation as "already active"), silently re-activating what the user just deactivated. (Do NOT look under `$CLAUDE_PROJECT_DIR/.flowy/` for state — the hook never reads it.)

### If `deactivate <flow-name>`:
1. Glob `<STATE_DIR>/state-*.json` to enumerate ALL state files (both `state-PENDING.json` and any `state-<id>.json`). For EACH one, read it and remove the `activeFlows` entry where `name == <flow-name>`.
2. For each file, after removal:
   - If `activeFlows` is still non-empty, write the updated `activeFlows` back to that file (preserving its `sessionId`).
   - If `activeFlows` becomes empty:
     - For a claimed `state-<id>.json`: write `"activeFlows": []` (the hook treats empty as deactivated and no-ops). Prefer leaving the empty array here rather than deleting, so a stale PENDING cannot silently re-activate.
     - For `state-PENDING.json`: **delete it** (so it can never be claimed with the deactivated Flow still inside). If you cannot delete, write `"activeFlows": []` to it instead.
3. **You MUST process state-PENDING.json in this same pass — do not stop after updating the claimed `state-<id>.json`.** Removing `<flow-name>` from the claimed file but leaving it in PENDING is exactly the stale-PENDING re-activation bug. Make the cleanup of BOTH file types explicit and complete.
4. Print: `Flow deactivated: <flow-name>`

### If `deactivate` (no argument):
1. Glob `<STATE_DIR>/state-*.json`. For EVERY match — including `state-PENDING.json` — either delete it or set `"activeFlows": []`. Prefer deleting `state-PENDING.json` and writing `"activeFlows": []` to any claimed `state-<id>.json`. Leave no file naming any Flow.
2. Print: `All Flows deactivated. Routing obligations cleared.`

---

## STATUS

`status` is invoked the same way as the other commands — through a wrapper forwarding the `status` argument to this activator (e.g. `flowy:superpowers-flow status`), or `/flowy status`. It answers TWO questions the user cannot otherwise distinguish: (a) **what** the state file says is active, and (b) **whether the enforcement hook is actually running this session**. These are different: a missing flow and a broken hook are both silent, and the user needs to tell them apart.

### Step A — enumerate state files

Glob `<STATE_DIR>/state-*.json` (the helper-computed OUT-OF-REPO state dir — run `flowy-paths.sh` to get `<STATE_DIR>` per the "Where state lives" section; do NOT look under `$CLAUDE_PROJECT_DIR/.flowy/`). Classify each match:
- `state-PENDING.json` — written by the activator, NOT yet claimed by the hook.
- any other `state-*.json` (i.e. `state-<session_id>.json`) — a file the hook CLAIMED by atomically renaming PENDING → `state-<session_id>.json` under its mkdir-lock. **The existence of a claimed `state-<session_id>.json` is the proof the hook ran**: the activator only ever writes `state-PENDING.json`, so the only thing that can produce a `state-<session_id>.json` is the hook's claim step. If one exists, the hook fired at least once this session.

### Step B — report whether the hook is live (the critical signal)

Decide and print exactly one of these:

- **A claimed `state-<session_id>.json` exists** → the hook has claimed this session, so enforcement is LIVE. Print:
  > Enforcement is live: the Flowy hook ran and claimed this session (`state-<session_id>.json` present). The routing banner fires on each prompt.
- **ONLY `state-PENDING.json` exists (no claimed file)** → the hook has NOT run yet this session (nothing ever renamed PENDING). Either you only just activated (the claim happens on your NEXT prompt), or the hook isn't registered. Print:
  > Enforcement NOT confirmed — only `state-PENDING.json` exists; the hook has not claimed this session. If you just activated, send one more prompt and re-check (the hook claims PENDING on the next prompt). If `state-PENDING.json` is STILL unclaimed after another prompt, the hook is not registered — **restart Claude Code** (plugin hooks register at session start) and re-activate.
- **No state file at all** → nothing has been activated this session. Print `No active Flows.` and stop (there is nothing for the hook to enforce, so the hook-ran question is moot).

### Step C — report what is active

If any state file has a non-empty `activeFlows`, for each entry (deduped across files) print:
```
Active Flow: <name>
  FLOW.md: <flowRef> (resolved under the plugin root)
```
If every state file has empty `activeFlows`, print `No active Flows.` (state files exist but everything is deactivated).

Always name which state file(s) you read (`state-PENDING.json` and/or `state-<session_id>.json`) so the user can correlate the active-flow list with the live/not-live signal from Step B.
