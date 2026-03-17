//
//  WatchHaptics.swift
//  TempoWatch
//
//  Precision haptic patterns — like mechanical watch complications,
//  each feedback tells you something without looking.
//

import WatchKit

enum WatchHaptics {

    // MARK: - Session Lifecycle

    /// Confident launch — double tap with rising intensity
    static func sessionStart() {
        let device = WKInterfaceDevice.current()
        device.play(.start)
        after(0.12) { device.play(.click) }
        after(0.25) { device.play(.directionUp) }
    }

    /// Clean stop — descending close
    static func sessionStop() {
        let device = WKInterfaceDevice.current()
        device.play(.directionDown)
        after(0.15) { device.play(.stop) }
    }

    /// Work phase complete → break begins
    static func phaseComplete() {
        let device = WKInterfaceDevice.current()
        device.play(.success)
        after(0.2) { device.play(.directionUp) }
        after(0.45) { device.play(.click) }
    }

    /// Full session complete — celebration sequence
    static func sessionComplete() {
        let device = WKInterfaceDevice.current()
        device.play(.success)
        after(0.12) { device.play(.success) }
        after(0.3) { device.play(.directionUp) }
        after(0.5) { device.play(.notification) }
        after(0.75) { device.play(.success) }
    }

    // MARK: - In-Session Feedback

    /// Minute boundary tick — Swiss watch movement
    static func minuteTick() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Final countdown (last 5 seconds) — single taps, escalating only at the end
    static func countdownTick(secondsRemaining: Int) {
        let device = WKInterfaceDevice.current()
        switch secondsRemaining {
        case 1:
            device.play(.directionUp)
        case 2...3:
            device.play(.click)
        case 4...5:
            device.play(.click)
        default:
            break
        }
    }

    /// Quarter-session milestone (25%, 50%, 75%)
    static func quarterMilestone() {
        let device = WKInterfaceDevice.current()
        device.play(.click)
        after(0.1) { device.play(.directionUp) }
    }

    // MARK: - Controls

    /// Pause — gentle double click
    static func pause() {
        let device = WKInterfaceDevice.current()
        device.play(.click)
        after(0.08) { device.play(.click) }
    }

    /// Resume — confident restart
    static func resume() {
        WKInterfaceDevice.current().play(.start)
    }

    /// Crown snapped to a normal duration preset
    static func crownSnap() {
        WKInterfaceDevice.current().play(.click)
    }

    /// Crown landed on the 25-min detent — heavy, deliberate, like a vault lock engaging
    static func crownDetent() {
        let device = WKInterfaceDevice.current()
        device.play(.click)
        after(0.04) { device.play(.click) }
        after(0.10) { device.play(.directionDown) }
    }

    /// Confirmation before destructive action
    static func confirmWarning() {
        let device = WKInterfaceDevice.current()
        device.play(.retry)
        after(0.3) { device.play(.retry) }
    }

    // MARK: - Utility

    private static func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}
