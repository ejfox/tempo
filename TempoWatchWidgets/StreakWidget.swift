//
//  StreakWidget.swift
//  TempoWatchWidgets
//
//  "Tempo Streak" — motivation complication. Flame + streak + cycle.
//

import SwiftUI
import WidgetKit

struct StreakTimelineProvider: TimelineProvider {
    typealias Entry = TempoTimelineEntry

    func placeholder(in context: Context) -> Entry {
        TempoTimelineEntry(
            date: Date(),
            isActive: false, isInBreak: false, isPaused: false, isBreakPending: false,
            remainingTime: 0, totalDuration: 0, progress: 0,
            phaseLabel: "", formattedTime: "00:00",
            currentStreak: 7, todayCount: 4, cyclePosition: 3, pomodorosPerCycle: 4
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(TempoComplicationData.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = TempoComplicationData.entry()
        completion(Timeline(entries: [entry], policy: .never))
    }
}

struct StreakWidget: Widget {
    let kind = "TempoStreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakTimelineProvider()) { entry in
            StreakComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Tempo Streak")
        .description("Your streak and cycle progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct StreakComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: TempoTimelineEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        case .accessoryInline:
            inlineView
        case .accessoryCorner:
            cornerView
        default:
            circularView
        }
    }

    private var circularView: some View {
        VStack(spacing: 1) {
            Image(systemName: "flame")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(entry.currentStreak > 0 ? .white : .white.opacity(0.3))
            Text("\(entry.currentStreak)")
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.currentStreak > 0 {
                HStack {
                    Image(systemName: "flame")
                        .font(.system(size: 11))
                    Text("\(entry.currentStreak) streak")
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                    Spacer()
                }

                MiniCycleBar(
                    position: entry.cyclePosition,
                    total: entry.pomodorosPerCycle
                )

                Text("\(entry.todayCount) today")
                    .font(.system(size: 10, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "flame")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.2))
                Text("begin a streak")
                    .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
    }

    private var inlineView: some View {
        Group {
            if entry.currentStreak > 0 {
                Text("\(entry.currentStreak) streak \u{00B7} \(entry.cyclePosition + 1)/\(entry.pomodorosPerCycle) cycle")
            } else {
                Text("start a streak")
            }
        }
    }

    private var cornerView: some View {
        // Gauge: cycle progress
        let cycleProgress = entry.pomodorosPerCycle > 0
            ? Double(entry.cyclePosition) / Double(entry.pomodorosPerCycle)
            : 0
        Gauge(value: cycleProgress) {
            Image(systemName: "flame")
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}
