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
    @EnvironmentObject private var prediction: PlaceholderPredictionService

    var body: some View {
        // Paged TabView: swipe horizontally between the main detection screen
        // and the experimental 3D-sphere visualization. The sphere page is a
        // prototype (see `MotionSphereView`) and is expected to be removed or
        // replaced once a real 3D renderer is wired in.
        TabView {
            DetectionView(motion: motion, prediction: prediction)
            MotionSphereView()
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    let motion = MotionManager()
    let prediction = PlaceholderPredictionService()
    return ContentView()
        .environmentObject(motion)
        .environmentObject(prediction)
}
