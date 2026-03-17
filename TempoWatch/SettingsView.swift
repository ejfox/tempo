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
                        WKInterfaceDevice.current().play(.click)
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
