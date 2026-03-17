//
//  WatchContentView.swift
//  TempoWatch
//
//  Fighter-jet instrumentation meets Swiss watchmaking.
//  Every pixel is a gauge. Every haptic is a signal.
//

import SwiftUI
import WatchKit

// MARK: - Main View

struct WatchContentView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings
    @State private var displayTime: String = "00:00"

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var isBreak: Bool { manager.session.isInBreak }

    var body: some View {
        ZStack {
            // Background — inverts during break if enabled
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: isBreak)

            if manager.celebrating {
                CelebrationView()
                    .environment(manager)
                    .transition(.opacity)
            } else if manager.session.isActive {
                ActiveSessionView(displayTime: $displayTime)
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
        .onReceive(timer) { _ in
            guard manager.session.isRunning else { return }
            manager.processTick()
            displayTime = manager.session.formattedTime
        }
    }

    private var backgroundColor: Color {
        if isBreak && settings.invertBreakColors {
            return .white
        }
        return .black
    }
}

// MARK: - Duration Selector (Idle State)

struct DurationSelectorView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings

    // Non-linear crown: 25 occupies a wider zone (3.5–5.5 vs 1.0 for others).
    // Total crown range 0–10, mapped to 9 presets with 25 getting 2x width.
    @State private var rawCrown: Double = 4.5 // center of the 25 zone
    @State private var selectedIndex: Int = 4  // 25 min
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
        // Zone layout: [0, 0.5, 1.5, 2.5, 3.5,  5.5,  6.5, 7.5, 8.5, 10]
        //    Preset:     0    1    2    3     4(wide)  5    6    7    8
        switch value {
        case ..<0.5:  return 0
        case ..<1.5:  return 1
        case ..<2.5:  return 2
        case ..<3.5:  return 3
        case ..<5.5:  return 4  // 25 min — 2x wide detent
        case ..<6.5:  return 5
        case ..<7.5:  return 6
        case ..<8.5:  return 7
        default:      return 8
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Outer ring — preview of session length, proportional to 60 min
                InstrumentRing(
                    progress: appeared ? selectedMinutes / 60.0 : 0,
                    thickness: isAtDetent ? 4 : 3,
                    color: .white.opacity(isAtDetent ? 0.2 : 0.15)
                )
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedMinutes)
                .animation(.easeInOut(duration: 0.2), value: isAtDetent)

                // Tick marks
                TickMarks(count: 12, majorEvery: 3, radius: 68)
                    .opacity(appeared ? 0.4 : 0)

                // Duration display
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

                    if manager.session.currentStreak > 0 {
                        HStack(spacing: 12) {
                            Label("\(manager.session.currentStreak)", systemImage: "flame")
                            Label("\(manager.session.todayCount)", systemImage: "checkmark.circle")
                        }
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                        .opacity(appeared ? 1 : 0)
                    }
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
                    let type = WatchPomodoroSession.sessionType(forMinutes: selectedMinutes)
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
            $rawCrown,
            from: 0,
            through: 10,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: false
        )
        .onChange(of: rawCrown) { _, newValue in
            let newIndex = indexFromCrown(newValue)
            guard newIndex != selectedIndex else { return }
            selectedIndex = newIndex
            if newIndex == detentIndex {
                WatchHaptics.crownDetent()
            } else {
                WatchHaptics.crownSnap()
            }
        }
        .onAppear {
            isFocused = true
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
        }
        .onDisappear {
            appeared = false
        }
    }
}

// MARK: - Active Session View

struct ActiveSessionView: View {
    @Environment(WatchSessionManager.self) private var manager
    @Environment(WatchSettings.self) private var settings
    @Binding var displayTime: String

    @State private var edgeAppeared = false
    @State private var showConfirmStop = false
    @State private var pulseOpacity: Double = 1.0
    @State private var confirmDismissWork: DispatchWorkItem?

    // Phase transition animation state
    @State private var transitionFlash: Double = 0
    @State private var transitionScale: CGFloat = 1.0
    @State private var transitionBlur: CGFloat = 0
    @State private var edgeGlowAnim: Double = 0
    @State private var transitionTextScale: CGFloat = 1.0

    private var isBreak: Bool { manager.session.isInBreak }
    private var inverted: Bool { isBreak && settings.invertBreakColors }

    private var edgeColor: Color {
        if inverted { return .black }
        return isBreak ? settings.breakColor : settings.focusColor
    }
    private var textColor: Color { inverted ? .black : .white }
    private var labelColor: Color { inverted ? .black.opacity(0.5) : .white.opacity(0.5) }
    private var flashColor: Color { inverted ? .black : .white }

