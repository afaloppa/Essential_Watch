import Foundation

@MainActor
protocol PredictionServicing: AnyObject {
    func consume(_ sample: AccelerometerSample)
    var latestPrediction: String? { get }
}
