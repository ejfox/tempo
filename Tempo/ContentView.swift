import SwiftUI
import Foundation
import CloudKit
import Combine
import ActivityKit

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

// MARK: - User Settings Management
/// Manages user-customizable timer settings and preferences
/// Persists to UserDefaults and syncs across devices via NSUbiquitousKeyValueStore
@Observable
class UserSettings {
    // Default Pomodoro intervals (in seconds)
    var shortWorkDuration: TimeInterval = 25 * 60      // 25 minutes
    var shortBreakDuration: TimeInterval = 5 * 60      // 5 minutes  
    var longWorkDuration: TimeInterval = 50 * 60       // 50 minutes
    var longBreakDuration: TimeInterval = 10 * 60      // 10 minutes
    var interruptionMode: PomodoroSession.InterruptionMode = .strict
    
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    
    init() {
        loadSettings()
        setupSync()
    }
    
    private func loadSettings() {
        // Load from UserDefaults first, then check iCloud
        shortWorkDuration = UserDefaults.standard.object(forKey: "shortWorkDuration") as? TimeInterval ?? 25 * 60
        shortBreakDuration = UserDefaults.standard.object(forKey: "shortBreakDuration") as? TimeInterval ?? 5 * 60
        longWorkDuration = UserDefaults.standard.object(forKey: "longWorkDuration") as? TimeInterval ?? 50 * 60
        longBreakDuration = UserDefaults.standard.object(forKey: "longBreakDuration") as? TimeInterval ?? 10 * 60
        
        if let modeString = UserDefaults.standard.string(forKey: "interruptionMode") {
            interruptionMode = PomodoroSession.InterruptionMode(rawValue: modeString) ?? .strict
        }
    }
    
    func saveSettings() {
        // Save to UserDefaults
        UserDefaults.standard.set(shortWorkDuration, forKey: "shortWorkDuration")
        UserDefaults.standard.set(shortBreakDuration, forKey: "shortBreakDuration")
        UserDefaults.standard.set(longWorkDuration, forKey: "longWorkDuration")
        UserDefaults.standard.set(longBreakDuration, forKey: "longBreakDuration")
        UserDefaults.standard.set(interruptionMode.rawValue, forKey: "interruptionMode")
        
        // Sync to iCloud
        ubiquitousStore.set(shortWorkDuration, forKey: "shortWorkDuration")
        ubiquitousStore.set(shortBreakDuration, forKey: "shortBreakDuration")
        ubiquitousStore.set(longWorkDuration, forKey: "longWorkDuration")
        ubiquitousStore.set(longBreakDuration, forKey: "longBreakDuration")
        ubiquitousStore.set(interruptionMode.rawValue, forKey: "interruptionMode")
        ubiquitousStore.synchronize()
    }
    
    private func setupSync() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { _ in
            self.syncFromCloud()
        }
    }
    
    private func syncFromCloud() {
        if let cloudShortWork = ubiquitousStore.object(forKey: "shortWorkDuration") as? TimeInterval {
            shortWorkDuration = cloudShortWork
        }
        if let cloudShortBreak = ubiquitousStore.object(forKey: "shortBreakDuration") as? TimeInterval {
            shortBreakDuration = cloudShortBreak
        }
        if let cloudLongWork = ubiquitousStore.object(forKey: "longWorkDuration") as? TimeInterval {
            longWorkDuration = cloudLongWork
        }
        if let cloudLongBreak = ubiquitousStore.object(forKey: "longBreakDuration") as? TimeInterval {
            longBreakDuration = cloudLongBreak
        }
        if let cloudModeString = ubiquitousStore.string(forKey: "interruptionMode") {
            interruptionMode = PomodoroSession.InterruptionMode(rawValue: cloudModeString) ?? .strict
        }
    }
    
    var shortSessionType: PomodoroSession.SessionType {
        .short(work: shortWorkDuration, break: shortBreakDuration)
    }
    
    var longSessionType: PomodoroSession.SessionType {
        .long(work: longWorkDuration, break: longBreakDuration)
    }
}

// MARK: - Core Timer Logic
/// PomodoroSession manages the core timer functionality and state transitions
/// Handles work/break cycles, interruption modes, and background/foreground state
/// Uses @Observable for SwiftUI reactive updates
@Observable
class PomodoroSession {
    let sessionID = UUID().uuidString.prefix(8)
    