    var body: some View {
        ZStack {
            // Edge-trace progress — hugs the watch bezel
            EdgeTraceProgress(
                progress: edgeAppeared ? manager.session.progress : 0,
                color: edgeColor,
                isPaused: manager.session.isPaused,
                lineWidth: CGFloat(settings.edgeLineWidth),
                showGlow: settings.edgeGlow
            )
            .animation(.linear(duration: 1), value: manager.session.progress)
            .animation(.easeInOut(duration: 0.6), value: isBreak)
            .ignoresSafeArea()

            // Transition flare — edge glow during phase change
            if edgeGlowAnim > 0 {
                RoundedRectangle(cornerRadius: 50, style: .continuous)
                    .stroke(flashColor.opacity(edgeGlowAnim), lineWidth: 12)
                    .blur(radius: 10)
                    .ignoresSafeArea()
            }

            // Center content + stop button
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 3) {
                    Text(manager.session.phaseLabel)
                        .font(.system(size: 11, weight: .light, design: .monospaced))
                        .foregroundStyle(labelColor)
                        .contentTransition(.interpolate)
                        .animation(.easeInOut(duration: 0.5), value: manager.session.phaseLabel)

                    Text(displayTime)
                        .font(.system(size: 38, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(textColor)
                        .contentTransition(.numericText(value: manager.session.remainingTime))
                        .opacity(manager.session.isPaused ? pulseOpacity : 1.0)
                        .scaleEffect(transitionTextScale)
                        .animation(.easeInOut(duration: 0.6), value: isBreak)

                    if manager.session.currentStreak > 0 && settings.showStreakDots {
                        StreakDots(count: manager.session.currentStreak, color: textColor)
                            .padding(.top, 2)
                    }
                }
                .scaleEffect(transitionScale)
                .blur(radius: transitionBlur)
                .onTapGesture {
                    manager.togglePause()
                }

                Spacer()

                StopButton(
                    showConfirm: $showConfirmStop,
                    confirmDismissWork: $confirmDismissWork,
                    isBreak: isBreak
                ) {
                    manager.stopSession()
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 4)
                .opacity(manager.phaseTransitioning ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: manager.phaseTransitioning)
            }

            // Flash overlay — white during focus→break, black during break→complete
            if transitionFlash > 0 {
                Color.white.opacity(transitionFlash)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                edgeAppeared = true
            }
        }
        .onChange(of: manager.session.isPaused) { _, _ in
            updatePulse()
        }
        .onChange(of: manager.phaseTransitioning) { _, isTransitioning in
            if isTransitioning {
                playPhaseTransition()
            }
        }
    }

    // MARK: - Phase Transition Choreography
    //
    // Timeline (1.6s total):
    //   0.0s  — Edge flares bright, timer zooms in slightly
    //   0.3s  — White flash pulse peaks
    //   0.5s  — Timer blurs and scales down
    //   0.8s  — Flash fades, content resets to break state
    //   1.2s  — Timer zooms back to normal, sharp
    //   1.6s  — Transition complete

    private func playPhaseTransition() {
        // Phase 1: Edge flare + timer zoom in (0–0.3s)
        withAnimation(.easeOut(duration: 0.3)) {
            edgeGlowAnim = 0.8
            transitionTextScale = 1.15
        }

        // Phase 2: White flash + blur (0.3–0.5s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.15)) {
                transitionFlash = 0.25
            }
            withAnimation(.easeOut(duration: 0.2)) {
                transitionBlur = 6
                transitionScale = 0.92
                transitionTextScale = 0.85
            }
        }

        // Phase 3: Flash fades, glow fades (0.5–0.8s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                transitionFlash = 0
                edgeGlowAnim = 0
            }
        }

        // Phase 4: Content reappears fresh (0.8–1.2s)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                transitionScale = 1.0
                transitionTextScale = 1.0
                transitionBlur = 0
            }
        }
    }

    private func updatePulse() {
        if manager.session.isPaused {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                pulseOpacity = 0.3
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Edge Trace Progress

/// Progress indicator that traces the watch display bezel using a continuous-curve
/// rounded rectangle (squircle). The `.continuous` corner style matches Apple's
/// device bezel shape. Corner radius scales to actual screen size.
///
/// RoundedRectangle's path starts at 3 o'clock. We offset by 0.75 to start at 12.
struct EdgeTraceProgress: View {
    let progress: Double
    var color: Color = .white
    var isPaused: Bool = false
    var lineWidth: CGFloat = 5
    var showGlow: Bool = true

    private let inset: CGFloat = 3
    /// 12 o'clock is ~75% through RoundedRectangle's path (which starts at 3 o'clock)
    private let startOffset: Double = 0.75

    var body: some View {
        GeometryReader { geo in
            let cr = min(geo.size.width, geo.size.height) * 0.27
            let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

            ZStack {
                // Faint track — full perimeter ghost outline
                shape
                    .stroke(color.opacity(0.06), lineWidth: lineWidth)
                    .padding(inset)

                // Glow bloom (optional)
                if showGlow {
                    WrappedTrim(shape: shape, from: startOffset, amount: progress)
                        .stroke(
                            color.opacity(isPaused ? 0.15 : 0.35),
                            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                        )
                        .padding(inset)
                        .blur(radius: 6)
                }

                // Hot core
                WrappedTrim(shape: shape, from: startOffset, amount: progress)
                    .stroke(
                        color.opacity(isPaused ? 0.4 : 0.8),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .padding(inset)

                // Bright tip at leading edge
                if progress > 0.005 {
                    WrappedTrim(shape: shape, from: startOffset + progress - 0.015, amount: 0.015)
                        .stroke(
                            color.opacity(isPaused ? 0.3 : 0.9),
                            style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                        )
                        .padding(inset)
                        .blur(radius: 3)
                }
            }
        }
    }
}

// MARK: - Wrapped Trim

/// Trims a shape starting at an arbitrary offset, wrapping around if it exceeds 1.0.
/// This lets us start the progress line at 12 o'clock even though
/// RoundedRectangle's path begins at 3 o'clock.
struct WrappedTrim<S: Shape>: Shape {
    let shape: S
    let from: Double
    let amount: Double

    func path(in rect: CGRect) -> Path {
        let start = from.truncatingRemainder(dividingBy: 1.0)
        let end = start + amount

        var path = Path()

        if end <= 1.0 {
            // Single segment — no wrapping needed
            path.addPath(shape.trim(from: start, to: end).path(in: rect))
        } else {
            // Wraps past 1.0 — draw two segments
            path.addPath(shape.trim(from: start, to: 1.0).path(in: rect))
            path.addPath(shape.trim(from: 0, to: end - 1.0).path(in: rect))
        }

        return path
    }
}

// MARK: - Streak Dots

struct StreakDots: View {
    let count: Int
    var color: Color = .white
    private let maxDots = 8

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<min(count, maxDots), id: \.self) { _ in
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 3, height: 3)
            }
            if count > maxDots {
                Text("+\(count - maxDots)")
                    .font(.system(size: 8, weight: .light, design: .monospaced))
                    .foregroundStyle(color.opacity(0.4))
            }
        }
    }
}

