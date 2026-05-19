import Foundation

/// A single accelerometer reading captured from the watch's motion sensor.
///
/// Values are expressed in units of gravitational acceleration (g) along the
/// device's three body axes, paired with the sensor timestamp that produced them.
struct AccelerometerSample: Sendable {
    /// Sensor timestamp (seconds since device boot) reported by CoreMotion.
    let timestamp: TimeInterval
    /// Acceleration along the device's X axis, in g's.
    let x: Double
    /// Acceleration along the device's Y axis, in g's.
    let y: Double
    /// Acceleration along the device's Z axis, in g's.
    let z: Double
}
