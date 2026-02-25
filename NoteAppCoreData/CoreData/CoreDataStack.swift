//
// NoteAppCoreData
// CoreDataStack.swift
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// CoreDataStack.swift
//
// The heart of CoreData setup.
// Concepts:
//   ✅ NSPersistentContainer — manages CoreData store
//   ✅ viewContext — main thread context for UI reads
//   ✅ backgroundContext — background writes (never block UI)
//   ✅ Automatic merge from background → viewContext
//   ✅ persistentStoreDescriptions — enables WAL mode (faster)
// ============================================================

import CoreData
import Foundation

class CoreDataStack {

    static let shared = CoreDataStack()

    // ─── NSPersistentContainer ──────────────────────────────
    // ✅ "NoteModel" must match your .xcdatamodeld filename exactly
    let container: NSPersistentContainer

    private init() {
        container = NSPersistentContainer(name: "NoteAppCoreData")

        // ✅ WAL journal mode — faster reads, better concurrency
        let description = container.persistentStoreDescriptions.first
        description?.setOption(["journal_mode": "WAL"] as NSObject,
                                forKey: NSSQLiteStoreType)

        // ✅ Merge changes from background context → viewContext automatically
        description?.setOption(true as NSNumber,
                                forKey: NSPersistentHistoryTrackingKey)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production: log this error, don't crash
                fatalError("CoreData load failed: \(error), \(error.userInfo)")
            }
            print("✅ CoreData loaded: \(storeDescription.url?.lastPathComponent ?? "")")
        }

        // ✅ Auto-merge changes: background save → viewContext updates
        // This is what makes @FetchRequest reactive!
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // ─── MAIN CONTEXT (UI Thread) ───────────────────────────
    // ✅ All @FetchRequest reads use this
    // ✅ NEVER do heavy writes here — blocks UI
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    // ─── BACKGROUND CONTEXT ─────────────────────────────────
    // ✅ All writes (create, update, delete) use this
    // ✅ Runs on background thread — UI never freezes
    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return ctx
    }

    // ─── SAVE BACKGROUND CONTEXT ────────────────────────────
    func saveBackground(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
            // ✅ automaticallyMergesChangesFromParent = true
            // → viewContext auto-updates → @FetchRequest fires → UI refreshes
        } catch {
            print("❌ CoreData save error: \(error)")
            context.rollback()
        }
    }

    // ─── SAVE VIEW CONTEXT (for simple ops) ─────────────────
    func saveViewContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("❌ ViewContext save error: \(error)")
            context.rollback()
        }
    }
}
