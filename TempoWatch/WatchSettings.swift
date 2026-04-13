//
//  WatchSettings.swift
//  TempoWatch
//
//  User-configurable visual and behavior settings.
//  Persisted via UserDefaults, synced to watch.
//

import SwiftUI

@Observable
class WatchSettings {

    // MARK: - Timer Behavior

    /// Break duration as ratio of work duration (0.1 = 10%, 0.2 = 20%, etc.)
    var breakRatio: Double {
        didSet { save() }
    }

    /// Auto-start break when focus ends (vs. requiring a tap)
    var autoStartBreak: Bool {
        didSet { save() }
    }

    /// Auto-start next focus when break ends
    var autoStartNextFocus: Bool {
        didSet { save() }
    }

    /// Duration of long break after completing a full cycle (in minutes)
    var longBreakMinutes: Double {
        didSet { save() }
    }

    /// Number of pomodoros per cycle before a long break (2, 3, or 4)
    var pomodorosPerCycle: Int {
        didSet { save() }
    }

    // MARK: - Haptics

    /// Master haptic toggle
    var hapticsEnabled: Bool {
        didSet { save() }
    }

    /// Haptic at quarter milestones (25%, 50%, 75%)
    var milestoneHaptics: Bool {
        didSet { save() }
    }

    /// Haptic countdown in last 5 seconds
    var countdownHaptics: Bool {
        didSet { save() }
    }

    /// Haptic at 5-minute interval marks
    var minuteMarkHaptics: Bool {
        didSet { save() }
    }

    /// Haptic on phase completion (focus → break)
    var phaseCompleteHaptics: Bool {
        didSet { save() }
    }

    /// Haptic on full session completion
    var sessionCompleteHaptics: Bool {
        didSet { save() }
    }

    /// Haptic on cycle completion (all pomodoros in a set)
    var cycleCompleteHaptics: Bool {
        didSet { save() }
    }

    /// Push notification alerts as session approaches end (halfway, 5m, 2m, 1m)
    var approachingEndAlerts: Bool {
        didSet { save() }
    }

    // MARK: - Visuals

    /// Edge trace line thickness (3–8 pt)
    var edgeLineWidth: Double {
        didSet { save() }
    }

    /// Show the glow bloom on the edge trace
    var edgeGlow: Bool {
        didSet { save() }
    }

    /// Invert colors during break (white bg, dark text)
    var invertBreakColors: Bool {
        didSet { save() }
    }

    /// Show streak dots during session
    var showStreakDots: Bool {
        didSet { save() }
    }

    /// Focus accent color
    var focusColorChoice: ColorChoice {
        didSet { save() }
    }

    /// Break accent color (used when invertBreakColors is off)
    var breakColorChoice: ColorChoice {
        didSet { save() }
    }

    // MARK: - Color Choices

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

