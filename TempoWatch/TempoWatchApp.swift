//
//  TempoWatchApp.swift
//  TempoWatch
//
//  Created by EJ Fox.
//

import SwiftUI

@main
struct TempoWatchApp: App {
    @State private var sessionManager = WatchSessionManager.shared
    @State private var settings = WatchSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
            .environment(sessionManager)
            .environment(settings)
            .onAppear {
                sessionManager.settings = settings
                sessionManager.session.resetDailyStatsIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    sessionManager.session.resetDailyStatsIfNeeded()
                }
            }
        }
    }
}
