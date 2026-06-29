//
//  TremorWatchView.swift
//  Essential_Watch (iOS companion)
//
//  Shows the live tremor probability streamed from the watch (replacing the old
//  local 3D accelerometer sphere). The watch runs the Core ML model; this is a
//  read-only mirror of its latest result.
//

import SwiftUI

struct TremorWatchView: View {
    @EnvironmentObject private var watchTremor: TremorSyncReceiver

    /// Consider the reading stale if nothing has arrived recently.
    private let stalenessSeconds: TimeInterval = 8

    var body: some View {
        // TimelineView drives a periodic re-render so the "stale" state appears
        // even when no new messages arrive from the watch.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let fresh = isFresh(at: context.date)
            VStack(spacing: 24) {
                Text("Tremor — from Apple Watch")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                if let probability = watchTremor.tremorProbability, fresh {
                    ring(probability: probability, isTremor: watchTremor.isTremor)
                    Label(watchTremor.isTremor ? "Tremor detected" : "No tremor",
                          systemImage: watchTremor.isTremor ? "waveform.path" : "checkmark.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(watchTremor.isTremor ? .orange : .green)
                } else {
                    waiting
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    // MARK: - Subviews

    private func ring(probability: Double, isTremor: Bool) -> some View {
        let color: Color = isTremor ? .orange : .green
        return ZStack {
            Circle()
                .stroke(.gray.opacity(0.2), lineWidth: 18)
            Circle()
                .trim(from: 0, to: probability)
                .stroke(color, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: probability)
            VStack(spacing: 2) {
                Text("\(Int((probability * 100).rounded()))%")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("tremor likelihood")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 220, height: 220)
    }

    private var waiting: some View {
        VStack(spacing: 12) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("Waiting for the watch…")
                .font(.headline)
            Text("Open the Essential Watch app on your Apple Watch and tap Start to stream tremor detection here.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func isFresh(at date: Date) -> Bool {
        guard let last = watchTremor.lastUpdate else { return false }
        return date.timeIntervalSince(last) <= stalenessSeconds
    }
}

#Preview {
    TremorWatchView()
        .environmentObject(TremorSyncReceiver())
}
