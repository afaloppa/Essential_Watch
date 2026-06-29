//
//  TremorPredictionService.swift
//  Essential_Watch Watch App
//
//  Real `PredictionServicing` implementation backed by `TremorClassifier.mlmodel`.
//
//  Pipeline per incoming sample:
//    1. Track gravity with a low-pass filter and subtract it -> dynamic
//       acceleration in g (matching the gravity removal in ml/prepare_data.py
//       and CoreMotion's own `userAcceleration`).
//    2. Buffer the dynamic samples into a 2 s sliding window (100 @ 50 Hz).
//    3. A few times per second, extract `TremorFeatures` and run the model.
//

import Foundation
import Combine
import CoreML

/// Streaming tremor detector. Publishes a human-readable label plus the raw
/// tremor probability and a boolean for richer UI binding.
@MainActor
final class TremorPredictionService: ObservableObject, PredictionServicing {

    /// Human-readable latest prediction, e.g. "Tremor 87%". `nil` until the
    /// first full window has been classified.
    @Published private(set) var latestPrediction: String?

    /// Probability of the "tremor" class for the latest window (0...1).
    @Published private(set) var tremorProbability: Double?

    /// Whether the latest window was classified as tremor.
    @Published private(set) var isTremor: Bool = false

    /// Measured tremor-band (4–12 Hz) acceleration RMS of the latest window, in
    /// g. Exposed mainly so the gate threshold can be tuned on a real wrist.
    @Published private(set) var tremorBandG: Double?

    /// Minimum tremor-band RMS (g) required before the model output is trusted.
    /// Windows below this are reported as "No tremor" regardless of the
    /// classifier — this suppresses false positives from sensor noise and
    /// low-amplitude physiological micro-tremor on a near-steady hand.
    /// Tunable: lower it to catch milder tremor, raise it to be stricter.
    let minTremorBandG: Double

    private let windowSize: Int
    private var buffer: SampleBuffer

    /// Run inference every `inferenceStride` samples once the window is full
    /// (throttling keeps CPU/battery use low; the window itself still slides).
    private let inferenceStride: Int
    private var samplesSinceInference = 0

    /// Low-pass gravity estimate, removed from each sample. `nil` until primed.
    private var gravity: SIMD3<Double>?
    private let gravityAlpha: Double

    private let model: MLModel?

    /// - Parameters:
    ///   - windowSize: samples per classification window (default 100 ≈ 2 s @ 50 Hz).
    ///   - sampleRate: incoming sample rate in Hz (must match `MotionManager`).
    ///   - inferenceHz: how often to classify once the window is full.
    ///   - gravityCutoffHz: cutoff of the gravity-tracking low-pass filter.
    ///   - minTremorBandG: amplitude gate; tremor-band RMS (g) below this is
    ///     reported as "No tremor". Default 0.03 g ≈ above a steady-hand floor.
    init(windowSize: Int = 100,
         sampleRate: Double = 50.0,
         inferenceHz: Double = 2.0,
         gravityCutoffHz: Double = 0.5,
         minTremorBandG: Double = 0.03) {
        self.windowSize = windowSize
        self.buffer = SampleBuffer(capacity: windowSize)
        self.inferenceStride = max(1, Int((sampleRate / inferenceHz).rounded()))
        // First-order low-pass coefficient for the given cutoff.
        self.gravityAlpha = 1 - exp(-2 * .pi * gravityCutoffHz / sampleRate)
        self.minTremorBandG = minTremorBandG
        self.model = Self.loadModel()
    }

    private static func loadModel() -> MLModel? {
        guard let url = Bundle.main.url(forResource: "TremorClassifier",
                                        withExtension: "mlmodelc") else {
            return nil
        }
        return try? MLModel(contentsOf: url)
    }

    /// Whether the Core ML model was found and loaded.
    var isModelAvailable: Bool { model != nil }

    // MARK: - PredictionServicing

    func consume(_ sample: AccelerometerSample) {
        // 1) Update gravity estimate and remove it -> dynamic acceleration.
        let raw = SIMD3(sample.x, sample.y, sample.z)
        let g: SIMD3<Double>
        if let prev = gravity {
            g = prev + (raw - prev) * gravityAlpha
        } else {
            g = raw // prime on the first sample to avoid a startup transient
        }
        gravity = g
        let dynamic = raw - g

        buffer.append(AccelerometerSample(timestamp: sample.timestamp,
                                          x: dynamic.x, y: dynamic.y, z: dynamic.z))

        // 2) Wait for a full window, then throttle inference.
        guard buffer.isFull else { return }
        samplesSinceInference += 1
        guard samplesSinceInference >= inferenceStride else { return }
        samplesSinceInference = 0

        runInference()
    }

    /// Clears the window and gravity state. Call when streaming stops/restarts.
    func reset() {
        buffer = SampleBuffer(capacity: windowSize)
        gravity = nil
        samplesSinceInference = 0
        latestPrediction = nil
        tremorProbability = nil
        tremorBandG = nil
        isTremor = false
    }

    // MARK: - Inference

    private func runInference() {
        guard let model else {
            latestPrediction = "Model unavailable"
            return
        }

        let window = buffer.snapshot

        // Amplitude gate: ignore the classifier when the wrist is near-steady.
        let bandRMS = TremorFeatures.tremorBandRMS(window: window)
        tremorBandG = bandRMS
        guard bandRMS >= minTremorBandG else {
            isTremor = false
            tremorProbability = 0
            latestPrediction = "No tremor"
            TremorSyncSender.shared.send(probability: 0, isTremor: false)
            return
        }

        let features = TremorFeatures.extract(window: window)
        let inputs = features.mapValues { MLFeatureValue(double: $0) }

        guard let provider = try? MLDictionaryFeatureProvider(dictionary: inputs),
              let output = try? model.prediction(from: provider) else {
            latestPrediction = "Prediction error"
            return
        }

        let label = output.featureValue(for: "tremorLabel")?.stringValue ?? "?"
        let probs = output.featureValue(for: "classProbability")?.dictionaryValue
        let p = probs?["tremor"]?.doubleValue ?? 0

        isTremor = (label == "tremor")
        tremorProbability = p
        let pct = Int(((isTremor ? p : 1 - p) * 100).rounded())
        latestPrediction = isTremor ? "Tremor \(pct)%" : "No tremor \(pct)%"
        TremorSyncSender.shared.send(probability: p, isTremor: isTremor)
    }
}
