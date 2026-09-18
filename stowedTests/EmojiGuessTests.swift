import Testing
@testable import stowed

@Suite struct EmojiGuessTests {
    @Test func longestKeywordWinsAndFallbackApplies() {
        #expect(EmojiGuess.guess(for: "Big Suitcase", fallback: "x") == "🧳")
        #expect(EmojiGuess.guess(for: "Camera bag", fallback: "x") == "📷")
        #expect(EmojiGuess.guess(for: "Thing", fallback: "x") == "x")
    }
}
