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

// MARK: - Edge Progress Bar
struct EdgeProgressBar: View {
    let progress: Double
    @State private var displayProgress: Double = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private var primaryColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        ZStack {
            // Background track - subtle edge trace
            ScreenEdgeShape(cornerRadius: UIScreen.main.displayCornerRadius)
                .stroke(primaryColor.opacity(0.05), lineWidth: 4)
            
            // Progress stroke - smooth Swiss watch movement
            ScreenEdgeShape(cornerRadius: UIScreen.main.displayCornerRadius)
                .trim(from: 0, to: displayProgress)
                .stroke(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.8),
                            primaryColor.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(
                        lineWidth: 4,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .shadow(color: primaryColor.opacity(0.3), radius: 2)
                .shadow(color: primaryColor.opacity(0.1), radius: 4)
        }
        .onAppear {
            displayProgress = progress
        }
        .onChange(of: progress) { oldValue, newValue in
            withAnimation(.easeInOut(duration: 0.5)) {
                displayProgress = newValue
            }
        }
    }
}

// MARK: - Screen Edge Shape
struct ScreenEdgeShape: Shape {
    let cornerRadius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let padding: CGFloat = 0
        
        let innerRect = CGRect(
            x: padding,
            y: padding,
            width: rect.width - (padding * 2),
            height: rect.height - (padding * 2)
        )
        
        // Begin path from top-center and trace clockwise
        path.move(to: CGPoint(x: innerRect.midX, y: innerRect.minY))
        
        // Top edge
        path.addLine(to: CGPoint(x: innerRect.maxX - cornerRadius, y: innerRect.minY))
        
        // Top-right corner arc
        path.addArc(
            center: CGPoint(x: innerRect.maxX - cornerRadius, y: innerRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: -90),
            endAngle: Angle(degrees: 0),
            clockwise: false
        )
        
        // Right edge
        path.addLine(to: CGPoint(x: innerRect.maxX, y: innerRect.maxY - cornerRadius))
        
        // Bottom-right corner arc
        path.addArc(
            center: CGPoint(x: innerRect.maxX - cornerRadius, y: innerRect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 0),
            endAngle: Angle(degrees: 90),
            clockwise: false
        )
        
        // Bottom edge
        path.addLine(to: CGPoint(x: innerRect.minX + cornerRadius, y: innerRect.maxY))
        
        // Bottom-left corner arc
        path.addArc(
            center: CGPoint(x: innerRect.minX + cornerRadius, y: innerRect.maxY - cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 90),
            endAngle: Angle(degrees: 180),
            clockwise: false
        )
        
        // Left edge
        path.addLine(to: CGPoint(x: innerRect.minX, y: innerRect.minY + cornerRadius))
        
        // Top-left corner arc
        path.addArc(
            center: CGPoint(x: innerRect.minX + cornerRadius, y: innerRect.minY + cornerRadius),
            radius: cornerRadius,
            startAngle: Angle(degrees: 180),
            endAngle: Angle(degrees: 270),
            clockwise: false
        )
        
        return path
    }
}

// Extension to get display corner radius
extension UIScreen {
    var displayCornerRadius: CGFloat {
        // Get the actual device corner radius
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return 39.0 // Default for modern iPhones
        }
        
        // Use the actual safe area and estimate corner radius
        let hasNotch = window.safeAreaInsets.top > 20
        if hasNotch {
            // Modern devices with notch/Dynamic Island
            return window.safeAreaInsets.top > 50 ? 55.0 : 39.0
        } else {
            // Older devices without notch
            return 0
        }
    }
}

