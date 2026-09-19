# How Stowed is put together

A guide to the code. `SPEC.md` says what the app must do and `DESIGN.md` says how it should
look; this file says where each job lives.

## The shape of it

One SwiftUI app, one SwiftData store, no third-party dependencies. Screens read the model
directly. There is no view-model layer and no repository protocol, because there is one
implementation of everything and a layer with one caller is just indirection.

## The model — `Models.swift`

Three types. `Trip` has bags; `Bag` has items; `Item` is one thing you packed. Deleting a
trip cascades all the way down.

The rule worth knowing: **there is no outbound check.** Putting an item in a bag *is*
packing it. The only verification pass is the return, and it lives on the item as three
fields: `returning` (is it meant to come home), `returnQuantity` (how many of it are), and
`returnConfirmedAt` (have you seen it). A missing `returnConfirmedAt` means "not looked at
yet", never "lost" — that distinction is why it is a date and not a boolean.

`Trip.startReturn(reimport:)` begins the check. Re-import expects everything you packed;
start fresh expects nothing until you say otherwise. Progress is computed on every read and
never stored, so it cannot go stale.

Every attribute added after v0.1.0 carries a default. Without one, SwiftData cannot migrate
an existing store, the store silently fails to load, and the app runs with no storage at
all. A test in `ReturnTests.swift` fails if a new mandatory attribute forgets its default.

## Screens

| File | Job |
|---|---|
| `StowedApp.swift` | Entry point. Attaches the SwiftData container. |
| `ContentView.swift` | The trips screen: which layout is showing, create, delete, the toolbar menu. |
| `TripDetailView.swift` | One trip: its bags, search, and the return check section. |
| `BagDetailView.swift` | One bag as a list: rows with a quantity stepper, notes, quick add. |
| `BagVisualView.swift` | The same bag drawn as a packed suitcase. Tapping ticks items during a return. |
| `ReturnView.swift` | The return check across every bag in a trip, as tiles. |

## Trip layouts

The trips screen can draw its cards four ways, chosen from the toolbar menu and remembered.

| File | Job |
|---|---|
| `ContentView.swift` | `stack`: a plain vertical scroll of cards. |
| `DeckView.swift` | `deck`: a pack of cards, most recent on top, swipe either way for the next. |
| `WalletView.swift` | `wallet` and `fan`: four trips held, the rest behind an ellipsis that opens a swipeable spread. |

`wallet` and `fan` are two takes on the same idea, both live so they can be compared.
One of them gets deleted once the choice is made.

## The card

| File | Job |
|---|---|
| `TripCard.swift` | Draws one trip as a playing card, and holds the film grain tile. |
| `CardPalette.swift` | The ten colours and four suits a card can be, and how its frame is tinted. |
| `CardTexture.swift` | The three textures, drawn with `Canvas` from the trip's own letters and dates. Also holds `SeededRandom`. |
| `MotionReader.swift` | The phone's tilt, when the motion effect is switched on. Nothing in the simulator. |

A card's look is **decided once and stored on the trip**: palette, suit and texture are
random at creation, then fixed forever. That is why two trips never look alike and why a
card never changes under you. `Trip.textureSeed` turns the trip's name and creation time
into a number, which `SeededRandom` expands into the scattered glyphs and the angles the
cards lie at in the deck. Same trip, same pile, every launch.

## Small pieces

| File | Job |
|---|---|
| `EmojiGuess.swift` | Guesses an emoji from an item's name, and the one-character emoji field. |
| `TripPresets.swift` | The chips above the name field when creating a trip. |

## Tests — `stowedTests/`

`ReturnTests.swift` covers the return semantics, the cascades, the unhappy paths and the
migration-defaults rule. `EmojiGuessTests.swift` and the presets test cover the two bits of
string logic. There are no UI tests; screens are checked by hand and by eye.

CI runs the whole suite on an iPhone 17 simulator for every pull request.

## Deleting a variant

Several things are deliberately built twice so they can be compared, and the losing half is
meant to be deleted by hand. Each one is self-contained, so removing it is a good first
exercise in the codebase. Nothing else depends on them.

| To drop | Delete | Then fix |
|---|---|---|
| The **fan** trips view | nothing (it shares `WalletView.swift`) | remove `case fan` from `TripsView` and the `.fan` branch in `ContentView`, then the `Layout` enum in `WalletView` |
| The **wallet** trips view | `WalletView.swift` | remove `case wallet` and its branch, same two places |
| The **stack** trips view | the `stack` property in `ContentView` | remove `case stack` and its branch |
| The **deck** trips view | `DeckView.swift` | remove `case deck` and its branch |
| The **neon** card | `NeonCard.swift`, and `neonHue` in `CardPalette.swift` | remove `case neon` from `CardStyle` and its branch in `ContentView` |
| The **playing card** | `TripCard.swift`, and `frameGradient`/`stock` in `CardPalette.swift` | remove `case playing` and its branch |

If an enum ends up with one case left, delete the enum and its `@AppStorage` line too, and
call the surviving view directly. The compiler will point at every place that needs it.

## Known overlap

`ReturnView`'s tile and `BagVisualView`'s packed item draw similar things for different
screens. They were left separate because the interactions differ; merge them if a third one
shows up.