// MARK: - Stop Button

struct StopButton: View {
    @Binding var showConfirm: Bool
    @Binding var confirmDismissWork: DispatchWorkItem?
    var isBreak: Bool = false
    let onStop: () -> Void

    private var buttonBg: Color { isBreak ? .black.opacity(0.08) : .white.opacity(0.05) }
    private var buttonFg: Color { isBreak ? .black.opacity(0.5) : .white.opacity(0.5) }

    var body: some View {
        if showConfirm {
            Button {
                confirmDismissWork?.cancel()
                onStop()
                showConfirm = false
            } label: {
                Text("confirm stop")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.red.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
        } else {
            Button {
                WatchHaptics.confirmWarning()
                withAnimation(.spring(response: 0.3)) {
                    showConfirm = true
                }
                let work = DispatchWorkItem {
                    withAnimation { showConfirm = false }
                }
                confirmDismissWork = work
                DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
            } label: {
                Text("stop")
                    .font(.system(size: 13, weight: .light, design: .monospaced))
                    .foregroundStyle(buttonFg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(buttonBg, in: Capsule())
            }
            .buttonStyle(.plain)
            .animation(.easeInOut(duration: 0.6), value: isBreak)
        }
    }
}

// MARK: - Celebration View

struct CelebrationView: View {
    @Environment(WatchSessionManager.self) private var manager

    @State private var ringScales: [CGFloat] = [0.3, 0.3, 0.3]
    @State private var ringOpacities: [Double] = [0.8, 0.6, 0.4]
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var streakScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            // Expanding celebration rings
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(ringOpacities[i]), lineWidth: 2)
                    .scaleEffect(ringScales[i])
            }

            VStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
                    .opacity(checkOpacity)

                VStack(spacing: 2) {
                    Text("\(manager.session.currentStreak)")
                        .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .scaleEffect(streakScale)

                    Text("streak")
                        .font(.system(size: 10, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onTapGesture {
            manager.dismissCelebration()
        }
        .onAppear {
            // Staggered ring expansion
            for i in 0..<3 {
                withAnimation(.easeOut(duration: 1.2).delay(Double(i) * 0.15)) {
                    ringScales[i] = 1.8
                    ringOpacities[i] = 0
                }
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                checkScale = 1.0
                checkOpacity = 1.0
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                streakScale = 1.0
            }
        }
    }
}

// MARK: - Instrument Ring

struct InstrumentRing: View {
    let progress: Double
    var thickness: CGFloat = 4
    var color: Color = .white
    var glowColor: Color? = nil

    private let glowThreshold = 0.01

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let glow = glowColor, progress > glowThreshold {
                Circle()
                    .trim(from: max(0, progress - 0.02), to: progress)
                    .stroke(glow.opacity(0.4), style: StrokeStyle(lineWidth: thickness + 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .blur(radius: 3)
            }
        }
        .padding(12)
    }
}

// MARK: - Tick Marks

struct TickMarks: View {
    let count: Int
    let majorEvery: Int
    let radius: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { tick in
                let isMajor = tick % majorEvery == 0
                Rectangle()
                    .fill(Color.white.opacity(isMajor ? 0.5 : 0.2))
                    .frame(width: isMajor ? 1.5 : 0.75, height: isMajor ? 6 : 3)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(Double(tick) * (360.0 / Double(count))))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WatchContentView()
        .environment(WatchSessionManager())
}
