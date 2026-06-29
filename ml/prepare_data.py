"""
prepare_data.py
---------------
Turn the raw OFF-DBS bilateral-tremor recordings into a windowed feature table
that can train a tremor-vs-rest classifier for the Apple Watch.

Pipeline (per participant, per wrist):
  1. Read the MATLAB v7.3 (HDF5) Posture_off.mat  -> 3-axis accelerometer + markers.
  2. Calibrate raw ADC counts -> g, using gravity as the 1-g reference.
  3. Remove gravity / drift with a high-pass filter -> dynamic acceleration (g),
     i.e. the same quantity CoreMotion exposes as `userAcceleration`.
  4. Anti-alias resample to 50 Hz (the watch sampling rate).
  5. Slide a 2 s window (1 s step) over the signal and label each window using the
     posture-block markers (2 = block start, 3 = block end):
         - inside a block            -> "tremor"
         - outside every block (+guard) -> "rest"
         - straddling / near an edge -> dropped
  6. Extract a small set of spectral + time-domain features per window.

Output: ml/features.csv  (one row per window).

Design notes
  * Wrists are treated as INDEPENDENT single-wrist samples (left xyz, right xyz),
    because the watch has one tri-axial accelerometer on one wrist.
  * cDBS_03 only has x/y channels (no z) and is skipped - we need 3 axes.
  * Recordings are 2048 Hz (most) or 4096 Hz (cDBS_07/08); both resample to 50 Hz.
  * The discriminative features (band-power ratio, dominant frequency, spectral
    entropy) are scale-invariant, so the model transfers despite the ADC->g
    calibration being only approximate.
"""

import os
import glob
import numpy as np
import pandas as pd
import h5py
from scipy import signal

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
DATA_DIR = os.path.join(os.path.dirname(__file__), "..", "Bilateral_tremor_data")
OUT_CSV = os.path.join(os.path.dirname(__file__), "features.csv")

TARGET_FS = 50.0        # Hz - Apple Watch CoreMotion target rate
WINDOW_S = 2.0          # window length in seconds
STEP_S = 1.0            # hop between windows (50% overlap)
GUARD_S = 3.0           # ignore rest windows within this margin of a block edge
GRAVITY_LP_HZ = 0.5     # low-pass cutoff used to estimate the gravity vector
HIGHPASS_HZ = 0.7       # high-pass cutoff to remove gravity/drift -> dynamic accel
TREMOR_BAND = (4.0, 12.0)   # essential-tremor frequency band (Hz)
ANALYSIS_BAND = (1.0, 24.0)  # band used for "total" power / spectral stats

WRISTS = {
    "left":  ["Aclx", "Acly", "Aclz"],
    "right": ["Acrx", "Acry", "Acrz"],
}


# ----------------------------------------------------------------------------
# .mat loading helpers (MATLAB v7.3 == HDF5)
# ----------------------------------------------------------------------------
def _decode_str(h5, dataset):
    arr = np.array(dataset).flatten()
    return "".join(chr(c) for c in arr if c != 0)


def load_recording(mat_path):
    """Return dict with fs, channel names, data [N,nch], and block intervals [s]."""
    with h5py.File(mat_path, "r") as h:
        s = h["SmrData"]
        fs = float(np.array(s["SR"]).ravel()[0])
        names = [_decode_str(h, h[ref]) for ref in np.array(s["WvTits"]).ravel()]
        data = np.array(s["WvData"])               # [N, nch]
        marker_vals = np.array(s["markerData"]).ravel().astype(int)
        marker_t = np.array(s["markerTime"]).ravel().astype(float)

    # Build posture-block intervals from (2 -> 3) marker pairs.
    blocks = []
    pending_start = None
    for v, t in zip(marker_vals, marker_t):
        if v == 2:
            pending_start = t
        elif v == 3 and pending_start is not None:
            blocks.append((pending_start, t))
            pending_start = None
    return {"fs": fs, "names": names, "data": data, "blocks": blocks}


