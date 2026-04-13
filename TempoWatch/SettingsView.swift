//
//  SettingsView.swift
//  TempoWatch
//

import SwiftUI

struct SettingsView: View {
    @Environment(WatchSettings.self) private var settings

    var body: some View {
        @Bindable var s = settings

        List {
            // MARK: - Behavior
            Section("Behavior") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Break length")
                        .font(.system(size: 13, design: .monospaced))
                    Picker("", selection: $s.breakRatio) {
                        Text("10%").tag(0.1)
                        Text("20%").tag(0.2)
                        Text("33%").tag(1.0 / 3.0)
                        Text("50%").tag(0.5)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }

                Toggle(isOn: $s.autoStartBreak) {
                    Text("Auto-start break")
                        .font(.system(size: 13, design: .monospaced))
                }

                Toggle(isOn: $s.autoStartNextFocus) {
                    Text("Auto-start next focus")
                        .font(.system(size: 13, design: .monospaced))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Long break")
                        .font(.system(size: 13, design: .monospaced))
                    Picker("", selection: $s.longBreakMinutes) {
                        Text("15m").tag(15.0)
                        Text("20m").tag(20.0)
                        Text("25m").tag(25.0)
                        Text("30m").tag(30.0)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Pomodoros/cycle")
                        .font(.system(size: 13, design: .monospaced))
                    Picker("", selection: $s.pomodorosPerCycle) {
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("4").tag(4)
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }
            }

            // MARK: - Alerts
            Section("Alerts") {
                Toggle(isOn: $s.approachingEndAlerts) {
                    Text("Approaching end")
                        .font(.system(size: 13, design: .monospaced))
                }

                if settings.approachingEndAlerts {
                    Text("Halfway · 5 min · 2 min · 1 min")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .listRowBackground(Color.clear)
                }
            }

            // MARK: - Haptics
            Section("Haptics") {
                Toggle(isOn: $s.hapticsEnabled) {
                    Text("Haptics")
                        .font(.system(size: 13, design: .monospaced))
                }

                if settings.hapticsEnabled {
                    Toggle(isOn: $s.milestoneHaptics) {
                        Text("Quarter milestones")
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Toggle(isOn: $s.countdownHaptics) {
                        Text("Final countdown")
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Toggle(isOn: $s.minuteMarkHaptics) {
                        Text("5-min marks")
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Toggle(isOn: $s.phaseCompleteHaptics) {
                        Text("Phase complete")
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Toggle(isOn: $s.sessionCompleteHaptics) {
                        Text("Session complete")
                            .font(.system(size: 12, design: .monospaced))
                    }

                    Toggle(isOn: $s.cycleCompleteHaptics) {
                        Text("Cycle complete")
                            .font(.system(size: 12, design: .monospaced))
                    }
                }
            }

            // MARK: - Customize
            Section("Customize") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top info")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $s.activeTopSlot) {
                        ForEach(WatchSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Bottom info")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $s.activeBottomSlot) {
                        ForEach(WatchSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Edge style")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $s.activeEdgeStyle) {
                        ForEach(WatchSettings.EdgeStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Idle stats")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Picker("", selection: $s.idleStatsSlot) {
                        ForEach(WatchSettings.InfoSlotContent.allCases) { slot in
                            Text(slot.displayName).tag(slot)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 40)
                }
            }

            // MARK: - Visuals
            Section("Visuals") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edge width: \(Int(settings.edgeLineWidth))pt")
                        .font(.system(size: 13, design: .monospaced))
                    Slider(value: $s.edgeLineWidth, in: 3...8, step: 1)
                }

                Toggle(isOn: $s.edgeGlow) {
                    Text("Edge glow")
                        .font(.system(size: 13, design: .monospaced))
                }

                Toggle(isOn: $s.invertBreakColors) {
                    Text("Invert on break")
                        .font(.system(size: 13, design: .monospaced))
                }

                Toggle(isOn: $s.showStreakDots) {
                    Text("Streak dots")
                        .font(.system(size: 13, design: .monospaced))
                }
            }

            // MARK: - Colors
            Section("Colors") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Focus")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ColorRow(selection: $s.focusColorChoice)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Break")
                        .font(.system(size: 12, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ColorRow(selection: $s.breakColorChoice)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Color Picker Row

struct ColorRow: View {
    @Binding var selection: WatchSettings.ColorChoice

    var body: some View {
        HStack(spacing: 6) {
            ForEach(WatchSettings.ColorChoice.allCases) { choice in
                Circle()
                    .fill(choice.color)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: selection == choice ? 2 : 0)
                    )
                    .onTapGesture {
                        selection = choice
                        WatchHaptics.crownSnap.play()
                    }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(WatchSettings())
    }
}
