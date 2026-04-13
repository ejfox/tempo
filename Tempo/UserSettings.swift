//
//  UserSettings.swift
//  Tempo
//
//  User-configurable settings. Persisted via shared App Group UserDefaults
//  so the widget extension can read them too. Matches WatchSettings API.
//

import SwiftUI

@Observable
class UserSettings {

    // MARK: - Timer Behavior

    var shortWorkDuration: TimeInterval { didSet { save() } }
    var shortBreakDuration: TimeInterval { didSet { save() } }
    var longWorkDuration: TimeInterval { didSet { save() } }
    var longBreakDuration: TimeInterval { didSet { save() } }

    var breakRatio: Double { didSet { save() } }
    var autoStartBreak: Bool { didSet { save() } }
    var autoStartNextFocus: Bool { didSet { save() } }
    var longBreakMinutes: Double { didSet { save() } }
    var pomodorosPerCycle: Int { didSet { save() } }

    // MARK: - Haptics

    var hapticsEnabled: Bool { didSet { save() } }
    var milestoneHaptics: Bool { didSet { save() } }
    var countdownHaptics: Bool { didSet { save() } }
    var minuteMarkHaptics: Bool { didSet { save() } }
    var phaseCompleteHaptics: Bool { didSet { save() } }
    var sessionCompleteHaptics: Bool { didSet { save() } }
    var cycleCompleteHaptics: Bool { didSet { save() } }

    // MARK: - Visuals

    var invertBreakColors: Bool { didSet { save() } }

    var focusColorChoice: ColorChoice { didSet { save() } }
    var breakColorChoice: ColorChoice { didSet { save() } }

    enum ColorChoice: String, CaseIterable, Identifiable {
        case white, cyan, orange, green, pink, yellow
        var id: String { rawValue }

        var color: Color {
            switch self {
            case .white:  return .white
            case .cyan:   return .cyan
            case .orange: return .orange
            case .green:  return .green
            case .pink:   return .pink
            case .yellow: return .yellow
            }
        }
    }

    var focusColor: Color { focusColorChoice.color }
    var breakColor: Color { breakColorChoice.color }

    // MARK: - Session Types

    var shortSessionType: PomodoroSession.SessionType {
        .short(work: shortWorkDuration, break: shortWorkDuration * breakRatio)
    }

    var longSessionType: PomodoroSession.SessionType {
        .long(work: longWorkDuration, break: longWorkDuration * breakRatio)
    }

    // MARK: - Persistence

    private let defaults = UserDefaults(suiteName: AppGroup.suiteName) ?? .standard
    private var saveTask: Task<Void, Never>?

    init() {
        shortWorkDuration   = defaults.object(forKey: "shortWorkDuration") as? TimeInterval ?? 25 * 60
        shortBreakDuration  = defaults.object(forKey: "shortBreakDuration") as? TimeInterval ?? 5 * 60
        longWorkDuration    = defaults.object(forKey: "longWorkDuration") as? TimeInterval ?? 50 * 60
        longBreakDuration   = defaults.object(forKey: "longBreakDuration") as? TimeInterval ?? 10 * 60
        breakRatio          = defaults.object(forKey: "breakRatio") as? Double ?? 0.2
        autoStartBreak      = defaults.object(forKey: "autoStartBreak") as? Bool ?? true
        autoStartNextFocus  = defaults.object(forKey: "autoStartNextFocus") as? Bool ?? false
        longBreakMinutes    = defaults.object(forKey: "longBreakMinutes") as? Double ?? 15
        pomodorosPerCycle   = defaults.object(forKey: "pomodorosPerCycle") as? Int ?? 4
        hapticsEnabled      = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        milestoneHaptics    = defaults.object(forKey: "milestoneHaptics") as? Bool ?? true
        countdownHaptics    = defaults.object(forKey: "countdownHaptics") as? Bool ?? true
        minuteMarkHaptics   = defaults.object(forKey: "minuteMarkHaptics") as? Bool ?? false
        phaseCompleteHaptics = defaults.object(forKey: "phaseCompleteHaptics") as? Bool ?? true
        sessionCompleteHaptics = defaults.object(forKey: "sessionCompleteHaptics") as? Bool ?? true
        cycleCompleteHaptics = defaults.object(forKey: "cycleCompleteHaptics") as? Bool ?? true
        invertBreakColors   = defaults.object(forKey: "invertBreakColors") as? Bool ?? true
        focusColorChoice    = ColorChoice(rawValue: defaults.string(forKey: "focusColor") ?? "white") ?? .white
        breakColorChoice    = ColorChoice(rawValue: defaults.string(forKey: "breakColor") ?? "cyan") ?? .cyan
    }

    private func save() {
        saveTask?.cancel()
        saveTask = Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        defaults.set(shortWorkDuration, forKey: "shortWorkDuration")
        defaults.set(shortBreakDuration, forKey: "shortBreakDuration")
        defaults.set(longWorkDuration, forKey: "longWorkDuration")
        defaults.set(longBreakDuration, forKey: "longBreakDuration")
        defaults.set(breakRatio, forKey: "breakRatio")
        defaults.set(autoStartBreak, forKey: "autoStartBreak")
        defaults.set(autoStartNextFocus, forKey: "autoStartNextFocus")
        defaults.set(longBreakMinutes, forKey: "longBreakMinutes")
        defaults.set(pomodorosPerCycle, forKey: "pomodorosPerCycle")
        defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
        defaults.set(milestoneHaptics, forKey: "milestoneHaptics")
        defaults.set(countdownHaptics, forKey: "countdownHaptics")
        defaults.set(minuteMarkHaptics, forKey: "minuteMarkHaptics")
        defaults.set(phaseCompleteHaptics, forKey: "phaseCompleteHaptics")
        defaults.set(sessionCompleteHaptics, forKey: "sessionCompleteHaptics")
        defaults.set(cycleCompleteHaptics, forKey: "cycleCompleteHaptics")
        defaults.set(invertBreakColors, forKey: "invertBreakColors")
        defaults.set(focusColorChoice.rawValue, forKey: "focusColor")
        defaults.set(breakColorChoice.rawValue, forKey: "breakColor")
    }
}
