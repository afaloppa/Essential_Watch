//
//  ContentView.swift
//  Essential_Watch Watch App
//
//  Created by Alex Faloppa on 15/05/26.
//

import SwiftUI

/// Thin root wrapper. The real UI lives in `DetectionView`; services are
/// supplied via `@EnvironmentObject` from `Essential_Watch_Watch_AppApp`.
struct ContentView: View {
    @EnvironmentObject private var motion: MotionManager
    @EnvironmentObject private var prediction: TremorPredictionService

    var body: some View {
        // The watch focuses purely on tremor detection. The accelerometer
        // visualization now lives in the iOS companion app (`MotionSphereView`).
        DetectionView(motion: motion, prediction: prediction)
    }
}

#Preview {
    let motion = MotionManager()
    let prediction = TremorPredictionService()
    return ContentView()
        .environmentObject(motion)
        .environmentObject(prediction)
}
