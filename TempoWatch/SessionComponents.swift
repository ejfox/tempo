//
//  SessionComponents.swift
//  TempoWatch
//
//  Small reusable components: StreakDots, CycleIndicator,
//  InstrumentRing, TickMarks, StopButton.
//

import SwiftUI

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

// MARK: - Cycle Indicator

/// Horizontal bar segments showing position within the Pomodoro cycle.
/// Filled = completed this cycle, empty = remaining.
struct CycleIndicator: View {
    let position: Int
    let total: Int
    var color: Color = .white

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color.opacity(i < position ? 0.6 : 0.12))
                    .frame(width: 14, height: 3)
            }
        }
    }
}

// MARK: - Instrument Ring

struct InstrumentRing: View {
    let progress: Double
    var thickness: CGFloat = 4
    var color: Color = .white

    var body: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .padding(6)
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

// MARK: - Stop Button

struct StopButton: View {
    @State private var showConfirm = false
    @State private var dismissTask: Task<Void, Never>?
    var isBreak: Bool = false
    let onStop: () -> Void

    var body: some View {
        if showConfirm {
            Button(role: .destructive) {
                dismissTask?.cancel()
                onStop()
                showConfirm = false
            } label: {
                Text("Confirm Stop")
                    .frame(maxWidth: .infinity)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .move(edge: .bottom)),
                removal: .opacity
            ))
        } else {
            Button {
                WatchHaptics.confirmWarning.play()
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
                Text("Stop")
                    .frame(maxWidth: .infinity)
            }
            .tint(.gray)
        }
    }
}
