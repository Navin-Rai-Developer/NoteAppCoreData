//
// NoteListView.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteListView.swift — Updated with Color Support
//
// Changes:
//   ✅ NoteRowView shows note background color
//   ✅ Color dot indicator in list row
//   ✅ noteIsDeleted predicate (not isDeleted)
// ============================================================

import SwiftUI
import CoreData

struct NoteListView: View {

    @StateObject private var viewModel = NoteListViewModel()

    // ✅ @FetchRequest — watches CoreData automatically
    // noteIsDeleted predicate — soft deleted notes kabhi nahi dikhenge
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \NoteEntity.lastModifiedAt, ascending: false)
        ],
        predicate: NSPredicate(format: "noteIsDeleted == NO"),
        animation: .default
    )
    private var noteEntities: FetchedResults<NoteEntity>

    @State private var showingNewNote = false
    @State private var editingNote: Note? = nil

    private var filteredNotes: [NoteEntity] {
        guard !viewModel.searchText.isEmpty else { return Array(noteEntities) }
        return noteEntities.filter {
            $0.title.localizedCaseInsensitiveContains(viewModel.searchText) ||
            $0.content.localizedCaseInsensitiveContains(viewModel.searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ─── SYNC STATUS BAR ────────────────────────
                SyncStatusBar()
                    .padding(.horizontal)
                    .padding(.vertical, 6)

                // ─── SEARCH ─────────────────────────────────
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search notes...", text: $viewModel.searchText)
                    if !viewModel.searchText.isEmpty {
                        Button { viewModel.searchText = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom, 8)

                // ─── LIST ────────────────────────────────────
                if filteredNotes.isEmpty {
                    EmptyNoteView(isSearching: !viewModel.searchText.isEmpty)
                } else {
                    List {
                        ForEach(filteredNotes, id: \.id) { entity in
                            NoteRowView(entity: entity)
                                .listRowInsets(EdgeInsets(
                                    top: 6, leading: 16,
                                    bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .onTapGesture {
                                    editingNote = entity.toNote()
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.requestDelete(entity.toNote())
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await viewModel.refresh() }
                }
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .fontWeight(.semibold)
                    }
                }
            }

            // ─── NEW NOTE ────────────────────────────────────
            .sheet(isPresented: $showingNewNote) {
                NoteEditorView(note: nil) {
                    showingNewNote = false
                }
            }

            // ─── EDIT NOTE ───────────────────────────────────
            // ✅ Bug Fix: .sheet(item:) properly resets when editingNote = nil
            .sheet(item: $editingNote) { note in
                NoteEditorView(note: note) {
                    editingNote = nil
                }
            }

            // ─── DELETE ALERT ────────────────────────────────
            .alert("Delete Note?", isPresented: $viewModel.showDeleteConfirm) {
                Button("Delete", role: .destructive) { viewModel.confirmDelete() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will be deleted from all your devices.")
            }
        }
    }
}

// ============================================================
// SyncStatusBar
// ============================================================
struct SyncStatusBar: View {
    @ObservedObject private var syncEngine = SyncEngine.shared

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                if syncEngine.isSyncing {
                    Circle()
                        .stroke(dotColor.opacity(0.4), lineWidth: 1.5)
                        .frame(width: 14, height: 14)
                        .scaleEffect(1.2)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(),
                            value: syncEngine.isSyncing
                        )
                }
            }

            Text(syncEngine.statusText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if let lastSync = syncEngine.lastSyncAt {
                Text("Synced \(lastSync.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var dotColor: Color {
        if syncEngine.isSyncing     { return .yellow }
        if !syncEngine.isOnline     { return .red }
        if syncEngine.pendingCount > 0 { return .orange }
        return .green
    }
}

// ============================================================
// NoteRowView — with color background
// ============================================================
struct NoteRowView: View {
    let entity: NoteEntity

    // Note ka color get karo — agar set nahi toh white
    private var noteColor: Color {
        guard !entity.colorHex.isEmpty else { return Color(.secondarySystemGroupedBackground) }
        return Color(hex: entity.colorHex) ?? Color(.secondarySystemGroupedBackground)
    }

    var body: some View {
        HStack(spacing: 12) {

            // ✅ Left color bar — note color indicator
            RoundedRectangle(cornerRadius: 3)
                .fill(noteColor == Color(.secondarySystemGroupedBackground)
                      ? Color.secondary.opacity(0.3)
                      : noteColor)
                .frame(width: 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entity.title.isEmpty ? "Untitled" : entity.title)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    // Sync pending indicator
                    if !entity.isSynced {
                        Image(systemName: "arrow.clockwise.icloud")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if !entity.content.isEmpty {
                    Text(entity.content)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Text(entity.lastModifiedAt.formatted(
                    date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        // ✅ Card background with note color
        .background(noteColor.opacity(0.35))
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(noteColor.opacity(0.5), lineWidth: 1)
        )
    }
}

// ============================================================
// EmptyNoteView
// ============================================================
struct EmptyNoteView: View {
    let isSearching: Bool
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: isSearching
                  ? "magnifyingglass"
                  : "note.text.badge.plus")
                .font(.system(size: 52))
                .foregroundColor(.secondary.opacity(0.4))
            Text(isSearching ? "No notes found" : "No Notes Yet")
                .font(.title3).fontWeight(.semibold)
            if !isSearching {
                Text("Tap ✏️ to write your first note\nWorks offline — syncs when connected")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
    }
}

// ============================================================
// ✅ PREVIEWS
// ============================================================
#Preview("Light Mode") {
    let _ = PreviewHelper.insertSampleNotes()
    return NoteListView()
        .environment(\.managedObjectContext, PreviewHelper.context)
}

//#Preview("Dark Mode") {
//    let _ = PreviewHelper.insertSampleNotes()
//    return NoteListView()
//        .environment(\.managedObjectContext, PreviewHelper.context)
//        .preferredColorScheme(.dark)
//}
