//
//  PlaceholderPredictionService.swift
//  Essential_Watch Watch App
//
//  A stub `PredictionServicing` implementation that lets the UI bind to
//  `latestPrediction` today, before the real CoreML model is integrated.
//

import Foundation
import Combine

/// A no-op prediction service that accumulates samples into a
/// `SampleBuffer` and publishes a fixed placeholder string once
/// the buffer's window is filled.
///
/// Replace the marked section in `consume` with a real CoreML
/// inference call when the model is available.
@MainActor
final class PlaceholderPredictionService: ObservableObject, PredictionServicing {

    /// Latest model output, human-readable. `nil` until the buffer first fills.
    @Published private(set) var latestPrediction: String?

    /// Sliding window of recent accelerometer samples that the future
    /// model will consume.
    private var buffer: SampleBuffer

    /// Creates a new placeholder service.
    /// - Parameter capacity: The sample-window size in samples
    ///   (default `100`, i.e. ~2s at 50 Hz).
    init(capacity: Int = 100) {
        self.buffer = SampleBuffer(capacity: capacity)
    }

    /// Appends `sample` to the internal window. Once the window is full,
    /// publishes a placeholder prediction so the UI can bind to it.
    /// - Parameter sample: The newest accelerometer sample.
    func consume(_ sample: AccelerometerSample) {
        buffer.append(sample)

        guard buffer.isFull else { return }

        // TODO: replace with CoreML inference
        // Feed `buffer.snapshot` into the CoreML model here and map the
        // output class to a human-readable string assigned to
        // `latestPrediction`.
        latestPrediction = "idle (placeholder)"
    }
}
