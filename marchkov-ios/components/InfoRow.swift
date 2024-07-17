import SwiftUI

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondaryText)
            Spacer()
            Text(value)
                .foregroundColor(.primaryText)
                .fontWeight(.medium)
        }
    }
}
