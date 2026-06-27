# FLOW.md: ultra-powers

> The everything-Flow for an indie founder building, shipping, and growing software. ~36 real, hand-verified skills across validate → design → plan → build → debug → verify → review → ship → grow, composed from five open-source suites — with a routing tree that knows *which* of the overlapping skills to fire.
> Skills by their respective authors (MIT / Apache-2.0, see Attribution). Routing by Flowy.

<!-- The Flowy engine supplies the universal contract (announce, READ/invoke, host-wins,
     post-compaction re-read). This file carries only the routing + disambiguation. -->

## The one rule that makes this Flow worth more than its skills

Five suites overlap on purpose. The Flow's value is knowing which to fire:

- **`superpowers` = portable DISCIPLINES** — laws + gates, no tooling (brainstorming, writing-plans, TDD, systematic-debugging, verification, code-review, worktrees). Reach for these when you want the *guardrail*.
- **`compound-engineering` (`ce-*`) = end-to-end WORKFLOWS** — tooling, sub-agents, auto-fix, tracker ingestion. Reach for these when you want the *machine*.
- **`gstack` = founder-lens REVIEWS + ops** — review a plan/diff through a CEO/eng/DX persona, audit security, generate docs.
- **`claude-seo` owns SEO execution; `marketing-skills` owns GTM.**

**Never fire both halves of a pair on one task.** Pick the lane (discipline *or* workflow), and route by the tiebreakers below.

## Routing

**The rule:** when a trigger matches, INVOKE the named skill BEFORE doing the task yourself.

```
USER MESSAGE
  │ — VALIDATE / IDEATE —
  ├─ is this NEW idea worth building? (demand, wedge, should-I)        → office-hours
  ├─ what should I build/improve NEXT in this project?                 → ce-ideate
  │ — DESIGN (spec) — pick ONE lane —
  ├─ refine a chosen idea into a design/architecture spec (TDD lane)?  → brainstorming        gate: approved design doc
  ├─ shape a chosen idea into a requirements doc (the WHAT; CE lane)?  → ce-brainstorm
  │ — DESIGN (UI) —
  ├─ design a NEW UI / page / visual identity (look, type, layout)?    → frontend-design
  ├─ make a UI FEEL right (animation, motion, micro-interactions)?     → emil-design-eng
  ├─ review existing animation / motion code?                          → review-animations
  │ — PLAN (create) — match the design lane —
  ├─ approved design → TDD implementation plan (code in every step)?   → writing-plans        gate: checkboxed tasks
  ├─ plan a broader / non-code / research-backed effort?               → ce-plan
  │ — PLAN (review) — harden a plan before building —
  ├─ stress-test a plan's scope / ambition ("think bigger")?           → plan-ceo-review
  ├─ stress-test a plan's architecture / edge cases / tests?           → plan-eng-review
  ├─ stress-test a dev-facing plan's DX (API/CLI/SDK)?                  → plan-devex-review
  ├─ run all the plan reviews at once?                                 → autoplan
  │ — BUILD —
  ├─ about to write implementation code (discipline)?                  → test-driven-development  gate: a failing test FIRST
  ├─ execute an approved plan end-to-end (CE machine)?                 → ce-work
  │ — DEBUG —
  ├─ something broken — want the root-cause guardrail?                 → systematic-debugging   gate: root cause written down
  ├─ bug tied to a tracker / want it diagnosed AND fixed end-to-end?   → ce-debug
  │ — VERIFY —
  ├─ about to claim done / fixed / passing?                            → verification-before-completion  gate: command output proves it
  │ — REVIEW —
  ├─ thorough pre-PR review with auto-fix (the system)?               → ce-review
  ├─ quick second-pair-of-eyes mid-task (one reviewer)?               → requesting-code-review
  ├─ received review feedback to address?                             → receiving-code-review  gate: every finding resolved
  ├─ pre-merge safety lens (SQL / LLM-trust / side-effects)?          → review
  │ — PROVE / SHIP —
  ├─ capture a GIF/screenshot proof of real usage for a PR?           → ce-demo-reel
  ├─ need parallel isolated branches?                                 → using-git-worktrees
  ├─ commit + push + open a PR with a value-first description?        → git-commit-push-pr
  ├─ land a finished branch (merge / integration choice)?             → finishing-a-development-branch  gate: tests pass
  │ — SECURE / CAPTURE / DOCS —
  ├─ security audit (secrets, supply chain, OWASP, STRIDE)?           → cso
  ├─ just solved something hard — capture it for reuse?               → ce-compound
  ├─ write user-facing docs from scratch (tutorial/how-to/ref)?       → document-generate
  ├─ "what did we ship" / weekly retrospective?                       → retro
  ├─ wrap a session / hand off to another agent?                      → handoff
  │ — GROW (set up once) —
  ├─ define positioning / ICP / who-this-is-for (do this FIRST)?      → product-marketing
  ├─ I don't know what growth move to make next?                      → marketing-ideas
  │ — GROW (GTM) —
  ├─ write page / landing / pricing copy?                             → copywriting
  ├─ a page isn't converting (layout, friction, trust, CTA)?         → cro
  ├─ set pricing / tiers / freemium?                                  → pricing
  ├─ plan a launch / Product Hunt / GTM moment?                       → launch
  ├─ decide WHAT content/topics to create?                           → content-strategy
  ├─ build-in-public / social posts / threads?                       → social
  │ — GROW (SEO — claude-seo owns this) —
  ├─ any SEO intent: rank / audit / schema / technical / AI-Overviews/ backlinks / pages-at-scale? → seo
  │ — META —
  ├─ ad-hoc parallel research / fan-out?                              → dispatching-parallel-agents
  ├─ scope changed mid-task?                                          → re-enter the earliest invalidated phase (office-hours / brainstorming / writing-plans)
  ├─ blocked on an external dependency?                               → park: record blocker + resume condition; don't fake progress
  └─ question, not work (advise / explain)?                           → answer only; no files change
```

