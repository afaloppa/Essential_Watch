import Foundation
import Combine
import CoreMotion

@MainActor
final class MotionManager: ObservableObject {

    @Published private(set) var isActive: Bool = false
    @Published private(set) var latestSample: AccelerometerSample?

    var onSample: ((AccelerometerSample) -> Void)?

    private let cmManager = CMMotionManager()

    init() {
        cmManager.accelerometerUpdateInterval = 1.0 / 50.0
    }

    func start() throws {
        guard cmManager.isAccelerometerAvailable else {
            throw MotionError.sensorUnavailable
        }
        guard !isActive else {
            throw MotionError.alreadyRunning
        }

        isActive = true
        cmManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if error != nil {
                    self.stop()
                    return
                }
                guard let data else { return }
                let sample = AccelerometerSample(
                    timestamp: data.timestamp,
                    x: data.acceleration.x,
                    y: data.acceleration.y,
                    z: data.acceleration.z
                )
                self.latestSample = sample
                self.onSample?(sample)
            }
        }
    }

    func stop() {
        guard isActive else { return }
        cmManager.stopAccelerometerUpdates()
        isActive = false
    }

    deinit {
        cmManager.stopAccelerometerUpdates()
    }
}
