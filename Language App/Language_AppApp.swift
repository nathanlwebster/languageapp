//
//  Language_AppApp.swift
//  Language App
//
//  Created by Nathan Webster on 3/5/25.
//

import SwiftUI

@main
struct Language_AppApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
