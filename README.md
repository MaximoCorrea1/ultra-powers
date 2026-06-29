# ultra-powers

**The everything-Flow for building, shipping, and growing software** — 40 hand-picked skills from 7 open-source suites, behind one `FLOW.md` router that fires the *right* skill on intent (and disambiguates the overlaps), with mandatory routing that survives context compaction.

Built on the [Flowy](https://flowy.sh) enforcement engine.

## Install

```
/plugin marketplace add MaximoCorrea1/ultra-powers
/plugin install ultra-powers@ultra-powers
```

Restart Claude Code (plugin hooks register at session start), then activate:

```
/ultra-powers:ultra-powers
```

You'll see `✓ ultra-powers active.` From then on a one-line ⚑ routing banner fires each prompt and the FLOW.md routes you to the right skill.

## What's inside

40 curated skills across the whole lifecycle — **validate → design → plan → build → debug → verify → review → ship → grow** — drawn from seven permissively-licensed suites:

| Suite | Author | Owns |
|---|---|---|
| [superpowers](https://github.com/obra/superpowers) | Jesse Vincent (obra) | disciplines/gates: TDD, debugging, verification, code review |
| [compound-engineering](https://github.com/EveryInc/compound-engineering-plugin) | EveryInc | end-to-end workflows: ideate, plan, work, review, compound |
| gstack | Garry Tan | founder-lens reviews: CEO/eng/DX plan review, security, retro |
| [frontend-design](https://github.com/anthropics/claude-code) | Anthropic | distinctive UI, anti-AI-slop |
| [emil/skills](https://github.com/emilkowalski/skills) | Emil Kowalski | UI polish + animation craft |
| [marketing-skills](https://github.com/coreyhaines31/marketingskills) | Corey Haines | GTM: positioning, copy, CRO, pricing, launch |
| [claude-seo](https://github.com/AgricIDaniel/claude-seo) | AgricIDaniel | SEO execution |

The value is the **disambiguation**: when two suites overlap (e.g. `systematic-debugging` vs `ce-debug`), the FLOW.md's "law" routes to exactly one. See [`flows/ultra-powers/FLOW.md`](flows/ultra-powers/FLOW.md) for the routing tree and [`flows/ultra-powers/ATTRIBUTION.md`](flows/ultra-powers/ATTRIBUTION.md) for per-skill credit + licenses.

## Enforcement (built in, no setup)

Installing the plugin installs a `UserPromptSubmit` hook — no `settings.json` editing. When ultra-powers is active, the hook injects a one-line routing banner each turn so routing survives context compaction. It's **fail-loud, never fail-closed**: no Flow active → silent, never blocks your prompts. Turn it off with `/ultra-powers:ultra-powers deactivate`.

## Attribution & license

Every bundled skill keeps its upstream **LICENSE** (copied alongside its `SKILL.md`) and is credited in [`ATTRIBUTION.md`](flows/ultra-powers/ATTRIBUTION.md) — all MIT or Apache-2.0. Nothing here is claimed as original; the original work is the **routing** (`FLOW.md`), licensed **CC-BY-SA-4.0**. `handoff` is referenced by the router but not bundled (no upstream license).
