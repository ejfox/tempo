//
//  TempoWidgetsLiveActivity.swift
//  TempoWidgets
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Activity Attributes

struct TempoActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var remainingTime: TimeInterval
        var currentStreak: Int
        var todayCount: Int
        var isInBreak: Bool
    }

    var sessionType: String
    var totalDuration: TimeInterval
}

// MARK: - Widget Configuration

struct TempoWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            // Lock screen / banner
            LockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Expanded
                DynamicIslandExpandedRegion(.center) {
                    ExpandedIslandView(context: context)
                }
            } compactLeading: {
                // Tiny progress arc
                CompactLeadingView(context: context)
            } compactTrailing: {
                // Countdown
                Text(timeString(from: context.state.remainingTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            } minimal: {
                // Single progress arc
                MinimalView(context: context)
            }
        }
    }

    private func timeString(from t: TimeInterval) -> String {
        String(format: "%d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Compact Leading (pill left side)

struct CompactLeadingView: View {
    let context: ActivityViewContext<TempoActivityAttributes>

    private var progress: Double {
        guard context.attributes.totalDuration > 0 else { return 0 }
        return 1.0 - (context.state.remainingTime / context.attributes.totalDuration)
    }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 2)

            // Progress
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    context.state.isInBreak ? Color.cyan : Color.white,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }
}

// MARK: - Minimal (single icon when space is tight)

struct MinimalView: View {
    let context: ActivityViewContext<TempoActivityAttributes>

    private var progress: Double {
        guard context.attributes.totalDuration > 0 else { return 0 }
        return 1.0 - (context.state.remainingTime / context.attributes.totalDuration)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    context.state.isInBreak ? Color.cyan : Color.white,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 14, height: 14)
    }
}

// MARK: - Expanded Dynamic Island

struct ExpandedIslandView: View {
    let context: ActivityViewContext<TempoActivityAttributes>

    private var progress: Double {
        guard context.attributes.totalDuration > 0 else { return 0 }
        return 1.0 - (context.state.remainingTime / context.attributes.totalDuration)
    }

    private var phaseLabel: String {
        context.state.isInBreak ? "break" : "focus"
    }

    var body: some View {
        VStack(spacing: 10) {
            // Progress bar — edge-to-edge thin line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 3)

                    // Fill
                    Capsule()
                        .fill(context.state.isInBreak ? Color.cyan : Color.white)
                        .frame(width: geo.size.width * progress, height: 3)
                        .shadow(color: (context.state.isInBreak ? Color.cyan : Color.white).opacity(0.5), radius: 4)
                }
            }
            .frame(height: 3)

            HStack(alignment: .center) {
                // Phase + streak
                VStack(alignment: .leading, spacing: 2) {
                    Text(phaseLabel)
                        .font(.system(size: 13, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Streak dots
                    if context.state.currentStreak > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(context.state.currentStreak, 10), id: \.self) { _ in
                                Circle()
                                    .fill(.white.opacity(0.4))
                                    .frame(width: 3, height: 3)
                            }
                            if context.state.currentStreak > 10 {
                                Text("+\(context.state.currentStreak - 10)")
                                    .font(.system(size: 8, weight: .light, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.3))
                            }
                        }
                    }
                }

                Spacer()

                // Big countdown
                Text(timeStringExpanded(from: context.state.remainingTime))
                    .font(.system(size: 32, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            // Today dots
            if context.state.todayCount > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<context.state.todayCount, id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.3))
                            .frame(width: 4, height: 4)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func timeStringExpanded(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Lock Screen / Banner

struct LockScreenView: View {
    let context: ActivityViewContext<TempoActivityAttributes>

    private var progress: Double {
        guard context.attributes.totalDuration > 0 else { return 0 }
        return 1.0 - (context.state.remainingTime / context.attributes.totalDuration)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.08))
                        .frame(height: 3)

                    Capsule()
                        .fill(context.state.isInBreak ? Color.cyan : Color.white.opacity(0.7))
                        .frame(width: geo.size.width * progress, height: 3)
                        .shadow(color: (context.state.isInBreak ? Color.cyan : Color.white).opacity(0.4), radius: 4)
                }
            }
            .frame(height: 3)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.state.isInBreak ? "break" : "focus")
                        .font(.system(size: 14, weight: .light, design: .monospaced))
                        .foregroundStyle(.secondary)

                    // Streak dots
                    if context.state.currentStreak > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(context.state.currentStreak, 12), id: \.self) { _ in
                                Circle()
                                    .fill(.white.opacity(0.35))
                                    .frame(width: 4, height: 4)
                            }
                        }
                    }
                }

                Spacer()

                Text(timeStringLock(from: context.state.remainingTime))
                    .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black)
    }

    private func timeStringLock(from t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}

// MARK: - Previews

extension TempoActivityAttributes {
    fileprivate static var preview: TempoActivityAttributes {
        TempoActivityAttributes(sessionType: "work", totalDuration: 1500)
    }
}

extension TempoActivityAttributes.ContentState {
    fileprivate static var workTime: TempoActivityAttributes.ContentState {
        TempoActivityAttributes.ContentState(remainingTime: 1200, currentStreak: 3, todayCount: 2, isInBreak: false)
    }

    fileprivate static var breakTime: TempoActivityAttributes.ContentState {
        TempoActivityAttributes.ContentState(remainingTime: 300, currentStreak: 3, todayCount: 2, isInBreak: true)
    }
}

#Preview("Notification", as: .content, using: TempoActivityAttributes.preview) {
   TempoWidgetsLiveActivity()
} contentStates: {
    TempoActivityAttributes.ContentState.workTime
    TempoActivityAttributes.ContentState.breakTime
}
