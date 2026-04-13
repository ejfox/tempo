//
//  ContentView.swift
//  Tempo
//
//  Three-tab iOS app: Timer, History, Settings.
//  Design DNA inherited from the watchOS app.
//

import SwiftUI

// MARK: - Root

struct ContentView: View {
    @Environment(SessionManager.self) private var manager

    var body: some View {
        ZStack {
            if manager.celebrating {
                CelebrationView(
                    isCycleComplete: manager.isCycleComplete,
                    streakCount: manager.currentSession.currentStreak,
                    onDismiss: { manager.dismissCelebration() }
                )
                .transition(.opacity)
            } else {
                TabView {
                    TimerTab()
                        .environment(manager)
                        .tabItem { Label("Timer", systemImage: "timer") }

                    HistoryTab()
                        .tabItem { Label("History", systemImage: "chart.bar") }

                    SettingsTab()
                        .environment(manager)
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
                .tint(.white)
            }
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: manager.celebrating)
    }
}

// MARK: - Timer Tab

struct TimerTab: View {
    @Environment(SessionManager.self) private var manager

    @State private var selectedMinutes: TimeInterval = 25
    @State private var pulseOpacity: Double = 1.0

    private var session: PomodoroSession { manager.currentSession }
    private var settings: UserSettings { manager.userSettings }
    private var isBreak: Bool { session.isInBreak }
    private var inverted: Bool { isBreak && settings.invertBreakColors }

    private var edgeColor: Color {
        inverted ? .black : (isBreak ? settings.breakColor : settings.focusColor)
    }
    private var textColor: Color { inverted ? .black : .white }
    private var labelColor: Color { inverted ? .black.opacity(0.5) : .white.opacity(0.5) }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            ZStack {
                (inverted ? Color.white : Color.black)
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: isBreak)

                if session.isActive {
                    activeView
                } else {
                    idleView
                }
            }
            .animation(.easeInOut(duration: 0.4), value: session.isActive)
        }
    }

    // MARK: - Idle View

    private var idleView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                Text("\(Int(selectedMinutes))")
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: selectedMinutes))
                    .animation(.spring(response: 0.3), value: selectedMinutes)

                Text("minutes")
                    .font(.system(size: 14, weight: .light, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            DurationPresetPicker(
                presets: PomodoroSession.durationPresets,
                selected: $selectedMinutes
            )
            .padding(.top, 24)

            // Idle stats — configurable
            idleSlotContent
                .padding(.top, 16)

            Spacer()

            Button {
                let type = PomodoroSession.sessionType(
                    forMinutes: selectedMinutes,
                    breakRatio: settings.breakRatio
                )
                manager.startSession(type: type)
            } label: {
                Text("begin")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.white.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
            .accessibilityLabel("Begin \(Int(selectedMinutes)) minute focus session")
        }
    }

    @State private var pulseEdgeOpacity: Double = 1.0

    // MARK: - Active View

    private var activeView: some View {
        ZStack {
            edgeView
                .animation(.linear(duration: 1), value: session.progress)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 6) {
                    // Top slot — configurable
                    slotContent(for: settings.activeTopSlot, color: labelColor)

                    Text(session.formattedTime)
                        .font(.system(size: 64, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .contentTransition(.numericText(value: session.remainingTime))
                        .opacity(session.isPaused ? pulseOpacity : 1.0)
                        .accessibilityLabel("\(Int(session.remainingTime / 60)) minutes \(Int(session.remainingTime) % 60) seconds remaining")
                        .accessibilityValue("\(Int(session.progress * 100)) percent complete")

                    // Bottom slot — configurable
                    slotContent(for: settings.activeBottomSlot, color: textColor)
                        .padding(.top, 4)
                }
                .onTapGesture {
                    if session.isBreakPending {
                        manager.startBreak()
                    } else {
                        manager.togglePause()
                    }
                }

                Spacer()

                if session.isBreakPending {
                    Button {
                        manager.startBreak()
                    } label: {
                        Text("start break")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundStyle(textColor.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(textColor.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 8)
                }

                StopButton(isBreak: isBreak) { manager.stopSession() }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
            }
        }
        .onChange(of: session.isPaused) { _, _ in
            if session.isPaused {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseOpacity = 0.3
                }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) { pulseOpacity = 1.0 }
            }
        }
    }

    // MARK: - Slot Content

    @ViewBuilder
    private func slotContent(for slot: UserSettings.InfoSlotContent, color: Color) -> some View {
        switch slot {
        case .phaseLabel:
            Text(session.phaseLabel)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.interpolate)
        case .cycleIndicator:
            CycleIndicator(position: session.cyclePosition, total: settings.pomodorosPerCycle, color: color)
        case .streakCount:
            if session.currentStreak > 0 && settings.showStreakDots {
                StreakDots(count: session.currentStreak, color: color)
            }
        case .todayCount:
            Label("\(session.todayCount)", systemImage: "checkmark.circle")
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
        case .none:
            EmptyView()
        }
    }

    // MARK: - Edge Style

    @ViewBuilder
    private var edgeView: some View {
        let progress = session.progress
        let paused = session.isPaused
        switch settings.activeEdgeStyle {
        case .thin:
            EdgeTraceProgress(progress: progress, color: edgeColor, isPaused: paused, lineWidth: 2, showGlow: false)
        case .thick:
            EdgeTraceProgress(progress: progress, color: edgeColor, isPaused: paused,
                              lineWidth: CGFloat(settings.edgeLineWidth), showGlow: settings.edgeGlow)
        case .none:
            EmptyView()
        case .pulse:
            EdgeTraceProgress(progress: progress, color: edgeColor, isPaused: paused, lineWidth: 4, showGlow: true)
                .opacity(pulseEdgeOpacity)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                        pulseEdgeOpacity = 0.4
                    }
                }
        }
    }

    // MARK: - Idle Slot

    @ViewBuilder
    private var idleSlotContent: some View {
        switch settings.idleStatsSlot {
        case .phaseLabel:
            Text("ready")
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
        case .cycleIndicator:
            CycleIndicator(position: session.cyclePosition, total: settings.pomodorosPerCycle)
        case .streakCount:
            if session.currentStreak > 0 || session.todayCount > 0 {
                HStack(spacing: 20) {
                    if session.currentStreak > 0 {
                        Label("\(session.currentStreak)", systemImage: "flame")
                    }
                    Label("\(session.todayCount)", systemImage: "checkmark.circle")
                }
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        case .todayCount:
            Label("\(session.todayCount) today", systemImage: "checkmark.circle")
                .font(.system(size: 13, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SessionManager())
}
