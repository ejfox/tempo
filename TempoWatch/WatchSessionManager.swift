//
//  WatchSessionManager.swift
//  TempoWatch
//
//  Coordinates session state, haptic feedback, and cross-device sync.
//

import Foundation
import WatchKit

@Observable
class WatchSessionManager {
    var session = WatchPomodoroSession()
    var celebrating = false
    /// True during the focus→break transition animation window
    var phaseTransitioning = false
    /// Reference to settings for haptic gating
    var settings: WatchSettings?

    // MARK: - Private State

    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var syncTickCount = 0
    private var syncObserver: NSObjectProtocol?
    private var celebrationDismissWork: DispatchWorkItem?

    // MARK: - Lifecycle

    init() {
        setupSync()
    }

    deinit {
        if let observer = syncObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        celebrationDismissWork?.cancel()
    }

    // MARK: - Session Control

    func startSession(type: WatchPomodoroSession.SessionType) {
        guard !celebrating else { return }
        session.startSession(type: type)
        WatchHaptics.sessionStart()
        broadcastState()
    }

    func stopSession() {
        session.stopSession()
        WatchHaptics.sessionStop()
        broadcastState()
    }

    func pauseSession() {
        session.pauseSession()
        WatchHaptics.pause()
        broadcastState()
    }

    func resumeSession() {
        session.resumeSession()
        WatchHaptics.resume()
        broadcastState()
    }

    func togglePause() {
        if session.isPaused {
            resumeSession()
        } else if session.isRunning {
            pauseSession()
        }
    }

    func dismissCelebration() {
        celebrationDismissWork?.cancel()
        celebrating = false
        session.resetToIdle()
    }

    // MARK: - Timer Processing

    /// Called every second by the view's timer.
    func processTick() {
        let events = session.tick()

        let haptics = settings?.hapticsEnabled ?? true

        for event in events {
            switch event {
            case .quarterMilestone:
                if haptics && (settings?.milestoneHaptics ?? true) {
                    WatchHaptics.quarterMilestone()
                }
            case .minuteBoundary:
                if haptics && (settings?.minuteMarkHaptics ?? false) {
                    WatchHaptics.minuteTick()
                }
            case .countdown(let seconds):
                if haptics && (settings?.countdownHaptics ?? true) {
                    WatchHaptics.countdownTick(secondsRemaining: seconds)
                }
            case .phaseComplete:
                if haptics { WatchHaptics.phaseComplete() }
                beginPhaseTransition()
                broadcastState()
            case .sessionComplete:
                if haptics { WatchHaptics.sessionComplete() }
                beginCelebration()
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
        // Hold the transition state for the animation duration, then release
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            self?.phaseTransitioning = false
        }
    }

    private func beginCelebration() {
        celebrating = true
        celebrationDismissWork?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.celebrating = false
            self?.session.resetToIdle()
        }
        celebrationDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
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
                session.lastUpdateTime = Date()
                session.firedMilestones = []
                session.lastCountdownSecond = -1

                WKInterfaceDevice.current().play(.notification)
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
            lastUpdateTime: Date()
        )

        do {
            let data = try JSONEncoder().encode(info)
            ubiquitousStore.set(data, forKey: "currentSession")
            ubiquitousStore.synchronize()
        } catch {
            print("Watch broadcast error: \(error)")
        }
    }
}