        var label: String { rawValue }
    }

    // MARK: - Slot Customization

    enum InfoSlotContent: String, CaseIterable, Identifiable, Codable {
        case phaseLabel, cycleIndicator, streakCount, todayCount, none
        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .phaseLabel:      return "phase"
            case .cycleIndicator:  return "cycle"
            case .streakCount:     return "streak"
            case .todayCount:      return "today"
            case .none:            return "none"
            }
        }
    }

    enum EdgeStyle: String, CaseIterable, Identifiable, Codable {
        case thin, thick, none, pulse
        var id: String { rawValue }
        var displayName: String { rawValue }
    }

    /// Info line above the timer in active session
    var activeTopSlot: InfoSlotContent {
        didSet { save() }
    }

    /// Info line below the timer in active session
    var activeBottomSlot: InfoSlotContent {
        didSet { save() }
    }

    /// Edge trace style during active session
    var activeEdgeStyle: EdgeStyle {
        didSet { save() }
    }

    /// Stats shown on the idle/selector screen
    var idleStatsSlot: InfoSlotContent {
        didSet { save() }
    }

    // MARK: - Computed

    var focusColor: Color { focusColorChoice.color }
    var breakColor: Color { breakColorChoice.color }

    // MARK: - Init / Persistence

    private let defaults = UserDefaults(suiteName: AppGroup.suiteName) ?? .standard

    private static let settingsKeys = [
        "breakRatio", "autoStartBreak", "autoStartNextFocus",
        "hapticsEnabled", "milestoneHaptics", "countdownHaptics", "minuteMarkHaptics",
        "phaseCompleteHaptics", "sessionCompleteHaptics", "cycleCompleteHaptics",
        "approachingEndAlerts", "longBreakMinutes", "pomodorosPerCycle",
        "edgeLineWidth", "edgeGlow", "invertBreakColors", "showStreakDots",
        "focusColor", "breakColor",
        "activeTopSlot", "activeBottomSlot", "activeEdgeStyle", "idleStatsSlot"
    ]

    /// One-time migration from .standard to shared App Group suite
    private static func migrateFromStandardIfNeeded(to shared: UserDefaults) {
        guard shared.object(forKey: "settings.migrated") == nil else { return }
        let old = UserDefaults.standard
        for key in settingsKeys {
            if let val = old.object(forKey: key) {
                shared.set(val, forKey: key)
            }
        }
        shared.set(true, forKey: "settings.migrated")
    }

    init() {
        Self.migrateFromStandardIfNeeded(to: defaults)
        breakRatio       = defaults.object(forKey: "breakRatio") as? Double ?? 0.2
        autoStartBreak   = defaults.object(forKey: "autoStartBreak") as? Bool ?? true
        autoStartNextFocus = defaults.object(forKey: "autoStartNextFocus") as? Bool ?? false
        hapticsEnabled   = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        milestoneHaptics = defaults.object(forKey: "milestoneHaptics") as? Bool ?? true
        countdownHaptics = defaults.object(forKey: "countdownHaptics") as? Bool ?? true
        minuteMarkHaptics = defaults.object(forKey: "minuteMarkHaptics") as? Bool ?? false
        phaseCompleteHaptics = defaults.object(forKey: "phaseCompleteHaptics") as? Bool ?? true
        sessionCompleteHaptics = defaults.object(forKey: "sessionCompleteHaptics") as? Bool ?? true
        cycleCompleteHaptics = defaults.object(forKey: "cycleCompleteHaptics") as? Bool ?? true
        approachingEndAlerts = defaults.object(forKey: "approachingEndAlerts") as? Bool ?? true
        longBreakMinutes = defaults.object(forKey: "longBreakMinutes") as? Double ?? 15
        pomodorosPerCycle = defaults.object(forKey: "pomodorosPerCycle") as? Int ?? 4
        edgeLineWidth    = defaults.object(forKey: "edgeLineWidth") as? Double ?? 5
        edgeGlow         = defaults.object(forKey: "edgeGlow") as? Bool ?? true
        invertBreakColors = defaults.object(forKey: "invertBreakColors") as? Bool ?? true
        showStreakDots   = defaults.object(forKey: "showStreakDots") as? Bool ?? true
        focusColorChoice = ColorChoice(rawValue: defaults.string(forKey: "focusColor") ?? "white") ?? .white
        breakColorChoice = ColorChoice(rawValue: defaults.string(forKey: "breakColor") ?? "cyan") ?? .cyan
        activeTopSlot    = InfoSlotContent(rawValue: defaults.string(forKey: "activeTopSlot") ?? "phaseLabel") ?? .phaseLabel
        activeBottomSlot = InfoSlotContent(rawValue: defaults.string(forKey: "activeBottomSlot") ?? "streakCount") ?? .streakCount
        activeEdgeStyle  = EdgeStyle(rawValue: defaults.string(forKey: "activeEdgeStyle") ?? "thick") ?? .thick
        idleStatsSlot    = InfoSlotContent(rawValue: defaults.string(forKey: "idleStatsSlot") ?? "streakCount") ?? .streakCount
    }

    private var saveTask: Task<Void, Never>?

    private func save() {
        // Debounce: coalesce rapid changes (e.g., slider drags) into one write
        saveTask?.cancel()
        saveTask = Task { @MainActor [self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            persistNow()
        }
    }

    private func persistNow() {
        defaults.set(breakRatio, forKey: "breakRatio")
        defaults.set(autoStartBreak, forKey: "autoStartBreak")
        defaults.set(autoStartNextFocus, forKey: "autoStartNextFocus")
        defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
        defaults.set(milestoneHaptics, forKey: "milestoneHaptics")
        defaults.set(countdownHaptics, forKey: "countdownHaptics")
        defaults.set(minuteMarkHaptics, forKey: "minuteMarkHaptics")
        defaults.set(phaseCompleteHaptics, forKey: "phaseCompleteHaptics")
        defaults.set(sessionCompleteHaptics, forKey: "sessionCompleteHaptics")
        defaults.set(cycleCompleteHaptics, forKey: "cycleCompleteHaptics")
        defaults.set(approachingEndAlerts, forKey: "approachingEndAlerts")
        defaults.set(longBreakMinutes, forKey: "longBreakMinutes")
        defaults.set(pomodorosPerCycle, forKey: "pomodorosPerCycle")
        defaults.set(edgeLineWidth, forKey: "edgeLineWidth")
        defaults.set(edgeGlow, forKey: "edgeGlow")
        defaults.set(invertBreakColors, forKey: "invertBreakColors")
        defaults.set(showStreakDots, forKey: "showStreakDots")
        defaults.set(focusColorChoice.rawValue, forKey: "focusColor")
        defaults.set(breakColorChoice.rawValue, forKey: "breakColor")
        defaults.set(activeTopSlot.rawValue, forKey: "activeTopSlot")
        defaults.set(activeBottomSlot.rawValue, forKey: "activeBottomSlot")
        defaults.set(activeEdgeStyle.rawValue, forKey: "activeEdgeStyle")
        defaults.set(idleStatsSlot.rawValue, forKey: "idleStatsSlot")
    }
}
