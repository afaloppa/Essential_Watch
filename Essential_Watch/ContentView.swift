//
//  ContentView.swift
//  Essential_Watch
//

import SwiftUI

/// The iOS companion is a read-only mirror of the watch's tremor detection.
/// It does not use the phone's own accelerometer.
struct ContentView: View {
    var body: some View {
        TremorWatchView()
    }
}

#Preview {
    ContentView()
        .environmentObject(TremorSyncReceiver())
}
