//
//  Essential_WatchApp.swift
//  Essential_Watch
//

import SwiftUI

@main
struct Essential_WatchApp: App {
    // The phone only mirrors the watch's tremor result; it has no local motion
    // capture or model of its own.
    @StateObject private var watchTremor = TremorSyncReceiver()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchTremor)
        }
    }
}
