//
//  TremorFeatures.swift
//  Essential_Watch Watch App
//
//  Computes the 17-element feature vector consumed by `TremorClassifier.mlmodel`.
//
//  This is the on-device port of `window_features()` in `ml/prepare_data.py`.
//  It MUST stay numerically aligned with that script — the model was trained on
//  features produced there. Input is a window of *dynamic* acceleration in g
//  (gravity already removed; see `TremorPredictionService`).
//

import Foundation

/// Stateless feature extractor mirroring `ml/prepare_data.py`.
enum TremorFeatures {

    /// Sampling rate of the incoming window, in Hz. Matches `MotionManager`.
    static let sampleRate: Double = 50.0

    /// Essential-tremor frequency band (Hz). Half-open to match the
    /// `(f >= 4) & (f < 12)` mask in `ml/prepare_data.py`.
    static let tremorBand: Range<Double> = 4.0 ..< 12.0
    /// Band used for "total" power and spectral statistics (Hz).
    static let analysisBand: Range<Double> = 1.0 ..< 24.0

    /// Feature names in the same order they appear in `features.csv`.
    /// (Order is informational; the model is fed a keyed dictionary.)
    static let featureNames: [String] = [
        "mag_band_ratio", "mag_dom_freq", "mag_peak_power", "mag_total_power",
        "mag_spec_entropy", "mag_spec_centroid", "mag_rms", "mag_std", "mag_zcr",
        "x_band_ratio", "x_rms", "y_band_ratio", "y_rms", "z_band_ratio", "z_rms",
        "max_axis_band_ratio", "mean_axis_band_ratio",
    ]

    /// Extracts the feature dictionary for one window of dynamic acceleration.
    /// - Parameter window: samples ordered oldest→newest (gravity removed, g).
    /// - Returns: feature name → value, ready to feed the Core ML model.
    static func extract(window: [AccelerometerSample]) -> [String: Double] {
        let x: [Double] = window.map { $0.x }
        let y: [Double] = window.map { $0.y }
        let z: [Double] = window.map { $0.z }
        var mag = [Double](repeating: 0, count: window.count)
        for i in window.indices {
            mag[i] = sqrt(x[i] * x[i] + y[i] * y[i] + z[i] * z[i])
        }

        let magSpec = spectralFeatures(mag)
        let xSpec = spectralFeatures(x)
        let ySpec = spectralFeatures(y)
        let zSpec = spectralFeatures(z)

        let ratios = [xSpec.bandRatio, ySpec.bandRatio, zSpec.bandRatio]

        return [
            "mag_band_ratio": magSpec.bandRatio,
            "mag_dom_freq": magSpec.domFreq,
            "mag_peak_power": magSpec.peakPower,
            "mag_total_power": magSpec.totalPower,
            "mag_spec_entropy": magSpec.specEntropy,
            "mag_spec_centroid": magSpec.specCentroid,
            "mag_rms": rms(mag),
            "mag_std": std(mag),
            "mag_zcr": zeroCrossingRate(mag),
            "x_band_ratio": xSpec.bandRatio,
            "x_rms": rms(x),
            "y_band_ratio": ySpec.bandRatio,
            "y_rms": rms(y),
            "z_band_ratio": zSpec.bandRatio,
            "z_rms": rms(z),
            "max_axis_band_ratio": ratios.max() ?? 0,
            "mean_axis_band_ratio": ratios.reduce(0, +) / Double(ratios.count),
        ]
    }

    // MARK: - Spectral features

    private struct SpectralFeatures {
        var bandRatio = 0.0
        var domFreq = 0.0
        var peakPower = 0.0
        var totalPower = 0.0
        var specEntropy = 0.0
        var specCentroid = 0.0
    }

