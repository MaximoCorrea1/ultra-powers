#!/usr/bin/env sh
# =============================================================================
# flowy-recompact.sh — SessionStart(source:compact) hook (V2 compaction recovery)
# =============================================================================
# After a compaction the FLOW.md content is gone from the agent's context; a
# lightweight banner is not enough. This hook forces a FULL re-read. It is a
# no-op for source=startup/resume (only a compaction drops context). FAIL-LOUD:
# always exit 0, never block. Minimal SELF-CONTAINED FLOW.md resolution that
# mirrors flowy-inject.sh — if that resolution changes, update here (or factor a
# shared helper). PostCompact cannot inject; SessionStart(source:compact) can.
# =============================================================================
trap 'exit 0' EXIT
set -u 2>/dev/null || true

STDIN="$(head -c 32768 2>/dev/null || true)"

# Only a compaction triggers the re-read.
SOURCE="$(printf '%s' "$STDIN" | grep -o '"source"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//')"
[ "$SOURCE" = "compact" ] || exit 0

SESSION_ID="$(printf '%s' "$STDIN" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//' | tr -d '\r')"
case "$SESSION_ID" in '' | *[!A-Za-z0-9_-]* ) exit 0 ;; esac
[ "${#SESSION_ID}" -le 128 ] 2>/dev/null || exit 0   # length guard (parity with flowy-inject.sh is_safe_id)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-}"
[ -n "$PROJECT_DIR" ] && [ -n "$PLUGIN_ROOT" ] || exit 0

. "$(dirname "$0")/flowy-paths.sh" 2>/dev/null || exit 0
. "$(dirname "$0")/flowy-resolve.sh" 2>/dev/null || exit 0
STATE_DIR="$(flowy_state_dir "$PROJECT_DIR" "$PLUGIN_ROOT")"
[ -n "$STATE_DIR" ] || exit 0

STATE="$STATE_DIR/state-$SESSION_ID.json"
{ [ -f "$STATE" ] && [ ! -L "$STATE" ]; } || exit 0
# Size cap (parity with flowy-inject.sh Fix 3): a giant/corrupt state must not stall SessionStart.
SB="$(wc -c < "$STATE" 2>/dev/null || echo 0)"
[ "$SB" -le 65536 ] 2>/dev/null || exit 0
SC="$(cat "$STATE" 2>/dev/null || true)"
[ -n "$SC" ] || exit 0

# Resolve the FIRST active flow's FLOW.md (mirror of flowy-inject.sh resolution).
NAME="$(printf '%s' "$SC" | grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//' | tr -d '\r')"
REF="$(printf '%s' "$SC" | grep -o '"flowRef"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//' | tr -d '\r')"
LOC="$(printf '%s' "$SC" | grep -o '"location"[[:space:]]*:[[:space:]]*"[^"]*"' | head -n 1 | sed 's/.*:[[:space:]]*"//; s/"$//' | tr -d '\r')"
case "$NAME" in '' | *[!A-Za-z0-9_.-]* | *..* ) exit 0 ;; esac

# Resolve via the shared helper (single source of truth with flowy-inject.sh).
RESOLVED="$(flowy_resolve_flowmd "$NAME" "$REF" "$LOC" "$PROJECT_DIR/.flowy/flows" "$PLUGIN_ROOT")"
[ -n "$RESOLVED" ] || exit 0

printf '%s\n' "⚑ Flowy: context was just compacted. RE-READ the FLOW.md at $RESOLVED IN FULL now, before your next routing decision."
# Reset the periodic reinject counter so the post-compaction cycle starts fresh — otherwise a
# session that compacted near count==N would fire this re-read AND the compact table on the very
# next prompt (double injection). SESSION_ID is allowlisted above; the write is fail-soft.
printf '0' > "$STATE_DIR/count-$SESSION_ID" 2>/dev/null || true
exit 0
