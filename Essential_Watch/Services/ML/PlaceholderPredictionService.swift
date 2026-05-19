import Foundation
import Combine

@MainActor
final class PlaceholderPredictionService: ObservableObject, PredictionServicing {

    @Published private(set) var latestPrediction: String?

    private var buffer: SampleBuffer

    init(capacity: Int = 100) {
        self.buffer = SampleBuffer(capacity: capacity)
    }

    func consume(_ sample: AccelerometerSample) {
        buffer.append(sample)
        guard buffer.isFull else { return }
        // TODO: replace with CoreML inference
        latestPrediction = "idle (placeholder)"
    }
}
