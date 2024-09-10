import SwiftUI
import CoreHaptics

struct SuccessView: View {
    let result: ReservationResult
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    @State private var isReverseReserving: Bool = false
    @State private var showReverseReservationError: Bool = false
    @State private var reverseReservationErrorMessage: String = ""
    @Binding var reservationResult: ReservationResult?
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var brightnessManager: BrightnessManager
    @State private var showQRCode: Bool = true
    let refresh: () async -> Void
    @State private var isCancelling: Bool = false
    @State private var showCancellationError: Bool = false
    @Binding var showHorseButton: Bool
    @State private var reverseButtonText: String = "预约反向班车"
    @State private var isReverseButtonDisabled: Bool = false
    @State private var engine: CHHapticEngine?
    @State private var shouldAutoRefresh: Bool = false

    private var mainColor: Color {
        result.isPastBus ?
            (colorScheme == .dark ? Color(red: 255/255, green: 150/255, blue: 50/255) : Color(hex: "D49A6A")) :
            (colorScheme == .dark ? Color(red: 80/255, green: 180/255, blue: 255/255) : Color(hex: "519CAB"))
    }

    private var accentColor: Color {
        colorScheme == .dark ? mainColor : mainColor.opacity(0.9)
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? mainColor : mainColor.opacity(0.75)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.95) : Color(hex: "2C3E50")
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.3) : Color.black.opacity(0.1)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(hex: "2f2f2f") : Color(hex: "eeeeee")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if showQRCode {
                VStack(spacing: 0) {
                    // 顶部条带
                    HStack {
                        Text(result.isPastBus ? "临时码" : "乘车码")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(accentColor)
                        Spacer()
                        Button(action: {
                            // 添加震动反馈
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            handleCancellation()
                        }) {
                            HStack {
                                Image(systemName: "xmark")
                                Text("取消")
                                    .font(.system(size: 14))
                            }
                            .foregroundColor(accentColor)
                        }
                        .disabled(isCancelling)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .background(
                        ZStack {
                            cardBackgroundColor
                            LinearGradient(
                                gradient: Gradient(colors: [accentColor.opacity(0.2), accentColor.opacity(0.05)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                    )
                    
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
                                Text(isReverseReserving ? "预约中..." : reverseButtonText)
                                    .fontWeight(.semibold)
                            }
                            .font(.system(size: 16))
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isReverseButtonDisabled ? Color.gray.opacity(0.05) : accentColor.opacity(0.08))
                            )
                            .foregroundColor(isReverseButtonDisabled ? Color.gray : accentColor)
                            .animation(.easeInOut(duration: 0.2), value: isReverseButtonDisabled)
                        }
                        .disabled(isReverseButtonDisabled)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                    }
                    .padding(25)
                }
                .background(cardBackgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
                .padding(.horizontal, 20)
            } else {
                HorseButtonView(refresh: refresh, showHorseButton: $showHorseButton)
            }
        }
        .onAppear {
            brightnessManager.captureCurrentBrightness()
            brightnessManager.isShowingQRCode = true
            brightnessManager.setMaxBrightness()
            prepareHaptics()
        }
        .onDisappear {
            brightnessManager.isShowingQRCode = false
            brightnessManager.restoreOriginalBrightness()
        }
        .onChange(of: reservationResult) { oldValue, newValue in
            // 当预约结果更新时，切换回QR码视图
            withAnimation {
                showQRCode = true
            }
        }
        .alert(isPresented: $showReverseReservationError) {
            Alert(
                title: Text("反向预约失败"),
                message: Text(reverseReservationErrorMessage),
                dismissButton: .default(Text("确定"))
            )
        }
        .alert(isPresented: $showCancellationError) {
            Alert(
                title: Text("取消预约失败"),
                message: Text("无法取消预约，请稍后重试"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
    
    private func setBrightness(to value: CGFloat) {
        DispatchQueue.main.async {
            UIScreen.main.brightness = value
        }
    }
    
    private func reverseReservation() {
        isReverseReserving = true
        isReverseButtonDisabled = true
        LogManager.shared.addLog("开始尝试反向预约")
        LoginService.shared.reverseReservation(currentResult: result) { result in
            DispatchQueue.main.async {
                isReverseReserving = false
                switch result {
                case .success(let newReservation):
                    LogManager.shared.addLog("反向预约成功：\(newReservation.name) \(newReservation.yaxis)")
                    reservationResult = newReservation
                    isReverseButtonDisabled = false
                case .failure(let error):
                    LogManager.shared.addLog("反向预约失败：\(error.localizedDescription)")
                    reverseButtonText = "反向无车可坐"
                    
                    // 触发连续震动反馈
                    complexFailureHaptic()
                    
                    // 检查当前时间是否在7:10-8:40之间
                    let currentTime = Date()
                    let calendar = Calendar.current
                    let hour = calendar.component(.hour, from: currentTime)
                    let minute = calendar.component(.minute, from: currentTime)
                    let currentMinutes = hour * 60 + minute
                    
                    if currentMinutes >= 430 && currentMinutes <= 520 { // 7:10 = 430分钟, 8:40 = 520分钟
                        shouldAutoRefresh = true
                    }
                    
                    // 2秒后恢复按钮文字和状态，并执行自动刷新（如果需要）
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        reverseButtonText = "预约反向班车"
                        isReverseButtonDisabled = false
                        
                        if shouldAutoRefresh {
                            Task {
                                await refresh()
                                shouldAutoRefresh = false
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func prepareHaptics() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            engine = try CHHapticEngine()
            try engine?.start()
        } catch {
            print("There was an error creating the engine: \(error.localizedDescription)")
        }
    }
    
    private func complexFailureHaptic() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        var events = [CHHapticEvent]()
        
        for i in stride(from: 0, to: 1.0, by: 0.1) {
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(1 - i))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(1 - i))
            let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: i)
            events.append(event)
        }
        
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine?.makePlayer(with: pattern)
            try player?.start(atTime: 0)
        } catch {
            print("Failed to play pattern: \(error.localizedDescription).")
        }
    }
    
    private func handleCancellation() {
        // 添加震动反馈
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        if result.isPastBus {
            // 如果是临时码，直接切换到🐴按钮视图
            withAnimation {
                showQRCode = false
                reservationResult = nil
                showHorseButton = true
            }
        } else {
            // 如果不是临时码，执行取消预约操作
            cancelReservation()
        }
    }

    private func cancelReservation() {
        guard let appointmentId = result.appointmentId,
              let appAppointmentId = result.appAppointmentId else {
            showCancellationError = true
            return
        }

        isCancelling = true
        LoginService.shared.cancelReservation(appointmentId: appointmentId, appAppointmentId: appAppointmentId) { result in
            DispatchQueue.main.async {
                isCancelling = false
                switch result {
                case .success:
                    withAnimation {
                        showQRCode = false
                        reservationResult = nil
                        showHorseButton = true
                    }
                case .failure:
                    showCancellationError = true
                }
            }
        }
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut, value: configuration.isPressed)
    }
}
