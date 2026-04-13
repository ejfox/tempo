//
//  WatchHaptics.swift
//  TempoWatch
//
//  Data-driven haptic sequences — each pattern is declared as data,
//  not code. Like sheet music for the Taptic Engine.
//

import WatchKit

// MARK: - Haptic Sequence

/// A timed sequence of haptic feedback events.
/// Declare patterns as data; the engine plays them.
struct HapticSequence {
    let steps: [(delay: TimeInterval, type: WKHapticType)]

    func play() {
        let device = WKInterfaceDevice.current()
        for step in steps {
            if step.delay == 0 {
                device.play(step.type)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + step.delay) {
                    device.play(step.type)
                }
            }
        }
    }
}

// MARK: - Pattern Library

enum WatchHaptics {

    // MARK: - Session Lifecycle

    /// Confident launch — rising double tap
    static let sessionStart = HapticSequence(steps: [
        (0,    .start),
        (0.12, .click),
        (0.25, .directionUp),
    ])

    /// Clean stop — descending close
    static let sessionStop = HapticSequence(steps: [
        (0,    .directionDown),
        (0.15, .stop),
    ])

    /// Work phase complete → break begins
    static let phaseComplete = HapticSequence(steps: [
        (0,    .success),
        (0.2,  .directionUp),
        (0.45, .click),
    ])

    /// Full session complete — celebration
    static let sessionComplete = HapticSequence(steps: [
        (0,    .success),
        (0.12, .success),
        (0.3,  .directionUp),
        (0.5,  .notification),
        (0.75, .success),
    ])

    /// Full cycle complete — the big one. Earned the long break.
    static let cycleComplete = HapticSequence(steps: [
        (0,    .success),
        (0.15, .success),
        (0.30, .success),
        (0.50, .directionUp),
        (0.65, .notification),
        (0.85, .success),
        (1.00, .notification),
    ])

    /// Long break starting — warm, earned
    static let cycleBreakStart = HapticSequence(steps: [
        (0,   .success),
        (0.2, .directionDown),
        (0.4, .click),
    ])

    // MARK: - In-Session Feedback

    /// Minute boundary tick
    static let minuteTick = HapticSequence(steps: [(0, .click)])

    /// Quarter-session milestone (25%, 50%, 75%)
    static let quarterMilestone = HapticSequence(steps: [
        (0,   .click),
        (0.1, .directionUp),
    ])

    // MARK: - Controls

    /// Pause — gentle double click
    static let pause = HapticSequence(steps: [
        (0,    .click),
        (0.08, .click),
    ])

    /// Resume — confident restart
    static let resume = HapticSequence(steps: [(0, .start)])

    /// Crown snapped to a preset
    static let crownSnap = HapticSequence(steps: [(0, .click)])

    /// Crown landed on the 25-min detent — vault lock engaging
    static let crownDetent = HapticSequence(steps: [
        (0,    .click),
        (0.04, .click),
        (0.10, .directionDown),
    ])

    /// Confirmation before destructive action
    static let confirmWarning = HapticSequence(steps: [
        (0,   .retry),
        (0.3, .retry),
    ])

    /// Remote session joined from another device
    static let remoteSessionJoined = HapticSequence(steps: [(0, .notification)])

    // MARK: - Countdown

    /// Final countdown tick — escalates as it approaches zero
    static func countdownTick(secondsRemaining: Int) {
        switch secondsRemaining {
        case 1:
            WKInterfaceDevice.current().play(.directionUp)
        case 2...5:
            WKInterfaceDevice.current().play(.click)
        default:
            break
        }
    }
}
