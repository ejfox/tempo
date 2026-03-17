//
//  WatchPomodoroSession.swift
//  TempoWatch
//
//  Time-based session model for watchOS.
//  Uses absolute timestamps so remaining time is always derived, never drifts.
//

import Foundation
import WatchKit

// MARK: - Sync Payload

/// Shared between iOS and watchOS for cross-device session handoff.
struct SessionSyncInfo: Codable {
    let isActive: Bool
    let startTime: Date
    let totalDuration: TimeInterval
    let workDuration: TimeInterval
    let breakDuration: TimeInterval
    let remainingTime: TimeInterval
    let currentStreak: Int
    let todayCount: Int
    let sessionType: String
    let isInBreak: Bool
    let lastUpdateTime: Date
}

// MARK: - Session Model

@Observable
class WatchPomodoroSession {

    // MARK: - Types

    enum SessionState: Equatable {
        case idle
        case running(type: SessionType, startTime: Date, duration: TimeInterval)
        case paused(type: SessionType, remaining: TimeInterval)
        case breakTime(startTime: Date, duration: TimeInterval)
        case breakPaused(remaining: TimeInterval)
        case completed
    }

    enum SessionType: Equatable {
        case short(work: TimeInterval, break: TimeInterval)
        case long(work: TimeInterval, break: TimeInterval)
        case custom(work: TimeInterval, break: TimeInterval)

        var workDuration: TimeInterval {
            switch self {
            case .short(let w, _), .long(let w, _), .custom(let w, _): return w
            }
        }

        var breakDuration: TimeInterval {
            switch self {
            case .short(_, let b), .long(_, let b), .custom(_, let b): return b
            }
        }

        /// Reconstruct from a sync string + durations.
        static func from(syncString: String, work: TimeInterval, break breakDur: TimeInterval) -> SessionType {
            switch syncString {
            case "short":  return .short(work: work, break: breakDur)
            case "long":   return .long(work: work, break: breakDur)
            default:       return .custom(work: work, break: breakDur)
            }
        }

        var syncString: String {
            switch self {
            case .short: return "short"
            case .long:  return "long"
            case .custom: return "custom"
            }
        }
    }

    // MARK: - State

    var state: SessionState = .idle
    var currentStreak: Int = 0
    var todayCount: Int = 0
    var lastUpdateTime: Date = Date()

    /// Quarter milestones already fired this phase (25, 50, 75).
    var firedMilestones: Set<Int> = []
    /// Prevents duplicate countdown haptics for the same second.
    var lastCountdownSecond: Int = -1
    /// Prevents duplicate minute boundary haptics.
    var lastMinuteFired: Int = -1

    // MARK: - Presets

    static let durationPresets: [TimeInterval] = [5, 10, 15, 20, 25, 30, 45, 50, 60]
    static let defaultPresetIndex = 4 // 25 min

    static func sessionType(forMinutes minutes: TimeInterval) -> SessionType {
        let workSeconds = minutes * 60
        let breakSeconds: TimeInterval = minutes <= 25 ? 5 * 60 : 10 * 60
        return minutes <= 25
            ? .short(work: workSeconds, break: breakSeconds)
            : .long(work: workSeconds, break: breakSeconds)
    }

    // MARK: - Derived Properties

    var remainingTime: TimeInterval {
        switch state {
        case .running(_, let start, let duration):
            return max(0, duration - Date().timeIntervalSince(start))
        case .breakTime(let start, let duration):
            return max(0, duration - Date().timeIntervalSince(start))
        case .paused(_, let remaining), .breakPaused(let remaining):
            return remaining
        default:
            return 0
        }
    }

