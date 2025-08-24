//
//  TempoWidgetsLiveActivity.swift
//  TempoWidgets
//
//  Created by EJ Fox on 8/19/25.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Use the same attributes defined in ContentView.swift
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

struct TempoWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.state.isInBreak ? "Break" : "Focus")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Circle()
                            .fill(context.state.isInBreak ? .green : .red)
                            .frame(width: 8, height: 8)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Streak")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(context.state.currentStreak)")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(timeString(from: context.state.remainingTime))
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("Today: \(context.state.todayCount)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Circle()
                    .fill(context.state.isInBreak ? .green : .red)
                    .frame(width: 12, height: 12)
            } compactTrailing: {
                Text(timeString(from: context.state.remainingTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            } minimal: {
                Circle()
                    .fill(context.state.isInBreak ? .green : .red)
                    .frame(width: 12, height: 12)
            }
        }
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct LiveActivityView: View {
    let context: ActivityViewContext<TempoActivityAttributes>
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(context.state.isInBreak ? .green : .red)
                        .frame(width: 8, height: 8)
                    
                    Text(context.state.isInBreak ? "Break Time" : "Focus Time")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
                Text("Streak: \(context.state.currentStreak)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(timeString(from: context.state.remainingTime))
                    .font(.system(size: 20, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
                
                Text("Today: \(context.state.todayCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(colorScheme == .dark ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

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
