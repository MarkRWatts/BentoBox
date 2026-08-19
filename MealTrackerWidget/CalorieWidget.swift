import WidgetKit
import SwiftUI

struct CalorieTimelineEntry: TimelineEntry {
    let date: Date
    let snapshot: DashboardSnapshot?
}

struct CalorieTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorieTimelineEntry {
        CalorieTimelineEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorieTimelineEntry) -> Void) {
        completion(CalorieTimelineEntry(date: Date(), snapshot: DashboardSnapshot.load() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorieTimelineEntry>) -> Void) {
        let entry = CalorieTimelineEntry(date: Date(), snapshot: DashboardSnapshot.load())
        // The app calls WidgetCenter.reloadTimelines whenever Today's data actually changes, so
        // this fallback refresh is just a staleness backstop, not the primary update path.
        let nextRefresh = Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

struct CalorieWidget: Widget {
    let kind = "MealTrackerCalorieWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalorieTimelineProvider()) { entry in
            CalorieWidgetView(snapshot: entry.snapshot)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Calories")
        .description("Today's calories at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

struct CalorieWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: DashboardSnapshot?

    private var progress: Double {
        guard let snapshot, snapshot.targetCalories > 0 else { return 0 }
        return min(snapshot.consumedCalories / snapshot.targetCalories, 1)
    }

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            homeScreenView
        }
    }

    private var circularView: some View {
        Gauge(value: progress) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text(snapshot.map { "\(Int($0.consumedCalories))" } ?? "–")
                .font(.system(size: 12))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Calories")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let snapshot {
                Text("\(Int(snapshot.consumedCalories)) / \(Int(snapshot.targetCalories))")
                    .font(.headline)
            } else {
                Text("Open cal:Track")
                    .font(.caption)
            }
        }
    }

    private var homeScreenView: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.brandForest, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    if let snapshot {
                        Text("\(Int(snapshot.consumedCalories))")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("of \(Int(snapshot.targetCalories))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                    }
                }
            }
            .frame(width: 90, height: 90)
            .padding(.top, 4)

            if family == .systemMedium, let snapshot {
                Text(snapshot.consumedCalories <= snapshot.targetCalories
                     ? "\(Int(snapshot.targetCalories - snapshot.consumedCalories)) cal remaining"
                     : "\(Int(snapshot.consumedCalories - snapshot.targetCalories)) cal over")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
