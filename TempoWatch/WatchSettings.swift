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

    // MARK: - Computed

    var focusColor: Color { focusColorChoice.color }
    var breakColor: Color { breakColorChoice.color }

    var computedBreakRatio: TimeInterval {
        breakRatio
    }

    // MARK: - Init / Persistence

    private let defaults = UserDefaults.standard

    init() {
        breakRatio       = defaults.object(forKey: "breakRatio") as? Double ?? 0.2
        autoStartBreak   = defaults.object(forKey: "autoStartBreak") as? Bool ?? true
        autoStartNextFocus = defaults.object(forKey: "autoStartNextFocus") as? Bool ?? false
        hapticsEnabled   = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        milestoneHaptics = defaults.object(forKey: "milestoneHaptics") as? Bool ?? true
        countdownHaptics = defaults.object(forKey: "countdownHaptics") as? Bool ?? true
        minuteMarkHaptics = defaults.object(forKey: "minuteMarkHaptics") as? Bool ?? false
        edgeLineWidth    = defaults.object(forKey: "edgeLineWidth") as? Double ?? 5
        edgeGlow         = defaults.object(forKey: "edgeGlow") as? Bool ?? true
        invertBreakColors = defaults.object(forKey: "invertBreakColors") as? Bool ?? true
        showStreakDots   = defaults.object(forKey: "showStreakDots") as? Bool ?? true
        focusColorChoice = ColorChoice(rawValue: defaults.string(forKey: "focusColor") ?? "white") ?? .white
        breakColorChoice = ColorChoice(rawValue: defaults.string(forKey: "breakColor") ?? "cyan") ?? .cyan
    }

    private func save() {
        defaults.set(breakRatio, forKey: "breakRatio")
        defaults.set(autoStartBreak, forKey: "autoStartBreak")
        defaults.set(autoStartNextFocus, forKey: "autoStartNextFocus")
        defaults.set(hapticsEnabled, forKey: "hapticsEnabled")
        defaults.set(milestoneHaptics, forKey: "milestoneHaptics")
        defaults.set(countdownHaptics, forKey: "countdownHaptics")
        defaults.set(minuteMarkHaptics, forKey: "minuteMarkHaptics")
        defaults.set(edgeLineWidth, forKey: "edgeLineWidth")
        defaults.set(edgeGlow, forKey: "edgeGlow")
        defaults.set(invertBreakColors, forKey: "invertBreakColors")
        defaults.set(showStreakDots, forKey: "showStreakDots")
        defaults.set(focusColorChoice.rawValue, forKey: "focusColor")
        defaults.set(breakColorChoice.rawValue, forKey: "breakColor")
    }
}
