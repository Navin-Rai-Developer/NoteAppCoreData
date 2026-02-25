//
// NoteEditorView.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteEditorView.swift — Fixed
//
// Fix 1: Debug panel removed (was always showing)
// Fix 2: Color immediately reflected in background
// Fix 3: Sheet dismiss bugs fixed
// Fix 4: TextEditor instead of TextField (no dismiss on typing)
// ============================================================

import SwiftUI
import CoreData


// ============================================================
// NoteEditorView
// ============================================================
struct NoteEditorView: View {

    let note: Note?
    let onDismiss: () -> Void

    @StateObject private var viewModel = NoteEditorViewModel()
    @FocusState private var focusedField: Field?

    enum Field { case title, content }

    // ✅ Background color — reacts instantly when color changes
    private var bgColor: Color {
        viewModel.selectedColor?.color ?? Color(.systemBackground)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // ✅ Full background = note color
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // ─── COLOR PICKER ───────────────────
                        colorPickerStrip
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 8)

                        // ─── TITLE ──────────────────────────
                        // ✅ Fix: Simple TextField, no axis:vertical
                        // axis:vertical causes sheet dismiss bug
                        TextField("Title", text: $viewModel.title)
                            .font(.system(size: 26, weight: .bold))
                            .focused($focusedField, equals: .title)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .content }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)

                        Divider()
                            .padding(.horizontal, 20)

                        // ─── CONTENT ────────────────────────
                        // ✅ Fix: TextEditor = proper multiline
                        // No dismiss bug when typing or pressing return
                        TextEditor(text: $viewModel.content)
                            .font(.body)
                            .focused($focusedField, equals: .content)
                            .frame(minHeight: 380, alignment: .topLeading)
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                    }
                }
            }
            .navigationTitle(viewModel.navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        viewModel.cancelAutoSave()
                        onDismiss()
                    }
                    .foregroundColor(.secondary)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.cancelAutoSave()
                        viewModel.save()
                        // ✅ onDismiss is called inside save() via onSave callback
                    }
                    .fontWeight(.semibold)
                    .disabled(
                        viewModel.title
                            .trimmingCharacters(in: .whitespaces)
                            .isEmpty
                    )
                }

                // Keyboard Done button
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            // ✅ Prevent accidental swipe dismiss when content exists
            .interactiveDismissDisabled(
                !viewModel.title.isEmpty || !viewModel.content.isEmpty
            )
        }
        .onAppear {
            viewModel.onSave = onDismiss
            if let note {
                viewModel.load(note)
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    focusedField = .title
                }
            }
        }
    }

    // ─── COLOR PICKER STRIP ──────────────────────────────────
    private var colorPickerStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose Color")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    // ✅ "None" option — removes color
                    Button {
                        withAnimation(.spring(response: 0.25)) {
                            viewModel.selectedColor = nil
                        }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .strokeBorder(
                                            Color.secondary.opacity(0.4),
                                            lineWidth: 1.5
                                        )
                                )
                            Image(systemName: "circle.slash")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)

                            if viewModel.selectedColor == nil {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.7),
                                                  lineWidth: 2.5)
                                    .frame(width: 34, height: 34)
                            }
                        }
                        .scaleEffect(viewModel.selectedColor == nil ? 1.12 : 1.0)
                    }
                    .buttonStyle(.plain)

                    // All color options
                    ForEach(NoteColor.allCases, id: \.self) { noteColor in
                        Button {
                            withAnimation(.spring(response: 0.25)) {
                                viewModel.selectedColor = noteColor
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(noteColor.color)
                                    .frame(width: 34, height: 34)
                                    .shadow(color: .black.opacity(0.1),
                                            radius: 2, x: 0, y: 1)

                                Circle()
                                    .strokeBorder(
                                        Color.secondary.opacity(0.2),
                                        lineWidth: 1
                                    )
                                    .frame(width: 34, height: 34)

                                // ✅ Selected indicator
                                if viewModel.selectedColor == noteColor {
                                    Circle()
                                        .strokeBorder(
                                            Color.primary.opacity(0.7),
                                            lineWidth: 2.5
                                        )
                                        .frame(width: 34, height: 34)

                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.primary.opacity(0.8))
                                }
                            }
                            .scaleEffect(
                                viewModel.selectedColor == noteColor ? 1.12 : 1.0
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }
}

// ============================================================
// ✅ PREVIEWS
// ============================================================
#Preview("New Note") {
    NoteEditorView(note: nil, onDismiss: {})
        .environment(\.managedObjectContext, PreviewHelper.context)
}

//#Preview("Edit — Yellow") {
//    let note = Note(
//        id: UUID(), title: "Travel Plans",
//        content: "Tokyo → Kyoto → Osaka",
//        noteIsDeleted: false, isSynced: false,
//        colorHex: NoteColor.yellow.rawValue,
//        lastModifiedAt: Date(), createdAt: Date()
//    )
//    return NoteEditorView(note: note, onDismiss: {})
//        .environment(\.managedObjectContext, PreviewHelper.context)
//}
//
//#Preview("Edit — Dark + Purple") {
//    let note = Note(
//        id: UUID(), title: "Interview Prep",
//        content: "CoreData, SwiftUI, MVVM",
//        noteIsDeleted: false, isSynced: true,
//        colorHex: NoteColor.purple.rawValue,
//        lastModifiedAt: Date(), createdAt: Date()
//    )
//    return NoteEditorView(note: note, onDismiss: {})
//        .environment(\.managedObjectContext, PreviewHelper.context)
//        .preferredColorScheme(.dark)
//}
