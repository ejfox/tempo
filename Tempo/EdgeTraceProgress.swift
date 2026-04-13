//
//  EdgeTraceProgress.swift
//  Tempo
//
//  Edge-trace progress indicator for iPhone. Traces the screen's
//  rounded rectangle bezel. Ported from watchOS version.
//

import SwiftUI

struct EdgeTraceProgress: View {
    let progress: Double
    var color: Color = .white
    var isPaused: Bool = false
    var lineWidth: CGFloat = 4
    var showGlow: Bool = true

    private let inset: CGFloat = 4
    private let startOffset: Double = 0.75

    var body: some View {
        GeometryReader { geo in
            let cr = min(geo.size.width, geo.size.height) * 0.12
            let shape = RoundedRectangle(cornerRadius: cr, style: .continuous)

            ZStack {
                shape
                    .stroke(color.opacity(0.04), lineWidth: lineWidth)
                    .padding(inset)

                if showGlow {
                    WrappedTrim(shape: shape, from: startOffset, amount: progress)
                        .stroke(
                            color.opacity(isPaused ? 0.1 : 0.25),
                            style: StrokeStyle(lineWidth: lineWidth + 8, lineCap: .round)
                        )
                        .padding(inset)
                        .blur(radius: 8)
                }

                WrappedTrim(shape: shape, from: startOffset, amount: progress)
                    .stroke(
                        color.opacity(isPaused ? 0.3 : 0.7),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .padding(inset)

                if progress > 0.005 {
                    WrappedTrim(shape: shape, from: startOffset + progress - 0.01, amount: 0.01)
                        .stroke(
                            color.opacity(isPaused ? 0.2 : 0.8),
                            style: StrokeStyle(lineWidth: lineWidth + 2, lineCap: .round)
                        )
                        .padding(inset)
                        .blur(radius: 4)
                }
            }
        }
    }
}

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
