import SwiftUI
import Foundation
import CloudKit
import Combine
import ActivityKit


struct SessionSyncInfo: Codable {
    let isActive: Bool
    let startTime: Date
    let totalDuration: TimeInterval
    let workDuration: TimeInterval
    let breakDuration: TimeInterval
    let remainingTime: TimeInterval
    let currentStreak: Int
    let todayCount: Int
    let sessionType: String
    let isInBreak: Bool
    let lastUpdateTime: Date
}

// MARK: - User Settings
@Observable
class UserSettings {
    var shortWorkDuration: TimeInterval = 25 * 60
    var shortBreakDuration: TimeInterval = 5 * 60
    var longWorkDuration: TimeInterval = 50 * 60
    var longBreakDuration: TimeInterval = 10 * 60
    var interruptionMode: PomodoroSession.InterruptionMode = .strict
    var minuteHaptics: Bool = false  // Opt-in for minute ticks
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    
    init() {
        loadSettings()
    }
    
    private func loadSettings() {
        shortWorkDuration = UserDefaults.standard.object(forKey: "shortWorkDuration") as? TimeInterval ?? 25 * 60
        shortBreakDuration = UserDefaults.standard.object(forKey: "shortBreakDuration") as? TimeInterval ?? 5 * 60
        longWorkDuration = UserDefaults.standard.object(forKey: "longWorkDuration") as? TimeInterval ?? 50 * 60
        longBreakDuration = UserDefaults.standard.object(forKey: "longBreakDuration") as? TimeInterval ?? 10 * 60
        minuteHaptics = UserDefaults.standard.bool(forKey: "minuteHaptics")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(shortWorkDuration, forKey: "shortWorkDuration")
        UserDefaults.standard.set(shortBreakDuration, forKey: "shortBreakDuration")
        UserDefaults.standard.set(longWorkDuration, forKey: "longWorkDuration")
        UserDefaults.standard.set(longBreakDuration, forKey: "longBreakDuration")
        UserDefaults.standard.set(minuteHaptics, forKey: "minuteHaptics")
    }
    
    var shortSessionType: PomodoroSession.SessionType {
        .short(work: shortWorkDuration, break: shortBreakDuration)
    }
    
    var longSessionType: PomodoroSession.SessionType {
        .long(work: longWorkDuration, break: longBreakDuration)
    }
}

// MARK: - Pomodoro Session
@Observable
class PomodoroSession {
    let sessionID = UUID().uuidString.prefix(8)
    
    enum SessionState: Equatable {
        case idle
        case running(type: SessionType, startTime: Date, duration: TimeInterval)
        case breakTime(startTime: Date, duration: TimeInterval)
        case completed
        case failed
    }
    
    enum SessionType: Equatable {
        case short(work: TimeInterval, break: TimeInterval)
        case long(work: TimeInterval, break: TimeInterval)
        
        var workDuration: TimeInterval {
            switch self {
            case .short(let work, _): return work
            case .long(let work, _): return work
            }
        }
        
        var breakDuration: TimeInterval {
            switch self {
            case .short(_, let breakTime): return breakTime
            case .long(_, let breakTime): return breakTime
            }
        }
    }
    
    enum InterruptionMode: String, CaseIterable {
        case strict = "strict"
        case focused = "focused"
        case flexible = "flexible"
        case practice = "practice"
    }
    
    var state: SessionState = .idle
    var currentStreak: Int = 0
    var todayCount: Int = 0
    var interruptionMode: InterruptionMode = .strict
    var lastUpdateTime: Date = Date()
    
    static let defaultShort = SessionType.short(work: 25 * 60, break: 5 * 60)
    static let defaultLong = SessionType.long(work: 50 * 60, break: 10 * 60)
    
    var remainingTime: TimeInterval {
        switch state {
        case .running(_, let startTime, let duration):
            let elapsed = Date().timeIntervalSince(startTime)
            return max(0, duration - elapsed)
        case .breakTime(let startTime, let duration):
            let elapsed = Date().timeIntervalSince(startTime)
            return max(0, duration - elapsed)
        default:
            return 0
        }
    }
    
