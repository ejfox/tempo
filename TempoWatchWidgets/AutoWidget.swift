//
//  AutoWidget.swift
//  TempoWatchWidgets
//
//  "Tempo Auto" — intelligently switches between Current, Day, and Streak
//  based on session state and daily progress.
//

import SwiftUI
import WidgetKit

struct AutoTimelineProvider: TimelineProvider {
    typealias Entry = TempoTimelineEntry

    func placeholder(in context: Context) -> Entry {
        TempoTimelineEntry(
            date: Date(),
            isActive: true, isInBreak: false, isPaused: false, isBreakPending: false,
            remainingTime: 15 * 60, totalDuration: 25 * 60, progress: 0.4,
            phaseLabel: "focus", formattedTime: "15:00",
            currentStreak: 3, todayCount: 2, cyclePosition: 1, pomodorosPerCycle: 4
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(TempoComplicationData.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entries = TempoComplicationData.activeTimeline()
        let policy: TimelineReloadPolicy = entries.first?.isActive == true ? .atEnd : .never
        completion(Timeline(entries: entries, policy: policy))
    }
}

struct AutoWidget: Widget {
    let kind = "TempoAutoWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AutoTimelineProvider()) { entry in
            AutoComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Tempo Auto")
        .description("Smart complication — adapts to what you need right now.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

/// Resolves which view to show based on context, then delegates to that view.
struct AutoComplicationView: View {
    @Environment(\.widgetFamily) var family
    let entry: TempoTimelineEntry

    var body: some View {
        switch resolvedView {
        case .current:
            CurrentComplicationView(entry: entry)
        case .day:
            DayComplicationView(entry: entry)
        case .streak:
            StreakComplicationView(entry: entry)
        }
    }

    private enum ResolvedView {
        case current, day, streak
    }

    private var resolvedView: ResolvedView {
        if entry.isActive { return .current }
        if entry.todayCount > 0 { return .day }
        return .streak
    }
}
