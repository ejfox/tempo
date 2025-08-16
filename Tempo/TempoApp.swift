//
//  TempoApp.swift
//  Tempo
//
//  Created by EJ Fox on 8/15/25.
//

import SwiftUI

@main
struct TempoApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
