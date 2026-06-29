//
//  TremorSyncReceiver.swift
//  Essential_Watch (iOS companion)
//
//  Receives the latest tremor result streamed from the watch app over
//  WatchConnectivity and publishes it for the UI.
//

import Foundation
import Combine
import WatchConnectivity

/// Observable store of the most recent tremor prediction received from the watch.
@MainActor
final class TremorSyncReceiver: NSObject, ObservableObject {

    /// Probability of the "tremor" class for the latest watch window (0...1).
    @Published private(set) var tremorProbability: Double?
    /// Whether the latest watch window was classified as tremor.
    @Published private(set) var isTremor: Bool = false
    /// When the last update arrived (used to show staleness).
    @Published private(set) var lastUpdate: Date?

    override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    fileprivate func ingest(_ payload: [String: Any]) {
        guard let probability = payload["tremorProbability"] as? Double,
              let tremor = payload["isTremor"] as? Bool else { return }
        tremorProbability = probability
        isTremor = tremor
        lastUpdate = Date()
    }
}

extension TremorSyncReceiver: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so we keep receiving if the active watch changes.
        WCSession.default.activate()
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.ingest(message) }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in self.ingest(applicationContext) }
    }
}
