import Testing
@testable import stowed

@Suite struct TripPresetsTests {
    @Test func previousFirstDedupedAndCapped() {
        let result = TripPresets.suggestions(previous: ["Kyoto", "kyoto", " Lisbon ", ""], cities: ["London", "Lisbon", "Paris"], limit: 4)
        #expect(result == ["Kyoto", "Lisbon", "London", "Paris"])
    }
}
