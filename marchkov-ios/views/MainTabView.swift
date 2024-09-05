import SwiftUI
import Combine
import Charts

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @State private var resources: [LoginService.Resource] = []
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var brightnessManager = BrightnessManager()
    @State private var selectedTab: Int = 0
    @State private var rideHistory: [LoginService.RideInfo]?
    @State private var isRideHistoryLoading: Bool = true
    @State private var isRideHistoryDataReady: Bool = false

    @State private var refreshTimer: AnyCancellable?
    @State private var lastNetworkActivityTime = Date()
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var gradientBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 25/255, green: 25/255, blue: 30/255), Color(red: 75/255, green: 75/255, blue: 85/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 245/255, green: 245/255, blue: 250/255), Color(red: 220/255, green: 220/255, blue: 230/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
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

            RideHistoryView(rideHistory: $rideHistory, isLoading: $isRideHistoryLoading)
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
                .tag(1)
                .onChange(of: isRideHistoryDataReady) { _, newValue in
                    if newValue {
                        isRideHistoryLoading = false
                    }
                }

            SettingsView(logout: logout, themeMode: $themeMode)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .accentColor(accentColor)
        .background(gradientBackground(colorScheme: colorScheme).edgesIgnoringSafeArea(.all))
        .onAppear(perform: startRefreshTimer)
        .onDisappear(perform: stopRefreshTimer)
        .onChange(of: currentTab, initial: false) { _, _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .environmentObject(brightnessManager)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 0 { // 切换到显示二维码的视图
                brightnessManager.captureCurrentBrightness()
                brightnessManager.setMaxBrightness()
            } else {
                brightnessManager.restoreOriginalBrightness()
            }
        }
        .onAppear {
            brightnessManager.updateOriginalBrightness()
            if rideHistory == nil {
                fetchRideHistory()
            }
        }
    }
    
    private func startRefreshTimer() {
        refreshTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if Date().timeIntervalSince(lastNetworkActivityTime) >= 60 * 10 {
                    Task {
                        await performAutoRefresh()
                    }
                }
            }
    }
    
    private func stopRefreshTimer() {
        refreshTimer?.cancel()
    }
    
    private func updateLastNetworkActivityTime() {
        lastNetworkActivityTime = Date()
    }
    
    private func performAutoRefresh() async {
        if isLoading {
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = ""
            reservationResult = nil
            resources = []
        }
        
        await refresh()
        
        updateLastNetworkActivityTime()
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
            
            LogManager.shared.addLog("重新登录成功，开始获取资")
            
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
            
            await MainActor.run {
                self.resources = newResources
                self.reservationResult = newReservationResult
                self.errorMessage = ""
                self.isLoading = false
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
            
            updateLastNetworkActivityTime()
        } catch {
            await MainActor.run {
                self.errorMessage = "刷新失败: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func fetchRideHistory() {
        isRideHistoryLoading = true
        isRideHistoryDataReady = false
        LoginService.shared.getRideHistory { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let history):
                    self.rideHistory = history
                    // 使用 DispatchQueue.main.asyncAfter 来确保数据在后台完全处理后再更新 UI
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.isRideHistoryDataReady = true
                    }
                case .failure(let error):
                    print("获取乘车历史失败: \(error.localizedDescription)")
                    self.isRideHistoryLoading = false
                }
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    gradientBackground(colorScheme: colorScheme).edgesIgnoringSafeArea(.all)
                    
                    if isLoading {
                        ProgressView("加载中...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                            .scaleEffect(1.2)
                    } else {
                        ScrollView {
                            VStack(spacing: 20) {
                                Spacer(minLength: 20)
                                
                                if !errorMessage.isEmpty {
                                    ErrorView(errorMessage: errorMessage, isDeveloperMode: isDeveloperMode, showLogs: $showLogs)
                                } else if let result = reservationResult {
                                    SuccessView(result: result, isDeveloperMode: isDeveloperMode, showLogs: $showLogs, reservationResult: $reservationResult)
                                } else {
                                    NoResultView()
                                }
                                
                                Spacer(minLength: 20)
                            }
                            .frame(minHeight: geometry.size.height)
                            .padding(.horizontal)
                        }
                        .refreshable {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            await refresh()
                        }
                        .scrollIndicators(.hidden)

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


struct NoResultView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        VStack {
            Image(systemName: "ticket.slash")
                .font(.system(size: 60))
                .foregroundColor(Color(.secondaryLabel))
            Text("暂无预约结果")
                .font(.headline)
                .foregroundColor(Color(.secondaryLabel))
        }
        .padding()
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
        .background(gradientBackground(colorScheme: colorScheme).edgesIgnoringSafeArea(.all))
    }
}

extension View {
    func gradientBackground(colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 25/255, green: 25/255, blue: 30/255), Color(red: 75/255, green: 75/255, blue: 85/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 245/255, green: 245/255, blue: 250/255), Color(red: 220/255, green: 220/255, blue: 230/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
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
