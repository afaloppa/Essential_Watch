//
//  DetectionViewModel.swift
//  Essential_Watch Watch App
//

import Foundation
import Combine
import SwiftUI

/// View model that coordinates the motion stream and the prediction service
/// for the main detection screen.
///
/// State is read directly from the underlying `ObservableObject` services
/// (kept as `@ObservedObject` from the view's perspective). This VM owns the
/// action logic (start/stop, error surfacing) only.
@MainActor
final class DetectionViewModel: ObservableObject {

    private let motion: MotionManager
    private let prediction: PlaceholderPredictionService

    /// User-facing error message produced by the most recent `start()` attempt.
    /// Cleared when the next `start()` succeeds or when the user stops.
    @Published var errorMessage: String?

    init(motion: MotionManager, prediction: PlaceholderPredictionService) {
        self.motion = motion
        self.prediction = prediction
    }

    var isActive: Bool { motion.isActive }
    var latestSample: AccelerometerSample? { motion.latestSample }
    var latestPrediction: String? { prediction.latestPrediction }

    /// Toggles the motion stream. Errors thrown by `start()` are caught and
    /// exposed via `errorMessage`.
    func toggle() {
        if motion.isActive {
            motion.stop()
            errorMessage = nil
        } else {
            do {
                try motion.start()
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