    /// Replicates `_spectral_feats()` from `prepare_data.py`.
    private static func spectralFeatures(_ signal: [Double]) -> SpectralFeatures {
        let n = signal.count
        guard n > 1 else { return SpectralFeatures() }

        let power = powerSpectrum(signal)              // bins 0...n/2
        let binHz = sampleRate / Double(n)

        var total = 1e-12                              // matches Python's +1e-12
        var tremorPower = 0.0
        var peakPower = 0.0
        var domFreq = 0.0
        var centroidNum = 0.0
        var probs: [Double] = []

        for k in power.indices {
            let f = Double(k) * binHz
            guard analysisBand.contains(f) else { continue }
            let p = power[k]
            total += p
            centroidNum += f * p
            if p > peakPower { peakPower = p; domFreq = f }
            if tremorBand.contains(f) { tremorPower += p }
        }

        // Spectral entropy is normalised by total (incl. the 1e-12 epsilon),
        // exactly as in the training script.
        for k in power.indices {
            let f = Double(k) * binHz
            guard analysisBand.contains(f) else { continue }
            let pp = power[k] / total
            if pp > 0 { probs.append(pp) }
        }
        var entropy = 0.0
        if probs.count > 1 {
            let s = probs.reduce(0) { $0 - ($1 * log($1)) }
            entropy = s / log(Double(probs.count))
        }

        var result = SpectralFeatures()
        result.bandRatio = tremorPower / total
        result.domFreq = domFreq
        result.peakPower = peakPower
        result.totalPower = total
        result.specEntropy = entropy
        result.specCentroid = centroidNum / total
        return result
    }

    /// One-sided power spectrum of a Hann-windowed (mean-removed) signal.
    /// Equivalent to `|numpy.fft.rfft((sig-mean)*hanning)|**2`.
    ///
    /// A direct DFT is used (window is only ~100 samples), which avoids the
    /// power-of-two / supported-length constraints of vDSP's FFT.
    private static func powerSpectrum(_ signal: [Double]) -> [Double] {
        let n = signal.count
        let mean = signal.reduce(0, +) / Double(n)

        // numpy.hanning(n): 0.5 - 0.5*cos(2*pi*j/(n-1))
        var windowed = [Double](repeating: 0, count: n)
        let denom = Double(n - 1)
        for j in 0..<n {
            let h = 0.5 - 0.5 * cos(2.0 * .pi * Double(j) / denom)
            windowed[j] = (signal[j] - mean) * h
        }

        let half = n / 2
        var power = [Double](repeating: 0, count: half + 1)
        for k in 0...half {
            var re = 0.0, im = 0.0
            let c = -2.0 * .pi * Double(k) / Double(n)
            for j in 0..<n {
                let ang = c * Double(j)
                re += windowed[j] * cos(ang)
                im += windowed[j] * sin(ang)
            }
            power[k] = re * re + im * im
        }
        return power
    }

    // MARK: - Time-domain features

    private static func rms(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let ss = v.reduce(0) { $0 + $1 * $1 }
        return sqrt(ss / Double(v.count))
    }

    /// Population standard deviation (numpy default, ddof=0).
    private static func std(_ v: [Double]) -> Double {
        guard !v.isEmpty else { return 0 }
        let mean = v.reduce(0, +) / Double(v.count)
        let varSum = v.reduce(0) { $0 + ($1 - mean) * ($1 - mean) }
        return sqrt(varSum / Double(v.count))
    }

    /// Fraction of consecutive samples whose mean-removed sign changes.
    /// Equivalent to `mean(abs(diff(sign(x-mean))) > 0)`.
    private static func zeroCrossingRate(_ v: [Double]) -> Double {
        guard v.count > 1 else { return 0 }
        let mean = v.reduce(0, +) / Double(v.count)
        func sgn(_ d: Double) -> Double { d > 0 ? 1 : (d < 0 ? -1 : 0) }
        var crossings = 0
        var prev = sgn(v[0] - mean)
        for i in 1..<v.count {
            let cur = sgn(v[i] - mean)
            if abs(cur - prev) > 0 { crossings += 1 }
            prev = cur
        }
        return Double(crossings) / Double(v.count - 1)
    }
}
