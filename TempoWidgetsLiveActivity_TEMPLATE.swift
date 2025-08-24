import ActivityKit
import WidgetKit
import SwiftUI

struct TempoWidgetsLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TempoActivityAttributes.self) { context in
            // Lock screen/banner UI goes here
            LiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here
                DynamicIslandExpandedRegion(.leading) {
                    Text("Focus")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.currentStreak)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)
                        
                        Text(timeString(from: context.state.remainingTime))
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
            } compactLeading: {
                Circle()
                    .fill(context.state.isInBreak ? .green : .red)
                    .frame(width: 8, height: 8)
            } compactTrailing: {
                Text(timeString(from: context.state.remainingTime))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.primary)
            } minimal: {
                Circle()
                    .fill(context.state.isInBreak ? .green : .red)
                    .frame(width: 8, height: 8)
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(context.state.isInBreak ? "Break Time" : "Focus Time")
                    .font(.headline)
                    .foregroundColor(.primary)
                
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
        .background(Color(.systemBackground))
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}