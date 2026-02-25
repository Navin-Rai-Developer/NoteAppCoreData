//
// NoteEditorViewModel.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteEditorViewModel.swift — Color Update Fix
//
// Root Cause: existingNote stale rehta tha after first save
// Doosri baar color change karo → same old existingNote
// → updateNote() call → lekin color already saved tha?
// NO — colorHex properly pass nahi ho raha tha
//
// Fix:
//   ✅ save() ke baad existingNote update karo naye values se
//   ✅ selectedColor properly load hota hai from note
//   ✅ cancelAutoSave() on dismiss
// ============================================================

import Foundation
import Combine

@MainActor
class NoteEditorViewModel: ObservableObject {

    @Published var title: String = ""
    @Published var content: String = ""
    @Published var selectedColor: NoteColor? = nil

    var existingNote: Note? = nil
    var onSave: (() -> Void)? = nil

    private let repository = NoteRepository.shared
    private var autoSaveTask: Task<Void, Never>?

    // ─── LOAD ────────────────────────────────────────────────
    func load(_ note: Note) {
        existingNote  = note
        title         = note.title
        content       = note.content
        // ✅ Load color from saved hex
        selectedColor = NoteColor(rawValue: note.colorHex)
        print("📖 Loaded note color: \(note.colorHex)")
    }

    // ─── SAVE ────────────────────────────────────────────────
    func save() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let hex = selectedColor?.rawValue ?? ""
        print("💾 Saving color: \(hex)")

        if let existing = existingNote {
            repository.updateNote(
                existing,
                title:    trimmed,
                content:  content,
                colorHex: hex
            ) { [weak self] in
                guard let self else { return }
                // ✅ Fix: existingNote update karo saved values se
                // Taaki next save mein fresh data ho
                self.existingNote = Note(
                    id:             existing.id,
                    title:          trimmed,
                    content:        self.content,
                    noteIsDeleted:  existing.noteIsDeleted,
                    isSynced:       false,
                    colorHex:       hex,
                    lastModifiedAt: Date(),
                    createdAt:      existing.createdAt
                )
                Task { await SyncEngine.shared.syncNow() }
            }
        } else {
            repository.createNote(
                title:    trimmed,
                content:  content,
                colorHex: hex
            ) { [weak self] note in
                // ✅ After create — set as existingNote
                // Taaki agar user fir se save kare toh update ho
                self?.existingNote = note
                Task { await SyncEngine.shared.syncNow() }
            }
        }

        onSave?()
    }

    // ─── AUTO SAVE ───────────────────────────────────────────
    func scheduleAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            if !Task.isCancelled { save() }
        }
    }

    // ✅ Cancel pending save on dismiss
    func cancelAutoSave() {
        autoSaveTask?.cancel()
        autoSaveTask = nil
    }

    var isNewNote: Bool { existingNote == nil }
    var navTitle: String { isNewNote ? "New Note" : "Edit Note" }
}