    func startSession(type: SessionType) {
        let now = Date()
        state = .running(type: type, startTime: now, duration: type.workDuration)
        lastUpdateTime = now
        
        // Starting haptic - confident and ready
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred(intensity: 0.8)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.prepare()
            soft.impactOccurred(intensity: 0.4)
        }
    }
    
    func stopSession() {
        state = .idle
        lastUpdateTime = Date()
        
        // Stopping haptic - gentle warning
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.warning)
    }
    
    func pauseSession() {
        // In time-based approach, pause just changes state
        lastUpdateTime = Date()
    }
    
    func resumeSession() {
        // Resume just triggers UI refresh
        lastUpdateTime = Date()
    }
    
    func checkPhaseCompletion() {
        if remainingTime <= 0 {
            completeCurrentPhase()
        }
    }
    
    func completeCurrentPhase() {
        switch state {
        case .running(let type, _, _):
            let now = Date()
            state = .breakTime(startTime: now, duration: type.breakDuration)
            lastUpdateTime = now
            triggerPhaseCompleteHaptics()
            
        case .breakTime:
            state = .completed
            todayCount += 1
            currentStreak += 1
            lastUpdateTime = Date()
            triggerSessionCompleteHaptics()
            state = .idle
            
        default:
            break
        }
    }
    
    private func triggerPhaseCompleteHaptics() {
        // Work phase done - medium satisfaction
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
        }
    }
    
    private func triggerSessionCompleteHaptics() {
        // Full session complete - maximum satisfaction
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
        
        // Success notification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let notification = UINotificationFeedbackGenerator()
            notification.prepare()
            notification.notificationOccurred(.success)
        }
        
        // Celebratory rhythm
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            medium.impactOccurred(intensity: 0.7)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: 0.5)
        }
    }
    
    var isRunning: Bool {
        switch state {
        case .running, .breakTime:
            return true
        default:
            return false
        }
    }
    
    var isInBreak: Bool {
        if case .breakTime = state {
            return true
        }
        return false
    }
    
    var formattedTime: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Brutalist Progress Bar
struct BrutalistProgressBar: View {
    let progress: Double
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Rectangle()
                    .fill(primaryColor)
                    .frame(height: 40)
                    .frame(width: geometry.size.width * progress)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}



