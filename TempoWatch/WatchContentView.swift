//
//  WatchContentView.swift
//  TempoWatch
//
//  Top-level view router + the three screen states:
//  DurationSelector (idle), ActiveSession (running), Celebration (done).
//
//  Components live in separate files:
//    EdgeTraceProgress.swift, CelebrationView.swift, SessionComponents.swift
//

import SwiftUI

// MARK: - Main View

struct WatchContentView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings

    private var isBreak: Bool { manager.session.isInBreak }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { _ in
            let _ = tickIfNeeded()

            ZStack {
                backgroundColor
                    .ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.6), value: isBreak)

                if manager.celebrating {
                    CelebrationView()
                        .environment(manager)
                        .transition(.opacity)
                } else if manager.session.isActive {
                    ActiveSessionView()
                        .environment(manager)
                        .environment(settings)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.9)),
                            removal: .opacity
                        ))
                } else {
                    DurationSelectorView()
                        .environment(manager)
                        .environment(settings)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 1.05)),
                            removal: .opacity.combined(with: .scale(scale: 0.9))
                        ))
                }
            }
            .animation(.easeInOut(duration: 0.4), value: manager.session.isActive)
            .animation(.easeInOut(duration: 0.3), value: manager.celebrating)
        }
    }

    private func tickIfNeeded() {
        guard manager.session.isRunning else { return }
        manager.processTick()
    }

    private var backgroundColor: Color {
        if isBreak && settings.invertBreakColors { return .white }
        return .black
    }
}

// MARK: - Duration Selector (Idle State)

