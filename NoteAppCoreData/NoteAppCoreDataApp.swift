//
//  NoteAppCoreDataApp.swift
//  NoteAppCoreData
//
//  Created by Navin Rai on 24/02/26.
//

import SwiftUI
import CoreData

@main
struct NoteAppCoreDataApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
