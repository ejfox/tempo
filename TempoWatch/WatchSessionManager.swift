//
//  WatchSessionManager.swift
//  TempoWatch
//
//  Coordinates session state, haptic feedback, and cross-device sync.
//

import Foundation
import WatchKit
import UserNotifications
import WidgetKit

@Observable
class WatchSessionManager {
    /// Shared instance for App Intents / Action Button access
    static let shared = WatchSessionManager()

    var session = WatchPomodoroSession()
    var celebrating = false
    /// True during the focus→break transition animation window
    var phaseTransitioning = false
    /// True when the celebration is for a full cycle completion (4th pomodoro)
    var isCycleComplete = false
    /// Reference to settings for haptic gating
    var settings: WatchSettings?

    // MARK: - Private State

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var syncTickCount = 0
    private var syncObserver: NSObjectProtocol?
    private var celebrationDismissTask: Task<Void, Never>?
    private let notificationCenter = UNUserNotificationCenter.current()
    private var extendedSession: WKExtendedRuntimeSession?

    // MARK: - Lifecycle

    init() {
        setupSync()
        requestNotificationPermission()
    }

    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        celebrationDismissTask?.cancel()
    }

    // MARK: - Session Control

    func startSession(type: WatchPomodoroSession.SessionType) {
        guard !celebrating else { return }
        session.startSession(type: type)
        WatchHaptics.sessionStart.play()
        scheduleApproachingEndAlerts(duration: type.workDuration, phase: "focus")
        startExtendedRuntime()
        broadcastState()
        reloadWidgets()
    }

    func stopSession() {
        session.stopSession()
        WatchHaptics.sessionStop.play()
        cancelApproachingEndAlerts()
        stopExtendedRuntime()
        broadcastState()
        reloadWidgets()
    }

    func pauseSession() {
        session.pauseSession()
        WatchHaptics.pause.play()
        cancelApproachingEndAlerts()
        stopExtendedRuntime()
        broadcastState()
        reloadWidgets()
    }

    func resumeSession() {
        session.resumeSession()
        WatchHaptics.resume.play()
        let remaining = session.remainingTime
        let phase = session.isInBreak ? "break" : "focus"
        scheduleApproachingEndAlerts(duration: remaining, phase: phase)
        startExtendedRuntime()
        broadcastState()
        reloadWidgets()
    }

    func togglePause() {
        if session.isPaused {
            resumeSession()
        } else if session.isRunning {
            pauseSession()
        }
    }

    /// Add time to a running or paused focus session.
    func extendSession(byMinutes minutes: Int) {
        session.extend(bySeconds: TimeInterval(minutes * 60))
        // Re-schedule approaching-end alerts for the new remaining time
        let remaining = session.remainingTime
        scheduleApproachingEndAlerts(duration: remaining, phase: "focus")
        broadcastState()
    }

    /// Start a break that was pending user confirmation (autoStartBreak is off).
    func startBreak() {
        session.startPendingBreak()
        WatchHaptics.sessionStart.play()
        scheduleApproachingEndAlerts(duration: session.breakDuration, phase: "break")
        broadcastState()
        reloadWidgets()
    }

    func dismissCelebration() {
        celebrationDismissTask?.cancel()
        celebrating = false
        isCycleComplete = false
        session.resetToIdle()
        stopExtendedRuntime()
    }

    // MARK: - Timer Processing

    /// Called every second by the view's timer.
    func processTick() {
        let events = session.tick(
            pomodorosPerCycle: settings?.pomodorosPerCycle ?? 4,
            longBreakDuration: (settings?.longBreakMinutes ?? 15) * 60,
            autoStartBreak: settings?.autoStartBreak ?? true,
            autoStartNextFocus: settings?.autoStartNextFocus ?? false
        )

        let haptics = settings?.hapticsEnabled ?? true

        for event in events {
            switch event {
            case .quarterMilestone:
                if haptics && (settings?.milestoneHaptics ?? true) {
                    WatchHaptics.quarterMilestone.play()
                }
            case .minuteBoundary:
                if haptics && (settings?.minuteMarkHaptics ?? false) {
                    WatchHaptics.minuteTick.play()
                }
            case .countdown(let seconds):
                if haptics && (settings?.countdownHaptics ?? true) {
                    WatchHaptics.countdownTick(secondsRemaining: seconds)
                }
            case .phaseComplete:
                if haptics && (settings?.phaseCompleteHaptics ?? true) {
                    WatchHaptics.phaseComplete.play()
                }
                beginPhaseTransition()
                scheduleApproachingEndAlerts(duration: session.breakDuration, phase: "break")
                broadcastState()
            case .sessionComplete:
                if haptics && (settings?.sessionCompleteHaptics ?? true) {
                    WatchHaptics.sessionComplete.play()
                }
                beginCelebration()
                broadcastState()
            case .cycleBreakStarted:
                if haptics && (settings?.cycleCompleteHaptics ?? true) {
                    WatchHaptics.cycleBreakStart.play()
                }
                scheduleApproachingEndAlerts(duration: session.breakDuration, phase: "long break")
                broadcastState()
            case .cycleComplete:
                if haptics && (settings?.cycleCompleteHaptics ?? true) {
                    WatchHaptics.cycleComplete.play()
                }
                beginCelebration(isCycleComplete: true)
                broadcastState()
            case .autoStartNext:
                let breakRatio = settings?.breakRatio ?? 0.2
                let minutes = session.lastWorkDuration / 60
                let type = WatchPomodoroSession.sessionType(forMinutes: minutes, breakRatio: breakRatio)
                session.startSession(type: type)
                if haptics { WatchHaptics.sessionStart.play() }
                scheduleApproachingEndAlerts(duration: type.workDuration, phase: "focus")
                broadcastState()
            }
        }

        // Broadcast state periodically for cross-device sync
        syncTickCount += 1
        if syncTickCount % 5 == 0 {
            broadcastState()
        }
    }

    private func beginPhaseTransition() {
        phaseTransitioning = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            self?.phaseTransitioning = false
        }
    }

    private func beginCelebration(isCycleComplete: Bool = false) {
        celebrating = true
        self.isCycleComplete = isCycleComplete
        celebrationDismissTask?.cancel()
        celebrationDismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.celebrating = false
            self?.session.resetToIdle()
        }
    }

    // MARK: - Approaching-End Notifications

    private func requestNotificationPermission() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// Schedule alerts at key moments before a phase ends.
    /// Alert points: halfway, 5 min, 2 min, 1 min remaining.
    /// Only schedules alerts that make sense for the duration (skips if duration is too short).
    func scheduleApproachingEndAlerts(duration: TimeInterval, phase: String) {
        cancelApproachingEndAlerts()

        let alertsEnabled = settings?.approachingEndAlerts ?? true
        guard alertsEnabled else { return }

        struct AlertPoint {
            let secondsBefore: TimeInterval
            let title: String
            let body: String
            let id: String
        }

        let alerts: [AlertPoint] = [
            AlertPoint(secondsBefore: duration / 2, title: "Halfway", body: "Halfway through \(phase).", id: "tempo.halfway"),
            AlertPoint(secondsBefore: 5 * 60, title: "5 minutes left", body: "5 minutes remaining.", id: "tempo.5min"),
            AlertPoint(secondsBefore: 2 * 60, title: "2 minutes left", body: "Almost there.", id: "tempo.2min"),
            AlertPoint(secondsBefore: 60, title: "Final minute", body: "One minute to go.", id: "tempo.1min"),
        ]

        for alert in alerts {
            let fireIn = duration - alert.secondsBefore
            // Need at least 5 seconds into the session, and don't double-fire
            // if two alert points land at the same time
            guard fireIn >= 5 && alert.secondsBefore < duration else { continue }

            let content = UNMutableNotificationContent()
            content.title = alert.title
            content.body = alert.body
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireIn, repeats: false)
            let request = UNNotificationRequest(identifier: alert.id, content: content, trigger: trigger)
            notificationCenter.add(request)
        }
    }

    private func cancelApproachingEndAlerts() {
        notificationCenter.removePendingNotificationRequests(
            withIdentifiers: ["tempo.halfway", "tempo.5min", "tempo.2min", "tempo.1min"]
        )
    }

    // MARK: - Extended Runtime

    private func startExtendedRuntime() {
        guard extendedSession == nil || extendedSession?.state == .invalid else { return }
        let ers = WKExtendedRuntimeSession()
        ers.delegate = self
        ers.start()
        extendedSession = ers
    }

    private func stopExtendedRuntime() {
        extendedSession?.invalidate()
        extendedSession = nil
    }

    // MARK: - iCloud KV Sync

    private func setupSync() {
        syncObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore,
            queue: .main
        ) { [weak self] _ in
            self?.handleRemoteUpdate()
        }
        ubiquitousStore.synchronize()
    }

    private func handleRemoteUpdate() {
        guard !celebrating else { return }
        guard let data = ubiquitousStore.data(forKey: "currentSession") else { return }

        do {
            let remote = try JSONDecoder().decode(SessionSyncInfo.self, from: data)
            guard remote.lastUpdateTime > session.lastUpdateTime else { return }

            if remote.isActive {
                // Recalculate remaining from startTime to account for network delay
                let elapsed = Date().timeIntervalSince(remote.startTime)
                let remaining = max(0, remote.totalDuration - elapsed)

                guard remaining > 0 else { return }

                let type = WatchPomodoroSession.SessionType.from(
                    syncString: remote.sessionType,
                    work: remote.workDuration,
                    break: remote.breakDuration
                )

                if remote.isInBreak {
                    session.state = .breakTime(startTime: remote.startTime, duration: remote.breakDuration)
                } else {
                    session.state = .running(type: type, startTime: remote.startTime, duration: remote.totalDuration)
                }

                session.currentStreak = remote.currentStreak
                session.todayCount = remote.todayCount
                session.cyclePosition = remote.cyclePosition ?? 0
                session.lastUpdateTime = Date()
                session.firedMilestones = []
                session.lastCountdownSecond = -1

                WatchHaptics.remoteSessionJoined.play()
            } else if session.isActive {
                session.stopSession()
            }
        } catch {
            print("Watch sync error: \(error)")
        }
    }

    // MARK: - Broadcast

    private func broadcastState() {
        let info = SessionSyncInfo(
            isActive: session.isRunning,
            startTime: session.startTime,
            totalDuration: session.totalDuration,
            workDuration: session.workDuration,
            breakDuration: session.breakDuration,
            remainingTime: session.remainingTime,
            currentStreak: session.currentStreak,
            todayCount: session.todayCount,
            sessionType: session.sessionTypeString,
            isInBreak: session.isInBreak,
            lastUpdateTime: Date(),
            cyclePosition: session.cyclePosition
        )

        do {
            let data = try JSONEncoder().encode(info)
            // iCloud sync for cross-device
            ubiquitousStore.set(data, forKey: "currentSession")
            ubiquitousStore.synchronize()
            // Shared App Group for local widget reads
            let shared = WatchPomodoroSession.sharedSuite
            shared.set(data, forKey: "widget.session")
            shared.set(session.todayCount, forKey: "widget.todayCount")
            shared.set(session.currentStreak, forKey: "widget.streak")
            shared.set(session.cyclePosition, forKey: "widget.cyclePosition")
            shared.set(settings?.pomodorosPerCycle ?? 4, forKey: "widget.pomodorosPerCycle")
        } catch {
            print("Watch broadcast error: \(error)")
        }
    }

    /// Trigger complication timeline refresh on meaningful state changes.
    private func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

// MARK: - Extended Runtime Delegate

extension WatchSessionManager: WKExtendedRuntimeSessionDelegate {
    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        // Runtime active — timer will continue when wrist drops
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        session.saveStats()
        broadcastState()
    }

    func extendedRuntimeSession(
        _ extendedRuntimeSession: WKExtendedRuntimeSession,
        didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason,
        error: (any Error)?
    ) {
        self.extendedSession = nil
        // If session still running, schedule fallback notification
        if session.isActive {
            scheduleApproachingEndAlerts(
                duration: session.remainingTime,
                phase: session.isInBreak ? "break" : "focus"
            )
        }
    }
}
