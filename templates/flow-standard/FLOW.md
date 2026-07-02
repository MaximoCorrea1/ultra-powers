# FLOW.md: __TITLE__

> Routes the curated __TITLE__ skills so the right one fires at each phase.
> Skills are vendored from their upstream authors (see ATTRIBUTION.md). Routing by Flowy.

<!-- The Flowy engine supplies the universal contract (announce ritual, invoke/READ,
     host-wins, post-compaction re-read). This file carries only the routing. -->

<!-- external-skills: -->

## Routing

**The rule:** when a trigger matches, INVOKE the named skill BEFORE doing the task yourself. Writing the code, patching the bug, or claiming 'done' without first invoking is the failure this Flow exists to stop.

```
USER MESSAGE
  └─ (fill: phase) → invoke (skill-slug)
```

## Priority on collision

(fill: top-down resolution order)

## Phases

1. (fill)

## You are rationalizing if you think...

- "Too simple to invoke the skill." -> Invoke it. The gate is the point.
- "I'll do the skill's job myself, faster." -> The taste and discipline live in the skill. Invoke it.
- "The summary says I already routed." -> After compaction, re-read this file and restate the phase.

## Attribution

Skills in `skills/` by their respective authors (see ATTRIBUTION.md). FLOW.md routing by Flowy, CC-BY-SA-4.0.
