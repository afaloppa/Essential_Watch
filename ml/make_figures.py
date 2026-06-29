"""
make_figures.py
---------------
Generate model-statistics figures for the README. Run AFTER train.py:

    ml/.venv/bin/python ml/prepare_data.py
    ml/.venv/bin/python ml/train.py
    ml/.venv/bin/python ml/make_figures.py

Produces (in ml/figures/):
  - confusion_matrix.png      pooled leave-one-out (LOO) confusion
  - per_participant_accuracy.png
  - roc_curve.png             pooled LOO ROC + AUC with a 95% bootstrap CI band
  - feature_importances.png   RandomForest importances (model trained on all data)

LOO = leave-one-out cross-validation: each participant is held out in turn, the
model trains on the rest, and predictions are pooled. This reflects the realistic
"new patient" scenario.
"""

import os
import numpy as np
import matplotlib

matplotlib.use("Agg")  # headless
import matplotlib.pyplot as plt
from sklearn.metrics import confusion_matrix, accuracy_score, roc_curve, auc, roc_auc_score

# Reuse the exact data loader + model from the training script.
from train import load, make_model, LABELS

HERE = os.path.dirname(__file__)
FIG_DIR = os.path.join(HERE, "figures")

ACCENT = "#E8833A"   # tremor (orange, matches the app)
REST = "#3FA34D"     # rest (green, matches the app)

N_BOOTSTRAP = 2000
RNG = np.random.default_rng(42)


def run_loo(X, y, groups):
    """Pooled leave-one-out predictions, probabilities, and per-participant acc."""
    true, pred, prob = [], [], []
    per_participant = {}
    for pid in sorted(np.unique(groups)):
        test, train = groups == pid, groups != pid
        model = make_model()
        model.fit(X[train], y[train])
        p_label = model.predict(X[test])
        p_prob = model.predict_proba(X[test])[:, list(model.classes_).index("tremor")]
        true.extend(y[test]); pred.extend(p_label); prob.extend(p_prob)
        per_participant[pid] = accuracy_score(y[test], p_label)
    return np.array(true), np.array(pred), np.array(prob), per_participant


def auc_with_ci(y_bin, prob):
    """Point AUC plus a percentile bootstrap 95% confidence interval."""
    point = roc_auc_score(y_bin, prob)
    n = len(y_bin)
    scores = []
    for _ in range(N_BOOTSTRAP):
        idx = RNG.integers(0, n, n)
        # Skip degenerate resamples that contain a single class.
        if len(np.unique(y_bin[idx])) < 2:
            continue
        scores.append(roc_auc_score(y_bin[idx], prob[idx]))
    lo, hi = np.percentile(scores, [2.5, 97.5])
    return point, lo, hi


def fig_confusion(true, pred):
    cm = confusion_matrix(true, pred, labels=LABELS)
    cm_norm = cm / cm.sum(axis=1, keepdims=True)
    fig, ax = plt.subplots(figsize=(4.6, 4.0))
    im = ax.imshow(cm_norm, cmap="Oranges", vmin=0, vmax=1)
    ax.set_xticks(range(len(LABELS)), LABELS)
    ax.set_yticks(range(len(LABELS)), LABELS)
    ax.set_xlabel("Predicted"); ax.set_ylabel("True")
    ax.set_title("Confusion matrix (pooled LOO)")
    for i in range(len(LABELS)):
        for j in range(len(LABELS)):
            ax.text(j, i, f"{cm[i, j]}\n{cm_norm[i, j]:.0%}",
                    ha="center", va="center",
                    color="white" if cm_norm[i, j] > 0.5 else "black", fontsize=11)
    fig.colorbar(im, fraction=0.046, pad=0.04)
    _save(fig, "confusion_matrix.png")


