---
name: ultra-powers
description: The everything-Flow for building, shipping, and growing software. 40 hand-picked skills across ideate to grow, with a routing tree that fires the right one on intent (and disambiguates the overlaps).
---

# Activate ultra-powers

Activate the ultra-powers Flow for this session. After activation, FLOW.md routing becomes mandatory before every action.

## What this does

This skill invokes the bundled `ultra-powers:_activator` skill (sibling skill in this plugin) with the flow name `ultra-powers`. The activator handles:

1. Reading the FLOW.md at `../../flows/ultra-powers/FLOW.md` (relative to this skill's directory — two levels up to the plugin root, then into the `flows/` directory)
2. Indexing the bundled skills
3. Writing `.flowy/state-PENDING.json`, which the auto-installed plugin hook claims for this session
4. Enforcing FLOW.md routing for the rest of the session

## Invocation

Look at the argument THIS skill was invoked with, and forward to `ultra-powers:_activator`:
- **No argument** (or anything that isn't `deactivate`/`status`) → activate: invoke `ultra-powers:_activator` with argument `ultra-powers`.
- **`deactivate`** (optionally followed by a flow name) → invoke `ultra-powers:_activator` with argument `deactivate ultra-powers` (use the user's named flow if they gave one). Turns this Flow off for THIS session only.
- **`status`** → invoke `ultra-powers:_activator` with argument `status`.

So `/ultra-powers:ultra-powers` activates, `/ultra-powers:ultra-powers deactivate` turns it off, and `/ultra-powers:ultra-powers status` reports what's active + whether the hook is live.

The activator resolves paths relative to this plugin's root automatically. The current skill's base directory is `skills/ultra-powers/`; the plugin root is two levels up.

## If the bundled activator is somehow unavailable

The bundled `_activator` skill should always be present in this plugin (it ships in the same plugin you installed). If for some reason it cannot be invoked, the manual fallback is:

1. Read this plugin's `../../flows/ultra-powers/FLOW.md` directly (path relative to this skill's directory)
2. Internalize the routing decision tree
3. Before every turn, state routing decisions per the FLOW.md table

The fallback path does NOT write `.flowy/state-PENDING.json`, so the auto-installed hook has nothing to claim and routing does NOT survive context compaction. Use only as last resort.
