"""
train.py
--------
Train a tremor-vs-rest classifier on the windowed features produced by
prepare_data.py, then export it as a Core ML model for the watchOS app.

Evaluation: leave-one-out (LOO) cross-validation, holding out one participant per
fold. Windows from the same person (and from the two wrists of that person) are
correlated, so a random split would leak and inflate accuracy. LOO reports how
well the model generalises to a NEW patient - the realistic deployment scenario.

The final model is then retrained on ALL participants and converted to
TremorClassifier.mlmodel via coremltools.
"""

import os
import json
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
import coremltools as ct

HERE = os.path.dirname(__file__)
FEATURES_CSV = os.path.join(HERE, "features.csv")
MODEL_OUT = os.path.join(HERE, "TremorClassifier.mlmodel")
META_OUT = os.path.join(HERE, "TremorClassifier_metadata.json")

LABELS = ["rest", "tremor"]


def load():
    df = pd.read_csv(FEATURES_CSV)
    meta = ["participant", "wrist", "label"]
    feat_cols = [c for c in df.columns if c not in meta]
    X = df[feat_cols].values.astype(np.float64)
    y = df["label"].values
    groups = df["participant"].values
    return df, X, y, groups, feat_cols


def make_model():
    # class_weight balances the slight tremor/rest imbalance; modest depth keeps
    # the forest small enough to run comfortably on the watch.
    return RandomForestClassifier(
        n_estimators=200,
        max_depth=12,
        min_samples_leaf=4,
        class_weight="balanced",
        random_state=42,
        n_jobs=-1,
    )


def loo_cv(X, y, groups):
    """Leave-one-out cross-validation (one participant held out per fold)."""
    print("=== Leave-One-Out (LOO) CV ===")
    accs = []
    agg_true, agg_pred = [], []
    for pid in sorted(np.unique(groups)):
        test = groups == pid
        train = ~test
        model = make_model()
        model.fit(X[train], y[train])
        pred = model.predict(X[test])
        acc = accuracy_score(y[test], pred)
        accs.append(acc)
        agg_true.extend(y[test])
        agg_pred.extend(pred)
        print(f"  hold-out {pid}: acc={acc:.3f}  (n={test.sum()})")
    print(f"\nMean LOO accuracy: {np.mean(accs):.3f} +/- {np.std(accs):.3f}")
    print("\nPooled confusion matrix (rows=true, cols=pred) [rest, tremor]:")
    print(confusion_matrix(agg_true, agg_pred, labels=LABELS))
    print("\nPooled classification report:")
    print(classification_report(agg_true, agg_pred, labels=LABELS, digits=3))
    return float(np.mean(accs)), float(np.std(accs))


def export_coreml(model, feat_cols, cv_mean, cv_std):
    print("=== Exporting Core ML model ===")
    coreml_model = ct.converters.sklearn.convert(
        model,
        input_features=feat_cols,
        output_feature_names="tremorLabel",
    )
    coreml_model.author = "Essential_Watch ML pipeline"
    coreml_model.short_description = (
        "Essential-tremor vs rest classifier from 2 s of 50 Hz wrist "
        "userAcceleration (dynamic, gravity removed). Trained on OFF-DBS data "
        "(He et al. 2025, MDS bilateral-tremor dataset)."
    )
    for c in feat_cols:
        coreml_model.input_description[c] = f"window feature: {c}"
    coreml_model.user_defined_metadata["loo_cv_accuracy"] = f"{cv_mean:.4f}"
    coreml_model.user_defined_metadata["loo_cv_std"] = f"{cv_std:.4f}"
    coreml_model.user_defined_metadata["window_seconds"] = "2.0"
    coreml_model.user_defined_metadata["sample_rate_hz"] = "50"
    coreml_model.user_defined_metadata["input_signal"] = "userAcceleration (g)"
    coreml_model.save(MODEL_OUT)
    print(f"Saved -> {MODEL_OUT}")


def main():
    df, X, y, groups, feat_cols = load()
    print(f"Loaded {len(df)} windows, {len(feat_cols)} features, "
          f"{len(np.unique(groups))} participants.\n")

    cv_mean, cv_std = loo_cv(X, y, groups)

    print("\n=== Training final model on all data ===")
    final = make_model()
    final.fit(X, y)

    # Feature importances (handy for trimming the Swift feature set later).
    imp = sorted(zip(feat_cols, final.feature_importances_),
                 key=lambda t: -t[1])
    print("Top feature importances:")
    for name, val in imp[:8]:
        print(f"  {name:22s} {val:.3f}")

    export_coreml(final, feat_cols, cv_mean, cv_std)

    with open(META_OUT, "w") as f:
        json.dump({
            "features": feat_cols,
            "labels": LABELS,
            "window_seconds": 2.0,
            "sample_rate_hz": 50,
            "input_signal": "userAcceleration (g), gravity removed",
            "loo_cv_accuracy": cv_mean,
            "loo_cv_std": cv_std,
            "feature_importances": {n: float(v) for n, v in imp},
        }, f, indent=2)
    print(f"Saved -> {META_OUT}")


if __name__ == "__main__":
    main()
