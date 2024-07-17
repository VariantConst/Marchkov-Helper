import SwiftUI

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @State private var resources: [LoginService.Resource] = []
    
    var body: some View {
        TabView(selection: $currentTab) {
            ReservationResultView(
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                reservationResult: $reservationResult,
                resources: $resources,
                refresh: refresh
            )
            .tabItem {
                Label("乘车", systemImage: "car.fill")
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
    
    private func refresh() async {
        do {
            guard let credentials = UserDataManager.shared.getUserCredentials() else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "未找到用户凭证"])
            }
            
            let loginResponse = try await withCheckedThrowingContinuation { continuation in
                LoginService.shared.login(username: credentials.username, password: credentials.password) { result in
                    continuation.resume(with: result)
                }
            }
            
            guard loginResponse.success, let token = loginResponse.token else {
                throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "登录失败：用户名或密码无效"])
            }
            
            LogManager.shared.addLog("重新登录成功，开始获取资源")
            
            let newResources = try await withCheckedThrowingContinuation { continuation in
                LoginService.shared.getResources(token: token) { result in
                    continuation.resume(with: result)
                }
            }
            
            let newReservationResult = try await withCheckedThrowingContinuation { continuation in
                LoginService.shared.getReservationResult(resources: newResources) { result in
                    continuation.resume(with: result)
                }
            }
            
            // 更新主视图的状态
            await MainActor.run {
                self.resources = newResources
                self.reservationResult = newReservationResult
                self.errorMessage = ""
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "刷新失败: \(error.localizedDescription)"
            }
        }
    }
}

struct ReservationResultView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    @Binding var resources: [LoginService.Resource]
    @State private var showLogs: Bool = false
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    let refresh: () async -> Void
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    if isLoading {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                    } else {
                        ScrollView {
                            VStack {
                                Spacer(minLength: 0)
                                
                                if !errorMessage.isEmpty {
                                    ErrorView(errorMessage: errorMessage, isDeveloperMode: isDeveloperMode, showLogs: $showLogs)
                                } else if let result = reservationResult {
                                    SuccessView(result: result, isDeveloperMode: isDeveloperMode, showLogs: $showLogs, reservationResult: $reservationResult)
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
                                }
                                
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: geometry.size.height)
                            .padding(.horizontal, 20) // 添加水平边距
                        }
                        .refreshable {
                            await refresh()
                        }
                    }
                    
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            if isDeveloperMode && !isLoading {
                                LogButton(showLogs: $showLogs)
                            }
                        }
                    }
                    .padding()
                }
            }
            .sheet(isPresented: $showLogs) {
                LogView()
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
    
    private let primaryGreen = Color(hex: "6B8E73")
    private let primaryOrange = Color(hex: "C1864F")
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
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

