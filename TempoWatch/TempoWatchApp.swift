//
//  TempoWatchApp.swift
//  TempoWatch
//
//  Created by EJ Fox.
//

import SwiftUI

@main
struct TempoWatchApp: App {
    @State private var sessionManager = WatchSessionManager()
    @State private var settings = WatchSettings()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchContentView()
            }
            .environment(sessionManager)
            .environment(settings)
            .onAppear {
                sessionManager.settings = settings
            }
        }
    }
}