// MARK: - Content View
struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var displayTime: String = "00:00"
    @State private var userSettings = UserSettings()
    @State private var buttonsVisible = false
    @State private var button25Scale: CGFloat = 0.8
    @State private var button50Scale: CGFloat = 0.8
    @State private var button25Opacity: Double = 0
    @State private var button50Opacity: Double = 0
    @State private var statsOpacity: Double = 0
    @State private var timerScale: CGFloat = 0.9
    @State private var progressBarWidth: CGFloat = 0
    @State private var blurRadius: CGFloat = 10
    @State private var lastMinuteMark: Int = 0
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            // Glass background
            Color(UIColor.systemBackground)
                .overlay(Rectangle().fill(.ultraThinMaterial).opacity(0.3))
                .ignoresSafeArea()
            
            // Edge progress bar - only show when running
            if sessionManager.currentSession.isRunning {
                EdgeProgressBar(progress: calculateProgress())
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .id(displayTime) // Force refresh when time changes
            }
            
            VStack(spacing: 60) {
                Spacer()
                
                if sessionManager.currentSession.isRunning {
                    // Running view with entrance animation
                    VStack(spacing: 20) {
                        Text(sessionManager.currentSession.isInBreak ? "break" : "focus")
                            .font(.system(size: 14, weight: .light, design: .monospaced))
                            .foregroundColor(.primary.opacity(0.6))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        
                        Text(displayTime)
                            .font(.system(size: 96, weight: .ultraLight, design: .monospaced))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                            .scaleEffect(timerScale)
                            .onAppear {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    timerScale = 1.0
                                }
                            }
                            .onDisappear {
                                timerScale = 0.9
                            }
                        
                        // Progress bar with delayed entrance
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(.primary.opacity(0.1))
                                    .frame(height: 2)
                                    .scaleEffect(x: progressBarWidth, y: 1, anchor: .leading)
                                
                                Rectangle()
                                    .fill(.primary.opacity(0.5))
                                    .frame(width: geometry.size.width * calculateProgress(), height: 2)
                                    .animation(.linear(duration: 0.5), value: calculateProgress())
                                    .opacity(progressBarWidth)
                            }
                        }
                        .frame(height: 2)
                        .padding(.horizontal, 40)
                        .onAppear {
                            withAnimation(.easeOut(duration: 0.8).delay(0.4)) {
                                progressBarWidth = 1
                            }
                        }
                        .onDisappear {
                            progressBarWidth = 0
                        }
                        
                        Button("stop") {
                            sessionManager.stopSession()
                            hapticFeedback()
                        }
                        .buttonStyle(GlassButtonStyle())
                    }
                } else {
                    // Idle view with staggered animations
                    VStack(spacing: 30) {
                        // Minute haptics toggle
                        Button {
                            userSettings.minuteHaptics.toggle()
                            userSettings.saveSettings()
                            selectionHaptic()
                        } label: {
                            HStack {
                                Image(systemName: userSettings.minuteHaptics ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                Text("minute ticks")
                                    .font(.system(size: 12, weight: .light, design: .monospaced))
                            }
                            .foregroundColor(.primary.opacity(0.5))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Stats with fade in
                        if sessionManager.currentSession.currentStreak > 0 {
                            HStack(spacing: 40) {
                                VStack {
                                    Text("\(sessionManager.currentSession.currentStreak)")
                                        .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Text("streak")
                                        .font(.system(size: 10, weight: .light, design: .monospaced))
                                        .foregroundColor(.primary.opacity(0.5))
                                }
                                
                                VStack {
                                    Text("\(sessionManager.currentSession.todayCount)")
                                        .font(.system(size: 24, weight: .ultraLight, design: .monospaced))
                                        .foregroundColor(.primary)
                                    Text("today")
                                        .font(.system(size: 10, weight: .light, design: .monospaced))
                                        .foregroundColor(.primary.opacity(0.5))
                                }
                            }
                            .opacity(statsOpacity)
                            .animation(.easeOut(duration: 0.6).delay(0.1), value: statsOpacity)
                        }
                        
                        // Start buttons with staggered scale/fade
                        HStack(spacing: 40) {
                            Button("25") {
                                sessionManager.startSession(type: userSettings.shortSessionType)
                                hapticFeedback()
                            }
                            .buttonStyle(GlassButtonStyle())
                            .scaleEffect(button25Scale)
                            .opacity(button25Opacity)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: button25Scale)
                            .animation(.easeOut(duration: 0.4).delay(0.2), value: button25Opacity)
                            
                            Button("50") {
                                sessionManager.startSession(type: userSettings.longSessionType)
                                hapticFeedback()
                            }
                            .buttonStyle(GlassButtonStyle())
                            .scaleEffect(button50Scale)
                            .opacity(button50Opacity)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.35), value: button50Scale)
                            .animation(.easeOut(duration: 0.4).delay(0.35), value: button50Opacity)
                        }
                    }
                    .onAppear {
                        // Trigger the animations
                        withAnimation {
                            statsOpacity = 1
                            button25Scale = 1
                            button25Opacity = 1
                            button50Scale = 1
                            button50Opacity = 1
                        }
                    }
                    .onDisappear {
                        // Reset for next appearance
                        statsOpacity = 0
                        button25Scale = 0.8
                        button25Opacity = 0
                        button50Scale = 0.8
                        button50Opacity = 0
                    }
                }
                
                Spacer()
            }
        }
        .blur(radius: blurRadius)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                blurRadius = 0
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

struct GlassButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 36, weight: .ultraLight, design: .monospaced))
            .foregroundColor(.primary.opacity(0.9))
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .opacity(configuration.isPressed ? 0.5 : 0.7)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    // Immediate tactile response on press
                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                    impact.prepare()
                    impact.impactOccurred(intensity: 0.5)
                }
            }
    }
}

// Notification names are defined in Persistence.swift

#Preview {
    ContentView()
        .environment(SessionManager())
}