//
//  PreviewHelpers.swift
//  TempoWatch
//
//  Preview helpers for Xcode SwiftUI Previews.
//  Creates pre-configured managers in specific states
//  so you can see every screen without running the app.
//

import SwiftUI

// MARK: - Preview Session Manager

/// A subclass that skips iCloud/notification setup for previews.
class PreviewSessionManager: WatchSessionManager {
    override init() {
        // Skip super.init() side effects (sync, notifications, extended runtime)
        // by calling NSObject.init directly
        // Note: session and other @Observable properties are initialized inline
    }

    /// Create a manager with the session in a specific state
    static func idle() -> PreviewSessionManager {
        let m = PreviewSessionManager()
        m.session.state = .idle
        m.session.currentStreak = 3
        m.session.todayCount = 5
        m.session.cyclePosition = 2
        return m
    }

    static func running(minutes: TimeInterval = 25, elapsed: TimeInterval = 300) -> PreviewSessionManager {
        let m = PreviewSessionManager()
        let type = WatchPomodoroSession.SessionType.short(work: minutes * 60, break: minutes * 60 * 0.2)
        m.session.state = .running(
            type: type,
            startTime: Date().addingTimeInterval(-elapsed),
            duration: minutes * 60
        )
        m.session.currentStreak = 3
        m.session.todayCount = 5
        m.session.cyclePosition = 2
        return m
    }

    static func paused(remaining: TimeInterval = 720) -> PreviewSessionManager {
        let m = PreviewSessionManager()
        let type = WatchPomodoroSession.SessionType.short(work: 25 * 60, break: 5 * 60)
        m.session.state = .paused(type: type, remaining: remaining)
        m.session.currentStreak = 3
        m.session.todayCount = 5
        return m
    }

    static func breakPending() -> PreviewSessionManager {
        let m = PreviewSessionManager()
        let type = WatchPomodoroSession.SessionType.short(work: 25 * 60, break: 5 * 60)
        m.session.state = .breakPending(type: type, breakDuration: 5 * 60)
        m.session.currentStreak = 4
        m.session.todayCount = 6
        m.session.cyclePosition = 3
        return m
    }

    static func onBreak(elapsed: TimeInterval = 60) -> PreviewSessionManager {
        let m = PreviewSessionManager()
        m.session.state = .breakTime(
            startTime: Date().addingTimeInterval(-elapsed),
            duration: 5 * 60
        )
        m.session.currentStreak = 4
        m.session.todayCount = 6
        return m
    }

    static func celebrating(cycleComplete: Bool = false) -> PreviewSessionManager {
        let m = PreviewSessionManager()
        m.celebrating = true
        m.isCycleComplete = cycleComplete
        m.session.currentStreak = 5
        m.session.todayCount = 7
        return m
    }
}

// MARK: - Preview Catalog

#Preview("Idle (Default)") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.idle() as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Idle (Streak)") {
    let settings = WatchSettings()
    settings.idleStatsSlot = .streakCount
    return NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.idle() as WatchSessionManager)
    .environment(settings)
}

#Preview("Running - 20min left") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.running(minutes: 25, elapsed: 300) as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Running - Almost Done") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.running(minutes: 25, elapsed: 24 * 60) as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Paused") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.paused() as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Break Pending") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.breakPending() as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("On Break") {
    let settings = WatchSettings()
    settings.invertBreakColors = true
    return NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.onBreak() as WatchSessionManager)
    .environment(settings)
}

#Preview("On Break (No Invert)") {
    let settings = WatchSettings()
    settings.invertBreakColors = false
    settings.breakColorChoice = .cyan
    return NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.onBreak() as WatchSessionManager)
    .environment(settings)
}

#Preview("Celebration") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.celebrating() as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Cycle Complete") {
    NavigationStack {
        WatchContentView()
    }
    .environment(PreviewSessionManager.celebrating(cycleComplete: true) as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Duration Selector Only") {
    NavigationStack {
        DurationSelectorView()
    }
    .environment(PreviewSessionManager.idle() as WatchSessionManager)
    .environment(WatchSettings())
}

#Preview("Active Session Only") {
    NavigationStack {
        ActiveSessionView()
    }
    .environment(PreviewSessionManager.running() as WatchSessionManager)
    .environment(WatchSettings())
}
