//
//  StartPomodoroIntent.swift
//  TempoWatch
//
//  Full App Intents ecosystem for Tempo.
//  Designed for Action Button, Siri, Shortcuts, and future AI agent orchestration.
//
//  Action Button: Settings → Action Button → Shortcut → "Start Pomodoro"
//
//  Intents return values so Shortcuts can chain them:
//    Start Pomodoro → Set Focus Mode → Log to Health
//

import AppIntents
import Foundation

// MARK: - Duration Enum

/// Predefined focus durations, surfaced as a Siri/Shortcuts parameter.
enum FocusDuration: Int, AppEnum {
    case five = 5
    case ten = 10
    case fifteen = 15
    case twenty = 20
    case twentyFive = 25
    case thirty = 30
    case fortyFive = 45
    case fifty = 50
    case sixty = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Duration"

    static var caseDisplayRepresentations: [FocusDuration: DisplayRepresentation] {
        [
            .five:        "5 minutes",
            .ten:         "10 minutes",
            .fifteen:     "15 minutes",
            .twenty:      "20 minutes",
            .twentyFive:  "25 minutes",
            .thirty:      "30 minutes",
            .fortyFive:   "45 minutes",
            .fifty:       "50 minutes",
            .sixty:       "60 minutes"
        ]
    }
}

// MARK: - Session Phase Enum (for output)

enum SessionPhase: String, AppEnum {
    case idle
    case focus
    case breakTime = "break"
    case paused
    case completed

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Session Phase"

    static var caseDisplayRepresentations: [SessionPhase: DisplayRepresentation] {
        [
            .idle:       "Idle",
            .focus:      "Focus",
            .breakTime:  "Break",
            .paused:     "Paused",
            .completed:  "Completed"
        ]
    }
}

// MARK: - Start Pomodoro

/// The primary intent. One press from the Action Button starts a 25-minute focus session.
/// Siri and Shortcuts can override the duration parameter.
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
            let remaining = Int(manager.session.remainingTime)
            return .result(
                value: remaining,
                dialog: "Session already running — \(manager.session.formattedTime) remaining."
            )
        }

        let minutes = TimeInterval(duration.rawValue)
        let breakRatio = WatchSettings().breakRatio
        let type = WatchPomodoroSession.sessionType(forMinutes: minutes, breakRatio: breakRatio)
        manager.startSession(type: type)

        return .result(
            value: duration.rawValue * 60,
            dialog: "\(duration.rawValue)-minute focus. Go."
        )
    }
}

// MARK: - Stop Session

struct StopSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Session"
    static var description: IntentDescription = IntentDescription(
        "Stop the current Pomodoro session immediately.",
        categoryName: "Session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared

        guard manager.session.isActive else {
            return .result(dialog: "No session running.")
        }

        manager.stopSession()
        return .result(dialog: "Session stopped.")
    }
}

// MARK: - Pause

struct PauseSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Pause Session"
    static var description: IntentDescription = IntentDescription(
        "Pause the current focus or break timer.",
        categoryName: "Session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared

        guard manager.session.isRunning else {
            return .result(dialog: "Nothing to pause.")
        }

        manager.pauseSession()
        return .result(dialog: "Paused at \(manager.session.formattedTime).")
    }
}

// MARK: - Resume

struct ResumeSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Resume Session"
    static var description: IntentDescription = IntentDescription(
        "Resume a paused Pomodoro session.",
        categoryName: "Session"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let manager = WatchSessionManager.shared

        guard manager.session.isPaused else {
            return .result(dialog: "Nothing paused.")
        }

        manager.resumeSession()
        return .result(dialog: "Resumed — \(manager.session.formattedTime) to go.")
    }
}

// MARK: - Toggle Pause

struct TogglePauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Pause"
    static var description: IntentDescription = IntentDescription(
        "Pause if running, resume if paused. Smart toggle.",
        categoryName: "Session"
    )
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

// MARK: - Extend Session

/// Add more time to a running or paused session.
/// Useful when you're in flow and don't want to break.
struct ExtendSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Extend Session"
    static var description: IntentDescription = IntentDescription(
        "Add more time to the current session. For when you're in the zone.",
        categoryName: "Session"
    )
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
        let newRemaining = Int(manager.session.remainingTime)

        return .result(
            value: newRemaining,
            dialog: "Added \(extraMinutes) min — \(manager.session.formattedTime) remaining."
        )
    }
}

// MARK: - Check Status

