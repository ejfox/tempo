//
//  TempoTests.swift
//  TempoTests
//
//  Created by EJ Fox on 8/15/25.
//

import XCTest
import Foundation
@testable import Tempo

final class TempoTests: XCTestCase {
    
    func testPomodoroSessionInitialization() async throws {
        let session = PomodoroSession()
        
        XCTAssert(session.state == .idle)
        XCTAssert(session.remainingTime == 0)
        XCTAssert(session.currentStreak == 0)
        XCTAssert(session.todayCount == 0)
        XCTAssert(session.interruptionMode == .strict)
        XCTAssert(!session.isRunning)
        XCTAssert(!session.isInBreak)
    }
    
    func testsessionTypeProperties() async throws {
        let shortType = PomodoroSession.SessionType.short(work: 1500, break: 300)
        let longType = PomodoroSession.SessionType.long(work: 3000, break: 600)
        
        XCTAssert(shortType.workDuration == 1500)
        XCTAssert(shortType.breakDuration == 300)
        XCTAssert(longType.workDuration == 3000)
        XCTAssert(longType.breakDuration == 600)
        
        XCTAssert(shortType == PomodoroSession.defaultShort)
        XCTAssert(longType == PomodoroSession.defaultLong)
    }
    
    func teststartSessionUpdatesState() async throws {
        let session = PomodoroSession()
        let sessionType = PomodoroSession.SessionType.short(work: 10, break: 5)
        
        session.startSession(type: sessionType)
        
        XCTAssert(session.isRunning)
        XCTAssert(!session.isInBreak)
        XCTAssert(session.remainingTime == 10)
        
        if case .running(let type, _, let duration) = session.state {
            XCTAssert(type == sessionType)
            XCTAssert(duration == 10)
        } else {
            XCTFail("Session should be in running state")
        }
    }
    
    func testpauseAndResumeSession() async throws {
        let session = PomodoroSession()
        let sessionType = PomodoroSession.SessionType.short(work: 10, break: 5)
        
        session.startSession(type: sessionType)
        XCTAssert(session.isRunning)
        
        session.pauseSession()
        XCTAssert(!session.isRunning)
        
        session.resumeSession()
        XCTAssert(session.isRunning)
    }
    
    func teststopSessionFailsTimer() async throws {
        let session = PomodoroSession()
        let sessionType = PomodoroSession.SessionType.short(work: 10, break: 5)
        
        session.startSession(type: sessionType)
        let initialStreak = session.currentStreak
        
        session.stopSession()
        
        XCTAssert(!session.isRunning)
        XCTAssert(session.currentStreak == 0)
        XCTAssert(session.remainingTime == 0)
    }
    
    func testformattedTimeDisplay() async throws {
        let session = PomodoroSession()
        
        session.remainingTime = 3661 // 1 hour, 1 minute, 1 second
        XCTAssert(session.formattedTime == "61:01")
        
        session.remainingTime = 300 // 5 minutes
        XCTAssert(session.formattedTime == "05:00")
        
        session.remainingTime = 59 // 59 seconds
        XCTAssert(session.formattedTime == "00:59")
        
        session.remainingTime = 0
        XCTAssert(session.formattedTime == "00:00")
    }
    
    func testinterruptionModeHandling() async throws {
        let session = PomodoroSession()
        
        session.interruptionMode = .strict
        XCTAssert(session.interruptionMode == .strict)
        
        session.interruptionMode = .flexible
        XCTAssert(session.interruptionMode == .flexible)
        
        session.interruptionMode = .practice
        XCTAssert(session.interruptionMode == .practice)
    }
    
