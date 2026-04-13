//
//  ComplicationComponents.swift
//  TempoWatchWidgets
//
//  Miniature versions of app components sized for complications.
//  Fixed-size (no GeometryReader) for the constrained complication viewport.
//

import SwiftUI
import WidgetKit

// MARK: - Progress Ring

/// Circular progress indicator for accessoryCircular complications.
struct MiniProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 3
    var trackOpacity: Double = 0.15
    var color: Color = .white

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(trackOpacity), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Cycle Bar

/// Tiny horizontal bar segments showing cycle position.
struct MiniCycleBar: View {
    let position: Int
    let total: Int
    var color: Color = .white

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color.opacity(i < position ? 0.7 : 0.15))
                    .frame(width: 8, height: 2)
            }
        }
    }
}

// MARK: - Progress Bar

/// Horizontal progress bar for accessoryRectangular complications.
struct MiniProgressBar: View {
    let progress: Double
    var color: Color = .white
    var height: CGFloat = 2

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(color.opacity(0.1))
                    .frame(height: height)
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * progress, height: height)
            }
        }
        .frame(height: height)
    }
}

// MARK: - Phase Color

extension TempoTimelineEntry {
    var phaseColor: Color {
        isInBreak ? .cyan : .white
    }
}
