//
//  CurrentWidget.swift
//  TempoWatchWidgets
//
//  "Tempo Current" — live session timer complication.
//  Shows progress ring + countdown when active, "ready" when idle.
//

import SwiftUI
import WidgetKit

// MARK: - Timeline Provider

struct CurrentTimelineProvider: TimelineProvider {
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

// MARK: - Widget Definition

struct CurrentWidget: Widget {
    let kind = "TempoCurrentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CurrentTimelineProvider()) { entry in
            CurrentComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Tempo Current")
        .description("Live session timer with progress.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

// MARK: - Complication Views

struct CurrentComplicationView: View {
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

    // MARK: - Circular

    private var circularView: some View {
        ZStack {
            if entry.isActive {
                MiniProgressRing(progress: entry.progress, color: entry.phaseColor)
                Text(shortTime)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            } else {
                MiniProgressRing(progress: 0, trackOpacity: 0.08)
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    // MARK: - Rectangular

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.isActive {
                HStack {
                    Text(entry.phaseLabel)
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    MiniCycleBar(
                        position: entry.cyclePosition,
                        total: entry.pomodorosPerCycle,
                        color: entry.phaseColor
                    )
                }

                MiniProgressBar(progress: entry.progress, color: entry.phaseColor)

                Text(entry.formattedTime)
                    .font(.system(size: 22, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(entry.phaseColor)
            } else {
                Text("ready")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)

                if entry.currentStreak > 0 {
                    HStack(spacing: 8) {
                        Label("\(entry.currentStreak)", systemImage: "flame")
                        Label("\(entry.todayCount)", systemImage: "checkmark.circle")
                    }
                    .font(.system(size: 12, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.6))
                } else {
                    Text("tap to begin")
                        .font(.system(size: 12, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
    }

    // MARK: - Inline

    private var inlineView: some View {
        Group {
            if entry.isActive {
                Text("\(entry.formattedTime) \(entry.phaseLabel)")
            } else {
                Text("tempo \u{00B7} ready")
            }
        }
    }

    // MARK: - Corner

    private var cornerView: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "timer")
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(entry.phaseColor)
    }

    // MARK: - Helpers

    /// Compact time for circular: "15:00" → "15m" or "0:45" → "45s"
    private var shortTime: String {
        let total = Int(entry.remainingTime)
        let minutes = total / 60
        let seconds = total % 60
        if minutes > 0 {
            return "\(minutes)m"
        }
        return "\(seconds)s"
    }
}

// MARK: - Preview

#Preview("Current Circular", as: .accessoryCircular) {
    CurrentWidget()
} timeline: {
    TempoTimelineEntry(
        date: Date(),
        isActive: true, isInBreak: false, isPaused: false, isBreakPending: false,
        remainingTime: 15 * 60, totalDuration: 25 * 60, progress: 0.4,
        phaseLabel: "focus", formattedTime: "15:00",
        currentStreak: 3, todayCount: 2, cyclePosition: 1, pomodorosPerCycle: 4
    )
    TempoTimelineEntry.idle
}

#Preview("Current Rectangular", as: .accessoryRectangular) {
    CurrentWidget()
} timeline: {
    TempoTimelineEntry(
        date: Date(),
        isActive: true, isInBreak: false, isPaused: false, isBreakPending: false,
        remainingTime: 15 * 60, totalDuration: 25 * 60, progress: 0.4,
        phaseLabel: "focus", formattedTime: "15:00",
        currentStreak: 3, todayCount: 2, cyclePosition: 1, pomodorosPerCycle: 4
    )
    TempoTimelineEntry.idle
}
