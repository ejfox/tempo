//
//  TempoWidgets.swift
//  TempoWidgets
//
//  Home screen widgets showing session status (active) or daily stats (idle).
//

import WidgetKit
import SwiftUI

// MARK: - Data Reader

struct WidgetSessionInfo: Codable {
    let isActive: Bool
    let startTime: Date
    let totalDuration: TimeInterval
    let workDuration: TimeInterval
    let breakDuration: TimeInterval
    let remainingTime: TimeInterval
    let currentStreak: Int
    let todayCount: Int
    let sessionType: String
    let isInBreak: Bool
    let lastUpdateTime: Date
    let cyclePosition: Int?
}

struct TempoWidgetEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let isInBreak: Bool
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let progress: Double
    let phaseLabel: String
    let formattedTime: String
    let currentStreak: Int
    let todayCount: Int
    let cyclePosition: Int
    let pomodorosPerCycle: Int

    static var idle: TempoWidgetEntry {
        TempoWidgetEntry(
            date: Date(), isActive: false, isInBreak: false,
            remainingTime: 0, totalDuration: 0, progress: 0,
            phaseLabel: "", formattedTime: "00:00",
            currentStreak: 0, todayCount: 0, cyclePosition: 0, pomodorosPerCycle: 4
        )
    }
}

struct TempoWidgetDataReader {
    private static let shared = UserDefaults(suiteName: "group.com.fox.Tempo")

    static func entry(for date: Date = Date()) -> TempoWidgetEntry {
        guard let defaults = shared else { return .idle }

        if let data = defaults.data(forKey: "widget.session"),
           let info = try? JSONDecoder().decode(WidgetSessionInfo.self, from: data),
           info.isActive {
            let elapsed = date.timeIntervalSince(info.startTime)
            let remaining = max(0, info.totalDuration - elapsed)
            let progress = info.totalDuration > 0 ? min(1.0, elapsed / info.totalDuration) : 0
            let total = Int(remaining)

            return TempoWidgetEntry(
                date: date, isActive: true, isInBreak: info.isInBreak,
                remainingTime: remaining, totalDuration: info.totalDuration,
                progress: progress,
                phaseLabel: info.isInBreak ? "break" : "focus",
                formattedTime: String(format: "%02d:%02d", total / 60, total % 60),
                currentStreak: info.currentStreak, todayCount: info.todayCount,
                cyclePosition: info.cyclePosition ?? 0,
                pomodorosPerCycle: max(2, defaults.integer(forKey: "widget.pomodorosPerCycle"))
            )
        }

        return TempoWidgetEntry(
            date: date, isActive: false, isInBreak: false,
            remainingTime: 0, totalDuration: 0, progress: 0,
            phaseLabel: "", formattedTime: "00:00",
            currentStreak: defaults.integer(forKey: "widget.streak"),
            todayCount: defaults.integer(forKey: "widget.todayCount"),
            cyclePosition: defaults.integer(forKey: "widget.cyclePosition"),
            pomodorosPerCycle: max(2, defaults.integer(forKey: "widget.pomodorosPerCycle"))
        )
    }

    static func timeline() -> [TempoWidgetEntry] {
        let now = Date()
        let base = entry(for: now)
        guard base.isActive, base.remainingTime > 0 else { return [base] }
        let minutes = min(Int(base.remainingTime / 60) + 1, 30)
        return (0..<minutes).map { entry(for: now.addingTimeInterval(TimeInterval($0 * 60))) }
    }
}

// MARK: - Timeline Provider

struct TempoTimelineProvider: TimelineProvider {
    typealias Entry = TempoWidgetEntry

    func placeholder(in context: Context) -> Entry {
        TempoWidgetEntry(
            date: Date(), isActive: true, isInBreak: false,
            remainingTime: 15 * 60, totalDuration: 25 * 60, progress: 0.4,
            phaseLabel: "focus", formattedTime: "15:00",
            currentStreak: 3, todayCount: 2, cyclePosition: 1, pomodorosPerCycle: 4
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(TempoWidgetDataReader.entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entries = TempoWidgetDataReader.timeline()
        let policy: TimelineReloadPolicy = entries.first?.isActive == true ? .atEnd : .never
        completion(Timeline(entries: entries, policy: policy))
    }
}

// MARK: - Widget

struct TempoStatusWidget: Widget {
    let kind = "TempoStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TempoTimelineProvider()) { entry in
            TempoWidgetView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Tempo")
        .description("Session status and daily progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct TempoWidgetView: View {
    @Environment(\.widgetFamily) var family
    let entry: TempoWidgetEntry
    private var accent: Color { entry.isInBreak ? .cyan : .white }

    var body: some View {
        switch family {
        case .systemSmall: smallView
        case .systemMedium: mediumView
        default: smallView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            if entry.isActive {
                ZStack {
                    Circle()
                        .stroke(accent.opacity(0.1), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(entry.formattedTime)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                        Text(entry.phaseLabel)
                            .font(.system(size: 10, weight: .light, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
            } else {
                VStack(spacing: 4) {
                    Text("\(entry.todayCount)")
                        .font(.system(size: 36, weight: .light, design: .monospaced))
                        .monospacedDigit()
                    Text("today")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if entry.currentStreak > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "flame").font(.system(size: 10))
                            Text("\(entry.currentStreak)")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                        }
                        .foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            if entry.isActive {
                ZStack {
                    Circle().stroke(accent.opacity(0.1), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.phaseLabel)
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(entry.formattedTime)
                        .font(.system(size: 28, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                    cycleBar
                }
                Spacer()
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(entry.todayCount)")
                                .font(.system(size: 28, weight: .light, design: .monospaced))
                            Text("today")
                                .font(.system(size: 11, weight: .light, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        if entry.currentStreak > 0 {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "flame").font(.system(size: 12))
                                    Text("\(entry.currentStreak)")
                                        .font(.system(size: 28, weight: .light, design: .monospaced))
                                }
                                Text("streak")
                                    .font(.system(size: 11, weight: .light, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    cycleBar
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
    }

    private var cycleBar: some View {
        HStack(spacing: 4) {
            ForEach(0..<entry.pomodorosPerCycle, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accent.opacity(i < entry.cyclePosition ? 0.6 : 0.08))
                    .frame(width: 14, height: 3)
            }
        }
    }
}
