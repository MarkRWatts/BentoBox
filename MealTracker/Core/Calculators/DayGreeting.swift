import Foundation

/// The greeting above the date on the Today tab's heading. Pure and injectable so the wording
/// and its cut-off hours are testable without waiting for the clock.
enum DayGreeting {
    static func text(at date: Date, name: String?, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: date)
        let greeting: String
        switch hour {
        case ..<12: greeting = "Good morning"
        case ..<18: greeting = "Good afternoon"
        default: greeting = "Good evening"
        }
        // Only the first name — a full "Good evening, Mark Watts" reads like a form letter. A
        // local-only account has no name at all, which is why this stays optional rather than
        // falling back to something invented.
        guard let firstName = name?.split(separator: " ").first.map(String.init),
              !firstName.isEmpty else {
            return greeting
        }
        return "\(greeting), \(firstName)"
    }
}
