//
//  TempoApp.swift
//  Tempo
//

import SwiftUI
import ActivityKit
import WidgetKit

// MARK: - Session Manager

@Observable
class SessionManager {
    private let persistenceController: PersistenceController
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default

    var currentSession: PomodoroSession
    var userStats: UserStats?
    var userSettings: UserSettings
    var celebrating = false
    var isCycleComplete = false
    var phaseTransitioning = false

    private var liveActivityTimer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []
    private var syncTickCount = 0
    private var celebrationTask: Task<Void, Never>?

    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.currentSession = PomodoroSession()
        self.userSettings = UserSettings()
        self.userStats = persistenceController.getOrCreateUserStats()

        setupNotifications()
        setupUbiquitousStoreSync()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
        liveActivityTimer?.invalidate()
        celebrationTask?.cancel()
    }

    // MARK: - Session Control

    func startSession(type: PomodoroSession.SessionType) {
        currentSession.startSession(type: type)
        iOSHaptics.sessionStart()
        _ = persistenceController.createSession(type: type)
        currentSession.currentStreak = Int(userStats?.currentStreak ?? 0)
        currentSession.todayCount = Int(userStats?.todayCount ?? 0)
        persistenceController.resetDailyStatsIfNeeded()
        startLiveActivity()
        startTickTimer()
        broadcastState()
        reloadWidgets()
    }

    func stopSession() {
        if let active = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(active, state: "failed")
        }
        currentSession.stopSession()
        iOSHaptics.sessionStop()
        refreshUserStats()
        broadcastState()
        stopTickTimer()
        endLiveActivity()
        reloadWidgets()
    }

    func pauseSession() {
        currentSession.pauseSession()
        iOSHaptics.pause()
        broadcastState()
    }

    func resumeSession() {
        currentSession.resumeSession()
        iOSHaptics.resume()
        broadcastState()
    }

    func togglePause() {
        if currentSession.isPaused { resumeSession() }
        else if currentSession.isRunning { pauseSession() }
    }

    func startBreak() {
        currentSession.startPendingBreak()
        iOSHaptics.sessionStart()
        broadcastState()
        reloadWidgets()
    }

    func dismissCelebration() {
        celebrationTask?.cancel()
        celebrating = false
        isCycleComplete = false
        currentSession.resetToIdle()
        reloadWidgets()
    }

    // MARK: - Tick Processing

    func processTick() {
        let s = userSettings
        let events = currentSession.tick(
            pomodorosPerCycle: s.pomodorosPerCycle,
            longBreakDuration: s.longBreakMinutes * 60,
            autoStartBreak: s.autoStartBreak,
            autoStartNextFocus: s.autoStartNextFocus
        )

        let haptics = s.hapticsEnabled

        for event in events {
            switch event {
            case .quarterMilestone:
                if haptics && s.milestoneHaptics { iOSHaptics.quarterMilestone() }
            case .minuteBoundary:
                if haptics && s.minuteMarkHaptics { iOSHaptics.minuteTick() }
            case .countdown(let sec):
                if haptics && s.countdownHaptics { iOSHaptics.countdownTick(secondsRemaining: sec) }
            case .phaseComplete:
                if haptics && s.phaseCompleteHaptics { iOSHaptics.phaseComplete() }
                handlePhaseComplete()
            case .sessionComplete:
                if haptics && s.sessionCompleteHaptics { iOSHaptics.sessionComplete() }
                handleSessionComplete()
            case .cycleBreakStarted:
                if haptics && s.cycleCompleteHaptics { iOSHaptics.cycleBreakStart() }
                broadcastState()
            case .cycleComplete:
                if haptics && s.cycleCompleteHaptics { iOSHaptics.cycleComplete() }
                handleSessionComplete(isCycle: true)
            case .autoStartNext:
                let type = PomodoroSession.sessionType(
                    forMinutes: currentSession.lastWorkDuration / 60,
                    breakRatio: s.breakRatio
                )
                currentSession.startSession(type: type)
                if haptics { iOSHaptics.sessionStart() }
                broadcastState()
            }
        }

        syncTickCount += 1
        if syncTickCount % SessionDefaults.syncBroadcastInterval == 0 {
            broadcastState()
        }
        updateLiveActivity()
    }

    private func handlePhaseComplete() {
        if let active = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(active, state: "breakTime")
        }
        phaseTransitioning = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            phaseTransitioning = false
        }
        broadcastState()
        reloadWidgets()
    }

    private func handleSessionComplete(isCycle: Bool = false) {
        if let active = persistenceController.getActiveSession() {
            persistenceController.updateSessionState(active, state: "completed")
        }
        refreshUserStats()
        celebrating = true
        isCycleComplete = isCycle
        celebrationTask?.cancel()
        celebrationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.celebrating = false
            self?.currentSession.resetToIdle()
        }
        broadcastState()
        stopTickTimer()
        endLiveActivity()
        reloadWidgets()
    }

    // MARK: - Timer

    private func startTickTimer() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, self.currentSession.isRunning else { return }
            self.processTick()
        }
    }

    private func stopTickTimer() {
        liveActivityTimer?.invalidate()
        liveActivityTimer = nil
    }

    // MARK: - Stats

    private func refreshUserStats() {
        userStats = persistenceController.getOrCreateUserStats()
        currentSession.currentStreak = Int(userStats?.currentStreak ?? 0)
        currentSession.todayCount = Int(userStats?.todayCount ?? 0)
    }

    // MARK: - Cross-Device Sync

    private func setupNotifications() {
        notificationObservers.append(
            NotificationCenter.default.addObserver(
                forName: .tempoDataUpdated, object: nil, queue: .main
            ) { [weak self] _ in self?.refreshUserStats() }
        )
    }

    private func setupUbiquitousStoreSync() {
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore, queue: .main
        ) { [weak self] _ in self?.handleRemoteUpdate() }
    }

    private func handleRemoteUpdate() {
        guard let data = ubiquitousStore.data(forKey: SyncKey.currentSession.rawValue) else { return }
        do {
            let remote = try JSONDecoder().decode(SessionSyncInfo.self, from: data)
            guard remote.lastUpdateTime > currentSession.lastUpdateTime else { return }

            if remote.isActive {
                let elapsed = Date().timeIntervalSince(remote.startTime)
                let remaining = max(0, remote.totalDuration - elapsed)
                guard remaining > 0 else { return }

                let type = PomodoroSession.SessionType.from(
                    syncString: remote.sessionType,
                    work: remote.workDuration,
                    break: remote.breakDuration
                )

                if remote.isInBreak {
                    currentSession.state = .breakTime(startTime: remote.startTime, duration: remote.breakDuration)
                } else {
                    currentSession.state = .running(type: type, startTime: remote.startTime, duration: remote.totalDuration)
                }

                currentSession.currentStreak = remote.currentStreak
                currentSession.todayCount = remote.todayCount
                currentSession.cyclePosition = remote.cyclePosition ?? 0
                currentSession.lastUpdateTime = Date()
                currentSession.firedMilestones = []
                currentSession.lastCountdownSecond = -1

                startTickTimer()
                updateLiveActivity()
            } else if currentSession.isActive {
                currentSession.stopSession()
                endLiveActivity()
            }
        } catch {
            print("Sync error: \(error)")
        }
    }

    private func broadcastState() {
        let info = SessionSyncInfo(
            isActive: currentSession.isRunning,
            startTime: currentSession.startTime,
            totalDuration: currentSession.totalDuration,
            workDuration: currentSession.workDuration,
            breakDuration: currentSession.breakDuration,
            remainingTime: currentSession.remainingTime,
            currentStreak: currentSession.currentStreak,
            todayCount: currentSession.todayCount,
            sessionType: currentSession.sessionTypeString,
            isInBreak: currentSession.isInBreak,
            lastUpdateTime: Date(),
            cyclePosition: currentSession.cyclePosition
        )

        do {
            let data = try JSONEncoder().encode(info)
            ubiquitousStore.set(data, forKey: SyncKey.currentSession.rawValue)
            ubiquitousStore.synchronize()
            // Widget data bridge
            let shared = PomodoroSession.sharedSuite
            shared.set(data, forKey: WidgetKey.session.rawValue)
            shared.set(currentSession.todayCount, forKey: WidgetKey.todayCount.rawValue)
            shared.set(currentSession.currentStreak, forKey: WidgetKey.streak.rawValue)
            shared.set(currentSession.cyclePosition, forKey: WidgetKey.cyclePosition.rawValue)
            shared.set(userSettings.pomodorosPerCycle, forKey: WidgetKey.pomodorosPerCycle.rawValue)
        } catch {
            print("Broadcast error: \(error)")
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attrs = TempoActivityAttributes(
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
        _ = try? Activity.request(attributes: attrs, content: content)
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
            let state = TempoActivityAttributes.ContentState(
                remainingTime: 0,
                currentStreak: currentSession.currentStreak,
                todayCount: currentSession.todayCount,
                isInBreak: false
            )
            for activity in Activity<TempoActivityAttributes>.activities {
                await activity.end(ActivityContent(state: state, staleDate: Date()), dismissalPolicy: .immediate)
            }
        }
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - App Entry Point

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
                .onAppear {
                    sessionManager.currentSession.resetDailyStatsIfNeeded()
                }
        }
    }
}
