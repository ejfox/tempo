//
//  StartPomodoroIntent.swift
//  TempoWatch
//
//  All App Intent definitions for Tempo.
//  Enums in IntentEnums.swift, shortcuts in TempoShortcuts.swift.
//

import AppIntents
import Foundation

// MARK: - Session Control Intents

struct StartPomodoroIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Pomodoro"
    static var description: IntentDescription = IntentDescription(
        "Start a focused Pomodoro session. Defaults to 25 minutes — the classic.",
        categoryName: "Session"
    )
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true

    @Parameter(title: "Duration", default: .twentyFive)
    var duration: FocusDuration

    static var parameterSummary: some ParameterSummary {
        Summary("Start a \(\.$duration) focus session")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let manager = WatchSessionManager.shared
        guard !manager.session.isActive else {
            return .result(value: Int(manager.session.remainingTime),
                           dialog: "Session already running — \(manager.session.formattedTime) remaining.")
        }
        let type = WatchPomodoroSession.sessionType(
            forMinutes: TimeInterval(duration.rawValue),
            breakRatio: WatchSettings().breakRatio
        )
        manager.startSession(type: type)
        return .result(value: duration.rawValue * 60, dialog: "\(duration.rawValue)-minute focus. Go.")
    }
}

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Session"
    static var description: IntentDescription = IntentDescription("Stop the current session.", categoryName: "Session")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared
        guard manager.session.isActive else { return .result(dialog: "No session running.") }
        manager.stopSession()
        return .result(dialog: "Session stopped.")
    }
}

struct PauseSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Session"
    static var description: IntentDescription = IntentDescription("Pause the current timer.", categoryName: "Session")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared
        guard manager.session.isRunning else { return .result(dialog: "Nothing to pause.") }
        manager.pauseSession()
        return .result(dialog: "Paused at \(manager.session.formattedTime).")
    }
}

struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Session"
    static var description: IntentDescription = IntentDescription("Resume a paused session.", categoryName: "Session")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared
        guard manager.session.isPaused else { return .result(dialog: "Nothing paused.") }
        manager.resumeSession()
        return .result(dialog: "Resumed — \(manager.session.formattedTime) to go.")
    }
}

struct TogglePauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription = IntentDescription("Pause if running, resume if paused.", categoryName: "Session")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared
        if manager.session.isPaused {
            manager.resumeSession()
            return .result(dialog: "Resumed — \(manager.session.formattedTime) to go.")
        } else if manager.session.isRunning {
            manager.pauseSession()
            return .result(dialog: "Paused at \(manager.session.formattedTime).")
        }
        return .result(dialog: "No active session.")
    }
}

struct ExtendSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Extend Session"
    static var description: IntentDescription = IntentDescription("Add time to the current session.", categoryName: "Session")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Extra minutes", default: 10)
    var extraMinutes: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$extraMinutes) minutes to the current session")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let manager = WatchSessionManager.shared
        guard manager.session.isActive && !manager.session.isInBreak else {
            return .result(value: 0, dialog: "No focus session to extend.")
        }
        manager.extendSession(byMinutes: extraMinutes)
        return .result(value: Int(manager.session.remainingTime),
                       dialog: "Added \(extraMinutes) min — \(manager.session.formattedTime) remaining.")
    }
}

// MARK: - Status Query Intents

struct CheckStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pomodoro Status"
    static var description: IntentDescription = IntentDescription("Session phase, time, streak, and cycle.", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let session = WatchSessionManager.shared.session
        guard session.isActive else {
            let s = session.currentStreak, t = session.todayCount
            if t > 0 || s > 0 { return .result(value: 0, dialog: "Idle. \(t) sessions today, streak of \(s).") }
            return .result(value: 0, dialog: "No session running. Ready when you are.")
        }
        let secs = Int(session.remainingTime)
        let pct = Int(session.progress * 100)
        let cyc = "\(session.cyclePosition + 1) of \(WatchSettings().pomodorosPerCycle)"
        let base = "\(session.formattedTime) remaining (\(pct)% done). Pomodoro \(cyc)."
        if session.isPaused {
            return .result(value: secs, dialog: "Paused. \(base)")
        }
        return .result(value: secs, dialog: "\(session.phaseLabel.capitalized): \(base)")
    }
}

struct GetTimeRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Time Remaining"
    static var description: IntentDescription = IntentDescription("Seconds remaining. 0 if idle.", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        .result(value: Int(WatchSessionManager.shared.session.remainingTime))
    }
}

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Streak"
    static var description: IntentDescription = IntentDescription("Current streak count.", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let s = WatchSessionManager.shared.session
        if s.currentStreak == 0 && s.todayCount == 0 {
            return .result(value: 0, dialog: "No sessions yet today. Start one!")
        }
        return .result(value: s.currentStreak, dialog: "\(s.todayCount) sessions today. Streak: \(s.currentStreak).")
    }
}

struct GetTodayCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Sessions"
    static var description: IntentDescription = IntentDescription("Sessions completed today.", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let t = WatchSessionManager.shared.session.todayCount
        return .result(value: t, dialog: "\(t) session\(t == 1 ? "" : "s") completed today.")
    }
}

struct GetSessionPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Session Phase"
    static var description: IntentDescription = IntentDescription("Current phase: idle/focus/break/paused.", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let s = WatchSessionManager.shared.session
        let phase: String
        if s.isPaused { phase = "paused" }
        else if s.isInBreak { phase = "break" }
        else if s.isRunning { phase = "focus" }
        else { phase = "idle" }
        return .result(value: phase)
    }
}

struct GetCyclePositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Cycle Position"
    static var description: IntentDescription = IntentDescription("Which pomodoro in the current cycle (1-based).", categoryName: "Status")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let s = WatchSessionManager.shared.session
        let pos = s.cyclePosition + 1, total = WatchSettings().pomodorosPerCycle
        return .result(value: pos, dialog: "Pomodoro \(pos) of \(total) in current cycle.")
    }
}
