import SwiftUI

struct LogButton: View {
    @Binding var showLogs: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    var body: some View {
        Button(action: { showLogs = true }) {
            Image(systemName: "doc.text.magnifyingglass")
                .foregroundColor(.white)
                .padding(12)
                .background(accentColor)
                .clipShape(Circle())
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}
