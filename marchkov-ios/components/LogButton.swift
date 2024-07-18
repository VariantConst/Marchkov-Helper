import SwiftUI

struct LogButton: View {
    @Binding var showLogs: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            showLogs.toggle()
        }) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.white)
                .padding(10)
                .background(Color(hex: "3A7CA5"))
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .scaleEffect(0.8)
        .opacity(0.9)
    }
}
