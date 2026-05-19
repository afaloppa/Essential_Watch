import Foundation
import Combine
import SwiftUI

@MainActor
final class DetectionViewModel: ObservableObject {

    private let motion: MotionManager
    private let prediction: PlaceholderPredictionService

    @Published var errorMessage: String?

    init(motion: MotionManager, prediction: PlaceholderPredictionService) {
        self.motion = motion
        self.prediction = prediction
    }

    var isActive: Bool { motion.isActive }
    var latestSample: AccelerometerSample? { motion.latestSample }
    var latestPrediction: String? { prediction.latestPrediction }

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