    var totalDuration: TimeInterval {
        switch state {
        case .running(_, _, let d), .breakTime(_, let d): return d
        case .paused(let type, _): return type.workDuration
        case .breakPaused(let remaining): return remaining // approximate
        default: return 0
        }
    }

    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return (1.0 - remainingTime / totalDuration).clamped(to: 0...1)
    }

    var isRunning: Bool {
        switch state {
        case .running, .breakTime: return true
        default: return false
        }
    }

    var isActive: Bool {
        switch state {
        case .idle, .completed: return false
        default: return true
        }
    }

    var isPaused: Bool {
        switch state {
        case .paused, .breakPaused: return true
        default: return false
        }
    }

    var isInBreak: Bool {
        switch state {
        case .breakTime, .breakPaused: return true
        default: return false
        }
    }

    var phaseLabel: String {
        switch state {
        case .running:              return "focus"
        case .paused, .breakPaused: return "paused"
        case .breakTime:            return "break"
        case .completed:            return "done"
        case .idle:                 return ""
        }
    }

    var formattedTime: String {
        let total = Int(remainingTime)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    var startTime: Date {
        switch state {
        case .running(_, let t, _), .breakTime(let t, _): return t
        default: return Date()
        }
    }

    var workDuration: TimeInterval {
        switch state {
        case .running(let type, _, _), .paused(let type, _): return type.workDuration
        default: return 25 * 60
        }
    }

    var breakDuration: TimeInterval {
        switch state {
        case .running(let type, _, _), .paused(let type, _): return type.breakDuration
        case .breakTime(_, let d): return d
        case .breakPaused(let d): return d
        default: return 5 * 60
        }
    }

    var sessionTypeString: String {
        switch state {
        case .running(let type, _, _), .paused(let type, _):
            return type.syncString
        default:
            return "short"
        }
    }

    // MARK: - Actions

    func startSession(type: SessionType) {
        state = .running(type: type, startTime: Date(), duration: type.workDuration)
        lastUpdateTime = Date()
        resetTracking()
    }

    func stopSession() {
        state = .idle
        lastUpdateTime = Date()
        resetTracking()
    }

    func pauseSession() {
        let remaining = remainingTime
        switch state {
        case .running(let type, _, _):
            state = .paused(type: type, remaining: remaining)
        case .breakTime:
            state = .breakPaused(remaining: remaining)
        default:
            break
        }
        lastUpdateTime = Date()
    }

    func resumeSession() {
        switch state {
        case .paused(let type, let remaining):
            state = .running(type: type, startTime: Date(), duration: remaining)
        case .breakPaused(let remaining):
            state = .breakTime(startTime: Date(), duration: remaining)
        default:
            break
        }
        lastUpdateTime = Date()
    }

    func resetToIdle() {
        state = .idle
    }

    // MARK: - Tick Processing

    /// Called every second while running. Returns events for the manager to dispatch haptics.
    func tick() -> [SessionEvent] {
        guard isRunning else { return [] }

        var events: [SessionEvent] = []
        let remaining = remainingTime
        let prog = progress

        // Quarter milestones (25%, 50%, 75%)
        for quarter in [25, 50, 75] where !firedMilestones.contains(quarter) {
            if prog >= Double(quarter) / 100.0 {
                firedMilestones.insert(quarter)
                events.append(.quarterMilestone(quarter))
            }
        }

        let secondsInt = Int(remaining)
        let currentMinute = secondsInt / 60

        // Minute boundary — only at 5-minute marks for long sessions,
        // skip entirely for short ones (milestones are enough).
        // Never fires on the first tick or last 10 seconds.
        if secondsInt > 10 && secondsInt % 60 == 0 && currentMinute != lastMinuteFired {
            let totalMinutes = Int(totalDuration) / 60
            let isFiveMinMark = currentMinute % 5 == 0
            // Only fire at 5-min marks for sessions > 15 min, skip for shorter ones
            if totalMinutes > 15 && isFiveMinMark && currentMinute > 0 {
                lastMinuteFired = currentMinute
                events.append(.minuteBoundary)
            }
        }

        // Final countdown (last 5 seconds only — 10 was too noisy)
        if secondsInt > 0 && secondsInt <= 5 && secondsInt != lastCountdownSecond {
            lastCountdownSecond = secondsInt
            events.append(.countdown(secondsInt))
        }

        // Phase completion
        if remaining <= 0 {
            events.append(contentsOf: completeCurrentPhase())
        }

        lastUpdateTime = Date()
        return events
    }

    // MARK: - Private

    private func completeCurrentPhase() -> [SessionEvent] {
        switch state {
        case .running(let type, _, _):
            state = .breakTime(startTime: Date(), duration: type.breakDuration)
            resetTracking()
            return [.phaseComplete]

        case .breakTime:
            todayCount += 1
            currentStreak += 1
            state = .completed
            resetTracking()
            return [.sessionComplete]

        default:
            return []
        }
    }

    private func resetTracking() {
        firedMilestones = []
        lastCountdownSecond = -1
        lastMinuteFired = -1
    }
}

// MARK: - Session Events

enum SessionEvent {
    case quarterMilestone(Int)
    case minuteBoundary
    case countdown(Int)
    case phaseComplete
    case sessionComplete
}

// MARK: - Comparable Clamping

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
