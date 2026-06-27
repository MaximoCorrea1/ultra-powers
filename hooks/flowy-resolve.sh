#!/usr/bin/env sh
# =============================================================================
# flowy-resolve.sh — shared FLOW.md resolution (SINGLE SOURCE OF TRUTH).
# Sourced (never executed) by flowy-inject.sh AND flowy-recompact.sh so the two
# hooks cannot drift on the per-flow "name/ref/location -> resolved FLOW.md"
# contract. POSIX sh; no jq/node.
#
#   flowy_resolve_flowmd NAME REF LOC PROJECT_FLOWS_DIR PLUGIN_ROOT
#     Echoes the resolved absolute FLOW.md path, or NOTHING (empty) if unresolvable.
#       location "project"      -> ONLY <PROJECT_FLOWS_DIR>/<name>/FLOW.md (no plugin
#                                  fallback; an explicit project entry must not be
#                                  silently rescued by a same-named bundled flow).
#       location "plugin"/absent -> <PLUGIN_ROOT>/<ref> if valid, else auto-repair
#                                  <PLUGIN_ROOT>/flows/<name>/FLOW.md.
#     Drops a REF containing `..`, a disallowed char ([^A-Za-z0-9_./-]), a bare single
#     dot, or a backslash (falls through to name-based auto-repair, like a stale ref).
#     Guards NAME against disallowed chars / `..` / empty. Rejects a SYMLINKED resolved
#     file (RR3): `[ -f ]` follows symlinks, so a planted link could read an arbitrary
#     file into the agent's context.
# =============================================================================
flowy_resolve_flowmd() {
  _name="$1"; _ref="$2"; _loc="$3"; _pfd="$4"; _pr="$5"
  _resolved=""

  # REF guard: drop traversal / disallowed chars / bare-dot / backslash.
  case "$_ref" in *..* ) _ref="" ;; esac
  case "$_ref" in
    *[!A-Za-z0-9_./-]* ) _ref="" ;;
    '.' ) _ref="" ;;
    *\\* ) _ref="" ;;
  esac

  if [ "$_loc" = "project" ]; then
    case "$_name" in
      *[!A-Za-z0-9_.-]* | *..* ) : ;;  # unsafe name → no resolution
      '' ) : ;;
      * )
        _pcanon="$_pfd/$_name/FLOW.md"
        if [ -f "$_pcanon" ] && [ ! -L "$_pcanon" ]; then _resolved="$_pcanon"; fi
        ;;
    esac
  elif [ -n "$_ref" ] && [ -f "$_pr/$_ref" ] && [ ! -L "$_pr/$_ref" ]; then
    _resolved="$_pr/$_ref"
  else
    case "$_name" in
      *[!A-Za-z0-9_.-]* | *..* ) : ;;  # unsafe name → skip auto-repair
      '' ) : ;;
      * )
        _canon="$_pr/flows/$_name/FLOW.md"
        if [ -f "$_canon" ] && [ ! -L "$_canon" ]; then _resolved="$_canon"; fi
        ;;
    esac
  fi

  printf '%s' "$_resolved"
}