def fig_per_participant(per_participant):
    pids = list(per_participant.keys())
    accs = [per_participant[p] for p in pids]
    fig, ax = plt.subplots(figsize=(6.2, 3.6))
    bars = ax.bar(pids, accs, color=ACCENT)
    mean = float(np.mean(accs))
    ax.axhline(mean, ls="--", color="gray", lw=1)
    ax.text(len(pids) - 0.5, mean + 0.01, f"mean {mean:.0%}",
            ha="right", color="gray", fontsize=9)
    ax.set_ylim(0, 1.05); ax.set_ylabel("Held-out accuracy")
    ax.set_title("Leave-one-out accuracy")
    for b, a in zip(bars, accs):
        ax.text(b.get_x() + b.get_width() / 2, a + 0.01, f"{a:.0%}",
                ha="center", fontsize=8)
    plt.xticks(rotation=30, ha="right")
    _save(fig, "per_participant_accuracy.png")


def fig_roc(true, prob):
    y_bin = (true == "tremor").astype(int)
    fpr, tpr, _ = roc_curve(y_bin, prob)
    point, lo, hi = auc_with_ci(y_bin, prob)

    # Bootstrap a confidence band for the ROC curve itself.
    mean_fpr = np.linspace(0, 1, 100)
    n = len(y_bin)
    tprs = []
    for _ in range(N_BOOTSTRAP):
        idx = RNG.integers(0, n, n)
        if len(np.unique(y_bin[idx])) < 2:
            continue
        bf, bt, _ = roc_curve(y_bin[idx], prob[idx])
        interp = np.interp(mean_fpr, bf, bt)
        interp[0] = 0.0
        tprs.append(interp)
    tpr_lo = np.percentile(tprs, 2.5, axis=0)
    tpr_hi = np.percentile(tprs, 97.5, axis=0)

    fig, ax = plt.subplots(figsize=(4.6, 4.2))
    ax.fill_between(mean_fpr, tpr_lo, tpr_hi, color=ACCENT, alpha=0.25,
                    label="95% CI")
    ax.plot(fpr, tpr, color=ACCENT, lw=2,
            label=f"AUC = {point:.3f}\n(95% CI {lo:.3f}–{hi:.3f})")
    ax.plot([0, 1], [0, 1], ls="--", color="gray", lw=1)
    ax.set_xlabel("False positive rate"); ax.set_ylabel("True positive rate")
    ax.set_title("ROC — tremor vs rest (pooled LOO)")
    ax.legend(loc="lower right", fontsize=9)
    _save(fig, "roc_curve.png")
    return point, lo, hi


def fig_importances(X, y, feat_cols):
    model = make_model(); model.fit(X, y)
    order = np.argsort(model.feature_importances_)
    names = np.array(feat_cols)[order]
    vals = model.feature_importances_[order]
    fig, ax = plt.subplots(figsize=(6.2, 5.2))
    colors = [ACCENT if "rms" in n or "power" in n else REST for n in names]
    ax.barh(names, vals, color=colors)
    ax.set_xlabel("Importance")
    ax.set_title("RandomForest feature importances")
    fig.text(0.62, 0.18, "orange: amplitude/power\ngreen: spectral shape",
             fontsize=8, color="gray")
    _save(fig, "feature_importances.png")


def _save(fig, name):
    fig.tight_layout()
    path = os.path.join(FIG_DIR, name)
    fig.savefig(path, dpi=130)
    plt.close(fig)
    print(f"  saved {path}")


def main():
    os.makedirs(FIG_DIR, exist_ok=True)
    _, X, y, groups, feat_cols = load()
    print("Running LOO for figures ...")
    true, pred, prob, per_participant = run_loo(X, y, groups)
    fig_confusion(true, pred)
    fig_per_participant(per_participant)
    point, lo, hi = fig_roc(true, prob)
    fig_importances(X, y, feat_cols)
    print(f"\nPooled LOO accuracy: {accuracy_score(true, pred):.3f}")
    print(f"Pooled LOO AUC:      {point:.3f} (95% CI {lo:.3f}–{hi:.3f})")


if __name__ == "__main__":
    main()
