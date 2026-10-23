import Foundation
import Testing
@testable import stowed

@Suite struct DeckDotTrackTests {
    @Test func tapsMatchCenteredDots() {
        let track = DeckDotTrack(count: 2, visible: 0..<2, width: 360)
        #expect(track.index(at: 172.5) == 0)
        #expect(track.index(at: 187.5) == 1)
        // Touching without moving stays on the dot you touched.
        #expect(track.position(from: 1, translation: 0) == 1)
    }

    @Test func tapsUseVisibleWindow() {
        let track = DeckDotTrack(count: 20, visible: 7..<16, width: 360)
        #expect(track.index(at: 120) == 7)
        #expect(track.index(at: 180) == 11)
        #expect(track.index(at: 240) == 15)
        #expect(track.index(at: 0) == 7)
        #expect(track.index(at: 360) == 15)
    }

    // The drag is measured from the dot it started on, in whole pitches, clamped to the deck.
    @Test func dragIsMeasuredFromItsStartDot() {
        let track = DeckDotTrack(count: 20, visible: 2..<11, width: 360)
        #expect(track.position(from: 4, translation: 30) == 6)
        #expect(track.position(from: 4, translation: 7.5) == 4.5)
        #expect(track.position(from: 4, translation: -500) == 0)
        #expect(track.position(from: 4, translation: 500) == 19)
    }

    // A small pack draws every card, top first, wrapping round.
    @Test func smallPackDrawsEveryCard() {
        #expect(deckDrawOrder(count: 3, top: 1, limit: 5) == [1, 2, 0])
        #expect(deckDrawOrder(count: 1, top: 7, limit: 5) == [0])
        #expect(deckDrawOrder(count: 0, top: 0, limit: 5) == [])
    }

    // A big pack draws the next four, then the card that went under last at the bottom.
    @Test func bigPackShowsTheCardThatWentUnderLast() {
        #expect(deckDrawOrder(count: 8, top: 0, limit: 5) == [0, 1, 2, 3, 7])
        #expect(deckDrawOrder(count: 8, top: 3, limit: 5) == [3, 4, 5, 6, 2])
        #expect(deckDrawOrder(count: 8, top: 11, limit: 5) == [3, 4, 5, 6, 2])
    }
}