# ----------------------------------------------------------------------------
# Signal conditioning
# ----------------------------------------------------------------------------
def to_dynamic_g(xyz, fs):
    """ADC counts [N,3] -> dynamic acceleration in g (gravity & drift removed).

    Gravity calibration: the low-passed 3-axis vector magnitude is dominated by
    gravity, whose true magnitude is 1 g, so its median gives ADC counts per g.
    """
    xyz = xyz.astype(float)

    # 1) Estimate gravity vector with a low-pass filter, derive ADC-per-g.
    b_lp, a_lp = signal.butter(2, GRAVITY_LP_HZ / (fs / 2.0), btype="low")
    gravity = signal.filtfilt(b_lp, a_lp, xyz, axis=0)
    g_ref = np.median(np.linalg.norm(gravity, axis=1))
    if not np.isfinite(g_ref) or g_ref <= 0:
        g_ref = np.std(xyz)  # degenerate fallback

    xyz_g = xyz / g_ref

    # 2) High-pass to remove gravity/orientation drift -> userAcceleration-like.
    b_hp, a_hp = signal.butter(2, HIGHPASS_HZ / (fs / 2.0), btype="high")
    dyn = signal.filtfilt(b_hp, a_hp, xyz_g, axis=0)
    return dyn


def resample_to_target(xyz, fs):
    """Anti-aliased resample [N,3] from fs to TARGET_FS."""
    if abs(fs - TARGET_FS) < 1e-6:
        return xyz
    g = np.gcd(int(round(fs)), int(TARGET_FS))
    up = int(TARGET_FS) // g
    down = int(round(fs)) // g
    return signal.resample_poly(xyz, up, down, axis=0)


# ----------------------------------------------------------------------------
# Feature extraction (per 3-axis window at TARGET_FS)
# ----------------------------------------------------------------------------
def _spectrum(sig1d, fs):
    """One-sided power spectrum of a Hann-windowed 1-D signal."""
    n = len(sig1d)
    w = np.hanning(n)
    sig1d = (sig1d - sig1d.mean()) * w
    P = np.abs(np.fft.rfft(sig1d)) ** 2
    f = np.fft.rfftfreq(n, 1.0 / fs)
    return f, P


def _band_power(f, P, lo, hi):
    m = (f >= lo) & (f < hi)
    return float(P[m].sum())


def _spectral_feats(sig1d, fs):
    """Scale-relevant + scale-invariant spectral features of one axis/magnitude."""
    f, P = _spectrum(sig1d, fs)
    ana = (f >= ANALYSIS_BAND[0]) & (f < ANALYSIS_BAND[1])
    total = float(P[ana].sum()) + 1e-12
    tremor = _band_power(f, P, *TREMOR_BAND)
    band_ratio = tremor / total
    # dominant frequency within the analysis band
    if ana.any():
        dom_freq = float(f[ana][np.argmax(P[ana])])
        peak_power = float(P[ana].max())
    else:
        dom_freq, peak_power = 0.0, 0.0
    # spectral entropy (normalised, within analysis band)
    p = P[ana] / total
    p = p[p > 0]
    spec_entropy = float(-(p * np.log(p)).sum() / np.log(len(p))) if len(p) > 1 else 0.0
    # spectral centroid
    centroid = float((f[ana] * P[ana]).sum() / total) if ana.any() else 0.0
    return {
        "band_ratio": band_ratio,
        "dom_freq": dom_freq,
        "peak_power": peak_power,
        "total_power": total,
        "spec_entropy": spec_entropy,
        "spec_centroid": centroid,
    }


