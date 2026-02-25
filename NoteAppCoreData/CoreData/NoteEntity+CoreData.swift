//
// NoteEntity+CoreData.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteEntity+CoreData.swift — Updated with colorHex
//
// Changes:
//   ✅ colorHex: String added
//   ✅ toNote() mein colorHex include kiya
//   ✅ update() mein colorHex update hota hai
//
// IMPORTANT: CoreData model mein bhi colorHex attribute add karo!
// (Steps neeche hain)
// ============================================================

import CoreData
import Foundation

@objc(NoteEntity)
public class NoteEntity: NSManagedObject {

    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var content: String
    @NSManaged public var noteIsDeleted: Bool
    @NSManaged public var isSynced: Bool
    @NSManaged public var colorHex: String      // ✅ NEW
    @NSManaged public var lastModifiedAt: Date
    @NSManaged public var createdAt: Date

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NoteEntity> {
        return NSFetchRequest<NoteEntity>(entityName: "NoteEntity")
    }

    // ─── Create from Note struct ─────────────────────────────
    @discardableResult
    convenience init(context: NSManagedObjectContext, note: Note) {
        self.init(context: context)
        self.id = note.id
        self.title = note.title
        self.content = note.content
        self.noteIsDeleted = note.noteIsDeleted
        self.isSynced = note.isSynced
        self.colorHex = note.colorHex           // ✅ NEW
        self.lastModifiedAt = note.lastModifiedAt
        self.createdAt = note.createdAt
    }

    // ─── Convert to Swift struct ─────────────────────────────
    func toNote() -> Note {
        Note(
            id: id,
            title: title,
            content: content,
            noteIsDeleted: noteIsDeleted,
            isSynced: isSynced,
            colorHex: colorHex,                 // ✅ NEW
            lastModifiedAt: lastModifiedAt,
            createdAt: createdAt
        )
    }

    // ─── Apply updates from struct ───────────────────────────
    func update(from note: Note) {
        self.title = note.title
        self.content = note.content
        self.noteIsDeleted = note.noteIsDeleted
        self.isSynced = note.isSynced
        self.colorHex = note.colorHex           // ✅ NEW
        self.lastModifiedAt = note.lastModifiedAt
    }
}

