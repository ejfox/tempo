//
//  WatchPomodoroSession.swift
//  TempoWatch
//
//  Time-based session model for watchOS.
//  Uses absolute timestamps so remaining time is always derived, never drifts.
//

import Foundation

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
    let cyclePosition: Int?

    init(isActive: Bool, startTime: Date, totalDuration: TimeInterval,
         workDuration: TimeInterval, breakDuration: TimeInterval,
         remainingTime: TimeInterval, currentStreak: Int, todayCount: Int,
         sessionType: String, isInBreak: Bool, lastUpdateTime: Date,
         cyclePosition: Int = 0) {
        self.isActive = isActive
        self.startTime = startTime
        self.totalDuration = totalDuration
        self.workDuration = workDuration
        self.breakDuration = breakDuration
        self.remainingTime = remainingTime
        self.currentStreak = currentStreak
        self.todayCount = todayCount
        self.sessionType = sessionType
        self.isInBreak = isInBreak
        self.lastUpdateTime = lastUpdateTime
        self.cyclePosition = cyclePosition
    }
}

// MARK: - Session Model

@Observable
class WatchPomodoroSession {

    // MARK: - Types

    enum SessionState: Equatable {
        case idle
        case running(type: SessionType, startTime: Date, duration: TimeInterval)
        case paused(type: SessionType, remaining: TimeInterval)
        case breakPending(type: SessionType, breakDuration: TimeInterval)
        case breakTime(startTime: Date, duration: TimeInterval)
        case breakPaused(remaining: TimeInterval, duration: TimeInterval)
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

    // MARK: - Lifecycle

    init() {
        restoreStats()
    }

    // MARK: - State

    var state: SessionState = .idle
    var currentStreak: Int = 0
    var todayCount: Int = 0
    var lastUpdateTime: Date = Date()

    /// Position within the current Pomodoro cycle (0-indexed, 0 to pomodorosPerCycle-1)
    var cyclePosition: Int = 0
    /// Remembers last work duration for auto-restart
    var lastWorkDuration: TimeInterval = 25 * 60

    /// Quarter milestones already fired this phase (25, 50, 75).
    var firedMilestones: Set<Int> = []
    /// Prevents duplicate countdown haptics for the same second.
    var lastCountdownSecond: Int = -1
    /// Prevents duplicate minute boundary haptics.
    var lastMinuteFired: Int = -1

    // MARK: - Presets

    static let durationPresets = SessionDefaults.durationPresets
    static let defaultPresetIndex = SessionDefaults.defaultPresetIndex

    static func sessionType(forMinutes minutes: TimeInterval, breakRatio: Double = 0.2) -> SessionType {
        let workSeconds = minutes * 60
        let breakSeconds = workSeconds * breakRatio
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
        case .paused(_, let remaining), .breakPaused(let remaining, _):
            return remaining
        case .breakPending(_, let breakDuration):
            return breakDuration
        default:
            return 0
        }
    }

