//
//  ContentView.swift
//  Essential_Watch
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var motion: MotionManager
    @EnvironmentObject private var prediction: PlaceholderPredictionService

    var body: some View {
        NavigationStack {
            DetectionView(motion: motion, prediction: prediction)
                .navigationTitle("Essential Watch")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    let motion = MotionManager()
    let prediction = PlaceholderPredictionService()
    return ContentView()
        .environmentObject(motion)
        .environmentObject(prediction)
}
