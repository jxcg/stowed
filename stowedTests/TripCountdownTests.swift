import Foundation
import Testing
@testable import stowed

// The countdown line on the open-book Trips page (#117).
@Suite struct TripCountdown {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func day(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour))!
    }

    // A trip from the 10th to the 16th: seven days.
    private func line(on today: Date) -> String {
        Trip(name: "Lisbon", startDate: day(10), endDate: day(16)).countdown(on: today, calendar: calendar)
    }

    @Test func everyLine() {
        #expect(Trip(name: "Someday").countdown(on: day(1), calendar: calendar) == "NO DATES")
        #expect(line(on: day(1)) == "IN 9 DAYS")
        #expect(line(on: day(9)) == "TOMORROW")
        #expect(line(on: day(10)) == "DAY 1 OF 7")
        #expect(line(on: day(12)) == "DAY 3 OF 7")
        #expect(line(on: day(16)) == "DAY 7 OF 7")
        #expect(line(on: day(17)) == "HOME YESTERDAY")
        #expect(line(on: day(20)) == "HOME 4 DAYS AGO")
    }

    // Days are calendar days, not 24-hour blocks: late on the 9th is still the day before.
    @Test func countsCalendarDaysNotHours() {
        #expect(line(on: day(9, hour: 23)) == "TOMORROW")
        #expect(line(on: day(10, hour: 1)) == "DAY 1 OF 7")
    }

    @Test func startWithoutEndIsOneDay() {
        let trip = Trip(name: "Day out", startDate: day(10))
        #expect(trip.countdown(on: day(10), calendar: calendar) == "DAY 1 OF 1")
        #expect(trip.countdown(on: day(11), calendar: calendar) == "HOME YESTERDAY")
    }
}
