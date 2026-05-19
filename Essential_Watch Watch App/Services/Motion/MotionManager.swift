import Foundation
import Combine
import CoreMotion

/// Streams accelerometer samples from the watch at a fixed rate suitable for
/// activity detection and on-device ML inference.
///
/// The manager publishes the most recent sample for SwiftUI consumers and also
/// forwards every sample via the `onSample` closure for pipelines that need the
/// full stream (e.g., feeding a Core ML model).
@MainActor
final class MotionManager: ObservableObject {

    /// Whether the manager is currently receiving accelerometer updates.
    @Published private(set) var isActive: Bool = false

    /// The most recently observed accelerometer sample, or `nil` if none yet.
    @Published private(set) var latestSample: AccelerometerSample?

    /// Closure invoked on the main actor for every sample produced while active.
    var onSample: ((AccelerometerSample) -> Void)?

    private let cmManager = CMMotionManager()

    /// Creates a manager configured for 50 Hz accelerometer streaming.
    init() {
        cmManager.accelerometerUpdateInterval = 1.0 / 50.0
    }

    /// Begins accelerometer streaming at 50 Hz.
    ///
    /// - Throws: `MotionError.sensorUnavailable` if the device lacks an
    ///   accelerometer, or `MotionError.alreadyRunning` if streaming is already
    ///   in progress.
    func start() throws {
        guard cmManager.isAccelerometerAvailable else {
            throw MotionError.sensorUnavailable
        }
        guard !isActive else {
            throw MotionError.alreadyRunning
        }

        isActive = true
        cmManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            // Handler is dispatched on the main queue, so it's safe to hop to the
            // main actor without re-dispatching.
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

    /// Stops accelerometer streaming. Safe to call repeatedly.
    func stop() {
        guard isActive else { return }
        cmManager.stopAccelerometerUpdates()
        isActive = false
    }

    deinit {
        // Can't touch @MainActor state from a synchronous deinit, but stopping
        // the underlying CMMotionManager is thread-safe.
        cmManager.stopAccelerometerUpdates()
    }
}
