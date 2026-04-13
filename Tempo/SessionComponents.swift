//
//  SessionComponents.swift
//  Tempo
//
//  Reusable UI components for the iOS app.
//  Scaled up from watch versions for iPhone display.
//

import SwiftUI

// MARK: - Streak Dots

struct StreakDots: View {
    let count: Int
    var color: Color = .white
    private let maxDots = 10

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<min(count, maxDots), id: \.self) { _ in
                Circle()
                    .fill(color.opacity(0.5))
                    .frame(width: 5, height: 5)
            }
            if count > maxDots {
                Text("+\(count - maxDots)")
                    .font(.system(size: 11, weight: .light, design: .monospaced))
                    .foregroundStyle(color.opacity(0.4))
            }
        }
    }
}

// MARK: - Cycle Indicator

struct CycleIndicator: View {
    let position: Int
    let total: Int
    var color: Color = .white

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color.opacity(i < position ? 0.6 : 0.1))
                    .frame(width: 20, height: 4)
            }
        }
    }
}

// MARK: - Duration Preset Picker

struct DurationPresetPicker: View {
    let presets: [TimeInterval]
    @Binding var selected: TimeInterval
    var accentColor: Color = .white

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.self) { minutes in
                        let isSelected = minutes == selected
                        Button {
                            selected = minutes
                            iOSHaptics.selection()
                        } label: {
                            Text("\(Int(minutes))")
                                .font(.system(size: 16, weight: isSelected ? .medium : .light, design: .monospaced))
                                .foregroundStyle(isSelected ? .black : accentColor.opacity(0.6))
                                .frame(width: 44, height: 36)
                                .background(
                                    isSelected
                                        ? accentColor.opacity(0.9)
                                        : accentColor.opacity(0.06),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .id(minutes)
                    }
                }
                .padding(.horizontal, 20)
            }
            .onAppear {
                proxy.scrollTo(selected, anchor: .center)
            }
            .onChange(of: selected) { _, newValue in
                withAnimation(.spring(response: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Stop Button

struct StopButton: View {
    @State private var showConfirm = false
    @State private var dismissTask: Task<Void, Never>?
    var isBreak: Bool = false
    let onStop: () -> Void

    var body: some View {
        if showConfirm {
            Button {
                dismissTask?.cancel()
                onStop()
                showConfirm = false
            } label: {
                Text("confirm stop")
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundStyle(.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.red.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
        } else {
            Button {
                iOSHaptics.confirmWarning()
                withAnimation(.spring(response: 0.3)) {
                    showConfirm = true
                }
                dismissTask?.cancel()
                dismissTask = Task {
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    withAnimation { showConfirm = false }
                }
            } label: {
                Text("stop")
                    .font(.system(size: 16, weight: .light, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.white.opacity(0.04), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Celebration View

struct CelebrationView: View {
    let isCycleComplete: Bool
    let streakCount: Int
    let onDismiss: () -> Void

    private var ringCount: Int { isCycleComplete ? 5 : 3 }
    @State private var ringScales: [CGFloat] = Array(repeating: 0.3, count: 5)
    @State private var ringOpacities: [Double] = [0.8, 0.7, 0.6, 0.5, 0.4]
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var textScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ForEach(0..<ringCount, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(ringOpacities[i]), lineWidth: isCycleComplete ? 4 : 3)
                    .scaleEffect(ringScales[i])
            }

            VStack(spacing: 16) {
                Image(systemName: isCycleComplete ? "trophy" : "checkmark")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
                    .opacity(checkOpacity)

                VStack(spacing: 4) {
                    Text("\(streakCount)")
                        .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .scaleEffect(textScale)

                    Text(isCycleComplete ? "cycle complete" : "streak")
                        .font(.system(size: 14, weight: isCycleComplete ? .medium : .light, design: .monospaced))
                        .foregroundStyle(isCycleComplete ? .white.opacity(0.8) : .secondary)
                        .scaleEffect(textScale)
                }
            }
        }
        .onTapGesture { onDismiss() }
        .onAppear {
            let stagger = isCycleComplete ? 0.1 : 0.12
            for i in 0..<ringCount {
                withAnimation(.easeOut(duration: isCycleComplete ? 1.5 : 1.2).delay(Double(i) * stagger)) {
                    ringScales[i] = isCycleComplete ? 2.5 : 2.0
                    ringOpacities[i] = 0
                }
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                checkScale = 1.0; checkOpacity = 1.0
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                textScale = 1.0
            }
        }
    }
}
