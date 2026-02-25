//
// PreviewHelper.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// PreviewHelper.swift — Updated with color notes
// ============================================================

import CoreData

struct PreviewHelper {

    static let container: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NoteAppCoreData")
        let desc = NSPersistentStoreDescription()
        desc.type = NSInMemoryStoreType
        container.persistentStoreDescriptions = [desc]
        container.loadPersistentStores { _, error in
            if let error { fatalError("Preview failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    static var context: NSManagedObjectContext { container.viewContext }

    // ─── Sample Notes with Colors ────────────────────────────
    @discardableResult
    static func insertSampleNotes() -> [NoteEntity] {
        let context = container.viewContext

        // Check already inserted
        let request = NoteEntity.fetchRequest()
        if let count = try? context.count(for: request), count > 0 { return [] }

        let samples: [(String, String, String, Bool)] = [
            ("Meeting Notes", "Discuss project timeline and Q1 deliverables with the team", NoteColor.blue.rawValue, true),
            ("Buy Groceries", "Milk, Eggs, Bread, Butter, Coffee", NoteColor.yellow.rawValue, false),
            ("iOS Interview Prep", "CoreData, SwiftUI, MVVM, Offline sync, UUID, Soft delete", NoteColor.green.rawValue, true),
            ("Travel Plans", "Tokyo → Kyoto → Osaka in April", NoteColor.pink.rawValue, false),
            ("Book Notes", "Atomic Habits — Chapter 3: Build better systems not goals", NoteColor.purple.rawValue, true),
        ]

        var entities: [NoteEntity] = []
        for (i, sample) in samples.enumerated() {
            let entity = NoteEntity(context: context)
            entity.id = UUID()
            entity.title = sample.0
            entity.content = sample.1
            entity.colorHex = sample.2
            entity.noteIsDeleted = false
            entity.isSynced = sample.3
            entity.lastModifiedAt = Date().addingTimeInterval(Double(-i * 3600))
            entity.createdAt = Date().addingTimeInterval(Double(-i * 3600))
            entities.append(entity)
        }

        try? context.save()
        return entities
    }
}
