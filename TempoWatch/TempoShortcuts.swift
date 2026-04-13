//
//  TempoShortcuts.swift
//  TempoWatch
//
//  Registers App Shortcuts for Siri, Shortcuts app, and Action Button.
//  Primary shortcut: "Start Pomodoro" → assign to Action Button.
//

import AppIntents

struct TempoShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
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