## Disambiguation (the tiebreakers — why this Flow beats loose skills)

**The superpowers ↔ compound-engineering pairs (the law: discipline vs workflow):**
- **office-hours vs ce-ideate** — office-hours validates whether a NEW idea is worth building (demand, wedge). ce-ideate *generates + ranks* what to build/improve next in an EXISTING project. Validate a bet → office-hours; "what's next" → ce-ideate.
- **brainstorming vs ce-brainstorm** — same job, different lane + handoff. `brainstorming` bakes architecture into a design spec and hands to **writing-plans → TDD**. `ce-brainstorm` produces a requirements doc (the WHAT only) and hands to **ce-plan → ce-work**. Pick the lane and stay in it.
- **writing-plans vs ce-plan** — same name, different jobs. `writing-plans` = a TDD-first implementation plan for **code** (actual code + failing-test-first in every step). `ce-plan` = general structured planning (non-code, research-backed, "deepen" mode). Code you'll TDD → writing-plans; anything else → ce-plan.
- **systematic-debugging vs ce-debug** — `systematic-debugging` is the portable root-cause *guardrail* you overlay on any failure (no tooling). `ce-debug` is the full *workflow* — pulls the issue from gh/Linear/Jira, reproduces, fixes end-to-end. ce-debug already contains the discipline; **don't stack them.** Tracker-tied / fix-it-all → ce-debug; stray failure → systematic-debugging.
- **ce-review vs requesting-code-review** — `ce-review` is a 17-persona orchestrated *system* with a confidence gate + auto-fix + headless mode. `requesting-code-review` dispatches ONE reviewer, fast, mid-task. Pre-PR gate / want auto-fix → ce-review; quick eyes → requesting-code-review.
- **verification-before-completion has NO CE twin** — keep it as the done-gate. (CE's `proof` is a markdown editor, not verification; `ce-demo-reel` makes *visual PR proof*, a different job.)

**Plan create vs plan review (a whole phase, not a duplicate):**
- superpowers/CE **create** plans (brainstorming/writing-plans, ce-brainstorm/ce-plan). gstack's **plan-ceo-review / plan-eng-review / plan-devex-review** *review an existing plan* through a persona lens. Different stage of the same loop — create first, then review.

**Design triad (overlap only on "motion"):**
- **frontend-design** = the *look* (aesthetic direction, palette, typography, layout, the signature). **emil-design-eng** = the *feel* (animation craft, easing, springs, micro-interactions). **review-animations** = reviewing motion code (won't auto-fire — only a Flow naming it surfaces it). New UI → frontend-design; make it feel right → emil; audit motion → review-animations.

**Grow — who owns "SEO":**
- **`seo` (claude-seo) owns ALL SEO execution** (audit, technical, schema, AI-Overviews/GEO, backlinks, pages-at-scale) — it's a 25-skill suite behind one router. `marketing-skills` owns broader GTM (positioning, copy, launch, channels). An SEO-specific verb → `seo`; growth strategy where SEO is one channel → marketing. `content-strategy` (marketing, decides *what* to write) and `seo` (is it *optimized*) are complementary, not duplicate.

## Priority on collision

Top-down: 1. **Debug** a broken state. 2. **Verify** a pending "done" claim. 3. **TDD** before writing code. 4. **Plan** before building. 5. **Design** before planning (and **validate/ideate** before design if the bet itself is unsettled). 6. Everything else in lifecycle order. A scope change re-enters the earliest invalidated phase.

## Phases

Validate (office-hours / ce-ideate) → Design (brainstorming|ce-brainstorm + frontend-design/emil) → Plan (writing-plans|ce-plan, then plan-*-review) → Build (TDD|ce-work) → Verify (verification-before-completion) → Review (ce-review / requesting-code-review / review) → Ship (worktrees / git-commit-push-pr / finishing-a-development-branch) → Secure & capture (cso / ce-compound / document-generate / retro / handoff) → Grow (product-marketing first, then GTM + seo).

**Shortcuts:** bug → systematic-debugging → TDD (regression test) → verify. UI feel → emil-design-eng → verify. Ship → git-commit-push-pr. Typo/config → fix → verify.

## You are rationalizing if you think…

- "I'll just design the screen / write the copy myself." → The taste is in the skill (frontend-design / emil / copywriting). Invoke it.
- "ce-debug and systematic-debugging are the same." → One is the machine, one is the guardrail. Pick the lane; don't stack.
- "I know which design skill." → New UI is frontend-design; *feel* is emil; *reviewing* motion is review-animations.
- "I'll verify after." → verification-before-completion. Run the command in THIS message.
- "I'll just ship it." → git-commit-push-pr / finishing-a-development-branch. The PR description and the integration choice matter.
- "The summary says I already routed." → After compaction, re-read this file and restate the phase.

## Attribution

Composed skills (each retains its upstream LICENSE + attribution; nothing here is claimed as original — the routing is the original work):
- **superpowers** — Jesse Vincent (obra), MIT — `brainstorming`, `writing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `requesting-code-review`, `receiving-code-review`, `using-git-worktrees`, `finishing-a-development-branch`, `dispatching-parallel-agents`
- **compound-engineering** — EveryInc, MIT — `ce-ideate`, `ce-brainstorm`, `ce-plan`, `ce-work`, `ce-debug`, `ce-review`, `ce-demo-reel`, `git-commit-push-pr`, `ce-compound`
- **gstack** — Garry Tan, MIT — `office-hours`, `plan-ceo-review`, `plan-eng-review`, `plan-devex-review`, `autoplan`, `review`, `cso`, `document-generate`, `retro` (pure-markdown skills only; gstack's daemon-bound skills are excluded)
- **frontend-design** — Apache-2.0 (NOTICE retained)
- **emilkowalski/skills** — Emil Kowalski, MIT — `emil-design-eng`, `review-animations`
- **marketing-skills** — Corey Haines, MIT — `product-marketing`, `marketing-ideas`, `copywriting`, `cro`, `pricing`, `launch`, `content-strategy`, `social`
- **claude-seo** — AgricIDaniel, MIT — `seo` (router over its ~7-skill indie subset)
- **`handoff`** — standalone skill, **NOT bundled** (no upstream LICENSE found); the FLOW routes to your INSTALLED `handoff`. Pin its license/ownership before redistributing ultra-powers wider.

Routing (this FLOW.md) by Flowy, CC-BY-SA-4.0.
