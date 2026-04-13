//
//  iOSHaptics.swift
//  Tempo
//
//  iOS haptic feedback patterns. Same vocabulary as WatchHaptics,
//  adapted for UIKit feedback generators.
//

import UIKit

enum iOSHaptics {

    // MARK: - Session Lifecycle

    static func sessionStart() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred(intensity: 0.8)
        after(0.1) {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.4)
        }
    }

    static func sessionStop() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    static func phaseComplete() {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(.success)
        after(0.15) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.6)
        }
    }

    static func sessionComplete() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        after(0.1) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        after(0.2) { UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7) }
        after(0.3) { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5) }
    }

    static func cycleComplete() {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.impactOccurred()
        after(0.1) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        after(0.25) { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 0.8) }
        after(0.4) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        after(0.6) { UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.6) }
    }

    static func cycleBreakStart() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        after(0.2) { UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.5) }
    }

    // MARK: - In-Session

    static func quarterMilestone() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
    }

    static func minuteTick() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.3)
    }

    static func countdownTick(secondsRemaining: Int) {
        switch secondsRemaining {
        case 1:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.8)
        case 2...5:
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        default:
            break
        }
    }

    // MARK: - Controls

    static func pause() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.5)
        after(0.08) { UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.3) }
    }

    static func resume() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.7)
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func confirmWarning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        after(0.3) { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }

    // MARK: - Utility

    private static func after(_ delay: TimeInterval, _ action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: action)
    }
}
