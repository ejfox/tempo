//
//  TempoTimelineEntry.swift
//  TempoWatchWidgets
//
//  Timeline entry containing all data a complication might need.
//

import WidgetKit

struct TempoTimelineEntry: TimelineEntry {
    let date: Date

    // Session state
    let isActive: Bool
    let isInBreak: Bool
    let isPaused: Bool
    let isBreakPending: Bool
    let remainingTime: TimeInterval
    let totalDuration: TimeInterval
    let progress: Double
    let phaseLabel: String
    let formattedTime: String

    // Stats
    let currentStreak: Int
    let todayCount: Int
    let cyclePosition: Int
    let pomodorosPerCycle: Int

    // Convenience
    var accentColor: String { isInBreak ? "cyan" : "white" }

    static var idle: TempoTimelineEntry {
        TempoTimelineEntry(
            date: Date(),
            isActive: false,
            isInBreak: false,
            isPaused: false,
            isBreakPending: false,
            remainingTime: 0,
            totalDuration: 0,
            progress: 0,
            phaseLabel: "",
            formattedTime: "00:00",
            currentStreak: 0,
            todayCount: 0,
            cyclePosition: 0,
            pomodorosPerCycle: 4
        )
    }
}
