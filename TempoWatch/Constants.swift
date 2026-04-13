//
//  Constants.swift
//  TempoWatch
//
//  Centralized keys and constants. No more string typos.
//

import Foundation

// MARK: - UserDefaults Keys

/// Keys for session stat persistence (shared App Group suite).
enum SessionKey: String {
    case todayCount     = "session.todayCount"
    case currentStreak  = "session.currentStreak"
    case cyclePosition  = "session.cyclePosition"
    case lastSaveDate   = "session.lastSaveDate"
    case migrated       = "session.migrated"
}

/// Keys for widget data bridge (shared App Group suite).
enum WidgetKey: String {
    case session          = "widget.session"
    case todayCount       = "widget.todayCount"
    case streak           = "widget.streak"
    case cyclePosition    = "widget.cyclePosition"
    case pomodorosPerCycle = "widget.pomodorosPerCycle"
}

/// Key for iCloud KV Store cross-device sync.
enum SyncKey: String {
    case currentSession = "currentSession"
}

/// Notification IDs for approaching-end alerts.
enum AlertID: String, CaseIterable {
    case halfway = "tempo.halfway"
    case fiveMin = "tempo.5min"
    case twoMin  = "tempo.2min"
    case oneMin  = "tempo.1min"

    static var allIDs: [String] { allCases.map(\.rawValue) }
}

// MARK: - App Group

enum AppGroup {
    static let suiteName = "group.com.fox.Tempo"
}

// MARK: - Session Defaults

enum SessionDefaults {
    static let durationPresets: [TimeInterval] = [5, 10, 15, 20, 25, 30, 45, 50, 60]
    static let defaultPresetIndex = 4
    static let milestonePercentages = [25, 50, 75]
    static let countdownSeconds = 5
    static let syncBroadcastInterval = 5
    static let maxTimelineMinutes = 30
}
