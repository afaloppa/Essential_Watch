//
//  TremorSyncSender.swift
//  Essential_Watch Watch App
//
//  Pushes the latest tremor result to the paired iPhone over WatchConnectivity.
//
//  We deliberately send only the low-rate prediction (probability + flag),
//  ~2x/sec, not the raw 50 Hz accelerometer stream — WatchConnectivity is not
//  suited to smooth high-rate streaming.
//

import Foundation
import WatchConnectivity

/// Singleton that forwards tremor predictions to the iOS companion app.
@MainActor
final class TremorSyncSender: NSObject {
    static let shared = TremorSyncSender()

    private override init() {
        super.init()
        activate()
    }

    private func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends the latest tremor result to the iPhone.
    /// - Parameters:
    ///   - probability: probability of the "tremor" class (0...1).
    ///   - isTremor: whether the latest window was classified as tremor.
    func send(probability: Double, isTremor: Bool) {
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = [
            "tremorProbability": probability,
            "isTremor": isTremor,
            "timestamp": Date().timeIntervalSince1970,
        ]

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            // Coalesced "latest state" delivery when the phone app isn't live.
            try? session.updateApplicationContext(payload)
        }
    }
}

extension TremorSyncSender: WCSessionDelegate {
    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
