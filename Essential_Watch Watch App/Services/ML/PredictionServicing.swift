//
//  PredictionServicing.swift
//  Essential_Watch Watch App
//
//  Protocol describing a streaming prediction service that consumes
//  accelerometer samples and exposes the latest model output.
//

import Foundation

/// A service that ingests accelerometer samples in real time and
/// publishes the most recent human-readable model prediction.
///
/// Implementations are expected to be cheap on the `consume` path
/// (no blocking work) and to perform any heavy inference asynchronously.
@MainActor
protocol PredictionServicing: AnyObject {
    /// Called for every new accelerometer sample. Must be cheap; do not block.
    func consume(_ sample: AccelerometerSample)

    /// Latest model output, human-readable. `nil` until the model produces something.
    var latestPrediction: String? { get }
}
