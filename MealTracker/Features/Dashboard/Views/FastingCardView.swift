import SwiftUI
import SwiftData

/// "FASTING" card — a start/stop window with a live elapsed readout. Only ever shown on today
/// (see `DashboardView`), since a running fast is a right-now thing rather than something to
/// browse a past day for.
///
/// The whole state is `profile.fastingStartedAt`; the ticking number is re-derived from it each
/// second by `TimelineView` rather than being counted by a stored timer, so closing the app —
/// or being killed by the system overnight — doesn't lose or drift the fast.
struct FastingCardView: View {
    @Bindable var profile: UserProfile

    @Environment(\.modelContext) private var modelContext
    @State private var isEditingStart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FASTING")
                    .font(.manrope(10, weight: .bold))
                    .tracking(1.4)
                    .foregroundStyle(Color.dashboardInkSecondary)
                Spacer()
                Text("\(FastingTimerCalculator.goalLabel(hours: profile.fastingGoalHours)) · \(Int(profile.fastingGoalHours))h goal")
                    .font(.manrope(12, weight: .semibold))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 14) {
                if let startedAt = profile.fastingStartedAt {
                    runningState(startedAt: startedAt)
                } else {
                    idleState
                }
            }
            .padding(16)
            .background(Color.dashboardCard, in: RoundedRectangle(cornerRadius: 24))
        }
        .sheet(isPresented: $isEditingStart) {
            if let startedAt = profile.fastingStartedAt {
                FastingStartEditorView(startedAt: startedAt) { newStart in
                    profile.fastingStartedAt = newStart
                    try? modelContext.save()
                }
            }
        }
    }

    private func runningState(startedAt: Date) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let progress = FastingTimerCalculator.progress(
                startedAt: startedAt,
                goalHours: profile.fastingGoalHours,
                now: context.date
            )

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(FastingTimerCalculator.preciseDurationText(progress.elapsed))
                        .font(.archivo(34, weight: .semibold))
                        .foregroundStyle(Color.dashboardInk)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text(progress.hasReachedGoal
                         ? "Goal reached — \(FastingTimerCalculator.durationText(progress.elapsed - progress.goal)) past it"
                         : "\(FastingTimerCalculator.durationText(progress.remaining)) to go")
                        .font(.manrope(12, weight: .semibold))
                        .foregroundStyle(progress.hasReachedGoal ? Color.dashboardLime : Color.dashboardAccent)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.dashboardBarTrack)
                        Capsule()
                            .fill(progress.hasReachedGoal ? Color.dashboardLime : Color.dashboardAccent)
                            .frame(width: geometry.size.width * progress.fraction)
                    }
                }
                .frame(height: 4)
                .accessibilityHidden(true)

                HStack {
                    Button {
                        isEditingStart = true
                    } label: {
                        Text("Started \(startedAt.formatted(date: .omitted, time: .shortened))")
                            .font(.manrope(12, weight: .semibold))
                            .foregroundStyle(Color.dashboardInkSecondary)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit fast start time")

                    Spacer()

                    Button {
                        endFast()
                    } label: {
                        Text("End Fast")
                            .font(.manrope(13, weight: .semibold))
                            .foregroundStyle(Color.dashboardInk)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(Color.dashboardBarTrack, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Fasting")
            .accessibilityValue("\(FastingTimerCalculator.durationText(progress.elapsed)) elapsed of a \(Int(profile.fastingGoalHours)) hour goal")
        }
    }

    private var idleState: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Not fasting")
                    .font(.archivo(28, weight: .semibold))
                    .foregroundStyle(Color.dashboardInk)
                Text(lastFastSummary ?? "Start the clock when you finish eating.")
                    .font(.manrope(12, weight: .semibold))
                    .foregroundStyle(Color.dashboardInkSecondary)
            }

            Button {
                startFast()
            } label: {
                Text("Start Fast")
                    .font(.manrope(13, weight: .semibold))
                    .foregroundStyle(Color.dashboardCard)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.dashboardAccent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    /// "Last fast 16h 20m, ended 09:15 Tue" — nil until one has actually been completed.
    private var lastFastSummary: String? {
        guard let start = profile.lastFastStartedAt, let end = profile.lastFastEndedAt, end > start else { return nil }
        let length = FastingTimerCalculator.durationText(end.timeIntervalSince(start))
        let ended = Calendar.current.isDateInToday(end)
            ? end.formatted(date: .omitted, time: .shortened)
            : end.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        return "Last fast \(length), ended \(ended)"
    }

    private func startFast() {
        profile.fastingStartedAt = Date()
        try? modelContext.save()
    }

    private func endFast() {
        guard let startedAt = profile.fastingStartedAt else { return }
        profile.lastFastStartedAt = startedAt
        profile.lastFastEndedAt = Date()
        profile.fastingStartedAt = nil
        try? modelContext.save()
    }
}

/// Corrects a start time that was tapped late — "I actually stopped eating at 8pm" is the normal
/// case, so the picker won't accept a start in the future.
private struct FastingStartEditorView: View {
    let startedAt: Date
    let onSave: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Date

    init(startedAt: Date, onSave: @escaping (Date) -> Void) {
        self.startedAt = startedAt
        self.onSave = onSave
        _draft = State(initialValue: startedAt)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Started", selection: $draft, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
            }
            .navigationTitle("Fast Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                }
            }
        }
        // Small enough to leave the running timer visible behind it — the compact picker is one
        // row, so a half-sheet would be mostly empty space.
        .presentationDetents([.height(200), .medium])
    }
}
