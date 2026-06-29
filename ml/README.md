# Tremor-detection ML pipeline

Trains a **tremor vs rest** classifier for the watchOS app from the OFF-DBS
bilateral-tremor recordings in `../Bilateral_tremor_data/`.

**Dataset:** "Bilateral tremor measurement in people with essential tremor under
DBS-OFF and DBS-ON conditions", MRC Brain Network Dynamics Unit, University of
Oxford — [data.mrc.ox.ac.uk](https://data.mrc.ox.ac.uk/data-set/bilateral-tremor-measurement-people-essential-tremor-under-dbs-and-dbs-conditions).

**Reference:** He S, et al. *Tremor Asymmetry and the Development of Bilateral
Phase-Specific Deep Brain Stimulation for Postural Tremor.* Movement Disorders,
2025. [doi:10.1002/mds.30275](https://doi.org/10.1002/mds.30275).

## What it produces

| File | Description |
|------|-------------|
| `features.csv` | One row per 2 s window: 17 features + participant/wrist/label (gitignored) |
| `TremorClassifier.mlmodel` | Core ML model — drop into the Xcode watch target |
| `TremorClassifier_metadata.json` | Feature list, label order, CV accuracy, feature importances |

## Run it

```sh
# one-time setup (isolated env; sklearn 1.5.1 is required by coremltools 9)
python3 -m venv ml/.venv
ml/.venv/bin/pip install "scikit-learn==1.5.1" "coremltools==9.0" "numpy<2" scipy pandas h5py matplotlib

# build the dataset, then train + export
ml/.venv/bin/python ml/prepare_data.py
ml/.venv/bin/python ml/train.py

# (optional) regenerate the README figures into ml/figures/
ml/.venv/bin/python ml/make_figures.py
```

## Design decisions

- **Task:** binary classification, `tremor` vs `rest`.
- **Labels:** posture-hold blocks (markers `2`→`3`) = tremor; gaps (with a 3 s
  guard around edges) = rest. Validated by FFT: posture peaks at ~8–9 Hz, rest
  at ~1 Hz.
- **Wrists:** left (`Acl*`) and right (`Acr*`) treated as independent
  single-wrist samples, matching one watch on one wrist.
- **Sample rate:** all recordings (2048 / 4096 Hz) resampled to **50 Hz**.
- **Signal:** ADC counts → g (gravity used as the 1 g reference) → high-pass to
  remove gravity/drift. This yields `userAcceleration`-equivalent dynamic
  acceleration, the same quantity CoreMotion gives on the watch.
- **Windows:** 2 s (100 samples), 1 s hop (50 % overlap).
- **cDBS_03 skipped** — only x/y channels, no z. cDBS_09 has no shared data.
- **Model:** RandomForest (200 trees, depth 12), `class_weight="balanced"`.

## Performance

Leave-One-Participant-Out CV: **~0.85 mean accuracy** (generalisation to a new
patient). Per-patient range 0.58–0.97 — the hardest patient (cDBS_06) had
weaker/low-amplitude tremor. Top features are amplitude-based (`z_rms`, `y_rms`,
`mag_rms`), consistent with tremor being a large oscillation, plus tremor-band
spectral ratios.

## Deploying on the watch — already wired

The `.mlmodel` takes the **17 features**, not raw accelerometer samples. The
watch app reproduces the exact feature pipeline in Swift before each prediction:

- `TremorClassifier.mlmodel` is bundled at
  `Essential_Watch Watch App/Services/ML/` (Xcode compiles it to `.mlmodelc`).
- `TremorPredictionService.swift` removes gravity (streaming low-pass), buffers a
  2 s window (`SampleBuffer`), and runs inference a few times per second.
- `TremorFeatures.swift` is a line-for-line port of `window_features()` here.
  It is verified numerically identical to this script (max relative diff ~1e-15
  on a shared test window) — **if you change features in `prepare_data.py`, mirror
  the change in `TremorFeatures.swift` or predictions will be garbage.**

To re-import a retrained model, just overwrite the bundled `.mlmodel` with the
freshly produced `ml/TremorClassifier.mlmodel`.

> Note: on the watch, gravity is removed with a streaming low-pass filter rather
> than the offline zero-phase filter used here, and acceleration is already in g
> (no ADC→g calibration needed). Amplitude features (RMS) are the most
> influential, so if on-device accuracy is lower than CV suggests, lean on the
> scale-invariant spectral features (band ratio, dominant frequency, entropy).
