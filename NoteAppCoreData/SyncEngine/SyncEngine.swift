//
// SyncEngine.swift
// NoteAppCoreData
//
// Created by Navin Rai on 24/02/26
//
// ============================================================
// SyncEngine.swift — Background Sync Manager (CoreData version)
//
// Concepts:
//   ✅ NWPathMonitor — detects online/offline in real time
//   ✅ Queue collapse — CREATE+DELETE = send nothing
//   ✅ Batch API — one call, not N calls
//   ✅ Exponential backoff — 2s → 4s → 8s
//   ✅ @Published — UI shows sync status badge
//   ✅ async/await — no Combine needed
// ============================================================

import Foundation
import Network
import Combine

@MainActor
class SyncEngine: ObservableObject {

    static let shared = SyncEngine()

    // ✅ @Published → UI reacts to sync state changes
    @Published var isOnline: Bool = false
    @Published var isSyncing: Bool = false
    @Published var lastSyncAt: Date? = nil
    @Published var pendingCount: Int = 0
    @Published var syncError: String? = nil

    private let monitor = NWPathMonitor()
    private let repository = NoteRepository.shared
    private let api = NoteAPIService.shared
    private var retryCount = 0
    private let maxRetries = 3

    private init() {
        startMonitoring()
    }

    // ─── NETWORK MONITOR ─────────────────────────────────────
    // ✅ NWPathMonitor watches real device network state
    // Works for WiFi, Cellular, Ethernet, VPN
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasOffline = !self.isOnline
                self.isOnline = (path.status == .satisfied)

                print(self.isOnline ? "📡 Online" : "📴 Offline")

                // ✅ Came back online → sync pending queue
                if wasOffline && self.isOnline {
                    await self.syncNow()
                }
            }
        }
        // Start monitoring on a background queue
        monitor.start(queue: DispatchQueue(label: "sync.network.monitor"))
    }

    // ─── SYNC NOW ────────────────────────────────────────────
    func syncNow() async {
        guard isOnline else {
            print("📴 Skipping sync — offline")
            updatePendingCount()
            return
        }
        guard !isSyncing else { return }

        isSyncing = true
        syncError = nil

        do {
            // 1. Get all unsynced from CoreData
            let unsynced = repository.fetchUnsynced()
            updatePendingCount()

            guard !unsynced.isEmpty else {
                print("✅ Queue empty — nothing to sync")
                isSyncing = false
                lastSyncAt = Date()
                return
            }

            print("📤 Syncing \(unsynced.count) notes...")

            // 2. ✅ COLLAPSE QUEUE — Senior optimization
            // CREATE + DELETE = send NOTHING (zero waste)
            let collapsed = repository.collapseQueue(unsynced)
            print("🗜️ After collapse: \(collapsed.count) ops (was \(unsynced.count))")

            if collapsed.isEmpty {
                // Everything cancelled out — mark all as synced
                unsynced.forEach { repository.markSynced(id: $0.id) }
                isSyncing = false
                lastSyncAt = Date()
                updatePendingCount()
                return
            }

            // 3. ✅ BATCH API — one network call for all ops
            let serverResults = try await api.batchSync(notes: collapsed)

            // 4. Save server results → conflict resolution inside saveFromServer()
            await withCheckedContinuation { continuation in
                repository.saveFromServer(serverResults) {
                    continuation.resume()
                }
            }

            // 5. Mark synced
            collapsed.forEach { repository.markSynced(id: $0.id) }

            retryCount = 0
            lastSyncAt = Date()
            updatePendingCount()
            print("✅ Sync complete — \(serverResults.count) notes")

        } catch {
            print("❌ Sync error: \(error.localizedDescription)")
            syncError = "Sync failed. Retrying..."
            await retryWithBackoff()
        }

        isSyncing = false
    }

    // ─── EXPONENTIAL BACKOFF ─────────────────────────────────
    // ✅ Don't hammer server — wait 2s, 4s, 8s between retries
    private func retryWithBackoff() async {
        guard retryCount < maxRetries else {
            syncError = "Sync failed after \(maxRetries) attempts."
            retryCount = 0
            return
        }
        retryCount += 1
        let delay = pow(2.0, Double(retryCount))  // 2, 4, 8 seconds
        print("🔄 Retry \(retryCount)/\(maxRetries) in \(Int(delay))s")
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        await syncNow()
    }

    // ─── UPDATE PENDING COUNT ────────────────────────────────
    private func updatePendingCount() {
        pendingCount = repository.fetchUnsynced().count
    }

    // ─── SYNC STATUS FOR UI ──────────────────────────────────
    var statusText: String {
        if isSyncing     { return "Syncing..." }
        if !isOnline     { return "Offline — \(pendingCount) pending" }
        if pendingCount > 0 { return "\(pendingCount) pending" }
        return "All synced ✓"
    }

    var statusSymbol: String {
        if isSyncing  { return "arrow.triangle.2.circlepath" }
        if !isOnline  { return "wifi.slash" }
        return "checkmark.icloud"
    }
}
