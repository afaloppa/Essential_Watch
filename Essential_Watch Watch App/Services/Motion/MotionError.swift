import Foundation

/// Errors emitted by motion-related services when streaming cannot start or continue.
enum MotionError: LocalizedError {
    /// The required motion sensor is not available on this device.
    case sensorUnavailable
    /// The user (or system) has denied access to motion data.
    case authorizationDenied
    /// `start()` was invoked while a streaming session is already active.
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .sensorUnavailable:
            // Most common cause on the watchOS Simulator, which has no accelerometer.
            return "Accelerometer not available on this device."
        case .authorizationDenied:
            return "Motion access was denied. Enable it in Settings."
        case .alreadyRunning:
            return "Detection is already running."
        }
    }
}
