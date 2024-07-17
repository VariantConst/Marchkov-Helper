import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(Color(.secondaryLabel))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color(.label))
        }
    }
}
