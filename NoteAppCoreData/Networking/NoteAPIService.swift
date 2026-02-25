//
// NoteAPIService.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// NoteAPIService.swift — Network Layer
//
// This is a MOCK — replace the body with real URLSession calls
// The interface (function signatures) stays the same.
//
// Concepts:
//   ✅ async/await — clean, no Combine needed
//   ✅ Batch endpoint — 1 call instead of N
//   ✅ PATCH with isDeleted:true (NOT DELETE)
//   ✅ Codable Note → easy JSON encoding
// ============================================================

import Foundation

enum APIError: LocalizedError {
    case networkUnavailable
    case notFound
    case serverError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .networkUnavailable: return "No internet connection"
        case .notFound: return "Resource not found"
        case .serverError(let code): return "Server error: \(code)"
        case .decodingError: return "Failed to decode response"
        }
    }
}

// ─── API Service ─────────────────────────────────────────────
class NoteAPIService {

    static let shared = NoteAPIService()
    private var serverDB: [UUID: Note] = [:]  // Mock server storage
    private init() {}

    // ─── FETCH ALL ───────────────────────────────────────────
    // GET /api/notes
    func fetchAll() async throws -> [Note] {
        try await mockDelay()
        return serverDB.values.filter { !$0.noteIsDeleted }
    }

    // ─── BATCH SYNC ──────────────────────────────────────────
    // ✅ POST /api/notes/batch
    // One call sends all pending creates/updates/deletes
    // Server handles each and returns resolved versions
    //
    // Real URLSession version:
    // var request = URLRequest(url: URL(string: "https://api.example.com/notes/batch")!)
    // request.httpMethod = "POST"
    // request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    // request.httpBody = try JSONEncoder().encode(notes)
    // let (data, _) = try await URLSession.shared.data(for: request)
    // return try JSONDecoder().decode([Note].self, from: data)
    func batchSync(notes: [Note]) async throws -> [Note] {
        try await mockDelay()

        var resolved: [Note] = []

        for note in notes {
            if let existing = serverDB[note.id] {
                // ✅ Conflict: compare timestamps
                if note.lastModifiedAt >= existing.lastModifiedAt {
                    serverDB[note.id] = note
                    resolved.append(note)
                } else {
                    // Server is newer — return server version
                    resolved.append(existing)
                }
            } else {
                // New note — create on server
                serverDB[note.id] = note
                resolved.append(note)
            }
        }

        return resolved
    }

    // ─── MOCK NETWORK DELAY ──────────────────────────────────
    private func mockDelay() async throws {
        let ms = UInt64.random(in: 500_000_000...1_500_000_000) // 0.5-1.5s
        try await Task.sleep(nanoseconds: ms)
    }
}
