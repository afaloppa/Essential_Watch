# Essential Watch

A paired **iOS + watchOS** app, built in SwiftUI, that streams accelerometer
data from the Apple Watch and is being wired up as the front-end for an
on-device motion-classification ML pipeline.

This repo is still early-stage: the motion capture path and UI scaffolding
are in place, but the prediction service is a placeholder.

## What it does today

- **Watch app (primary target)**
  - Start / Stop accelerometer streaming via `CoreMotion`
  - Live `DetectionView` showing motion state and a status indicator
  - Experimental `MotionSphereView` 3D-ish visualization (swipeable page)
  - Clean MVVM split:
    - `Views/` — SwiftUI screens
    - `ViewModels/DetectionViewModel.swift` — UI state
    - `Services/Motion/` — `MotionManager`, `AccelerometerSample`, `MotionError`
    - `Services/ML/` — `PredictionServicing` protocol + `PlaceholderPredictionService` + `SampleBuffer`
- **iOS companion app** — scaffolded shell that embeds the watch app via the
  *Embed Watch Content* build phase. No companion features yet.

The architecture is intentionally service-oriented so the placeholder
prediction service can later be swapped for a real CoreML model without
touching the views.

## Project layout

```
Essential_Watch/                   # iOS companion app
Essential_Watch Watch App/         # watchOS app (primary)
  Views/                           # SwiftUI views
  ViewModels/                      # Observable view models
  Services/Motion/                 # CoreMotion capture
  Services/ML/                     # Prediction service + buffering
Essential_Watch.xcodeproj/         # Xcode project (two app + four test targets)
```

## Build & run

Open `Essential_Watch.xcodeproj` in Xcode and run the **Essential_Watch Watch App**
scheme on a watchOS simulator, or from the command line:

```sh
xcodebuild -project Essential_Watch.xcodeproj \
  -scheme "Essential_Watch Watch App" \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 10 (46mm)' \
  build
```

Tests use **Swift Testing** (`@Test` / `#expect`); UI tests use XCUITest.

Deployment targets are iOS 26 / watchOS 26 — latest-SDK SwiftUI APIs only.

## Roadmap

- Replace `PlaceholderPredictionService` with a real CoreML classifier
- Buffer / windowing logic in `SampleBuffer` for fixed-length inference
- iOS companion: session history & model management
- Replace prototype sphere view with a proper 3D renderer

## License

See [LICENSE](LICENSE).
