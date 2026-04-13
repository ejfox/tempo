//
//  Constants.swift
//  Tempo
//
//  Centralized keys and constants. Matches TempoWatch/Constants.swift
//  exactly — keys must be identical for cross-device sync.
//

import Foundation

// MARK: - UserDefaults Keys

enum SessionKey: String {
    case todayCount     = "session.todayCount"
    case currentStreak  = "session.currentStreak"
    case cyclePosition  = "session.cyclePosition"
    case lastSaveDate   = "session.lastSaveDate"
    case migrated       = "session.migrated"
}

enum WidgetKey: String {
    case session          = "widget.session"
    case todayCount       = "widget.todayCount"
    case streak           = "widget.streak"
    case cyclePosition    = "widget.cyclePosition"
    case pomodorosPerCycle = "widget.pomodorosPerCycle"
}

enum SyncKey: String {
    case currentSession = "currentSession"
}

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
