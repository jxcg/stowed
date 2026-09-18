# Stowed — Specification

**Status:** initial specification, agreed 2026-09-18.
**Owner:** Joshua (owns functionality, scope, acceptance).
**This document is the source of truth for approved behaviour.** Later decisions amend this
file rather than living in conversation history. Sections are split into CONFIRMED (owner
has approved), PROPOSED (engineering suggestion, not yet approved), and OPEN (deliberately
undecided). Do not silently promote anything between them.

---

## 1. What Stowed is

An iPhone app for packing a trip and getting everything home again.

You create a trip, add bags, add items to those bags, and confirm they are packed. During
the trip you can find an item and see which bag holds it. At the end you run a **return
check** against the same inventory — no rebuilding a list — and see that everything expected
for the return has been accounted for.

The core value: remembering what you packed, finding it, and bringing it home.

**The recheck asserts:** *"Verify that I still have the belongings I originally packed and
am bringing them back."*

---

## 2. CONFIRMED requirements

### Product

- App name: **Stowed**.
- Minimum supported OS: **iOS 27**. Primary device: **iPhone**.
- Multiple bags or suitcases per trip.
- Users can determine what they packed and which bag contains it.
- One inventory, reused for both outbound and return verification.
- Items can be added and removed during the trip.
- Both a **list view** and a **visual suitcase/bag view** of the same information.
- System emoji alongside user-written item descriptions.
- Fun, clean, predominantly visual interface with fast performance.
- Visual design guidance lives in `DESIGN.md`.

### Verification semantics

- **Confirmations are separate per checkpoint.** Confirming an item before departure must
  not confirm it for the return.
- **Unchecked means "not yet verified", never "missing."**
- The inventory persists for the whole trip and is reused by each check.

### Decisions taken 2026-09-18

1. **Arrival check is deferred.** The first version ships outbound and return only. An
   arrival check was requested as a possibility and remains a candidate for later.
2. **A finished check closes and stays closed.** Items added afterwards join the *next*
   check. Items added while a check is still running join *that* check.
   - Pack and tick all 10 → outbound 10/10, done. Buy a souvenir in Lisbon and add it →
     outbound stays 10/10; the return check expects 11.
   - Mid-pack at 8/10, remember the charger and add it → outbound becomes 8/11.
3. **No quantities in the first version.** One row per item.
4. **Explicit "not returning" state** for items that are consumed, used up, or deliberately
   left behind. This is a mark, not a deletion: the item keeps its outbound history and drops
   out of the return check's expectations. Nothing re-prompts and nothing recalculates.

### Decisions taken 2026-09-18 (second round, planning Q&A)

5. **"Not returning" affects the return check only.** Outbound never looks at the mark:
   you still have to pack it. Open return excludes marked items. Closed return excludes
   items marked *before* it closed. (Closes the gap where a used-up sunscreen, marked before
   the return check closed, would reappear in the frozen count as 10/11.)
6. **Finish is one tap plus a confirmation sheet, allowed at any progress.** Unchecked is
   unverified, not missing, so closing at 8/11 is legitimate. **No reopen.** Reopening was
   considered and rejected as too much ceremony; forgot something → add it and it joins the
   return check; packed something you didn't → delete it or mark it not returning.
7. **Both checkpoints exist from trip creation, open, with no enforced ordering.** There is
   no "start check" step. `startedAt` is dropped from the model as a consequence.
8. **A tick can be un-ticked while the check is open.** After close, ticks are read-only.
9. **Emoji is guessed from the name** via a small built-in English word list, with a tap on
   the emoji to override from the keyboard. Fallback when nothing matches: 🧳 for a bag,
   📦 for an item. (Partially resolves the OPEN "exact item-entry method": entry is a name
   field; the emoji takes no extra effort.)
10. **"Not returning" is reversible**, set and cleared by a swipe action on the item. A marked
    item shows its emoji in greyscale.
11. **In scope for v1 beyond the brief:** rename bags and items; move an item to another bag
    (confirmations travel with it). **Out:** manual reordering; trip dates shown on the list
    (list sorts by creation, newest first).

### Data scope (first version)

On-device only. One user, local persistence, no account, no network.

---

## 3. Design

### 3.1 Why check state cannot live on the item

Two confirmed rules together — "outbound must not auto-confirm return" and "unchecked ≠
missing" — rule out an `isPacked: Bool` on an item. A single boolean cannot hold two
independent verification passes, and `false` would conflate *not yet looked at* with *known
gone*.

So a **confirmation is its own record**, keyed by (item, checkpoint), and **the absence of a
record is the unverified state**. There is no stored value that could drift into meaning
"missing".

### 3.2 Model

Persistence is **SwiftData** — native to the platform, no third-party dependencies, and
upgradable to CloudKit sync later by configuration rather than rewrite.

```
Trip          name, startDate?, endDate?, createdAt   → bags, checkpoints
Bag           name, emoji                             → items           (belongs to Trip)
Item          name, emoji, addedAt, notReturningAt?   → confirmations   (belongs to Bag)
Checkpoint    kind (.outbound | .return), closedAt?             (belongs to Trip)
Confirmation  confirmedAt                             (item × checkpoint)
```

Two nullable dates — `Checkpoint.closedAt` and `Item.notReturningAt` — carry decisions 2, 4 and
5. No extra entity and no snapshot table are required.

### 3.3 Which items a checkpoint expects

Base set, both kinds:

