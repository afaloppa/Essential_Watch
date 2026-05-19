import Foundation

struct AccelerometerSample: Sendable {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double
}
