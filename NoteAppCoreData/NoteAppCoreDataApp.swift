//
//  NoteAppCoreDataApp.swift
//  NoteAppCoreData
//
//  Created by Navin Rai on 24/02/26.
//

import SwiftUI
import CoreData

//@main
//struct NoteAppCoreDataApp: App {
//    let persistenceController = PersistenceController.shared
//
//    var body: some Scene {
//        WindowGroup {
//            ContentView()
//                .environment(\.managedObjectContext, persistenceController.container.viewContext)
//        }
//    }
//}

@main
struct NoteAppCoreDataApp: App {

    // ✅ CoreDataStack initialized at app start
    let coreDataStack = CoreDataStack.shared

    init() {
        // Cleanup tombstones older than 30 days on every launch
        NoteRepository.shared.cleanupOldTombstones()
        print("🚀 App launched — CoreData ready")
    }

    var body: some Scene {
        WindowGroup {
            NoteListView()
                // ✅ This ONE line makes @FetchRequest work in ALL child views
                // Without this: @FetchRequest crashes with "no context in environment"
                .environment(\.managedObjectContext, coreDataStack.viewContext)
        }
    }
}
