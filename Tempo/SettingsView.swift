//
//  SettingsView.swift
//  Tempo
//
//  iOS settings: behavior, haptics, appearance.
//

import SwiftUI

struct SettingsTab: View {
    @Environment(SessionManager.self) private var manager

    var body: some View {
        @Bindable var s = manager.userSettings

        NavigationStack {
            List {
                // MARK: - Behavior
                Section("Behavior") {
                    Picker("Break ratio", selection: $s.breakRatio) {
                        Text("10%").tag(0.1)
                        Text("20%").tag(0.2)
                        Text("33%").tag(1.0 / 3.0)
                        Text("50%").tag(0.5)
                    }

                    Toggle("Auto-start break", isOn: $s.autoStartBreak)
                    Toggle("Auto-start next focus", isOn: $s.autoStartNextFocus)

                    Picker("Long break", selection: $s.longBreakMinutes) {
                        Text("15 min").tag(15.0)
                        Text("20 min").tag(20.0)
                        Text("25 min").tag(25.0)
                        Text("30 min").tag(30.0)
                    }

                    Picker("Pomodoros per cycle", selection: $s.pomodorosPerCycle) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                }

                // MARK: - Haptics
                Section("Haptics") {
                    Toggle("Haptic feedback", isOn: $s.hapticsEnabled)

                    if s.hapticsEnabled {
                        Toggle("Quarter milestones", isOn: $s.milestoneHaptics)
                        Toggle("Final countdown", isOn: $s.countdownHaptics)
                        Toggle("5-min marks", isOn: $s.minuteMarkHaptics)
                        Toggle("Phase complete", isOn: $s.phaseCompleteHaptics)
                        Toggle("Session complete", isOn: $s.sessionCompleteHaptics)
                        Toggle("Cycle complete", isOn: $s.cycleCompleteHaptics)
                    }
                }

                // MARK: - Customize
                Section("Customize") {
                    Picker("Top info", selection: $s.activeTopSlot) {
                        ForEach(UserSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }

                    Picker("Bottom info", selection: $s.activeBottomSlot) {
                        ForEach(UserSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }

                    Picker("Edge style", selection: $s.activeEdgeStyle) {
                        ForEach(UserSettings.EdgeStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }

                    Picker("Idle stats", selection: $s.idleStatsSlot) {
                        ForEach(UserSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                }

                // MARK: - Appearance
                Section("Appearance") {
                    Toggle("Invert colors on break", isOn: $s.invertBreakColors)
                    Toggle("Show streak dots", isOn: $s.showStreakDots)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Edge width: \(Int(s.edgeLineWidth))pt")
                        Slider(value: $s.edgeLineWidth, in: 2...8, step: 1)
                    }

                    Toggle("Edge glow", isOn: $s.edgeGlow)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Focus color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ColorRow(selection: $s.focusColorChoice)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Break color")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ColorRow(selection: $s.breakColorChoice)
                    }
                }

                // MARK: - About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Color Row

struct ColorRow: View {
    @Binding var selection: UserSettings.ColorChoice

    var body: some View {
        HStack(spacing: 8) {
            ForEach(UserSettings.ColorChoice.allCases) { choice in
                Circle()
                    .fill(choice.color)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selection == choice ? 2.5 : 0)
                    )
                    .onTapGesture {
                        selection = choice
                        iOSHaptics.selection()
                    }
                    .accessibilityLabel(choice.rawValue)
                    .accessibilityAddTraits(selection == choice ? .isSelected : [])
            }
        }
    }
}
