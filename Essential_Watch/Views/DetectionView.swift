import SwiftUI

struct DetectionView: View {
    @EnvironmentObject private var motion: MotionManager
    @EnvironmentObject private var prediction: PlaceholderPredictionService

    @StateObject private var viewModel: DetectionViewModel

    init(motion: MotionManager, prediction: PlaceholderPredictionService) {
        _viewModel = StateObject(
            wrappedValue: DetectionViewModel(motion: motion, prediction: prediction)
        )
    }

    var body: some View {
        VStack(spacing: 24) {
            StatusIndicator(isActive: motion.isActive)

            if let sample = motion.latestSample {
                VStack(spacing: 4) {
                    Text(String(format: "x: %+.3f g", sample.x))
                    Text(String(format: "y: %+.3f g", sample.y))
                    Text(String(format: "z: %+.3f g", sample.z))
                }
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
            }

            Button(action: { viewModel.toggle() }) {
                Text(motion.isActive ? "Stop" : "Start")
                    .frame(maxWidth: 220)
                    .padding(.vertical, 8)
            }
            .tint(motion.isActive ? .red : .green)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(prediction.latestPrediction ?? "—")
                .font(.headline)
                .foregroundStyle(.primary)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
    }
}

#Preview {
    let motion = MotionManager()
    let prediction = PlaceholderPredictionService()
    return DetectionView(motion: motion, prediction: prediction)
        .environmentObject(motion)
        .environmentObject(prediction)
}
