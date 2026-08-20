import Testing
import Foundation
@testable import MealTracker

struct DayGreetingTests {
    private func date(hour: Int, minute: Int = 0) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())!
    }

    @Test func morningRunsUntilNoon() {
        #expect(DayGreeting.text(at: date(hour: 0), name: nil) == "Good morning")
        #expect(DayGreeting.text(at: date(hour: 11, minute: 59), name: nil) == "Good morning")
    }

    @Test func afternoonStartsAtNoonAndRunsUntilSix() {
        #expect(DayGreeting.text(at: date(hour: 12), name: nil) == "Good afternoon")
        #expect(DayGreeting.text(at: date(hour: 17, minute: 59), name: nil) == "Good afternoon")
    }

    @Test func eveningCoversTheRestOfTheDay() {
        #expect(DayGreeting.text(at: date(hour: 18), name: nil) == "Good evening")
        #expect(DayGreeting.text(at: date(hour: 23), name: nil) == "Good evening")
    }

    @Test func usesOnlyTheFirstNameWhenOneIsKnown() {
        #expect(DayGreeting.text(at: date(hour: 9), name: "Mark Watts") == "Good morning, Mark")
    }

    /// A local-only account has no name, and a blank one from the sign-in provider shouldn't
    /// produce a dangling comma.
    @Test func fallsBackToThePlainGreetingWithoutAUsableName() {
        #expect(DayGreeting.text(at: date(hour: 9), name: nil) == "Good morning")
        #expect(DayGreeting.text(at: date(hour: 9), name: "") == "Good morning")
        #expect(DayGreeting.text(at: date(hour: 9), name: "   ") == "Good morning")
    }
}
