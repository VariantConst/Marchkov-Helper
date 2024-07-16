import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(Color(hex: colorScheme == .dark ? "A0AEC0" : "718096"))
                .font(.system(size: 16, weight: .medium))
            Spacer()
            Text(value)
                .foregroundColor(Color(hex: colorScheme == .dark ? "E2E8F0" : "2D3748"))
                .font(.system(size: 16, weight: .semibold))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
    }
}
