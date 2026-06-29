//
//  Essential_WatchApp.swift
//  Essential_Watch Watch App
//
//  Created by Alex Faloppa on 15/05/26.
//

import SwiftUI

@main
struct Essential_Watch_Watch_AppApp: App {
    @StateObject private var motion = MotionManager()
    @StateObject private var prediction = TremorPredictionService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(motion)
                .environmentObject(prediction)
                .onAppear {
                    // Forward each accelerometer sample into the prediction
                    // pipeline. `[weak prediction]` avoids a retain cycle if
                    // the closure outlives the service.
                    motion.onSample = { [weak prediction] sample in
                        prediction?.consume(sample)
                    }
                }
        }
    }
}
