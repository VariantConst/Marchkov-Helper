import SwiftUI

struct ErrorView: View {
    let errorMessage: String
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 20) {
                Text("😅")
                    .font(.system(size: 128))
                
                VStack(alignment: .center, spacing: 10) {
                    Text("这会没有班车可坐")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                    Text("急了？")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Color(.label))
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.vertical, 30)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
    }
}