    // MARK: - Session State Management
    /// Represents the current state of a Pomodoro session
    /// Time-based approach: store start time and duration, calculate remaining time dynamically
    enum SessionState: Equatable {
        case idle                                                               // No active session
        case running(type: SessionType, startTime: Date, duration: TimeInterval)  // Work phase active
        case breakTime(startTime: Date, duration: TimeInterval)                // Break phase active  
        case completed                                                          // Session finished successfully
        case failed                                                            // Session interrupted/failed
        
        static func == (lhs: SessionState, rhs: SessionState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.completed, .completed), (.failed, .failed):
                return true
            case (.running(let lType, _, _), .running(let rType, _, _)):
                return lType == rType
            case (.breakTime, .breakTime):
                return true
            default:
                return false
            }
        }
    }
    
    // MARK: - Session Types
    /// Defines the two core Pomodoro session types with their durations
    /// Default configurations: 25/5 (focused) and 50/10 (deep work)
    enum SessionType: Equatable {
        case short(work: TimeInterval, break: TimeInterval)    // 25min work / 5min break
        case long(work: TimeInterval, break: TimeInterval)     // 50min work / 10min break
        
        /// Duration of the work phase for this session type
        var workDuration: TimeInterval {
            switch self {
            case .short(let work, _): return work
            case .long(let work, _): return work
            }
        }
        
        /// Duration of the break phase for this session type  
        var breakDuration: TimeInterval {
            switch self {
            case .short(_, let breakTime): return breakTime
            case .long(_, let breakTime): return breakTime
            }
        }
    }
    
    // MARK: - Interruption Handling
    /// Defines how the session responds to app backgrounding/interruptions
    /// Strict mode fails immediately, Practice mode never fails
    enum InterruptionMode: String, CaseIterable {
        case strict = "strict"      // Fails after 2 seconds in background
        case focused = "focused"    // Fails after 2 minutes in background  
        case flexible = "flexible"  // Auto-pauses, can resume same day
        case practice = "practice"  // Never fails, doesn't count toward streaks
    }
    
    var state: SessionState = .idle
    var currentStreak: Int = 0
    var todayCount: Int = 0
    var interruptionMode: InterruptionMode = .strict
    var isBackgrounded: Bool = false
    var lastUpdateTime: Date = Date()
    
    private var backgroundTime: Date?
    
    static let defaultShort = SessionType.short(work: 25 * 60, break: 5 * 60)
    static let defaultLong = SessionType.long(work: 50 * 60, break: 10 * 60)
    
    /// Calculated remaining time based on start time and duration
    /// This is the single source of truth for timer display
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
    
    init() {
        setupBackgroundNotifications()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleBackground()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleForeground()
        }
    }
    
    func startSession(type: SessionType) {
        print("🎯 PomodoroSession[\(sessionID)].startSession called with type: \(type)")
        let now = Date()
        state = .running(type: type, startTime: now, duration: type.workDuration)
        lastUpdateTime = now
        print("🎯 Session[\(sessionID)] Started at \(now), duration: \(type.workDuration)s")
        print("🎯 Session[\(sessionID)] Calculated remainingTime: \(remainingTime) seconds")
    }
    
    func pauseSession() {
        // In time-based approach, pause just changes state
        // UI will stop updating, but time calculation remains accurate
        print("⏸️ Session[\(sessionID)] Paused")
    }
    
    func resumeSession() {
        // Resume just triggers UI refresh
        lastUpdateTime = Date()
        print("▶️ Session[\(sessionID)] Resumed")
    }
    
    func stopSession() {
        switch state {
        case .running:
            state = .failed
            currentStreak = 0
        case .breakTime:
            state = .completed
            todayCount += 1
            currentStreak += 1
        default:
            break
        }
        
        state = .idle
        lastUpdateTime = Date()
        print("🛑 Session[\(sessionID)] Stopped")
    }
    
    /// Check if current phase should complete based on elapsed time
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
            triggerVictoryHaptics()
            NotificationCenter.default.post(name: .workPhaseCompleted, object: nil)
            print("✅ Work phase completed, starting break: \(type.breakDuration)s")
            
        case .breakTime:
            state = .completed
            todayCount += 1
            currentStreak += 1
            lastUpdateTime = Date()
            triggerVictoryHaptics()
            NotificationCenter.default.post(name: .sessionCompleted, object: nil)
            state = .idle
            print("🎉 Session completed! Streak: \(currentStreak), Today: \(todayCount)")
            
        default:
            break
        }
    }
    
    private func handleBackground() {
        isBackgrounded = true
        backgroundTime = Date()
    }
    
    private func handleForeground() {
        isBackgrounded = false
        
        guard let backgroundTime = backgroundTime else { return }
        let timeAwayInterval = Date().timeIntervalSince(backgroundTime)
        
        switch interruptionMode {
        case .strict:
            if timeAwayInterval > 2.0 {
                failSession()
            }
        case .focused:
            if timeAwayInterval > 120.0 {
                failSession()
            }
        case .flexible:
            break
        case .practice:
            break
        }
        
        self.backgroundTime = nil
        
        if case .running = state, !isSessionFailed() {
            // In time-based approach, just check if phase should complete
            checkPhaseCompletion()
        }
    }
    
    private func failSession() {
        state = .failed
        currentStreak = 0
        lastUpdateTime = Date()
        state = .idle
        print("❌ Session[\(sessionID)] Failed due to interruption")
    }
    
    private func isSessionFailed() -> Bool {
        if case .failed = state {
            return true
        }
        return false
    }
    
    private func triggerVictoryHaptics() {
        // 2025 Enhanced Victory Haptic Sequence - Sparks Maximum Joy! 🎉
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
        
        // Success notification early for immediate satisfaction
        let success = UINotificationFeedbackGenerator()
        success.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            success.notificationOccurred(.success)
        }
        
        // Cascading medium impacts for rhythm
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let medium1 = UIImpactFeedbackGenerator(style: .medium)
            medium1.prepare()
            medium1.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let medium2 = UIImpactFeedbackGenerator(style: .medium)
            medium2.prepare()
            medium2.impactOccurred()
        }
        
        // Light tap sequence for celebration feel
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let light1 = UIImpactFeedbackGenerator(style: .light)
            light1.prepare()
            light1.impactOccurred()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let light2 = UIImpactFeedbackGenerator(style: .light)
            light2.prepare()
            light2.impactOccurred()
        }
        
        // Final success confirmation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let finalSuccess = UINotificationFeedbackGenerator()
            finalSuccess.prepare()
            finalSuccess.notificationOccurred(.success)
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
    
    func updateFromPersistence(_ tempoSession: TempoSession) {
        // Update existing session properties instead of creating new instance
        print("📥 Session[\(sessionID)] Updating from persistence")
        
        // Update state based on persistence
        switch tempoSession.state {
        case "running":
            if let startTime = tempoSession.startTime {
                let sessionType: SessionType = tempoSession.sessionType == "short" 
                    ? .short(work: tempoSession.workDuration, break: tempoSession.breakDuration)
                    : .long(work: tempoSession.workDuration, break: tempoSession.breakDuration)
                state = .running(type: sessionType, startTime: startTime, duration: tempoSession.workDuration)
            }
        case "breakTime":
            if let startTime = tempoSession.startTime {
                state = .breakTime(startTime: startTime, duration: tempoSession.breakDuration)
            }
        case "completed":
            state = .completed
        case "failed":
            state = .failed
        default:
            state = .idle
        }
        
        lastUpdateTime = Date()
        print("📥 Session[\(sessionID)] Updated - state: \(state), remaining: \(remainingTime)")
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(SessionManager.self) private var sessionManager
    @State private var isPressed25 = false
    @State private var isPressed50 = false
    @State private var confettiTrigger = false
    @State private var showingSettings = false
    @State private var userSettings = UserSettings()
    @State private var displayTime: String = "00:00"
    
    // Apple recommended timer approach
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            if showingSettings {
                settingsView
            } else if sessionManager.currentSession.isRunning {
                runningSessionView
            } else {
                idleView
            }
            
            if confettiTrigger {
                confettiView
            }
        }
        .onReceive(timer) { _ in
            let session = sessionManager.currentSession
            
            if session.isRunning {
                // Check if phase should complete (time-based)
                session.checkPhaseCompletion()
                
                // Update display time
                displayTime = session.formattedTime
                
                // Update lastUpdateTime to trigger @Observable
                session.lastUpdateTime = Date()
            } else {
                displayTime = "00:00"
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .sessionCompleted)) { _ in
            withAnimation(.easeInOut(duration: 0.4)) {
                confettiTrigger = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    confettiTrigger = false
                }
            }
        }
    }
    
    var idleView: some View {
        VStack(spacing: 50) {
            VStack(spacing: 20) {
                HStack {
                    Spacer()
                    
                    Text("TEMPO")
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundColor(primaryTextColor)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSettings = true
                        }
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                if sessionManager.currentSession.currentStreak > 0 {
                    HStack(spacing: 15) {
                        Text("STREAK \(sessionManager.currentSession.currentStreak)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                        
                        Text("TODAY \(sessionManager.currentSession.todayCount)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(secondaryTextColor)
                    }
                }
                
                Text("Pure time, no clutter.")
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(secondaryTextColor)
            }
            
            VStack(spacing: 20) {
                Button("25/5 FOCUSED") {
                    print("🔥 25/5 button pressed")
                    
                    // Enhanced haptic sequence for joy - 2025 style
                    let heavy = UIImpactFeedbackGenerator(style: .heavy)
                    heavy.prepare()
                    heavy.impactOccurred()
                    
                    let notification = UINotificationFeedbackGenerator()
                    notification.prepare()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        notification.notificationOccurred(.success)
                    }
                    
                    sessionManager.startSession(type: userSettings.shortSessionType)
                }
                .buttonStyle(.borderedProminent)
                .font(.system(.title2, design: .monospaced))
                .scaleEffect(isPressed25 ? 0.95 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed25)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed25 = pressing
                    }
                }, perform: {})
                
                Button("50/10 DEEP WORK") {
                    print("🔥 50/10 button pressed")
                    
                    // Enhanced haptic sequence for joy - 2025 style
                    let heavy = UIImpactFeedbackGenerator(style: .heavy)
                    heavy.prepare()
                    heavy.impactOccurred()
                    
                    let notification = UINotificationFeedbackGenerator()
                    notification.prepare()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        notification.notificationOccurred(.success)
                    }
                    
                    sessionManager.startSession(type: userSettings.longSessionType)
                }
                .buttonStyle(.borderedProminent)
                .font(.system(.title2, design: .monospaced))
                .scaleEffect(isPressed50 ? 0.95 : 1.0)
                .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.6), value: isPressed50)
                .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed50 = pressing
                    }
                }, perform: {})
            }
        }
    }
    
    var runningSessionView: some View {
        VStack(spacing: 60) {
            VStack(spacing: 10) {
                Text(sessionManager.currentSession.isInBreak ? "BREAK" : "FOCUS")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .foregroundColor(sessionManager.currentSession.isInBreak ? .green : primaryTextColor)
                
                Text(displayTime)
                    .font(.system(size: 72, weight: .bold, design: .monospaced))
                    .foregroundColor(primaryTextColor)
                    .monospacedDigit()
            }
            
            HStack(spacing: 40) {
                Button("PAUSE") {
                    sessionManager.pauseSession()
                }
                .buttonStyle(SecondaryButtonStyle(colorScheme: colorScheme))
                
                Button("STOP") {
                    sessionManager.stopSession()
                }
                .buttonStyle(DestructiveButtonStyle(colorScheme: colorScheme))
            }
        }
    }
    
    var confettiView: some View {
        ZStack {
            ForEach(0..<16, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(i % 2 == 0 ? Color.accentColor : Color.primary)
                    .frame(width: 3, height: 20 + Double(i % 4) * 10)
                    .offset(
                        x: confettiTrigger ? CGFloat.random(in: -100...100) : 0,
                        y: confettiTrigger ? -500 - CGFloat.random(in: 0...100) : 0
                    )
                    .rotationEffect(.degrees(confettiTrigger ? Double.random(in: -180...180) : 0))
                    .opacity(confettiTrigger ? 0 : 1)
                    .animation(
                        .easeOut(duration: 1.2 + Double.random(in: -0.3...0.3))
                        .delay(Double(i) * 0.03),
                        value: confettiTrigger
                    )
            }
            
            Circle()
                .fill(Color.accentColor.opacity(0.3))
                .frame(width: confettiTrigger ? 200 : 0, height: confettiTrigger ? 200 : 0)
                .animation(.easeOut(duration: 0.6), value: confettiTrigger)
        }
    }
    
    var settingsView: some View {
        VStack(spacing: 30) {
            VStack(spacing: 20) {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSettings = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(secondaryTextColor)
                    }
                    
                    Spacer()
                    
                    Text("SETTINGS")
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .foregroundColor(primaryTextColor)
                    
                    Spacer()
                    
                    Button("SAVE") {
                        userSettings.saveSettings()
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingSettings = false
                        }
                    }
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(primaryTextColor)
                }
                .padding(.horizontal)
            }
            
            ScrollView {
                VStack(spacing: 25) {
                    settingsSection(title: "FOCUSED SESSION") {
                        timeSlider(
                            title: "Work",
                            value: Binding(
                                get: { userSettings.shortWorkDuration / 60 },
                                set: { userSettings.shortWorkDuration = $0 * 60 }
                            ),
                            range: 10...60,
                            suffix: "min"
                        )
                        
                        timeSlider(
                            title: "Break",
                            value: Binding(
                                get: { userSettings.shortBreakDuration / 60 },
                                set: { userSettings.shortBreakDuration = $0 * 60 }
                            ),
                            range: 1...15,
                            suffix: "min"
                        )
                    }
                    
                    settingsSection(title: "DEEP WORK SESSION") {
                        timeSlider(
                            title: "Work",
                            value: Binding(
                                get: { userSettings.longWorkDuration / 60 },
                                set: { userSettings.longWorkDuration = $0 * 60 }
                            ),
                            range: 25...120,
                            suffix: "min"
                        )
                        
                        timeSlider(
                            title: "Break",
                            value: Binding(
                                get: { userSettings.longBreakDuration / 60 },
                                set: { userSettings.longBreakDuration = $0 * 60 }
                            ),
                            range: 5...30,
                            suffix: "min"
                        )
                    }
                    
                    settingsSection(title: "INTERRUPTION MODE") {
                        VStack(spacing: 12) {
                            ForEach(PomodoroSession.InterruptionMode.allCases, id: \.self) { mode in
                                Button {
                                    userSettings.interruptionMode = mode
                                    let selection = UISelectionFeedbackGenerator()
                                    selection.selectionChanged()
                                } label: {
                                    HStack {
                                        Text(mode.rawValue.uppercased())
                                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                                            .foregroundColor(userSettings.interruptionMode == mode ? buttonTextColor : primaryTextColor)
                                        
                                        Spacer()
                                        
                                        Text(modeDescription(mode))
                                            .font(.system(size: 14, weight: .regular, design: .monospaced))
                                            .foregroundColor(secondaryTextColor)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(userSettings.interruptionMode == mode ? buttonBackgroundColor : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(primaryTextColor.opacity(0.3), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    func settingsSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(title)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundColor(primaryTextColor)
            
            content()
        }
    }
    
    func timeSlider(title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(primaryTextColor)
                
                Spacer()
                
                Text("\(Int(value.wrappedValue)) \(suffix)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(primaryTextColor)
            }
            
            Slider(value: value, in: range, step: 1)
                .accentColor(.primary)
        }
    }
    
    func modeDescription(_ mode: PomodoroSession.InterruptionMode) -> String {
        switch mode {
        case .strict: return "Fails after 2s in background"
        case .focused: return "Fails after 2min in background"
        case .flexible: return "Auto-pauses, can resume"
        case .practice: return "Never fails, no streak"
        }
    }
    
    func mechanicalButton(
        text: String,
        subtitle: String,
        isPressed: Bool,
        action: @escaping () -> Void,
        pressedChange: @escaping (Bool) -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundColor(buttonTextColor)
                
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(buttonTextColor.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(buttonBackgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1),
                radius: isPressed ? 2 : 8,
                x: 0,
                y: isPressed ? 1 : 4
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1)) {
                pressedChange(pressing)
            }
            
            if pressing {
                let impact = UIImpactFeedbackGenerator(style: .medium)
                impact.prepare()
                impact.impactOccurred()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    let light = UIImpactFeedbackGenerator(style: .light)
                    light.prepare()
                    light.impactOccurred()
                }
            } else {
                let selection = UISelectionFeedbackGenerator()
                selection.prepare()
                selection.selectionChanged()
            }
        }, perform: {
            // This perform block was empty, which was preventing the Button action from firing
            // Now the action will be called when the long press completes
            action()
        })
    }
    
    func startSession(type: PomodoroSession.SessionType) {
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
        
        let notification = UINotificationFeedbackGenerator()
        notification.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            notification.notificationOccurred(.success)
        }
        
        withAnimation(.interactiveSpring(response: 0.4, dampingFraction: 0.75, blendDuration: 0.2)) {
            sessionManager.startSession(type: type)
        }
    }
    
    var primaryTextColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var secondaryTextColor: Color {
        colorScheme == .dark ? .gray : .black.opacity(0.6)
    }
    
    var buttonBackgroundColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var buttonTextColor: Color {
        colorScheme == .dark ? .black : .white
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.clear)
            .foregroundColor(colorScheme == .dark ? .white : .black)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(colorScheme == .dark ? .white : .black, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .monospaced))
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
