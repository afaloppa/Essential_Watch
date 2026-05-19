import SwiftUI

struct StatusIndicator: View {
    let isActive: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isActive ? Color.green : Color.gray)
                .frame(width: 12, height: 12)
            Text(isActive ? "Active" : "Inactive")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}
