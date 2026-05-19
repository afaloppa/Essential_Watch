import Foundation

enum MotionError: LocalizedError {
    case sensorUnavailable
    case authorizationDenied
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .sensorUnavailable:
            return "Accelerometer not available on this device."
        case .authorizationDenied:
            return "Motion access was denied. Enable it in Settings."
        case .alreadyRunning:
            return "Detection is already running."
        }
    }
}
