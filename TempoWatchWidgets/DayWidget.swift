//
//  DayWidget.swift
//  TempoWatchWidgets
//
//  "Tempo Day" — today's productivity at a glance.
//

import SwiftUI
import WidgetKit

struct DayTimelineProvider: TimelineProvider {
    typealias Entry = TempoTimelineEntry

    func placeholder(in context: Context) -> Entry {
        TempoTimelineEntry(
            date: Date(),
            isActive: false, isInBreak: false, isPaused: false, isBreakPending: false,
            remainingTime: 0, totalDuration: 0, progress: 0,
            phaseLabel: "", formattedTime: "00:00",
            currentStreak: 5, todayCount: 3, cyclePosition: 2, pomodorosPerCycle: 4
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

struct DayWidget: Widget {
    let kind = "TempoDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayTimelineProvider()) { entry in
            DayComplicationView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Tempo Day")
        .description("Today's sessions and focus time.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct DayComplicationView: View {
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
            Text("\(entry.todayCount)")
                .font(.system(size: 20, weight: .medium, design: .monospaced))
                .monospacedDigit()
            Text("today")
                .font(.system(size: 8, weight: .light, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 3) {
            if entry.todayCount > 0 {
                HStack {
                    Text("\(entry.todayCount) sessions")
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                    Spacer()
                }

                MiniCycleBar(
                    position: entry.cyclePosition,
                    total: entry.pomodorosPerCycle
                )

                HStack(spacing: 8) {
                    Label("\(entry.currentStreak)", systemImage: "flame")
                    Text("streak")
                }
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(.secondary)
            } else {
                Text("start your day")
                    .font(.system(size: 13, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))

                Text("tap to begin")
                    .font(.system(size: 10, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.2))
            }
        }
    }

    private var inlineView: some View {
        Group {
            if entry.todayCount > 0 {
                Text("\(entry.todayCount) sessions today")
            } else {
                Text("no sessions yet")
            }
        }
    }

    private var cornerView: some View {
        // Gauge: today count vs soft max of 8
        Gauge(value: Double(min(entry.todayCount, 8)), in: 0...8) {
            Text("\(entry.todayCount)")
                .font(.system(size: 10, design: .monospaced))
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }
}
