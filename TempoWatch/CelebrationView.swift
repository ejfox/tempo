//
//  CelebrationView.swift
//  TempoWatch
//
//  Expanding rings + trophy/checkmark on session or cycle completion.
//

import SwiftUI

struct CelebrationView: View {
    @Environment(WatchSessionManager.self) private var manager

    private var isCycle: Bool { manager.isCycleComplete }
    private var ringCount: Int { isCycle ? 5 : 3 }

    @State private var ringScales: [CGFloat] = Array(repeating: 0.3, count: 5)
    @State private var ringOpacities: [Double] = [0.8, 0.7, 0.6, 0.5, 0.4]
    @State private var checkScale: CGFloat = 0
    @State private var checkOpacity: Double = 0
    @State private var streakScale: CGFloat = 0.5
    @State private var labelScale: CGFloat = 0.5

    var body: some View {
        ZStack {
            ForEach(0..<ringCount, id: \.self) { i in
                Circle()
                    .stroke(Color.white.opacity(ringOpacities[i]), lineWidth: isCycle ? 3 : 2)
                    .scaleEffect(ringScales[i])
            }

            VStack(spacing: 8) {
                Image(systemName: isCycle ? "trophy" : "checkmark")
                    .font(.system(size: isCycle ? 28 : 32, weight: .light))
                    .foregroundStyle(.white)
                    .scaleEffect(checkScale)
                    .opacity(checkOpacity)

                VStack(spacing: 2) {
                    Text("\(manager.session.currentStreak)")
                        .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .scaleEffect(streakScale)

                    Text(isCycle ? "cycle complete" : "streak")
                        .font(.system(size: 10, weight: isCycle ? .medium : .light, design: .monospaced))
                        .foregroundStyle(isCycle ? .white.opacity(0.8) : .secondary)
                        .scaleEffect(labelScale)
                }
            }
        }
        .onTapGesture {
            manager.dismissCelebration()
        }
        .onAppear {
            let stagger = isCycle ? 0.12 : 0.15
            for i in 0..<ringCount {
                withAnimation(.easeOut(duration: isCycle ? 1.5 : 1.2).delay(Double(i) * stagger)) {
                    ringScales[i] = isCycle ? 2.2 : 1.8
                    ringOpacities[i] = 0
                }
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.2)) {
                checkScale = 1.0
                checkOpacity = 1.0
            }

            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.4)) {
                streakScale = 1.0
                labelScale = 1.0
            }
        }
    }
}
