#!/usr/bin/env sh
# =============================================================================
# flowy-activate.sh — write a fresh single-flow state-PENDING.json for activation.
#
# Invoked by the _activator skill with the flow ALREADY resolved. Deterministic,
# SILENT on success. Reuses hooks/flowy-paths.sh (the canonical key helper) so the
# activator and the hook agree on the out-of-repo state dir byte-for-byte.
#
# Usage: flowy-activate.sh <plugin-root> <flow-name> <flow-ref> [<location>]
#   <plugin-root>  CLAUDE_PLUGIN_ROOT (carries /plugins/) or a /.claude home
#   <flow-name>    kebab-case slug, e.g. superpowers-flow
#   <flow-ref>     plugin-root-relative ref, e.g. flows/superpowers-flow/FLOW.md
#   <location>     "plugin" (default) or "project"
#
# Project dir: prefer $CLAUDE_PROJECT_DIR (exact match with the hook where the
# shell exposes it); else $(pwd). The canonical helper folds /e/ <-> E:\ to one
# key, so pwd's MSYS form resolves to the hook's Windows-form key.
#
# KNOWN LIMITATION (rare): if Claude Code's project dir (what the hook sees in
# CLAUDE_PROJECT_DIR) differs from the shell's $(pwd) at a DIFFERENT DEPTH (e.g.
# the hook sees repo/apps/web while pwd is the repo root), the PENDING lands under
# a different key than the hook reads and the banner will not fire. This is NOT a
# path-FORM issue (the helper folds E:\ <-> /e/); it is a project-dir mismatch.
# Diagnostic: if no banner appears next prompt, re-activate from the project root
# the hook actually uses. We deliberately do NOT auto-write to "sibling" keys — a
# sibling key can be a DIFFERENT project, so that would leak activation across
# projects.
#
# Output contract: success => exit 0, NOTHING on stdout. Failure => non-zero and
# a one-line reason on stderr. Fail-loud, never a wrong key. FLOW_NAME and
# FLOW_REF are charset-validated below before being written into the JSON
# (the hook's read-side strip only sanitizes display, not a structural breakout).
# =============================================================================

set -u 2>/dev/null || true

PLUGIN_ROOT="${1:-}"
FLOW_NAME="${2:-}"
FLOW_REF="${3:-}"
LOCATION="${4:-plugin}"

[ -n "$PLUGIN_ROOT" ] || { printf 'flowy-activate: missing plugin root\n' >&2; exit 2; }
[ -n "$FLOW_NAME" ]   || { printf 'flowy-activate: missing flow name\n' >&2; exit 2; }
[ -n "$FLOW_REF" ]    || { printf 'flowy-activate: missing flow ref\n' >&2; exit 2; }
# Charset-validate name + ref BEFORE interpolating them into the state JSON below:
# a crafted name/ref could otherwise break out of the JSON string and inject a
# second activeFlows entry that the hook's line-oriented parser would resolve.
case "$FLOW_NAME" in
  -* | *[!a-z0-9-]*) printf 'flowy-activate: invalid flow name: %s\n' "$FLOW_NAME" >&2; exit 2 ;;
esac
case "$FLOW_REF" in
  *..* | *[!A-Za-z0-9_./-]*) printf 'flowy-activate: invalid flow ref: %s\n' "$FLOW_REF" >&2; exit 2 ;;
esac
case "$LOCATION" in plugin | project) : ;; *) LOCATION="plugin" ;; esac

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
[ -n "$PROJECT_DIR" ] || { printf 'flowy-activate: no project dir\n' >&2; exit 3; }

