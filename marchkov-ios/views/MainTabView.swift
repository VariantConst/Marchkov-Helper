import SwiftUI

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    
    var body: some View {
        TabView(selection: $currentTab) {
            ReservationResultView(isLoading: $isLoading, errorMessage: $errorMessage, reservationResult: $reservationResult)
                .tabItem {
                    Label("预约结果", systemImage: "car.fill")
                }
                .tag(0)

            SettingsView(logout: logout, themeMode: $themeMode)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(.blue)
        .background(Color(.systemBackground))
    }
}

struct ReservationResultView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    @State private var showLogs: Bool = false
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color(.systemGroupedBackground)
                        .edgesIgnoringSafeArea(.all)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            ZStack(alignment: .bottomTrailing) {
                                VStack(spacing: 20) {
                                    if isLoading {
                                        ProgressView("加载中...")
                                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                            .scaleEffect(1.5)
                                            .frame(height: geometry.size.height * 0.8)
                                    } else if !errorMessage.isEmpty {
                                        ErrorView(errorMessage: errorMessage, isDeveloperMode: isDeveloperMode, showLogs: $showLogs)
                                            .frame(height: geometry.size.height * 0.8)
                                    } else if let result = reservationResult {
                                        VStack {
                                            Spacer()
                                            SuccessView(result: result, isDeveloperMode: isDeveloperMode, showLogs: $showLogs, reservationResult: $reservationResult)
                                            Spacer()
                                        }
                                        .frame(height: geometry.size.height * 0.8)
                                    } else {
                                        VStack {
                                            Image(systemName: "ticket.slash")
                                                .font(.system(size: 60))
                                                .foregroundColor(.secondary)
                                            Text("暂无预约结果")
                                                .font(.headline)
                                                .foregroundColor(.secondary)
                                        }
                                        .padding()
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                        .frame(height: geometry.size.height * 0.8)
                                    }
                                }
                                .padding()
                                
                                if isDeveloperMode && !isLoading {
                                    LogButton(showLogs: $showLogs)
                                        .offset(x: 20, y: 40)
                                }
                            }
                        }
                        .padding()
                        .frame(minHeight: geometry.size.height)
                    }
                    .sheet(isPresented: $showLogs) {
                        LogView()
                    }
                }
            }
        }
    }
}

struct SuccessView: View {
    let result: ReservationResult
    let isDeveloperMode: Bool
    @Binding var showLogs: Bool
    @State private var isReverseReserving: Bool = false
    @State private var showReverseReservationError: Bool = false
    @Binding var reservationResult: ReservationResult?
    @Environment(\.colorScheme) var colorScheme
    
    // 更新的颜色定义
    private let primaryGreen = Color(hex: "6B8E73")  // 保持不变的柔和绿色
    private let primaryOrange = Color(hex: "C1864F")  // 新的高级橙色
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // 顶部窄条显示乘车码类型
                Text(result.isPastBus ? "临时码" : "乘车码")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(result.isPastBus ? primaryOrange : primaryGreen)
                
                VStack(spacing: 35) {
                    Text("欢迎，\(result.username)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: colorScheme == .dark ? "E0E0E0" : "2C3E50"))
                        .padding(.top, 15)
                    
                    VStack(alignment: .leading, spacing: 15) {
                        InfoRow(title: "班车名称", value: result.name)
                        InfoRow(title: "发车时间", value: result.yaxis)
                    }
                    .padding()
                    .background(Color(hex: colorScheme == .dark ? "2C3E50" : "ECF0F1"))
                    .cornerRadius(12)
                    
                    QRCodeView(qrCode: result.qrCode)
                        .frame(width: 200, height: 200)
                        .padding()
                    
                    Button(action: {
                        reverseReservation()
                    }) {
                        HStack {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text(isReverseReserving ? "预约中..." : "预约反向班车")
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(isReverseReserving ? Color(hex: "95A5A6") : (result.isPastBus ? primaryOrange : primaryGreen))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(isReverseReserving)
                }
                .padding(20)
            }
            .background(Color(hex: colorScheme == .dark ? "1E272E" : "F5F7FA"))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(result.isPastBus ? primaryOrange : primaryGreen, lineWidth: 2)
            )
            .shadow(radius: 10)
        }
        .alert(isPresented: $showReverseReservationError) {
            Alert(title: Text("反向预约失败"), message: Text("反向无车可坐"), dismissButton: .default(Text("确定")))
        }
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

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

