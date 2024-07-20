import SwiftUI

struct SuccessView: View {
    let result: ReservationResult
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    @State private var isReverseReserving: Bool = false
    @State private var showReverseReservationError: Bool = false
    @Binding var reservationResult: ReservationResult?
    @Environment(\.colorScheme) var colorScheme
    
    private var mainColor: Color {
        result.isPastBus ?
            (colorScheme == .dark ? Color(red: 255/255, green: 170/255, blue: 50/255) : Color(hex: "C2956E")) :
            (colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(hex: "3A7CA5"))
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? mainColor : mainColor.opacity(0.95)
    }
    
    private var secondaryColor: Color {
        colorScheme == .dark ? mainColor : mainColor.opacity(0.8)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Color(hex: "2C3E50")
    }
    
    private var metallicGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(hex: colorScheme == .dark ? "2A2A2A" : "F0F0F0"),
                Color(hex: colorScheme == .dark ? "1A1A1A" : "E0E0E0")
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部条带
            Text(result.isPastBus ? "临时码" : "乘车码")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    ZStack {
                        metallicGradient
                        LinearGradient(
                            gradient: Gradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                )
                .foregroundColor(accentColor)
            
            VStack(spacing: 25) {
                VStack(spacing: 12) {
                    Text(result.name)
                        .font(.system(size: result.name.count > 10 ? 16 : 20, weight: .medium))
                        .foregroundColor(secondaryColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text(result.yaxis)
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor)
                }
                .padding(.top, 20)
                
                QRCodeView(qrCode: result.qrCode)
                    .frame(width: 200, height: 200)
                    .background(Color.white)
                
                Button(action: {
                    reverseReservation()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .imageScale(.small)
                        Text(isReverseReserving ? "预约中..." : "预约反向班车")
                            .fontWeight(.semibold)
                    }
                    .font(.system(size: 16))
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isReverseReserving ? Color.gray.opacity(0.05) : accentColor.opacity(0.08))
                    )
                    .foregroundColor(isReverseReserving ? Color.gray : accentColor)
                    .animation(.easeInOut(duration: 0.2), value: isReverseReserving)
                }
                .disabled(isReverseReserving)
                .padding(.horizontal, 26)
                .padding(.vertical, 10)
            }
            .padding(25)
            .background(metallicGradient)
        }
        .background(metallicGradient)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: mainColor.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 10)
        .alert(isPresented: $showReverseReservationError) {
            Alert(title: Text("反向预约失败"), message: Text("反向无车可坐"), dismissButton: .default(Text("确定")))
        }
        .padding(.horizontal, 20)
    }
    
    private func reverseReservation() {
        isReverseReserving = true
        LoginService.shared.reverseReservation(currentResult: result) { result in
            DispatchQueue.main.async {
                isReverseReserving = false
                switch result {
                case .success(let newReservation):
                    reservationResult = newReservation
                case .failure:
                    showReverseReservationError = true
                }
            }
        }
    }
}