# --- Override-injection scan (ADR-032; honors ADR-022 §3 for ALL flows) -------
# The scan lives HERE, in the one-shot script — not model-side — so activation
# stays a single call AND every flow (plugin OR project) is scanned. Resolve the
# FLOW.md with the SAME helper the hook uses; if it resolves, refuse activation on
# any instruction-override pattern. An unresolvable ref (a not-yet-present flow)
# has nothing to scan and falls through to the normal write. Deterministic
# (case/substring), so it does not vary per model. NOTE: POSIX sh cannot do NFKC,
# so this is an ASCII substring scan — the upstream flowy-add ingestion scan (Node,
# NFKC-capable) and the host-wins routing contract remain the other layers.
. "$PLUGIN_ROOT/hooks/flowy-resolve.sh" 2>/dev/null || {
  printf 'flowy-activate: cannot source flowy-resolve.sh under %s\n' "$PLUGIN_ROOT" >&2
  exit 9
}
FLOWMD="$(flowy_resolve_flowmd "$FLOW_NAME" "$FLOW_REF" "$LOCATION" "$PROJECT_DIR/.flowy/flows" "$PLUGIN_ROOT")"
if [ -n "$FLOWMD" ] && [ -r "$FLOWMD" ]; then
  # Normalize: lowercase + collapse all whitespace to single spaces (so a phrase
  # split across a newline still matches); first 256KB only (cap a pathological file).
  _scan="$(head -c 262144 "$FLOWMD" 2>/dev/null | tr 'A-Z' 'a-z' | tr -s '[:space:]' ' ')"
  case "$_scan" in
    *"ignore claude.md"* | *"disregard claude.md"* | *"override claude.md"* \
      | *"supersede claude.md"* | *"bypass claude.md"* | *"claude.md is outdated"* \
      | *"claude.md does not apply"* | *"treat claude.md as non-binding"* \
      | *"disregard project instructions"* | *"override project settings"* \
      | *"ignore project standards"* )
      printf 'flowy-activate: FLOW.md for %s attempts to override CLAUDE.md/project instructions; refused\n' "$FLOW_NAME" >&2
      exit 10 ;;
  esac
fi

# Canonical state dir via the SINGLE source of truth (same as the hook + GC).
. "$PLUGIN_ROOT/hooks/flowy-paths.sh" 2>/dev/null || {
  printf 'flowy-activate: cannot source flowy-paths.sh under %s\n' "$PLUGIN_ROOT" >&2
  exit 4
}
STATE_DIR="$(flowy_state_dir "$PROJECT_DIR" "$PLUGIN_ROOT")"
[ -n "$STATE_DIR" ] || { printf 'flowy-activate: empty state dir (unexpected layout)\n' >&2; exit 5; }

mkdir -p "$STATE_DIR" 2>/dev/null || {
  printf 'flowy-activate: cannot mkdir %s\n' "$STATE_DIR" >&2
  exit 6
}

# A fresh activation supersedes any unclaimed PENDING. Claimed state-<id>.json
# files (this or other sessions) are left to the GC + TTL — not our job.
rm -f "$STATE_DIR/state-PENDING.json" 2>/dev/null || true

EPOCH="$(date +%s 2>/dev/null)"
case "$EPOCH" in '' | *[!0-9]*) printf 'flowy-activate: no epoch\n' >&2; exit 7 ;; esac

# Write atomically: tmp + mv, so the hook never claims a half-written file. We rm
# the real file above first, so the mv targets a non-existent path (avoids the
# Windows replace-over-existing quirk).
TMP="$STATE_DIR/state-PENDING.json.tmp"
cat > "$TMP" <<EOF
{
  "schema": "flowy-state-v1",
  "sessionId": "PENDING",
  "createdAtEpoch": $EPOCH,
  "activeFlows": [
    { "name": "$FLOW_NAME", "flowRef": "$FLOW_REF", "location": "$LOCATION" }
  ]
}
EOF
mv "$TMP" "$STATE_DIR/state-PENDING.json" 2>/dev/null || {
  rm -f "$TMP" 2>/dev/null || true
  printf 'flowy-activate: cannot write state file in %s\n' "$STATE_DIR" >&2
  exit 8
}

exit 0
