# Essential Watch

A paired **iOS + watchOS** app, built in SwiftUI, that streams accelerometer
data from the Apple Watch and runs an **on-device Core ML model that detects
essential tremor** in real time.

The model is trained from clinical OFF-DBS wrist-accelerometer recordings; see
[`ml/README.md`](ml/README.md) for the data-prep and training pipeline.

## Screenshots

| Watch (detecting) | iPhone — no tremor | iPhone — tremor |
|:---:|:---:|:---:|
| <img src="App_screen/Watch_View.PNG" width="200"> | <img src="App_screen/Phone_notremor.PNG" width="200"> | <img src="App_screen/Phone_tremor.PNG" width="200"> |

The watch runs detection; the iPhone mirrors the live tremor likelihood over
WatchConnectivity.

## What it does today

- **Watch app (primary target)**
  - Start / Stop accelerometer streaming via `CoreMotion` (50 Hz)
  - Live `DetectionView` showing motion state and the latest prediction
    (e.g. *"Tremor 87%"* / *"No tremor 92%"*, highlighted when tremor is detected)
  - Real-time tremor detection: gravity removal → 2 s sliding window →
    feature extraction → Core ML classification, a few times per second
  - **Amplitude gate**: windows whose tremor-band (4–12 Hz) acceleration RMS is
    below a small threshold (default 0.03 g) are reported as *No tremor*
    regardless of the classifier, suppressing false positives from sensor noise
    and low-amplitude physiological micro-tremor on a steady hand
  - Clean MVVM split:
    - `Views/` — SwiftUI screens
    - `ViewModels/DetectionViewModel.swift` — UI state
    - `Services/Motion/` — `MotionManager`, `AccelerometerSample`, `MotionError`
    - `Services/ML/` — `PredictionServicing` protocol, `TremorPredictionService`
      (real Core ML inference), `TremorFeatures` (feature extraction),
      `SampleBuffer`, `TremorClassifier.mlmodel`
    - `Services/Sync/` — `TremorSyncSender` (pushes results to the iPhone)
- **iOS companion app** — embeds the watch app via the *Embed Watch Content*
  build phase. A single screen mirrors the watch's live tremor probability (a
  ring + percentage) streamed over **WatchConnectivity**. The phone does **not**
  use its own accelerometer — the model runs on the watch and the phone is a
  read-only display. (Raw 50 Hz accelerometer isn't streamed — WatchConnectivity
  isn't suited to smooth high-rate data — so only the ~2 Hz prediction is sent.)

The architecture is service-oriented: `TremorPredictionService` is injected
behind the `PredictionServicing` protocol, so the model can be retrained or
swapped without touching the views.

> **Note:** real detection requires a physical Apple Watch — the watchOS
> Simulator has no accelerometer, so `MotionManager.start()` reports
> *"Accelerometer not available"* there.

## Project layout

```
Essential_Watch/                   # iOS companion app
Essential_Watch Watch App/         # watchOS app (primary)
  Views/                           # SwiftUI views
  ViewModels/                      # Observable view models
  Services/Motion/                 # CoreMotion capture
  Services/ML/                     # Prediction service + buffering
Essential_Watch.xcodeproj/         # Xcode project (two app + four test targets)
ml/                                # Python pipeline: prepare data + train Core ML model
```

The `ml/` directory holds the offline training pipeline (data prep, training,
exported `.mlmodel`). Heavy artifacts — the raw dataset (`Bilateral_tremor_data/`),
the Python virtualenv (`ml/.venv/`), and the generated `ml/features.csv` — are
git-ignored; only the scripts and the trained model are committed.

## Dataset

The tremor classifier is trained on **"Bilateral tremor measurement in people
with essential tremor under DBS-OFF and DBS-ON conditions"**, an open dataset
from the MRC Brain Network Dynamics Unit, University of Oxford.

- **Source / download:** [data.mrc.ox.ac.uk — bilateral tremor measurement](https://data.mrc.ox.ac.uk/data-set/bilateral-tremor-measurement-people-essential-tremor-under-dbs-and-dbs-conditions)
- Lives locally in `Bilateral_tremor_data/` (git-ignored; see its
  `Dataset_Description.txt`).

**What it contains.** Bilateral wrist-accelerometer recordings from essential-
tremor patients performing a tremor-provoking posture-holding task (arms raised,
~30 s holds alternating with ~30 s rest), captured under two conditions:
continuous high-frequency DBS turned **OFF** and **ON**. Raw data are shared for
8 participants (`cDBS_01`–`cDBS_08`). Each `.mat` (MATLAB v7.3 / HDF5) holds a
6-channel accelerometer matrix (left + right wrist, x/y/z), the sampling rate
(2048 or 4096 Hz), and posture-block markers (`2` = block start, `3` = block end).

**How this project uses it.** Only the **DBS-OFF** recordings are used — that's
the untreated condition where tremor is strongest. Each posture block is labeled
*tremor* and the inter-block gaps *rest*; each wrist is treated as an independent
single-wrist sample (the watch has one accelerometer on one wrist). Full
preprocessing and training details are in [`ml/README.md`](ml/README.md).

**Reference.** He S, et al. *Tremor Asymmetry and the Development of Bilateral
Phase-Specific Deep Brain Stimulation for Postural Tremor.* Movement Disorders,
2025. [doi:10.1002/mds.30275](https://doi.org/10.1002/mds.30275) ·
[PubMed 40546090](https://pubmed.ncbi.nlm.nih.gov/40546090/)

Please cite the dataset and paper above if you use this work, and follow the
dataset's own license/terms from the Oxford data portal.

## Model performance

Evaluated with **leave-one-participant-out (LOPO)** cross-validation — each
patient is held out in turn, so these numbers reflect generalisation to a *new*
patient. Pooled LOPO accuracy is **~0.83** (mean per-patient **~0.85**), ROC
**AUC ≈ 0.93**. The hardest case (cDBS_06) had weak, low-amplitude tremor.

| | |
|:---:|:---:|
| <img src="ml/figures/confusion_matrix.png" width="360"> | <img src="ml/figures/roc_curve.png" width="360"> |
| <img src="ml/figures/per_participant_accuracy.png" width="360"> | <img src="ml/figures/feature_importances.png" width="360"> |

Regenerate after retraining with:

```sh
ml/.venv/bin/python ml/make_figures.py   # writes ml/figures/*.png
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

- ~~Replace `PlaceholderPredictionService` with a real CoreML classifier~~ ✅
- ~~Buffer / windowing logic in `SampleBuffer` for fixed-length inference~~ ✅
- Tremor severity / scoring (regression) in addition to binary detection
- iOS companion: session history & model management
- Replace prototype sphere view with a proper 3D renderer

## License

See [LICENSE](LICENSE).
