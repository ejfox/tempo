//
//  Persistence.swift
//  Tempo
//
//  Created by EJ Fox on 8/15/25.
//

import CoreData
import CloudKit
import Foundation
import UIKit

struct PersistenceController {
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        let stats = UserStats(context: viewContext)
        stats.id = UUID()
        stats.currentStreak = 5
        stats.todayCount = 3
        stats.totalSessions = 47
        stats.longestStreak = 12
        stats.lastSessionDate = Date()
        
        let session = TempoSession(context: viewContext)
        session.id = UUID()
        session.workDuration = 25 * 60
        session.breakDuration = 5 * 60
        session.startTime = Date()
        session.state = "running"
        session.sessionType = "short"
        session.isCompleted = false
        session.deviceID = "preview"
        session.interruptionMode = "strict"
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "Tempo")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            setupCloudKitConfiguration()
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        setupCloudKitNotifications()
    }
    
    private func setupCloudKitConfiguration() {
        guard let description = container.persistentStoreDescriptions.first else {
            return
        }
        
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        
        // Skip CloudKit configuration for now to avoid startup issues
        // let cloudKitOptions = NSPersistentCloudKitContainerOptions(
        //     containerIdentifier: "iCloud.com.ejfox.Tempo"
        // )
        // description.cloudKitContainerOptions = cloudKitOptions
        
        // do {
        //     try container.initializeCloudKitSchema(options: [])
        // } catch {
        //     print("CloudKit schema initialization failed: \(error)")
        // }
    }
    
    private func setupCloudKitNotifications() {
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            self.handleRemoteChange()
        }
    }
    
    private func handleRemoteChange() {
        container.viewContext.perform {
            do {
                try self.container.viewContext.save()
                NotificationCenter.default.post(name: .tempoDataUpdated, object: nil)
            } catch {
                print("Failed to handle remote change: \(error)")
            }
        }
    }
    
    func saveContext() {
        let context = container.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func getCurrentUserStats() -> UserStats? {
        let request: NSFetchRequest<UserStats> = UserStats.fetchRequest()
        request.fetchLimit = 1
        
        do {
            let stats = try container.viewContext.fetch(request)
            return stats.first
        } catch {
            print("Failed to fetch user stats: \(error)")
            return nil
        }
    }
    
    func getOrCreateUserStats() -> UserStats {
        if let existingStats = getCurrentUserStats() {
            return existingStats
        }
        
        let stats = UserStats(context: container.viewContext)
        stats.id = UUID()
        stats.currentStreak = 0
        stats.todayCount = 0
        stats.totalSessions = 0
        stats.longestStreak = 0
        stats.lastResetDate = Calendar.current.startOfDay(for: Date())
        
        saveContext()
        return stats
    }
    
    func getActiveSession() -> TempoSession? {
        let request: NSFetchRequest<TempoSession> = TempoSession.fetchRequest()
        request.predicate = NSPredicate(format: "state IN %@", ["running", "breakTime"])
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
        
        do {
            let sessions = try container.viewContext.fetch(request)
            return sessions.first
        } catch {
            print("Failed to fetch active session: \(error)")
            return nil
        }
    }
    
    func createSession(type: PomodoroSession.SessionType, startTime: Date = Date()) -> TempoSession {
        let session = TempoSession(context: container.viewContext)
        session.id = UUID()
        session.workDuration = type.workDuration
        session.breakDuration = type.breakDuration
        session.startTime = startTime
        session.state = "running"
        session.sessionType = type == PomodoroSession.defaultShort ? "short" : "long"
        session.isCompleted = false
        session.deviceID = UIDevice.current.identifierForVendor?.uuidString
        session.interruptionMode = "strict"
        session.lastSyncTime = Date()
        
        saveContext()
        return session
    }
    
    func updateSessionState(_ session: TempoSession, state: String) {
        session.state = state
        session.lastSyncTime = Date()
        
        if state == "completed" {
            session.isCompleted = true
            session.endTime = Date()
            
            updateUserStatsOnCompletion()
        } else if state == "failed" {
            session.endTime = Date()
            updateUserStatsOnFailure()
        }
        
        saveContext()
        
        // Trigger immediate CloudKit sync for cross-device updates
        triggerImmediateSync()
    }
    
    private func triggerImmediateSync() {
        container.viewContext.perform {
            do {
                try self.container.viewContext.save()
                NotificationCenter.default.post(name: .tempoDataUpdated, object: nil)
            } catch {
                print("Failed to trigger immediate sync: \(error)")
            }
        }
    }
    
    private func updateUserStatsOnCompletion() {
        let stats = getOrCreateUserStats()
        stats.currentStreak += 1
        stats.todayCount += 1
        stats.totalSessions += 1
        stats.lastSessionDate = Date()
        
        if stats.currentStreak > stats.longestStreak {
            stats.longestStreak = stats.currentStreak
        }
        
        saveContext()
    }
    
    private func updateUserStatsOnFailure() {
        let stats = getOrCreateUserStats()
        stats.currentStreak = 0
        saveContext()
    }
    
    func resetDailyStatsIfNeeded() {
        let stats = getOrCreateUserStats()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastReset = stats.lastResetDate,
           !calendar.isDate(lastReset, inSameDayAs: today) {
            stats.todayCount = 0
            stats.lastResetDate = today
            saveContext()
        }
    }
}

extension Notification.Name {
    static let tempoDataUpdated = Notification.Name("tempoDataUpdated")
    static let workPhaseCompleted = Notification.Name("workPhaseCompleted")
    static let sessionCompleted = Notification.Name("sessionCompleted")
}

extension PomodoroSession {
    convenience init(from coreDataSession: TempoSession) {
        self.init()
        
        let sessionType: SessionType = coreDataSession.sessionType == "short" 
            ? .short(work: coreDataSession.workDuration, break: coreDataSession.breakDuration)
            : .long(work: coreDataSession.workDuration, break: coreDataSession.breakDuration)
        
        switch coreDataSession.state {
        case "running":
            self.state = .running(type: sessionType, startTime: coreDataSession.startTime ?? Date(), duration: coreDataSession.workDuration)
        case "breakTime":
            self.state = .breakTime(startTime: coreDataSession.startTime ?? Date(), duration: coreDataSession.breakDuration)
        case "completed":
            self.state = .completed
        case "failed":
            self.state = .failed
        default:
            self.state = .idle
        }
        
        self.interruptionMode = InterruptionMode(rawValue: coreDataSession.interruptionMode ?? "strict") ?? .strict
    }
}