struct DurationSelectorView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings

    @State private var rawCrown: Double = 4.5
    @State private var selectedIndex: Int = 4
    @State private var appeared = false
    @FocusState private var isFocused: Bool

    private let presets = WatchPomodoroSession.durationPresets
    private let detentIndex = WatchPomodoroSession.defaultPresetIndex

    private var selectedMinutes: TimeInterval {
        guard presets.indices.contains(selectedIndex) else { return 25 }
        return presets[selectedIndex]
    }

    private var isAtDetent: Bool { selectedIndex == detentIndex }

    /// Maps continuous crown value to preset index.
    /// The 25-min zone (index 4) spans 2 crown units; all others span 1.
    private func indexFromCrown(_ value: Double) -> Int {
        switch value {
        case ..<0.5:  return 0
        case ..<1.5:  return 1
        case ..<2.5:  return 2
        case ..<3.5:  return 3
        case ..<5.5:  return 4
        case ..<6.5:  return 5
        case ..<7.5:  return 6
        case ..<8.5:  return 7
        default:      return 8
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                InstrumentRing(
                    progress: appeared ? selectedMinutes / 60.0 : 0,
                    thickness: isAtDetent ? 4 : 3,
                    color: .white.opacity(isAtDetent ? 0.2 : 0.15)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedMinutes)
                .animation(.easeInOut(duration: 0.2), value: isAtDetent)

                TickMarks(count: 12, majorEvery: 3, radius: 68)
                    .opacity(appeared ? 0.4 : 0)

                VStack(spacing: 4) {
                    Text("\(Int(selectedMinutes))")
                        .font(.system(size: 48, weight: isAtDetent ? .thin : .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText(value: selectedMinutes))
                        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedMinutes)
                        .scaleEffect(appeared ? 1 : 0.8)
                        .opacity(appeared ? 1 : 0)

                    Text("minutes")
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .opacity(appeared ? 0.7 : 0)

                    idleSlotContent
                        .padding(.top, 4)
                        .opacity(appeared ? 0.8 : 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 12) {
                NavigationLink {
                    SettingsView()
                        .environment(settings)
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    let type = WatchPomodoroSession.sessionType(
                        forMinutes: selectedMinutes,
                        breakRatio: settings.breakRatio
                    )
                    manager.startSession(type: type)
                } label: {
                    Text("begin")
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .opacity(appeared ? 1 : 0)
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .focusable()
        .focused($isFocused)
        .digitalCrownRotation(
            $rawCrown, from: 0, through: 10,
            sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false
        )
        .onChange(of: rawCrown) { _, newValue in
            let newIndex = indexFromCrown(newValue)
            guard newIndex != selectedIndex else { return }
            selectedIndex = newIndex
            if newIndex == detentIndex {
                WatchHaptics.crownDetent.play()
            } else {
                WatchHaptics.crownSnap.play()
            }
        }
        .onAppear {
            isFocused = true
            withAnimation(.easeOut(duration: 0.6)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }

    @ViewBuilder
    private var idleSlotContent: some View {
        switch settings.idleStatsSlot {
        case .phaseLabel:
            Text("ready")
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
        case .cycleIndicator:
            CycleIndicator(position: manager.session.cyclePosition, total: settings.pomodorosPerCycle)
        case .streakCount:
            if manager.session.currentStreak > 0 {
                HStack(spacing: 12) {
                    Label("\(manager.session.currentStreak)", systemImage: "flame")
                    Label("\(manager.session.todayCount)", systemImage: "checkmark.circle")
                }
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
            }
        case .todayCount:
            Label("\(manager.session.todayCount) today", systemImage: "checkmark.circle")
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(.tertiary)
        case .none:
            EmptyView()
        }
    }
}

// MARK: - Active Session View

struct ActiveSessionView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings

    @State private var edgeAppeared = false
    @State private var pulseOpacity: Double = 1.0
    @State private var pulseEdgeOpacity: Double = 1.0

    // Phase transition animation state
    @State private var transitionFlash: Double = 0
    @State private var transitionScale: CGFloat = 1.0
    @State private var transitionBlur: CGFloat = 0
    @State private var edgeGlowAnim: Double = 0
    @State private var transitionTextScale: CGFloat = 1.0

    private var isBreak: Bool { manager.session.isInBreak }
    private var inverted: Bool { isBreak && settings.invertBreakColors }

    private var edgeColor: Color {
        inverted ? .black : (isBreak ? settings.breakColor : settings.focusColor)
    }
    private var textColor: Color { inverted ? .black : .white }
    private var labelColor: Color { inverted ? .black.opacity(0.5) : .white.opacity(0.5) }
    private var flashColor: Color { inverted ? .black : .white }

    var body: some View {
        ZStack {
            edgeView
                .animation(.linear(duration: 1), value: manager.session.progress)
                .animation(.easeInOut(duration: 0.6), value: isBreak)
                .ignoresSafeArea()

            if edgeGlowAnim > 0 {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .stroke(flashColor.opacity(edgeGlowAnim), lineWidth: 12)
                    .blur(radius: 10)
                    .ignoresSafeArea()
            }

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 3) {
                    slotContent(for: settings.activeTopSlot, color: labelColor)

                    Text(manager.session.formattedTime)
                        .font(.system(size: 38, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .contentTransition(.numericText(value: manager.session.remainingTime))
                        .opacity(manager.session.isPaused ? pulseOpacity : 1.0)
                        .scaleEffect(transitionTextScale)
                        .animation(.easeInOut(duration: 0.6), value: isBreak)

                    slotContent(for: settings.activeBottomSlot, color: textColor)
                        .padding(.top, 2)
                }
                .scaleEffect(transitionScale)
                .blur(radius: transitionBlur)
                .onTapGesture {
                    if manager.session.isBreakPending {
                        manager.startBreak()
                    } else {
                        manager.togglePause()
                    }
                }

                Spacer()

                if manager.session.isBreakPending {
                    Button {
                        manager.startBreak()
                    } label: {
                        Text("start break")
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(textColor.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(textColor.opacity(0.1), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                }

                StopButton(isBreak: isBreak) { manager.stopSession() }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)
                    .opacity(manager.phaseTransitioning ? 0 : 1)
                    .animation(.easeInOut(duration: 0.2), value: manager.phaseTransitioning)
            }

            if transitionFlash > 0 {
                Color.white.opacity(transitionFlash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { edgeAppeared = true }
        }
        .onChange(of: manager.session.isPaused) { _, _ in updatePulse() }
        .onChange(of: manager.phaseTransitioning) { _, transitioning in
            if transitioning { playPhaseTransition() }
        }
    }

    // MARK: - Phase Transition (1.6s choreography)

    private func playPhaseTransition() {
        withAnimation(.easeOut(duration: 0.3)) {
            edgeGlowAnim = 0.8
            transitionTextScale = 1.15
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.15)) { transitionFlash = 0.25 }
            withAnimation(.easeOut(duration: 0.2)) {
                transitionBlur = 6; transitionScale = 0.92; transitionTextScale = 0.85
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) { transitionFlash = 0; edgeGlowAnim = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                transitionScale = 1.0; transitionTextScale = 1.0; transitionBlur = 0
            }
        }
    }

    private func updatePulse() {
        if manager.session.isPaused {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) { pulseOpacity = 1.0 }
        }
    }

    // MARK: - Slot Content

    @ViewBuilder
    private func slotContent(for slot: WatchSettings.InfoSlotContent, color: Color) -> some View {
        switch slot {
        case .phaseLabel:
            Text(manager.session.phaseLabel)
                .font(.system(size: 11, weight: .light, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.5), value: manager.session.phaseLabel)
        case .cycleIndicator:
            CycleIndicator(position: manager.session.cyclePosition, total: settings.pomodorosPerCycle, color: color)
        case .streakCount:
            if manager.session.currentStreak > 0 {
                StreakDots(count: manager.session.currentStreak, color: color)
            }
        case .todayCount:
            Label("\(manager.session.todayCount)", systemImage: "checkmark.circle")
                .font(.system(size: 10, weight: .light, design: .monospaced))
                .foregroundStyle(color.opacity(0.7))
        case .none:
            EmptyView()
        }
    }

    // MARK: - Edge Style

    @ViewBuilder
    private var edgeView: some View {
        let progress = edgeAppeared ? manager.session.progress : 0
        let paused = manager.session.isPaused
        switch settings.activeEdgeStyle {
        case .thin:
            EdgeTraceProgress(progress: progress, color: edgeColor, isPaused: paused, lineWidth: 3, showGlow: false)
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
}

// MARK: - Preview

#Preview {
    WatchContentView()
        .environment(WatchSessionManager())
}
