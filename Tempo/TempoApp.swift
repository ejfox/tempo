//
//  TempoApp.swift
//  Tempo
//
//  Created by EJ Fox on 8/15/25.
//

import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Session Management
/// SessionManager coordinates between UI, persistence, and cross-device sync
/// Manages Live Activities, real-time sync via NSUbiquitousKeyValueStore,
/// and handles session lifecycle events
@Observable
class SessionManager {
    // MARK: - Core Dependencies
    private let persistenceController: PersistenceController
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    
    // MARK: - Published State
    var currentSession: PomodoroSession {
        didSet {
            print("🔄 SessionManager currentSession changed")
        }
    }
    var userStats: UserStats?
    
    // MARK: - Private State
    private var liveActivityTimer: Timer?
    
    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
        
        // Always start with a fresh session
        self.currentSession = PomodoroSession()
        self.userStats = persistenceController.getOrCreateUserStats()
        
        setupNotifications()
        setupUbiquitousStoreSync()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: .tempoDataUpdated,
            object: nil,
            queue: .main
        ) { _ in
            self.refreshFromPersistence()
        }
        
        NotificationCenter.default.addObserver(
            forName: .workPhaseCompleted,
            object: nil,
            queue: .main
        ) { _ in
            self.handleWorkPhaseCompletion()
        }
        
        NotificationCenter.default.addObserver(
            forName: .sessionCompleted,
            object: nil,
            queue: .main
        ) { _ in
            self.handleSessionCompletion()
        }
    }
    
    private func restoreSessionIfActive() {
        if let activeSession = persistenceController.getActiveSession() {
            // Update existing session instead of creating new instance
            currentSession.updateFromPersistence(activeSession)
            
            if case .running = currentSession.state {
                if currentSession.remainingTime > 0 {
                    currentSession.resumeSession()
                } else {
                    currentSession.completeCurrentPhase()
                }
            } else if case .breakTime = currentSession.state {
                if currentSession.remainingTime > 0 {
                    currentSession.resumeSession()
                } else {
                    finishSession()
                }
            }
        }
    }
    
    // MARK: - Session Control
    /// Starts a new Pomodoro session with the specified type
    /// Initializes Live Activities, cross-device sync, and persistent storage
    func startSession(type: PomodoroSession.SessionType) {
        print("🚀 SessionManager.startSession called with type: \(type)")
        
        // Use the EXISTING currentSession instance instead of creating new one
        currentSession.startSession(type: type)
        
        print("🚀 SessionManager currentSession remainingTime: \(currentSession.remainingTime)")
        print("🚀 SessionManager currentSession isRunning: \(currentSession.isRunning)")
        
        // Save to persistence
        _ = persistenceController.createSession(type: type)
        
        currentSession.currentStreak = Int(userStats?.currentStreak ?? 0)
        currentSession.todayCount = Int(userStats?.todayCount ?? 0)
        
        persistenceController.resetDailyStatsIfNeeded()
        
        startLiveActivity()
        startLiveActivityTimer()
        broadcastSessionState()
        reloadWidgets()
    }
    
    func pauseSession() {
        currentSession.pauseSession()
        
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: "paused")
        }
        
        broadcastSessionState()
    }
    
    func resumeSession() {
        currentSession.resumeSession()
        
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: currentSession.isInBreak ? "breakTime" : "running")
        }
        
        broadcastSessionState()
    }
    
    func stopSession() {
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: "failed")
        }
        
        currentSession.stopSession()
        refreshUserStats()
        broadcastSessionState()
    }
    
    func completeSession() {
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: "completed")
        }
        
        finishSession()
    }
    
    private func finishSession() {
        currentSession.state = .idle
        refreshUserStats()
    }
    
    private func refreshUserStats() {
        userStats = persistenceController.getOrCreateUserStats()
        currentSession.currentStreak = Int(userStats?.currentStreak ?? 0)
        currentSession.todayCount = Int(userStats?.todayCount ?? 0)
    }
    
    private func refreshFromPersistence() {
        refreshUserStats()
        
        // In time-based approach, we can safely update from persistence
        // since all devices calculate from the same start time
        if let activeSession = persistenceController.getActiveSession() {
            currentSession.updateFromPersistence(activeSession)
            updateLiveActivity()
        }
    }
    
    private func handleWorkPhaseCompletion() {
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: "breakTime")
        }
    }
    
    private func handleSessionCompletion() {
        if let activeSession = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(activeSession, state: "completed")
        }
        
        finishSession()
        stopLiveActivityTimer()
        endLiveActivity()
        reloadWidgets()
    }
    
    // MARK: - Cross-Device Sync
    /// Sets up real-time synchronization across devices using NSUbiquitousKeyValueStore
    /// Updates when remote devices change session state for seamless handoff
    private func setupUbiquitousStoreSync() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { _ in
            self.handleRemoteSessionUpdate()
        }
    }
    
    private func handleRemoteSessionUpdate() {
        guard let sessionData = ubiquitousStore.data(forKey: "currentSession") else { return }
        
        do {
            let decoder = JSONDecoder()
            let remoteSessionInfo = try decoder.decode(SessionSyncInfo.self, from: sessionData)
            
            if remoteSessionInfo.lastUpdateTime > currentSession.lastUpdateTime {
                syncFromRemoteSession(remoteSessionInfo)
            }
        } catch {
            print("Failed to decode remote session: \(error)")
        }
    }
    
    private func syncFromRemoteSession(_ remoteInfo: SessionSyncInfo) {
        print("🌐 Syncing from remote session - active: \(remoteInfo.isActive)")
        
        if remoteInfo.isActive {
            // Calculate current remaining time from remote start time
            let elapsed = Date().timeIntervalSince(remoteInfo.startTime)
            let calculatedRemaining = max(0, remoteInfo.totalDuration - elapsed)
            
            if calculatedRemaining > 0 {
                let sessionType: PomodoroSession.SessionType = remoteInfo.sessionType == "short" 
                    ? .short(work: remoteInfo.workDuration, break: remoteInfo.breakDuration)
                    : .long(work: remoteInfo.workDuration, break: remoteInfo.breakDuration)
                    
                if remoteInfo.isInBreak {
                    currentSession.state = .breakTime(startTime: remoteInfo.startTime, duration: remoteInfo.breakDuration)
                } else {
                    currentSession.state = .running(type: sessionType, startTime: remoteInfo.startTime, duration: remoteInfo.totalDuration)
                }
                
                currentSession.currentStreak = remoteInfo.currentStreak
                currentSession.todayCount = remoteInfo.todayCount
                currentSession.lastUpdateTime = Date()
                
                updateLiveActivity()
                print("📱 Joined remote session - remaining: \(calculatedRemaining)s")
            }
        } else if currentSession.isRunning {
            currentSession.stopSession()
            endLiveActivity()
            print("🛑 Remote session stopped - stopping local session")
        }
    }
    
    private func broadcastSessionState() {
        let sessionInfo = SessionSyncInfo(
            isActive: currentSession.isRunning,
            startTime: getSessionStartTime(),
            totalDuration: getSessionTotalDuration(),
            workDuration: getWorkDuration(),
            breakDuration: getBreakDuration(),
            remainingTime: currentSession.remainingTime,
            currentStreak: currentSession.currentStreak,
            todayCount: currentSession.todayCount,
            sessionType: getSessionTypeString(),
            isInBreak: currentSession.isInBreak,
            lastUpdateTime: Date()
        )
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(sessionInfo)
            ubiquitousStore.set(data, forKey: "currentSession")
            ubiquitousStore.synchronize()
        } catch {
            print("Failed to broadcast session state: \(error)")
        }
    }
    
    private func getSessionStartTime() -> Date {
        switch currentSession.state {
        case .running(_, let startTime, _), .breakTime(let startTime, _):
            return startTime
        default:
            return Date()
        }
    }
    
    private func getSessionTotalDuration() -> TimeInterval {
        switch currentSession.state {
        case .running(_, _, let duration):
            return duration
        case .breakTime(_, let duration):
            return duration
        default:
            return 0
        }
    }
    
    private func getWorkDuration() -> TimeInterval {
        switch currentSession.state {
        case .running(let type, _, _):
            return type.workDuration
        case .breakTime:
            return 25 * 60 // Default fallback
        default:
            return 0
        }
    }
    
    private func getBreakDuration() -> TimeInterval {
        switch currentSession.state {
        case .running(let type, _, _):
            return type.breakDuration
        case .breakTime:
            return 5 * 60 // Default fallback
        default:
            return 0
        }
    }
    
    private func getSessionTypeString() -> String {
        switch currentSession.state {
        case .running(let type, _, _):
            return type == PomodoroSession.defaultShort ? "short" : "long"
        default:
            return "short"
        }
    }
    
    // MARK: - Live Activities Management
    /// Manages Dynamic Island and Lock Screen Live Activities
    /// Updates real-time with session progress, streaks, and remaining time
    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = TempoActivityAttributes(
            sessionType: currentSession.isInBreak ? "break" : "work",
            totalDuration: currentSession.remainingTime
        )
        
        let state = TempoActivityAttributes.ContentState(
            remainingTime: currentSession.remainingTime,
            currentStreak: currentSession.currentStreak,
            todayCount: currentSession.todayCount,
            isInBreak: currentSession.isInBreak
        )
        
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30))
        
        do {
            let activity = try Activity.request(attributes: attributes, content: content)
            print("Live Activity started: \(activity.id)")
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    private func updateLiveActivity() {
        Task {
            let state = TempoActivityAttributes.ContentState(
                remainingTime: currentSession.remainingTime,
                currentStreak: currentSession.currentStreak,
                todayCount: currentSession.todayCount,
                isInBreak: currentSession.isInBreak
            )
            
            let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(30))
            
            for activity in Activity<TempoActivityAttributes>.activities {
                await activity.update(content)
            }
        }
    }
    
    private func endLiveActivity() {
        Task {
            for activity in Activity<TempoActivityAttributes>.activities {
                await activity.end(
                    ActivityContent(
                        state: TempoActivityAttributes.ContentState(
                            remainingTime: 0,
                            currentStreak: currentSession.currentStreak,
                            todayCount: currentSession.todayCount,
                            isInBreak: false
                        ),
                        staleDate: Date()
                    ),
                    dismissalPolicy: .immediate
                )
            }
        }
    }
    
    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    private func startLiveActivityTimer() {
        liveActivityTimer?.invalidate()
        var tickCount = 0
        liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if self.currentSession.isRunning {
                self.updateLiveActivity()
                
                // Broadcast state every 5 seconds for real-time sync
                tickCount += 1
                if tickCount % 5 == 0 {
                    self.broadcastSessionState()
                }
            }
        }
    }
    
    private func stopLiveActivityTimer() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
    }
}

@main
struct TempoApp: App {
    let persistenceController = PersistenceController.shared
    @State private var sessionManager: SessionManager

    init() {
        let persistence = PersistenceController.shared
        _sessionManager = State(initialValue: SessionManager(persistenceController: persistence))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environment(sessionManager)
        }
    }
}
