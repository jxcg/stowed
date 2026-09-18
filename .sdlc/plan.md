---
tracker: github
github_repo: jxcg/stowed
key: STW
---

# Stowed — plan (2026-09-18)

Source of truth for behaviour is `SPEC.md`. This plan only says how we get through it.
**No Jira.** Tickets are GitHub issues on `jxcg/stowed`; `STW-n` means issue `#n`.

## Goal

Ship the first walkable journey of Stowed on the iPhone 17 simulator: create a trip, add
bags and emoji items, run and close an outbound check, find an item during the trip, mark
things "not returning", run and close a return check. List views only; the visual
suitcase view waits for `DESIGN.md`.

## Context / constraints

- Tier: **Real** (public release holding user data). Crash reporting, logging, staging,
  CI deploys deferred to a later Hardening/Release stage, not built now.
- iOS 27, iPhone only, SwiftUI + SwiftData, Swift 6 language mode, no third-party deps.
- Tests: Swift Testing, in a new test target. The checkpoint semantics in SPEC §3.3 and
  §7 are the logic that gets tests. UI gets a manual walkthrough on the simulator.
- Confirmation is its own record; absence = unverified. `closedAt` / `notReturningAt`
  carry the two key rules. Progress is computed, never stored.
- Repo hygiene lands before feature work (SPEC §6).
- Nothing in SPEC §5 OPEN gets decided silently.

## Approach

Bottom-up, in SPEC §8 order: hygiene → model + tests → screens in journey order.
Model first because every screen reads the same expected-set rule; test it once and the
UI tickets stay thin. Expected-set logic lives in one method on `Checkpoint`, not in views.

## Workflow (agreed 2026-09-18)

- One issue in flight at a time.
- Branch per issue, named `stw-<n>-<slug>`, cut from `main`.
- Moving to Review = PR opened with `gh`, referencing `Closes #n`. Joshua merges on GitHub.
- Column moves are issue comments: what was done, what was verified, what to check.
- Commits only when asked.

## Epics (already registered as issues, grouped by label)

1. **Foundation** (`foundation`) — #1 spec + README, #2 hygiene, #3 model + tests.
2. **First journey** (`enhancement`) — #4 trips, #5 bags, #6 items, #7 outbound check,
   #8 search, #9 return check. Done = full journey walkable on the simulator.
3. **Visual bag view** (`blocked`) — #11, blocked on #10 (`DESIGN.md`, owner action).

## Decisions from planning Q&A (2026-09-18)

Recorded in SPEC.md as decisions 5–11. Summary: not-returning affects return only; finish
is one tap + confirm, any progress, no reopen; both checkpoints exist from trip creation;
un-tick while open only; emoji guessed from name with tap-to-override; not-returning is a
reversible swipe and shows greyscale; rename + move-between-bags in scope, reorder out.

## Defaults I am taking unless told otherwise

- `xcuserstate` gets untracked in #1's PR (one line), not left for #2.
- Search: case-insensitive substring on item name, within the current trip only.
- Delete: swipe. Confirmation sheet for trip and bag (cascade), none for a single item.
- Empty expected set shows "no items" rather than 0/0 complete.
- No SwiftUI previews until the design pass; accessibility labels on any custom control.
- Trip list sorted by createdAt, newest first.

## Round 2 (2026-09-18): the owner's rewrite

v0.1.0 is the stable PoC. Round 2 is SPEC decisions 12–19: no outbound check, no locks,
quantity + note, return as a flag per item, tile return screen, three trips-page layouts
behind a switch. Five tickets, each branched from `main`, **no stacking**:

1. Model v2 + tests (deletes Checkpoint and Confirmation, clean schema break).
2. Bag screen rows with stepper and note.
3. Return flow: start, tile grid, not returning, quantity edit, completion seal.
4. Trips page: carousel, hero + list, card stack behind a Layout menu.
5. Delete the two losing layouts.

## Open questions

- Everything in SPEC §5 stays open.
