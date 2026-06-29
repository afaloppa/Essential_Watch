# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository status

Paired iOS + watchOS app. The **watch app is functional**: it streams wrist
accelerometer data via CoreMotion (50 Hz, Start/Stop UI) and runs an on-device
Core ML model that classifies **essential tremor vs rest** in real time, with a
clean separation between UI, the motion service, and the ML prediction pipeline.

- **Watch target** (`Essential_Watch Watch App/`) — fully wired:
  `MotionManager` (Services/Motion) → `TremorPredictionService` (Services/ML)
  which removes gravity, buffers a 2 s window, extracts features
  (`TremorFeatures`), and runs `TremorClassifier.mlmodel`. `DetectionView` shows
  the live prediction.
- **iOS companion** (`Essential_Watch/`) — still scaffolding; uses
  `PlaceholderPredictionService` and has no model bundled.
- **`ml/`** — offline Python pipeline that produces the model: `prepare_data.py`
  (raw `.mat` → windowed `features.csv`) and `train.py` (RandomForest →
  `TremorClassifier.mlmodel`, ~0.85 leave-one-participant-out accuracy). Run via
  `ml/.venv` (pinned scikit-learn 1.5.1 + coremltools 9). See `ml/README.md`.
- **`Bilateral_tremor_data/`** — clinical source dataset (git-ignored). Described
  in its `Dataset_Description.txt`.

When changing the model, keep `ml/prepare_data.py`'s `window_features()` and the
Swift `TremorFeatures.extract()` numerically identical — the model is trained on
one and fed by the other. Keep new code organized along the original agent
boundaries: `ui-agent` (Views/ViewModels), `sensor-agent` (Services/Motion),
`ml-agent` (Services/ML).

## Project layout

The Xcode project (`Essential_Watch.xcodeproj`) defines **two app targets plus four test targets**:

- `Essential_Watch/` — iOS companion app (TARGETED_DEVICE_FAMILY = "1,2", iOS 26)
- `Essential_Watch Watch App/` — watchOS app, embedded into the iOS app via the "Embed Watch Content" build phase (TARGETED_DEVICE_FAMILY = 4, watchOS 26). This is the primary target.
- `Essential_WatchTests/`, `Essential_Watch Watch AppTests/` — unit tests (Swift Testing framework, `@Test` / `#expect`)
- `Essential_WatchUITests/`, `Essential_Watch Watch AppUITests/` — XCUITest UI tests

Note the directory names containing spaces (`Essential_Watch Watch App`, etc.) — quote paths in shell commands. Both apps currently contain a file literally named `Essential_WatchApp.swift`; when adding watch-specific code, place it under `Essential_Watch Watch App/`, not the iOS target.

## Build / run / test

Use `xcodebuild` from the repo root (or open `Essential_Watch.xcodeproj` in Xcode). Scheme names match the target names.

```sh
# Build the watch app for the simulator
xcodebuild -project Essential_Watch.xcodeproj \
  -scheme "Essential_Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build

# Run all tests for a scheme
xcodebuild -project Essential_Watch.xcodeproj \
  -scheme "Essential_Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  test

# Run a single test (Swift Testing): use -only-testing:<Target>/<Suite>/<testFunc>
xcodebuild test \
  -project Essential_Watch.xcodeproj \
  -scheme "Essential_Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  -only-testing:"Essential_Watch Watch AppTests/Essential_Watch_Watch_AppTests/example"
```

The iOS scheme is `Essential_Watch` with a `platform=iOS Simulator` destination. There is no linter, package manager, or CI configured.

## Conventions worth knowing

- Tests use **Swift Testing** (`import Testing`, `@Test`, `#expect`) — not XCTest. UI tests still use XCTest/XCUIApplication.
- Deployment targets are unusually high (iOS 26 / watchOS 26) — SwiftUI APIs from the latest SDK are available; don't add availability shims for older OSes.
- When implementing the motion pipeline, design the `MotionManager` as an `ObservableObject` / `@Observable` service injected into views so the same service can later feed a CoreML model without UI changes (per `watchos_ai_coder_prompt.md`).