def window_features(win, fs):
    """Features for one [W,3] window of dynamic acceleration (g)."""
    x, y, z = win[:, 0], win[:, 1], win[:, 2]
    mag = np.sqrt((win ** 2).sum(axis=1))

    feats = {}
    # Magnitude spectral features (orientation-independent).
    m = _spectral_feats(mag, fs)
    feats.update({f"mag_{k}": v for k, v in m.items()})
    # Time-domain on magnitude.
    feats["mag_rms"] = float(np.sqrt(np.mean(mag ** 2)))
    feats["mag_std"] = float(np.std(mag))
    mz = mag - mag.mean()
    feats["mag_zcr"] = float(np.mean(np.abs(np.diff(np.sign(mz))) > 0))

    # Per-axis: band ratio + rms (compact orientation cues).
    ratios = []
    for name, axis in (("x", x), ("y", y), ("z", z)):
        sf = _spectral_feats(axis, fs)
        feats[f"{name}_band_ratio"] = sf["band_ratio"]
        feats[f"{name}_rms"] = float(np.sqrt(np.mean(axis ** 2)))
        ratios.append(sf["band_ratio"])
    feats["max_axis_band_ratio"] = float(np.max(ratios))
    feats["mean_axis_band_ratio"] = float(np.mean(ratios))
    return feats


# ----------------------------------------------------------------------------
# Window labelling
# ----------------------------------------------------------------------------
def label_window(t0, t1, blocks):
    """Return 'tremor', 'rest', or None (drop) for a window spanning [t0,t1]."""
    for b0, b1 in blocks:
        if t0 >= b0 and t1 <= b1:
            return "tremor"
    for b0, b1 in blocks:
        # overlaps a block or its guard margin -> ambiguous, drop
        if not (t1 <= b0 - GUARD_S or t0 >= b1 + GUARD_S):
            return None
    return "rest"


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def process_participant(folder):
    pid = os.path.basename(folder)
    mat = os.path.join(folder, "Posture_off.mat")
    if not os.path.exists(mat):
        print(f"  [skip] {pid}: no Posture_off.mat")
        return []

    rec = load_recording(mat)
    rows = []
    win_n = int(round(WINDOW_S * TARGET_FS))
    step_n = int(round(STEP_S * TARGET_FS))

    for wrist, chans in WRISTS.items():
        if not all(c in rec["names"] for c in chans):
            print(f"  [skip] {pid} {wrist}: missing channels (have {rec['names']})")
            continue
        idx = [rec["names"].index(c) for c in chans]
        raw = rec["data"][:, idx]

        dyn = to_dynamic_g(raw, rec["fs"])
        dyn = resample_to_target(dyn, rec["fs"])

        n = dyn.shape[0]
        n_tremor = n_rest = 0
        for start in range(0, n - win_n + 1, step_n):
            t0 = start / TARGET_FS
            t1 = (start + win_n) / TARGET_FS
            label = label_window(t0, t1, rec["blocks"])
            if label is None:
                continue
            feats = window_features(dyn[start:start + win_n], TARGET_FS)
            feats["participant"] = pid
            feats["wrist"] = wrist
            feats["label"] = label
            rows.append(feats)
            n_tremor += label == "tremor"
            n_rest += label == "rest"
        print(f"  {pid} {wrist}: tremor={n_tremor} rest={n_rest} "
              f"(fs={rec['fs']:.0f}Hz, blocks={len(rec['blocks'])})")
    return rows


def main():
    folders = sorted(glob.glob(os.path.join(DATA_DIR, "cDBS_*")))
    all_rows = []
    for folder in folders:
        print(f"Processing {os.path.basename(folder)} ...")
        all_rows.extend(process_participant(folder))

    df = pd.DataFrame(all_rows)
    # Stable column order: features first, metadata last.
    meta = ["participant", "wrist", "label"]
    feat_cols = [c for c in df.columns if c not in meta]
    df = df[feat_cols + meta]
    df.to_csv(OUT_CSV, index=False)

    print("\n=== Summary ===")
    print(f"Total windows: {len(df)}")
    print(df["label"].value_counts().to_string())
    print(f"Participants: {sorted(df['participant'].unique())}")
    print(f"Feature columns ({len(feat_cols)}): {feat_cols}")
    print(f"Saved -> {OUT_CSV}")


if __name__ == "__main__":
    main()
