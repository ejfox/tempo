//
//  TempoComplicationData.swift
//  TempoWatchWidgets
//
//  Reads session state from the shared App Group UserDefaults.
//  The watch app writes here via WatchSessionManager.broadcastState().
//

import Foundation

/// Mirror of the watch app's SessionSyncInfo for decoding.
/// Kept as a separate struct to avoid cross-target dependencies.
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

struct TempoComplicationData {
    private static let shared = UserDefaults(suiteName: "group.com.fox.Tempo")

    /// Read current state and produce a timeline entry for a given date.
    static func entry(for date: Date = Date()) -> TempoTimelineEntry {
        guard let defaults = shared else { return .idle }

        // Try to decode full session info
        if let data = defaults.data(forKey: "widget.session"),
           let info = try? JSONDecoder().decode(WidgetSessionInfo.self, from: data),
           info.isActive {
            // Recalculate remaining time from startTime for accuracy
            let elapsed = date.timeIntervalSince(info.startTime)
            let remaining = max(0, info.totalDuration - elapsed)
            let progress = info.totalDuration > 0
                ? min(1.0, max(0.0, elapsed / info.totalDuration))
                : 0

            let totalSeconds = Int(remaining)
            let formatted = String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)

            return TempoTimelineEntry(
                date: date,
                isActive: true,
                isInBreak: info.isInBreak,
                isPaused: false,
                isBreakPending: false,
                remainingTime: remaining,
                totalDuration: info.totalDuration,
                progress: progress,
                phaseLabel: info.isInBreak ? "break" : "focus",
                formattedTime: formatted,
                currentStreak: info.currentStreak,
                todayCount: info.todayCount,
                cyclePosition: info.cyclePosition ?? 0,
                pomodorosPerCycle: defaults.integer(forKey: "widget.pomodorosPerCycle").clamped(2, 4)
            )
        }

        // Idle — read individual stat keys
        let streak = defaults.integer(forKey: "widget.streak")
        let today = defaults.integer(forKey: "widget.todayCount")
        let cycle = defaults.integer(forKey: "widget.cyclePosition")
        let perCycle = defaults.integer(forKey: "widget.pomodorosPerCycle").clamped(2, 4)

        return TempoTimelineEntry(
            date: date,
            isActive: false,
            isInBreak: false,
            isPaused: false,
            isBreakPending: false,
            remainingTime: 0,
            totalDuration: 0,
            progress: 0,
            phaseLabel: "",
            formattedTime: "00:00",
            currentStreak: streak,
            todayCount: today,
            cyclePosition: cycle,
            pomodorosPerCycle: perCycle
        )
    }

    /// Generate a timeline of entries for an active session.
    /// Pre-computes remaining time at 1-minute intervals.
    static func activeTimeline() -> [TempoTimelineEntry] {
        let now = Date()
        let base = entry(for: now)
        guard base.isActive, base.remainingTime > 0 else { return [base] }

        let minutes = Int(base.remainingTime / 60) + 1
        return (0..<minutes).map { i in
            let futureDate = now.addingTimeInterval(TimeInterval(i * 60))
            return entry(for: futureDate)
        }
    }
}

// MARK: - Int Clamping

private extension Int {
    func clamped(_ low: Int, _ high: Int) -> Int {
        self == 0 ? low : Swift.min(Swift.max(self, low), high)
    }
}
