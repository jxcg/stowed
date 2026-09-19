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

### Decisions taken 2026-09-18 (third round, after v0.1.0 shipped)

The owner walked through the journey and rewrote it. These supersede earlier decisions
where they conflict.

12. **There is no outbound check.** Adding an item to a bag means it is packed. No ticking
    before departure, no Finish. The bag list *is* the outbound record. Supersedes decisions
    2, 6, 7 and 8 as far as outbound is concerned.
13. **Nothing locks.** Every list stays editable for the life of the trip. "I could find
    something later on" beats "frozen history". Supersedes decision 6.
14. **Quantity and note on an item.** "T-shirt" with quantity 8 and a note like "1x white,
    3x black, 4x silver". Supersedes decision 3. The stepper on the row is how quantity is
    edited.
15. **Return is a flag per item, not a second list.** Each item carries `returning`
    (default true). Starting the return check offers **Re-import everything I packed**
    (leaves every flag on) or **Start fresh** (turns every flag off, for "everything got
    lost or replaced"). Items added after the return started are returning by default.
    "Not returning" turns the flag off and greys the tile. The return check expects flagged
    items only. Supersedes the mechanics of decisions 4 and 5; the meaning is unchanged.
16. **Partial return edits the number.** Only 2 of 3 T-shirts came home: set the return
    quantity to 2 on the return screen and tick it. `returnQuantity` is nil until edited, so
    the bag list still shows what was packed.
17. **Screens.** Bag screen is rows: emoji, name, note caption, stepper on the trailing edge,
    quick-add row at the bottom. Return screen is an emoji tile grid: tap ticks, long press
    for not-returning and quantity. `DESIGN.md` still owns the visual language.
18. **Trips page is a vertical stack of cards.** Chosen 2026-09-18 from three layouts built
    behind a switch (carousel, hero + list, card stack); the other two and the switch are
    deleted.
19. **Schema changes must migrate in place.** Every new non-optional attribute carries a
    default value so SwiftData's lightweight migration can fill existing rows. A test guards
    this. Learned the hard way on 2026-09-18: `Item.note` without a default made the store
    fail to load on top of a v0.1.0 store, and the app ran with no store at all, silently
    dropping every insert. Versioned schemas start at the first TestFlight build.

20. **Trip cards look like playing cards.** Thin foil frame, one deep colour for the face
    falling to a darker edge, film grain heaviest in the middle, a faint lattice, a double
    hairline rule, a small-caps footer with the dates; the trip's initial and suit in two
    corners, the bottom one rotated; the initial again as a faint monogram in the centre. No
    emoji on the card: they clash with its formality and live on the bag screens instead. New
    York serif throughout.
21. **Card colour and suit are random from a curated set, stored on the trip.** Ten named
    palettes (oxblood, navy, forest, plum, slate, rust, teal, charcoal, ochre, bordeaux), each
    a single hue for the face. The frame is the only second colour: a tint of the same hue, or
    gold foil for the jewel palettes. One of four suits. Both picked at creation and kept;
    user-chosen palettes come later.
22. **Trips page has two views, Stack and Deck**, switched from a menu on the page and
    remembered. Stack is the vertical scroll of cards with a gap. Deck is a pile: the top trip
    in full, up to four more behind it at a slight angle, a deeper shadow the more trips there
    are, swipe the top card away to bring the next forward. Never more than five drawn.
23. **Motion effect, off by default.** A toggle in the trips page menu. When on, the phone's
    tilt moves the card's sheen and shimmer and adds a holographic spectrum band that sweeps
    with it. Reads the motion sensors only while the trips page is showing. Off whenever the
    system Reduce Motion setting is on.
24. **Card textures, random from a curated set, stored on the trip.** Three procedural
    textures drawn from the trip's own initial, dates and name, seeded so a card never
    changes: a scatter of the initial and date digits, the initial tiled on a diagonal
    lattice, and a passport-stamp ring of name, dates and STOWED around the inner border. All
    sit under the grain and the holographic band.
25. **New-trip presets.** Chips above the name field: your previous trip names first, then a
    short curated list of cities, deduplicated and capped at eight. Tapping one fills the name
    only; typing still works. No network, no place search.
26. **Visual bag view.** A bag screen toggle between the list and a drawn bag: the trip's
    palette, grain and texture in a suitcase shape with a handle and latches, items as emoji
    inside. Same data, no new model fields. During the return check, tapping an item ticks it;
    confirmed is told apart by opacity, a tick glyph, sitting upright rather than tilted, and a
    ring, so colour is never the only signal.
27. **Trips are ordered most recent first** in both views: the newest trip is the top card of
    the deck and the first card of the stack, the oldest is at the bottom. The deck draws the
    pack imperfectly, each card behind the top one offset and angled by an amount fixed to that
    trip, with its own shadow, and a pile shadow that deepens with the number of trips. Swiping
    either way takes the top card off and reveals the next.
28. **There is one card.** The playing card is gone; what is left is metal and light: a muted
    ground carrying splashes, a prismatic seam across it, brushed metal over the lot, the
    trip's mark punched out of metal dots, the place in SF Extended, stats under wide labels,
    the dates along the bottom, and a 4pt rim running into the neighbouring hue.
29. **Wallet and fan are under comparison.** Two collapsed takes on holding four trips with
    the rest behind an ellipsis that opens a swipeable spread. One gets deleted once chosen.
30. **One base for every card, two modes**: pale blue into lavender by day, deep indigo by
    night. The colours are muted rather than fluorescent, so they age. Three accents only:
    cyan, violet, magenta. The ground carries the same two splash colours on every card, thrown
    across it differently each time and fixed to the trip, the place's letter tiled small, and
    grain over the lot.
31. **Under the light, the neon card fluoresces and catches a rainbow.** With the motion effect on, tilting the
    phone brings up security printing the way ultraviolet does on a banknote: fibres through
    the stock, a dashed thread down one side, and the trip's letter watermarked across the
    middle, plus a slick of spectrum sweeping across like a holographic patch. It all fades
    back to nothing when the phone is held still. The playing card gets the spectrum band only.
32. **Cards have a back.** Two buttons sit in the corner of every card, above the turn so they
    never flip with it. Quick view turns the card over to everything packed, grouped by bag and
    scrollable, with the return ticks where a return has started. Edit opens the trip. Tapping
    the card itself still opens the trip. The back is quiet brushed metal with a
    single faint prismatic seam across it, after the Siri icon in iOS 27. It stays a background:
    a scrim sits over it so the writing leads.

On-device only. One user, local persistence, no account, no network.

---

## 3. Design

### 3.1 Why the return record lives on the item now

With the outbound check gone (decision 12) there is exactly one verification pass. A single
nullable date per pass on the item, `returnConfirmedAt`, is the record: present means
verified, absent means not yet verified. Nothing can drift into meaning "missing". An arrival
check later is one more nullable date, not a redesign.

### 3.2 Model

Persistence is **SwiftData**, no third-party dependencies.

```
Trip   name, startDate?, endDate?, createdAt, returnStartedAt?      → bags
Bag    name, emoji                                                  → items   (belongs to Trip)
Item   name, emoji, quantity, note, addedAt,
       returning, returnQuantity?, returnConfirmedAt?                        (belongs to Bag)
```

`returnStartedAt` says whether the return check has begun. `returning`, `returnQuantity`
and `returnConfirmedAt` carry decisions 15 and 16. Cascade deletes run from `Trip` downward.
Dates are stored as absolute time (UTC) and formatted only for display.

### 3.3 What the return check expects

Items where `returning == true`. Progress = flagged items with `returnConfirmedAt` set, over
flagged items. Computed live, never stored. Complete when every flagged item is ticked and
there is at least one. Removing an item never breaks completion: it leaves numerator and
denominator together.

### 3.4 Screens

Trips page (three layouts, decision 18) → trip: bags plus a Return section → bag: rows with
stepper and note → return check: tile grid, start with re-import or fresh → search across
the trip that returns the containing bag.

The visual suitcase/bag view is confirmed scope but remains **blocked on `DESIGN.md`**.

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
- Accounts, syncing, sharing, offline requirements, monetisation.
- The precise first-release scope.
- Real bundle identifier (currently the `devplaceholder.…` template value).
- The real minimum-OS floor at public release. iOS 27 is confirmed and correct for now;
  note that it excludes most devices currently in the field.

---

## 6. Repository state

Updated 2026-09-18 after round 2.

Repo `jxcg/stowed`, branch `main`. `v0.1.0` tags the first walkable version (§8 rows
0–8). Round 2 (decisions 12–19) is merged on top of it.

Present: `README.md`, `.gitignore`, `stowedTests` (Swift Testing, 15 tests), shared
`stowed` scheme, Swift 6 language mode, iPhone-only platforms, CI running the tests on every
PR (`.github/workflows/test.yml`).

Not yet present: `DESIGN.md` (owner action, #10), SwiftLint, crash reporting, versioned
schema migrations (start at the first TestFlight build, decision 19), a real bundle
identifier.

Toolchain: Xcode 27.0, iOS 27.0 SDK, iPhone 17 simulator on iOS 27 (the iOS 26.5 one will
not install the app), `gh` authenticated.

---

## 7. Verification approach

Unit tests using **Swift Testing** on an in-memory container. The logic worth testing is the
return semantics:

- ticking an item sets `returnConfirmedAt`; unticking clears it; no lock ever refuses it;
- start fresh → every existing item is not returning, return expects nothing;
- re-import → return expects everything;
- an item added after return start is expected;
- "not returning" → excluded, still present in its bag with its packed quantity;
- editing the return quantity leaves `quantity` untouched;
- removing a ticked item from a complete return keeps it complete;
- search returns the containing bag; deleting a bag or trip cascades.

Unhappy paths: empty trip, bag with no items, item deleted mid-check, quantity never below 1.

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

Items 0–8 shipped as **v0.1.0** on 2026-09-18.

Round 2 (decisions 12–19), each its own issue, each branched from `main`:

| # | Work |
|---|------|
| 10 | Model v2: drop checkpoints and confirmations, add quantity, note, returning, return fields, tests |
| 11 | Bag screen: rows with stepper and note, edit sheet |
| 12 | Return flow: start (re-import or fresh), tile check screen, not returning, quantity edit, completion |
| 13 | Trips page: three layouts behind a runtime switch |
| 14 | Delete the two losing layouts once the owner picks |
