import SwiftUI


struct ErrorView: View {
    let errorMessage: String
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    
    var body: some View {
        VStack(spacing: 15) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text(errorMessage)
                .font(.headline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            
            if isDeveloperMode {
                LogButton(showLogs: $showLogs)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(radius: 5)
    }
}
