//
//  EdgeTraceProgress.swift
//  TempoWatch
//
//  Progress indicator that traces the watch display bezel using a continuous-curve
//  rounded rectangle (squircle). The `.continuous` corner style matches Apple's
//  device bezel shape. Corner radius scales to actual screen size.
//
//  RoundedRectangle's path starts at 3 o'clock. We offset by 0.75 to start at 12.
//

import SwiftUI

struct EdgeTraceProgress: View {
    let progress: Double
    var color: Color = .white
    var isPaused: Bool = false
    var lineWidth: CGFloat = 5
    var showGlow: Bool = true

    private let inset: CGFloat = 3
    private let startOffset: Double = 0.75

    var body: some View {
        GeometryReader { geo in
            let cr = min(geo.size.width, geo.size.height) * 0.27
            let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

            ZStack {
                shape
                    .stroke(color.opacity(0.06), lineWidth: lineWidth)
                    .padding(inset)

                if showGlow {
                    WrappedTrim(shape: shape, from: startOffset, amount: progress)
                        .stroke(
                            color.opacity(isPaused ? 0.15 : 0.35),
                            style: StrokeStyle(lineWidth: lineWidth + 6, lineCap: .round)
                        )
                        .padding(inset)
                        .blur(radius: 6)
                }

                WrappedTrim(shape: shape, from: startOffset, amount: progress)
                    .stroke(
                        color.opacity(isPaused ? 0.4 : 0.8),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .padding(inset)

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

/// Trims a shape starting at an arbitrary offset, wrapping around if it exceeds 1.0.
struct WrappedTrim<S: Shape>: Shape {
    let shape: S
    let from: Double
    let amount: Double

    func path(in rect: CGRect) -> Path {
        let start = from.truncatingRemainder(dividingBy: 1.0)
        let end = start + amount
        var path = Path()
        if end <= 1.0 {
            path.addPath(shape.trim(from: start, to: end).path(in: rect))
        } else {
            path.addPath(shape.trim(from: start, to: 1.0).path(in: rect))
            path.addPath(shape.trim(from: 0, to: end - 1.0).path(in: rect))
        }
        return path
    }
}