    var totalDuration: TimeInterval {
        switch state {
        case .running(_, _, let d), .breakTime(_, let d): return d
        case .paused(let type, _): return type.workDuration
        case .breakPaused(_, let duration): return duration
        case .breakPending(_, let breakDuration): return breakDuration
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
        default: return true // includes breakPending
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

    var isBreakPending: Bool {
        if case .breakPending = state { return true }
        return false
    }

    var phaseLabel: String {
        switch state {
        case .running:              return "focus"
        case .paused, .breakPaused: return "paused"
        case .breakPending:         return "break ready"
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
        case .running(let type, _, _), .paused(let type, _), .breakPending(let type, _):
            return type.workDuration
        default: return 25 * 60
        }
    }

    var breakDuration: TimeInterval {
        switch state {
        case .running(let type, _, _), .paused(let type, _): return type.breakDuration
        case .breakPending(_, let d): return d
        case .breakTime(_, let d): return d
        case .breakPaused(_, let d): return d
        default: return 5 * 60
        }
    }

    var sessionTypeString: String {
        switch state {
        case .running(let type, _, _), .paused(let type, _), .breakPending(let type, _):
            return type.syncString
        default:
            return "short"
        }
    }

    // MARK: - Actions

    func startSession(type: SessionType) {
        lastWorkDuration = type.workDuration
        state = .running(type: type, startTime: Date(), duration: type.workDuration)
        lastUpdateTime = Date()
        resetTracking()
    }

    func stopSession() {
        state = .idle
        lastUpdateTime = Date()
        resetTracking()
        saveStats()
    }

    func pauseSession() {
        let remaining = remainingTime
        switch state {
        case .running(let type, _, _):
            state = .paused(type: type, remaining: remaining)
        case .breakTime(_, let duration):
            state = .breakPaused(remaining: remaining, duration: duration)
        default:
            break
        }
        lastUpdateTime = Date()
    }

    func resumeSession() {
        switch state {
        case .paused(let type, let remaining):
            state = .running(type: type, startTime: Date(), duration: remaining)
        case .breakPaused(let remaining, _):
            state = .breakTime(startTime: Date(), duration: remaining)
        default:
            break
        }
        lastUpdateTime = Date()
    }

    func resetToIdle() {
        state = .idle
    }

    /// Start a break that was pending user confirmation (autoStartBreak is off).
    func startPendingBreak() {
        switch state {
        case .breakPending(_, let breakDuration):
            state = .breakTime(startTime: Date(), duration: breakDuration)
            resetTracking()
        default:
            break
        }
        lastUpdateTime = Date()
    }

    /// Extend the current focus session by adding more seconds.
    /// Works for both running and paused states.
    func extend(bySeconds seconds: TimeInterval) {
        switch state {
        case .running(let type, let start, let duration):
            let newDuration = duration + seconds
            let newType = SessionType.custom(work: newDuration, break: type.breakDuration)
            state = .running(type: newType, startTime: start, duration: newDuration)
        case .paused(let type, let remaining):
            let newRemaining = remaining + seconds
            let newType = SessionType.custom(work: type.workDuration + seconds, break: type.breakDuration)
            state = .paused(type: newType, remaining: newRemaining)
        default:
            break
        }
        lastUpdateTime = Date()
    }

    // MARK: - Tick Processing

    /// Called every second while running. Returns events for the manager to dispatch haptics.
    /// Cycle configuration is passed through from the manager (session stays settings-agnostic).
    func tick(
        pomodorosPerCycle: Int = 4,
        longBreakDuration: TimeInterval = 15 * 60,
        autoStartBreak: Bool = true,
        autoStartNextFocus: Bool = false
    ) -> [SessionEvent] {
        guard isRunning else { return [] }

        var events: [SessionEvent] = []
        let remaining = remainingTime
        let prog = progress

        for quarter in SessionDefaults.milestonePercentages where !firedMilestones.contains(quarter) {
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

        if secondsInt > 0 && secondsInt <= SessionDefaults.countdownSeconds && secondsInt != lastCountdownSecond {
            lastCountdownSecond = secondsInt
            events.append(.countdown(secondsInt))
        }

        // Phase completion
        if remaining <= 0 {
            events.append(contentsOf: completeCurrentPhase(
                pomodorosPerCycle: pomodorosPerCycle,
                longBreakDuration: longBreakDuration,
                autoStartBreak: autoStartBreak,
                autoStartNextFocus: autoStartNextFocus
            ))
        }

        lastUpdateTime = Date()
        return events
    }

    // MARK: - Phase Completion (Cycle Logic)

    private func completeCurrentPhase(
        pomodorosPerCycle: Int,
        longBreakDuration: TimeInterval,
        autoStartBreak: Bool,
        autoStartNextFocus: Bool
    ) -> [SessionEvent] {
        switch state {
        case .running(let type, _, _):
            // Work phase completed — determine break duration
            let isLongBreak = cyclePosition == (pomodorosPerCycle - 1)
            let breakDur = isLongBreak ? longBreakDuration : type.breakDuration

            if autoStartBreak {
                state = .breakTime(startTime: Date(), duration: breakDur)
            } else {
                state = .breakPending(type: type, breakDuration: breakDur)
            }
            resetTracking()
            return isLongBreak ? [.phaseComplete, .cycleBreakStarted] : [.phaseComplete]

        case .breakTime:
            todayCount += 1
            currentStreak += 1
            cyclePosition = (cyclePosition + 1) % pomodorosPerCycle
            let isCycleComplete = cyclePosition == 0
            resetTracking()
            saveStats()

            if autoStartNextFocus {
                return isCycleComplete
                    ? [.cycleComplete, .autoStartNext]
                    : [.sessionComplete, .autoStartNext]
            } else {
                state = .completed
                return isCycleComplete ? [.cycleComplete] : [.sessionComplete]
            }

        default:
            return []
        }
    }

    private func resetTracking() {
        firedMilestones = []
        lastCountdownSecond = -1
        lastMinuteFired = -1
    }

    // MARK: - Persistence

    static let sharedSuite = UserDefaults(suiteName: AppGroup.suiteName) ?? .standard

    private static var migrated = false

    /// One-time migration from .standard to shared suite
    private func migrateIfNeeded() {
        guard !Self.migrated else { return }
        Self.migrated = true
        let shared = Self.sharedSuite
        guard shared.object(forKey: SessionKey.migrated.rawValue) == nil else { return }
        let old = UserDefaults.standard
        for key in [SessionKey.todayCount, .currentStreak, .cyclePosition, .lastSaveDate] {
            if let val = old.object(forKey: key.rawValue) {
                shared.set(val, forKey: key.rawValue)
            }
        }
        shared.set(true, forKey: SessionKey.migrated.rawValue)
    }

    func saveStats() {
        let d = Self.sharedSuite
        d.set(todayCount, forKey: SessionKey.todayCount.rawValue)
        d.set(currentStreak, forKey: SessionKey.currentStreak.rawValue)
        d.set(cyclePosition, forKey: SessionKey.cyclePosition.rawValue)
        d.set(Date(), forKey: SessionKey.lastSaveDate.rawValue)
    }

    func restoreStats() {
        migrateIfNeeded()
        let d = Self.sharedSuite
        todayCount = d.integer(forKey: SessionKey.todayCount.rawValue)
        currentStreak = d.integer(forKey: SessionKey.currentStreak.rawValue)
        cyclePosition = d.integer(forKey: SessionKey.cyclePosition.rawValue)
    }

    func resetDailyStatsIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        if let lastSave = Self.sharedSuite.object(forKey: SessionKey.lastSaveDate.rawValue) as? Date,
           !calendar.isDate(lastSave, inSameDayAs: today) {
            todayCount = 0
            cyclePosition = 0
            saveStats()
        }
    }
}

// MARK: - Session Events

enum SessionEvent {
    case quarterMilestone(Int)
    case minuteBoundary
    case countdown(Int)
    case phaseComplete
    case sessionComplete
    case cycleBreakStarted   // long break begins (4th pomodoro earned it)
    case cycleComplete       // full cycle of N pomodoros finished
    case autoStartNext       // auto-start next focus session
}

// MARK: - Comparable Clamping

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