- **Closed** (`closedAt != nil`) — items where `addedAt <= closedAt`. History is frozen: a
  souvenir added later is excluded.
- **Open** (`closedAt == nil`) — all current items.

Then, **for `.return` only** (decision 5), remove items marked not-returning: while open,
any marked item; once closed, items where `notReturningAt <= closedAt`. Marking something
after a check closed never rewrites what already happened. Outbound ignores the mark.

**Progress** = confirmations whose item is still in the expected set, over the expected count.
It is computed live and never stored, so it cannot go stale.

**Removing an item can never reopen a check.** It leaves the numerator and denominator
together: 10/10 becomes 9/9 (still complete), and 9/10 becomes 9/9 (now complete). This is
arithmetic, not a policy choice.

Adding the arrival checkpoint later is a new enum case, not a behavioural migration.

Cascade deletes run from `Trip` downward. Dates are stored as absolute time (UTC) and
formatted only for display.

### 3.4 Screens for the first journey

Trip list → trip detail (bags, per-checkpoint progress) → bag detail (items) → check flow
(outbound / return, with an explicit **finish** action that sets `closedAt`) → search across
the trip that returns the containing bag.

The visual suitcase/bag view is confirmed scope but is **blocked on `DESIGN.md`**, which does
not yet exist. The first version ships the list view so the journey is walkable end to end;
the visual view follows once design guidance exists.

---

## 4. PROPOSED (engineering, not yet owner-approved)

- **Project tier: Real**, per the owner's standing engineering instructions — this is built
  toward public release holding users' trip data. Real-tier infrastructure (crash reporting,
  persistent logging, staging environment, CI-driven deploys) is deferred to the Hardening and
  Release stages rather than built now.
- **No repository/persistence protocol.** It would be an interface with a single
  implementation, and the iCloud upgrade path is configuration, not a rewrite.
- Schema changes go through SwiftData's versioned migrations, never hand-edited stores.
- Manually creating the first trip's inventory is the first-version approach. This is a
  starting point, not an approved restriction on how inventories may be created.

---

## 5. OPEN — deliberately undecided

Not needed for the first version, and **not** to be chosen silently:

- Arrival check (requested as a possibility; deferred, not rejected).
- Copying previous trips, reusable templates, an item catalogue.
- The exact item-entry method beyond v1's name field + guessed emoji (decision 9).
- Quantities (excluded from v1; the question of how partial recovery would be expressed
  remains open).
- Accounts, syncing, sharing, offline requirements, monetisation.
- The precise first-release scope.
- Real bundle identifier (currently the `devplaceholder.…` template value).
- The real minimum-OS floor at public release. iOS 27 is confirmed and correct for now;
  note that it excludes most devices currently in the field.

---

## 6. Repository state at time of writing

Repo `jxcg/stowed`, branch `main`, one commit, stock SwiftUI template
(`ContentView.swift` renders `Text("Hello, world!")`).

Toolchain available: Xcode 27.0, iOS 27.0 SDK, iPhone 17 / 17 Pro / 17e / Air / 18 Pro
simulators, `gh` authenticated.

Not yet present: `DESIGN.md`, `README.md`, `.gitignore`, a test target, SwiftLint, CI.

Known issues to address before feature work:

- `UserInterfaceState.xcuserstate` is tracked in git and should be ignored and untracked.
- `TARGETED_DEVICE_FAMILY = "1,2,7"` and `SUPPORTED_PLATFORMS` include macOS and visionOS;
  the brief specifies iPhone.
- `SWIFT_VERSION = 5.0` under Xcode 27 — move to Swift 6 language mode while there is no
  code to migrate.
- `MyApp.swift` should be renamed `StowedApp.swift`.

---

## 7. Verification approach

Unit tests using **Swift Testing**, in a test target that does not yet exist. The logic worth
testing is the checkpoint semantics, because that is where the confirmed rules are easy to
break:

- confirming an item outbound leaves its return state unverified;
- closing outbound, then adding an item → outbound count unchanged, item expected by return;
- adding an item while outbound is still open → it joins outbound;
- marking "not returning" → excluded from the open return check, still present in the closed
  outbound check and in an open outbound check;
- marking "not returning", then closing return → still excluded from the closed return;
  marking after return closed → still included (frozen);
- un-tick while open removes the confirmation; un-tick after close is refused;
- moving an item to another bag keeps its confirmations;
- removing a confirmed item from a closed, complete check → it stays complete;
- search returns the containing bag; cascade delete removes orphaned confirmations.

Unhappy paths: empty trip, bag with no items, item deleted mid-check.

Then build and run on the iPhone 17 simulator and walk the full journey by hand.

---

## 8. Proposed execution order

Not started. One item at a time, each tracked as its own issue.

| # | Work | Notes |
|---|------|-------|
| 0 | This `SPEC.md` + a `README.md` pointing at it | Done when committed |
| 1 | Hygiene: `.gitignore`, untrack `xcuserstate`, test target, iPhone-only platforms, Swift 6, rename `MyApp.swift` | No behaviour |
| 2 | SwiftData model + the tests in §7 | No UI |
| 3 | Trip list and creation | |
| 4 | Bags within a trip | |
| 5 | Items with emoji | |
| 6 | Outbound check flow, including finish/close | |
| 7 | Search / locate an item | |
| 8 | Return check, "not returning" marking, completion state | Completes the first journey |
| 9 | Visual suitcase/bag view | **Blocked on `DESIGN.md`** |

Items 0–8 constitute the first working version.
