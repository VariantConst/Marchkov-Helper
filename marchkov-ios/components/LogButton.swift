import SwiftUI

struct LogButton: View {
    @Binding var showLogs: Bool
    
    var body: some View {
        Button(action: {
            showLogs = true
        }) {
            Image(systemName: "doc.text.fill")
                .foregroundColor(.white)
                .padding(12)
                .background(Color.gray)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
        }
    }
}
