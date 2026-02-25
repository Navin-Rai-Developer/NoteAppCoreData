//
// NoteRepository.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteRepository.swift — Color Update Fix
//
// Root Cause: background context fetch karta tha UUID se
// Lekin save ke baad existingNote stale tha
// 
// Fix: viewContext pe directly update karo for color changes
// Background context se merge delay hota tha
// ============================================================

import CoreData
import Foundation

class NoteRepository {

    static let shared = NoteRepository()
    private let stack = CoreDataStack.shared
    private init() {}

    // ─── FETCH VISIBLE ───────────────────────────────────────
    func fetchVisible() -> [Note] {
        let request = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "noteIsDeleted == NO")
        request.sortDescriptors = [
            NSSortDescriptor(key: "lastModifiedAt", ascending: false)
        ]
        do {
            return try stack.viewContext.fetch(request).map { $0.toNote() }
        } catch { return [] }
    }

    // ─── FETCH UNSYNCED ──────────────────────────────────────
    func fetchUnsynced() -> [Note] {
        let request = NoteEntity.fetchRequest()
        request.predicate = NSPredicate(format: "isSynced == NO")
        do {
            return try stack.viewContext.fetch(request).map { $0.toNote() }
        } catch { return [] }
    }

    // ─── CREATE ──────────────────────────────────────────────
    func createNote(
        title: String,
        content: String = "",
        colorHex: String = "",
        completion: @escaping (Note) -> Void
    ) {
        let bgContext = stack.newBackgroundContext()
        bgContext.perform {
            let note = Note(
                id: UUID(),
                title: title,
                content: content,
                noteIsDeleted: false,
                isSynced: false,
                colorHex: colorHex,
                lastModifiedAt: Date(),
                createdAt: Date()
            )
            NoteEntity(context: bgContext, note: note)
            self.stack.saveBackground(bgContext)
            print("📝 Created: \(note.id) color:\(colorHex)")
            DispatchQueue.main.async { completion(note) }
        }
    }

    // ─── UPDATE ──────────────────────────────────────────────
    // ✅ Fix: viewContext pe directly fetch and save karo
    // Background context → merge delay → color not updating
    // viewContext → instant update → @FetchRequest fires immediately
    func updateNote(
        _ note: Note,
        title: String,
        content: String,
        colorHex: String = "",
        completion: (() -> Void)? = nil
    ) {
        // ✅ viewContext pe directly karo — no background context
        // Kyunki: @FetchRequest viewContext watch karta hai
        // Background save ke baad merge hota hai — isme delay hota hai
        // viewContext direct update = instant UI refresh
        let context = stack.viewContext

        context.perform {
            let request = NoteEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "id == %@", note.id as CVarArg
            )
            request.fetchLimit = 1

            do {
                if let entity = try context.fetch(request).first {
                    entity.title          = title
                    entity.content        = content
                    entity.colorHex       = colorHex   // ✅ KEY: color update
                    entity.lastModifiedAt = Date()
                    entity.isSynced       = false

                    // ✅ viewContext save → @FetchRequest INSTANTLY fires
                    self.stack.saveViewContext()
                    print("✏️ Updated on viewContext: id=\(note.id) color=\(colorHex)")
                } else {
                    print("⚠️ Entity not found for id: \(note.id)")
                }
            } catch {
                print("❌ Update error: \(error)")
            }

            DispatchQueue.main.async { completion?() }
        }
    }

    // ─── SOFT DELETE ─────────────────────────────────────────
    func softDeleteNote(_ note: Note, completion: (() -> Void)? = nil) {
        let context = stack.viewContext
        context.perform {
            let request = NoteEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "id == %@", note.id as CVarArg
            )
            request.fetchLimit = 1
            do {
                if let entity = try context.fetch(request).first {
                    entity.noteIsDeleted  = true
                    entity.lastModifiedAt = Date()
                    entity.isSynced       = false
                    self.stack.saveViewContext()
                    print("🗑️ Soft deleted: \(note.id)")
                }
            } catch { print("❌ Delete error: \(error)") }
            DispatchQueue.main.async { completion?() }
        }
    }

    // ─── SAVE FROM SERVER ────────────────────────────────────
    // Server se aaya data — background context theek hai yahan
    func saveFromServer(_ serverNotes: [Note], completion: (() -> Void)? = nil) {
        let bgContext = stack.newBackgroundContext()
        bgContext.perform {
            for serverNote in serverNotes {
                let request = NoteEntity.fetchRequest()
                request.predicate = NSPredicate(
                    format: "id == %@", serverNote.id as CVarArg
                )
                request.fetchLimit = 1
                do {
                    if let existing = try bgContext.fetch(request).first {
                        if existing.noteIsDeleted &&
                           existing.lastModifiedAt > serverNote.lastModifiedAt {
                            continue
                        }
                        if serverNote.lastModifiedAt > existing.lastModifiedAt {
                            existing.update(from: serverNote)
                            existing.isSynced = true
                        }
                    } else {
                        NoteEntity(context: bgContext, note: serverNote)
                    }
                } catch { print("❌ Server save error: \(error)") }
            }
            self.stack.saveBackground(bgContext)
            DispatchQueue.main.async { completion?() }
        }
    }

    // ─── MARK SYNCED ─────────────────────────────────────────
    func markSynced(id: UUID) {
        let bgContext = stack.newBackgroundContext()
        bgContext.perform {
            let request = NoteEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1
            if let entity = try? bgContext.fetch(request).first {
                entity.isSynced = true
                self.stack.saveBackground(bgContext)
            }
        }
    }

    // ─── QUEUE COLLAPSE ──────────────────────────────────────
    func collapseQueue(_ notes: [Note]) -> [Note] {
        var collapsed: [UUID: Note] = [:]
        let sorted = notes.sorted { $0.lastModifiedAt < $1.lastModifiedAt }
        for note in sorted {
            if let existing = collapsed[note.id] {
                if !existing.noteIsDeleted &&
                    note.noteIsDeleted &&
                    !existing.isSynced {
                    collapsed.removeValue(forKey: note.id)
                    continue
                }
                if note.lastModifiedAt > existing.lastModifiedAt {
                    collapsed[note.id] = note
                }
            } else {
                collapsed[note.id] = note
            }
        }
        return Array(collapsed.values)
    }

    // ─── TOMBSTONE CLEANUP ───────────────────────────────────
    func cleanupOldTombstones() {
        let bgContext = stack.newBackgroundContext()
        bgContext.perform {
            let cutoff = Date().addingTimeInterval(-30 * 24 * 60 * 60)
            let request = NoteEntity.fetchRequest()
            request.predicate = NSPredicate(
                format: "noteIsDeleted == YES AND lastModifiedAt < %@",
                cutoff as NSDate
            )
            do {
                let old = try bgContext.fetch(request)
                old.forEach { bgContext.delete($0) }
                if !old.isEmpty {
                    self.stack.saveBackground(bgContext)
                    print("🧹 Cleaned \(old.count) tombstones")
                }
            } catch { print("❌ Cleanup error: \(error)") }
        }
    }
}