/// Returns both a spoken dialog and machine-readable values for Shortcuts chaining.
struct CheckStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Pomodoro Status"
    static var description: IntentDescription = IntentDescription(
        "Get the current session phase, time remaining, streak, and today's count.",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let session = WatchSessionManager.shared.session

        guard session.isActive else {
            let streak = session.currentStreak
            let today = session.todayCount
            if today > 0 || streak > 0 {
                return .result(
                    value: 0,
                    dialog: "Idle. \(today) sessions today, streak of \(streak)."
                )
            }
            return .result(value: 0, dialog: "No session running. Ready when you are.")
        }

        let remainingSeconds = Int(session.remainingTime)
        let remaining = session.formattedTime
        let phase = session.phaseLabel
        let progress = Int(session.progress * 100)
        let cycle = session.cyclePosition + 1
        let total = WatchSettings().pomodorosPerCycle

        if session.isPaused {
            return .result(
                value: remainingSeconds,
                dialog: "Paused during \(phase). \(remaining) remaining (\(progress)% done). Pomodoro \(cycle) of \(total)."
            )
        }

        return .result(
            value: remainingSeconds,
            dialog: "\(phase.capitalized): \(remaining) remaining (\(progress)% done). Pomodoro \(cycle) of \(total)."
        )
    }
}

// MARK: - Get Time Remaining

/// Focused intent that just returns seconds remaining as a number.
/// Perfect for Shortcuts automations: "If time remaining < 300, set Focus off"
struct GetTimeRemainingIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Time Remaining"
    static var description: IntentDescription = IntentDescription(
        "Returns the number of seconds remaining in the current session. 0 if idle.",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> {
        let remaining = Int(WatchSessionManager.shared.session.remainingTime)
        return .result(value: remaining)
    }
}

// MARK: - Get Streak

struct GetStreakIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Streak"
    static var description: IntentDescription = IntentDescription(
        "Returns your current consecutive-session streak count.",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let session = WatchSessionManager.shared.session
        let streak = session.currentStreak
        let today = session.todayCount

        if streak == 0 && today == 0 {
            return .result(value: 0, dialog: "No sessions yet today. Start one!")
        }

        return .result(
            value: streak,
            dialog: "\(today) sessions today. Streak: \(streak)."
        )
    }
}

// MARK: - Get Today Count

struct GetTodayCountIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Today's Sessions"
    static var description: IntentDescription = IntentDescription(
        "Returns how many Pomodoro sessions you've completed today.",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let today = WatchSessionManager.shared.session.todayCount
        return .result(
            value: today,
            dialog: "\(today) session\(today == 1 ? "" : "s") completed today."
        )
    }
}

// MARK: - Get Session Phase

/// Returns the current phase as an enum value. Useful for conditional Shortcuts:
/// "If phase is focus, don't interrupt. If idle, start a new one."
struct GetSessionPhaseIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Session Phase"
    static var description: IntentDescription = IntentDescription(
        "Returns the current session phase: idle, focus, break, paused, or completed.",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let session = WatchSessionManager.shared.session
        let phase: String
        if session.isPaused {
            phase = "paused"
        } else if session.isInBreak {
            phase = "break"
        } else if session.isRunning {
            phase = "focus"
        } else {
            phase = "idle"
        }
        return .result(value: phase)
    }
}

// MARK: - Get Cycle Position

struct GetCyclePositionIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Cycle Position"
    static var description: IntentDescription = IntentDescription(
        "Returns which pomodoro you're on in the current cycle (1-based).",
        categoryName: "Status"
    )
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ReturnsValue<Int> & ProvidesDialog {
        let session = WatchSessionManager.shared.session
        let pos = session.cyclePosition + 1
        let total = WatchSettings().pomodorosPerCycle
        return .result(
            value: pos,
            dialog: "Pomodoro \(pos) of \(total) in current cycle."
        )
    }
}

// MARK: - App Shortcuts Provider

struct TempoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        // Primary — this is the one for the Action Button
        AppShortcut(
            intent: StartPomodoroIntent(),
            phrases: [
                "Start a pomodoro with \(.applicationName)",
                "Start focus with \(.applicationName)",
                "Begin a session in \(.applicationName)",
                "\(.applicationName) focus",
                "Focus time with \(.applicationName)",
                "Start \(.applicationName)",
                "Let's go \(.applicationName)"
            ],
            shortTitle: "Start Pomodoro",
            systemImageName: "timer"
        )

        AppShortcut(
            intent: StopSessionIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "End session in \(.applicationName)",
                "Cancel pomodoro with \(.applicationName)"
            ],
            shortTitle: "Stop Session",
            systemImageName: "stop.fill"
        )

        AppShortcut(
            intent: TogglePauseIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Resume \(.applicationName)",
                "Toggle \(.applicationName)"
            ],
            shortTitle: "Pause / Resume",
            systemImageName: "pause.fill"
        )

        AppShortcut(
            intent: ExtendSessionIntent(),
            phrases: [
                "Extend \(.applicationName)",
                "Add time to \(.applicationName)",
                "More time with \(.applicationName)"
            ],
            shortTitle: "Extend Session",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: CheckStatusIntent(),
            phrases: [
                "How much time in \(.applicationName)",
                "Check \(.applicationName)",
                "\(.applicationName) status",
                "Am I in focus with \(.applicationName)"
            ],
            shortTitle: "Check Status",
            systemImageName: "clock"
        )

        AppShortcut(
            intent: GetStreakIntent(),
            phrases: [
                "My \(.applicationName) streak",
                "How many pomodoros today with \(.applicationName)"
            ],
            shortTitle: "Get Streak",
            systemImageName: "flame"
        )
    }
}
