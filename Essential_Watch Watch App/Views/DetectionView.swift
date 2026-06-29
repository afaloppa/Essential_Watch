//
//  DetectionView.swift
//  Essential_Watch Watch App
//

import SwiftUI

/// Main screen: shows live detection status, a start/stop toggle, and the
/// current prediction emitted by the prediction service.
struct DetectionView: View {
    @EnvironmentObject private var motion: MotionManager
    @EnvironmentObject private var prediction: TremorPredictionService

    @StateObject private var viewModel: DetectionViewModel

    init(motion: MotionManager, prediction: TremorPredictionService) {
        _viewModel = StateObject(
            wrappedValue: DetectionViewModel(motion: motion, prediction: prediction)
        )
    }

    var body: some View {
        VStack(spacing: 10) {
            StatusIndicator(isActive: motion.isActive)

            Button(action: { viewModel.toggle() }) {
                Text(motion.isActive ? "Stop" : "Start")
                    .frame(maxWidth: .infinity)
            }
            .tint(motion.isActive ? .red : .green)
            .buttonStyle(.borderedProminent)

            Text(prediction.latestPrediction ?? "—")
                .font(.footnote)
                .fontWeight(prediction.isTremor ? .semibold : .regular)
                .foregroundStyle(prediction.isTremor ? Color.orange : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 4)
    }
}

/// Convenience wrapper that pulls services from the environment and forwards
/// them to `DetectionView`'s injecting initializer.
struct DetectionScreen: View {
    @EnvironmentObject private var motion: MotionManager
    @EnvironmentObject private var prediction: TremorPredictionService

    var body: some View {
        DetectionView(motion: motion, prediction: prediction)
    }
}

#Preview {
    let motion = MotionManager()
    let prediction = TremorPredictionService()
    return DetectionView(motion: motion, prediction: prediction)
        .environmentObject(motion)
        .environmentObject(prediction)
}
