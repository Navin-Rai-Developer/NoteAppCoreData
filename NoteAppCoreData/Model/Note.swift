//
// Note.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// Note.swift — Updated with colorHex field
//
// Changes:
//   ✅ colorHex: String added — stores color as "#FEF08A" etc
// ============================================================

import Foundation

struct Note: Identifiable, Codable, Equatable, Hashable {

    let id: UUID
    var title: String
    var content: String
    var noteIsDeleted: Bool
    var isSynced: Bool

    // ✅ NEW: Color stored as hex string
    // "" = no color (default white/system)
    // "#FEF08A" = yellow, etc.
    var colorHex: String

    var lastModifiedAt: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String = "",
        content: String = "",
        noteIsDeleted: Bool = false,
        isSynced: Bool = false,
        colorHex: String = "",        // ← default no color
        lastModifiedAt: Date = Date(),
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.noteIsDeleted = noteIsDeleted
        self.isSynced = isSynced
        self.colorHex = colorHex
        self.lastModifiedAt = lastModifiedAt
        self.createdAt = createdAt
    }
}
