//
//  Essential_WatchApp.swift
//  Essential_Watch
//

import SwiftUI

@main
struct Essential_WatchApp: App {
    @StateObject private var motion = MotionManager()
    @StateObject private var prediction = PlaceholderPredictionService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motion)
                .environmentObject(prediction)
                .onAppear {
                    motion.onSample = { [weak prediction] sample in
                        prediction?.consume(sample)
                    }
                }
        }
    }
}
