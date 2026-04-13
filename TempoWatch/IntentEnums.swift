//
//  IntentEnums.swift
//  TempoWatch
//
//  AppEnum types used as parameters in App Intents.
//

import AppIntents

/// Predefined focus durations, surfaced as a Siri/Shortcuts parameter.
enum FocusDuration: Int, AppEnum {
    case five = 5, ten = 10, fifteen = 15, twenty = 20
    case twentyFive = 25, thirty = 30, fortyFive = 45, fifty = 50, sixty = 60

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Duration"

    static var caseDisplayRepresentations: [FocusDuration: DisplayRepresentation] {
        [
            .five: "5 minutes",     .ten: "10 minutes",      .fifteen: "15 minutes",
            .twenty: "20 minutes",  .twentyFive: "25 minutes", .thirty: "30 minutes",
            .fortyFive: "45 minutes", .fifty: "50 minutes",    .sixty: "60 minutes"
        ]
    }
}

/// Session phase reported by status intents.
enum SessionPhase: String, AppEnum {
    case idle, focus
    case breakTime = "break"
    case paused, completed

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Session Phase"

    static var caseDisplayRepresentations: [SessionPhase: DisplayRepresentation] {
        [.idle: "Idle", .focus: "Focus", .breakTime: "Break", .paused: "Paused", .completed: "Completed"]
    }
}
