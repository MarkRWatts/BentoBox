import SwiftUI
import SwiftData

struct CalorieCyclingEditorView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    private let weekdaySymbols = Calendar.current.weekdaySymbols

    private var baseline: Double {
        TDEECalculator.dailyCalorieTarget(for: profile)
    }

    private var overridesByWeekday: [Int: Double] {
        Dictionary(uniqueKeysWithValues: profile.calorieDayOverrides.map { ($0.weekday, $0.extraCalories) })
    }

    var body: some View {
        List {
            Section {
                Toggle("Enable Calorie Cycling", isOn: $profile.isCalorieCyclingEnabled)
            } footer: {
                Text("Set higher-calorie days, like Friday and Saturday — the other days automatically adjust down so your weekly total, and macros, stay the same.")
            }

            if profile.isCalorieCyclingEnabled {
                Section {
                    ForEach(1...7, id: \.self) { weekday in
                        dayRow(weekday: weekday)
                    }
                } header: {
                    Text("Daily Targets")
                } footer: {
                    let weeklyTotal = CalorieCyclingCalculator.weeklyTotal(baseline: baseline, overrides: overridesByWeekday)
                    Text("Weekly total: \(Int(weeklyTotal)) cal — matches your standard \(Int(baseline * 7)) cal/week target.")
                }
            }
        }
        .navigationTitle("Calorie Cycling")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func dayRow(weekday: Int) -> some View {
        let symbol = weekdaySymbols[weekday - 1]
        let target = CalorieCyclingCalculator.dailyCalorieTarget(baseline: baseline, overrides: overridesByWeekday, for: weekday)
        let hasOverride = overridesByWeekday[weekday] != nil

        HStack {
            Text(symbol)
            Spacer()
            if hasOverride {
                Stepper(value: extraCaloriesBinding(weekday: weekday), in: -1000...1000, step: 50) {
                    Text("\(Int(target)) cal")
                }
            } else {
                Text("\(Int(target)) cal")
                    .foregroundStyle(.secondary)
                Button("Customize") {
                    addOverride(weekday: weekday)
                }
                .buttonStyle(.borderless)
                .disabled(overridesByWeekday.count >= 6)
            }
            if hasOverride {
                Button(role: .destructive) {
                    removeOverride(weekday: weekday)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove custom target for \(symbol)")
            }
        }
    }

    private func extraCaloriesBinding(weekday: Int) -> Binding<Double> {
        Binding(
            get: { overridesByWeekday[weekday] ?? 0 },
            set: { newValue in
                guard let existing = profile.calorieDayOverrides.first(where: { $0.weekday == weekday }) else { return }
                existing.extraCalories = newValue
                try? modelContext.save()
            }
        )
    }

    private func addOverride(weekday: Int) {
        let override = DayCalorieOverride(weekday: weekday, extraCalories: 300, profile: profile)
        modelContext.insert(override)
        try? modelContext.save()
    }

    private func removeOverride(weekday: Int) {
        guard let existing = profile.calorieDayOverrides.first(where: { $0.weekday == weekday }) else { return }
        modelContext.delete(existing)
        try? modelContext.save()
    }
}
