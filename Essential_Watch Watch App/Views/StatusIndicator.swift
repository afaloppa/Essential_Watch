//
//  StatusIndicator.swift
//  Essential_Watch Watch App
//

import SwiftUI

/// Compact status pill: a colored dot plus an "Active"/"Inactive" label.
struct StatusIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 10, height: 10)
            Text(isActive ? "Active" : "Inactive")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}

#Preview {
    VStack(spacing: 8) {
        StatusIndicator(isActive: true)
        StatusIndicator(isActive: false)
    }
}
