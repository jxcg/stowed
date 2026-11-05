import Testing
@testable import stowed

@Suite struct TripPresetsTests {
    @Test func previousFirstDedupedAndCapped() {
        let result = TripPresets.suggestions(previous: ["Kyoto", "kyoto", " Lisbon ", ""], cities: ["London", "Lisbon", "Paris"], limit: 4)
        #expect(result == ["Kyoto", "Lisbon", "London", "Paris"])
        #expect(TripPresets.suggestions(previous: ["Kyoto"], cities: ["Rome"], limit: 0).isEmpty)
        // Blank and duplicate names must not consume the limit; preserve the first spelling.
        #expect(TripPresets.suggestions(previous: [" ", " KYOTO ", "kyoto"], cities: ["Kyoto", "東京", "東京"], limit: 2) == ["KYOTO", "東京"])
        #expect(TripPresets.suggestions(previous: [" "], cities: [], limit: 8).isEmpty)
    }
}