    func testsessionCompletionFlow() async throws {
        let session = PomodoroSession()
        let sessionType = PomodoroSession.SessionType.short(work: 1, break: 1)
        
        session.startSession(type: sessionType)
        session.remainingTime = 0
        
        let expectation = expectation(description: "Work phase completed")
        
        NotificationCenter.default.addObserver(
            forName: .workPhaseCompleted,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        
        session.completeCurrentPhase()
        
        XCTAssert(session.isInBreak)
        XCTAssert(session.remainingTime == 1)
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testpersistenceControllerInitialization() async throws {
        let persistence = PersistenceController(inMemory: true)
        
        XCTAssert(persistence.container.name == "Tempo")
        
        let stats = persistence.getOrCreateUserStats()
        XCTAssert(stats.currentStreak == 0)
        XCTAssert(stats.todayCount == 0)
        XCTAssert(stats.totalSessions == 0)
        XCTAssert(stats.longestStreak == 0)
    }
    
    func testsessionCreationAndRetrieval() async throws {
        let persistence = PersistenceController(inMemory: true)
        let sessionType = PomodoroSession.SessionType.short(work: 1500, break: 300)
        
        let session = persistence.createSession(type: sessionType)
        
        XCTAssert(session.workDuration == 1500)
        XCTAssert(session.breakDuration == 300)
        XCTAssert(session.sessionType == "short")
        XCTAssert(!session.isCompleted)
        XCTAssert(session.state == "running")
        
        let retrievedSession = persistence.getActiveSession()
        XCTAssert(retrievedSession?.id == session.id)
    }
    
    func testsessionStateUpdates() async throws {
        let persistence = PersistenceController(inMemory: true)
        let sessionType = PomodoroSession.SessionType.short(work: 1500, break: 300)
        
        let session = persistence.createSession(type: sessionType)
        XCTAssert(session.state == "running")
        
        persistence.updateSessionState(session, state: "breakTime")
        XCTAssert(session.state == "breakTime")
        
        persistence.updateSessionState(session, state: "completed")
        XCTAssert(session.state == "completed")
        XCTAssert(session.isCompleted)
        XCTAssert(session.endTime != nil)
    }
    
    func testuserStatsUpdatesOnCompletion() async throws {
        let persistence = PersistenceController(inMemory: true)
        let sessionType = PomodoroSession.SessionType.short(work: 1500, break: 300)
        
        let initialStats = persistence.getOrCreateUserStats()
        let initialStreak = initialStats.currentStreak
        let initialToday = initialStats.todayCount
        let initialTotal = initialStats.totalSessions
        
        let session = persistence.createSession(type: sessionType)
        persistence.updateSessionState(session, state: "completed")
        
        let updatedStats = persistence.getCurrentUserStats()
        XCTAssert(updatedStats?.currentStreak == initialStreak + 1)
        XCTAssert(updatedStats?.todayCount == initialToday + 1)
        XCTAssert(updatedStats?.totalSessions == initialTotal + 1)
        XCTAssert(updatedStats?.lastSessionDate != nil)
    }
    
    func testuserStatsResetOnFailure() async throws {
        let persistence = PersistenceController(inMemory: true)
        let sessionType = PomodoroSession.SessionType.short(work: 1500, break: 300)
        
        let stats = persistence.getOrCreateUserStats()
        stats.currentStreak = 5
        persistence.saveContext()
        
        let session = persistence.createSession(type: sessionType)
        persistence.updateSessionState(session, state: "failed")
        
        let updatedStats = persistence.getCurrentUserStats()
        XCTAssert(updatedStats?.currentStreak == 0)
    }
    
    func testsessionManagerIntegration() async throws {
        let persistence = PersistenceController(inMemory: true)
        let sessionManager = SessionManager(persistenceController: persistence)
        
        XCTAssert(!sessionManager.currentSession.isRunning)
        XCTAssert(sessionManager.userStats != nil)
        
        let sessionType = PomodoroSession.SessionType.short(work: 10, break: 5)
        sessionManager.startSession(type: sessionType)
        
        XCTAssert(sessionManager.currentSession.isRunning)
        XCTAssert(sessionManager.currentSession.remainingTime == 10)
        
        let activeSession = persistence.getActiveSession()
        XCTAssert(activeSession != nil)
        XCTAssert(activeSession?.state == "running")
    }
}