// MARK: - Content View
struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var displayTime: String = "00:00"
    @State private var userSettings = UserSettings()
    @State private var lastMinuteMark: Int = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Stark background - pure monochrome
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            // Brutalist progress bar - only show when running
            if sessionManager.currentSession.isRunning {
                BrutalistProgressBar(progress: calculateProgress())
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                if sessionManager.currentSession.isRunning {
                    // Running view - massive brutalist text
                    VStack(spacing: 0) {
                        Text(sessionManager.currentSession.isInBreak ? "BREAK" : "FOCUS")
                            .font(.system(size: 36, weight: .black, design: .default))
                            .foregroundColor(.primary)
                            .tracking(8)
                            .padding(.bottom, 20)
                        
                        Text(displayTime)
                            .font(.system(size: 140, weight: .black, design: .default))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                            .tracking(-8)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        
                        // Brutalist progress indicator
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.primary)
                                .frame(width: geometry.size.width * calculateProgress(), height: 12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 12)
                        .padding(.top, 40)
                        
                        Button("STOP") {
                            sessionManager.stopSession()
                            hapticFeedback()
                        }
                        .buttonStyle(BrutalistButtonStyle())
                        .padding(.top, 60)
                    }
                } else {
                    // Idle view - stark interface
                    VStack(spacing: 40) {
                        // Minute haptics toggle
                        Button {
                            userSettings.minuteHaptics.toggle()
                            userSettings.saveSettings()
                            selectionHaptic()
                        } label: {
                            HStack(spacing: 12) {
                                Rectangle()
                                    .fill(.primary)
                                    .frame(width: 20, height: 20)
                                    .overlay(
                                        Rectangle()
                                            .fill(Color(UIColor.systemBackground))
                                            .frame(width: 12, height: 12)
                                            .opacity(userSettings.minuteHaptics ? 0 : 1)
                                    )
                                Text("MINUTE TICKS")
                                    .font(.system(size: 16, weight: .black, design: .default))
                                    .tracking(2)
                            }
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Stats
                        if sessionManager.currentSession.currentStreak > 0 {
                            HStack(spacing: 60) {
                                VStack(spacing: 8) {
                                    Text("\(sessionManager.currentSession.currentStreak)")
                                        .font(.system(size: 56, weight: .black, design: .default))
                                        .foregroundColor(.primary)
                                    Text("STREAK")
                                        .font(.system(size: 14, weight: .black, design: .default))
                                        .tracking(3)
                                        .foregroundColor(.primary)
                                }
                                
                                Rectangle()
                                    .fill(.primary)
                                    .frame(width: 4, height: 80)
                                
                                VStack(spacing: 8) {
                                    Text("\(sessionManager.currentSession.todayCount)")
                                        .font(.system(size: 56, weight: .black, design: .default))
                                        .foregroundColor(.primary)
                                    Text("TODAY")
                                        .font(.system(size: 14, weight: .black, design: .default))
                                        .tracking(3)
                                        .foregroundColor(.primary)
                                }
                            }
                            .padding(.vertical, 20)
                        }
                        
                        // Start buttons - massive blocks
                        VStack(spacing: 20) {
                            Button("25") {
                                sessionManager.startSession(type: userSettings.shortSessionType)
                                hapticFeedback()
                            }
                            .buttonStyle(BrutalistButtonStyle())
                            
                            Button("50") {
                                sessionManager.startSession(type: userSettings.longSessionType)
                                hapticFeedback()
                            }
                            .buttonStyle(BrutalistButtonStyle())
                        }
                    }
                }
                
                Spacer()
            }
        }
        .onReceive(timer) { _ in
            let session = sessionManager.currentSession
            
            if session.isRunning {
                session.checkPhaseCompletion()
                displayTime = session.formattedTime
                session.lastUpdateTime = Date()
                
                // Check for minute haptics
                if userSettings.minuteHaptics {
                    let currentMinute = Int(session.remainingTime) / 60
                    if currentMinute != lastMinuteMark && currentMinute > 0 {
                        // A minute has passed - trigger subtle haptic
                        minuteTickHaptic()
                        lastMinuteMark = currentMinute
                    }
                }
            } else {
                displayTime = "00:00"
                lastMinuteMark = 0
            }
        }
    }
    
    func calculateProgress() -> Double {
        let session = sessionManager.currentSession
        guard session.isRunning else { return 0.0 }
        
        switch session.state {
        case .running(_, let startTime, let duration):
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = elapsed / duration
            return min(max(progress, 0.0), 1.0)
            
        case .breakTime(let startTime, let duration):
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = elapsed / duration
            return min(max(progress, 0.0), 1.0)
            
        default:
            return 0.0
        }
    }
    
    func hapticFeedback() {
        // Modern haptic composition - subtle but satisfying
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred(intensity: 0.7)
        
        // Add a tiny secondary tap for texture
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let soft = UIImpactFeedbackGenerator(style: .soft)
            soft.prepare()
            soft.impactOccurred(intensity: 0.3)
        }
    }
    
    func successHaptics() {
        // Session complete celebration
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        notification.notificationOccurred(.success)
        
        // Add satisfying impacts
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let medium = UIImpactFeedbackGenerator(style: .medium)
            medium.prepare()
            medium.impactOccurred(intensity: 0.8)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let light = UIImpactFeedbackGenerator(style: .light)
            light.prepare()
            light.impactOccurred(intensity: 0.5)
        }
    }
    
    func selectionHaptic() {
        // Clean selection feedback
        let selection = UISelectionFeedbackGenerator()
        selection.prepare()
        selection.selectionChanged()
    }
    
    func minuteTickHaptic() {
        // Very subtle tick - like a luxury watch
        let impact = UIImpactFeedbackGenerator(style: .soft)
        impact.prepare()
        impact.impactOccurred(intensity: 0.3)
    }
}

struct BrutalistButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 72, weight: .black, design: .default))
            .foregroundColor(configuration.isPressed ? Color(UIColor.systemBackground) : .primary)
            .tracking(4)
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                Rectangle()
                    .fill(configuration.isPressed ? .primary : Color(UIColor.systemBackground))
                    .overlay(
                        Rectangle()
                            .stroke(.primary, lineWidth: 6)
                    )
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    // Immediate tactile response on press
                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                    impact.prepare()
                    impact.impactOccurred(intensity: 0.8)
                }
            }
    }
}

// Notification names are defined in Persistence.swift

#Preview {
    ContentView()
        .environment(SessionManager())
}