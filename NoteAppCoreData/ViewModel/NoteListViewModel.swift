//
// NoteListViewModel.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteListViewModel.swift — MVVM ViewModel (CoreData version)
//
// Concepts:
//   ✅ @Published — reactive, SwiftUI re-renders on change
//   ✅ @MainActor — all UI updates guaranteed on main thread
//   ✅ ViewModel never touches CoreData directly → uses Repository
//   ✅ No Combine needed — async/await + @Published is enough
//
// NOTE: In SwiftUI views we ALSO use @FetchRequest directly
// This ViewModel handles: search, loading state, actions
// ============================================================

import Foundation
import Combine

@MainActor
class NoteListViewModel: ObservableObject {

    // ✅ @Published — any change triggers SwiftUI re-render
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var noteToDelete: Note? = nil
    @Published var showDeleteConfirm: Bool = false

    // Access SyncEngine for status display
    let syncEngine = SyncEngine.shared
    private let repository = NoteRepository.shared

    // ─── CREATE ──────────────────────────────────────────────
    // ✅ Background write → @FetchRequest auto-updates UI
    // No need to manually reload notes list!
    func createNote(title: String, content: String = "") {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        repository.createNote(title: title, content: content) { note in
            print("✅ Note created, @FetchRequest will auto-update UI")
            // ✅ No loadNotes() needed! CoreData + @FetchRequest handles it
            Task {
                await SyncEngine.shared.syncNow()
            }
        }
    }

    // ─── UPDATE ──────────────────────────────────────────────
    func updateNote(_ note: Note, title: String, content: String) {
        repository.updateNote(note, title: title, content: content) {
            Task { await SyncEngine.shared.syncNow() }
        }
    }

    // ─── DELETE (Soft) ───────────────────────────────────────
    // ✅ isDeleted = true → @FetchRequest predicate hides it
    // UI updates automatically — no manual reload
    func deleteNote(_ note: Note) {
        repository.softDeleteNote(note) {
            Task { await SyncEngine.shared.syncNow() }
        }
    }

    // ─── REQUEST DELETE (shows confirmation alert) ───────────
    func requestDelete(_ note: Note) {
        noteToDelete = note
        showDeleteConfirm = true
    }

    func confirmDelete() {
        guard let note = noteToDelete else { return }
        deleteNote(note)
        noteToDelete = nil
    }

    // ─── REFRESH FROM SERVER ─────────────────────────────────
    func refresh() async {
        isLoading = true
        await syncEngine.syncNow()
        isLoading = false
    }

    // ─── SYNC STATUS ─────────────────────────────────────────
    var syncBadgeColor: String {
        if syncEngine.isSyncing { return "yellow" }
        if !syncEngine.isOnline { return "red" }
        if syncEngine.pendingCount > 0 { return "orange" }
        return "green"
    }
}
