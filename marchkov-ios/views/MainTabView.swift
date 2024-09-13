import SwiftUI
import Combine
import Charts
import CoreMotion

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
    
    @State private var availableBuses: [String: [BusInfo]] = [:]
    @State private var token: String?
    
    @AppStorage("isAutoReservationEnabled") private var isAutoReservationEnabled: Bool = true
    @State private var showHorseButton: Bool = false
    
    var body: some View {
        TabView(selection: $currentTab) {
            ReservationResultView(
                isLoading: $isLoading,
                errorMessage: $errorMessage,
                reservationResult: $reservationResult,
                resources: $resources,
                showHorseButton: $showHorseButton,
                refresh: refresh
            )
            .tabItem {
                Label("乘车", systemImage: "car.fill")
            }
            .tag(0)

            ReservationView()
                .tabItem {
                    Label("预约", systemImage: "calendar")
                }
                .tag(1)

            RideHistoryView(rideHistory: $rideHistory, isLoading: $isRideHistoryLoading)
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
                .tag(2)
                .onChange(of: isRideHistoryDataReady) { _, newValue in
                    if newValue {
                        isRideHistoryLoading = false
                    }
                }

            SettingsView(logout: performLogout, themeMode: $themeMode)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(accentColor)
        .background(gradientBackground(colorScheme: colorScheme).edgesIgnoringSafeArea(.all))
        .onAppear(perform: startRefreshTimer)
        .onDisappear(perform: stopRefreshTimer)
        .onChange(of: currentTab, initial: false) { _, _ in
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        .environmentObject(brightnessManager)
        .onChange(of: currentTab) { oldValue, newValue in
            if newValue == 0 {
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
            if isAutoReservationEnabled {
                fetchAvailableBuses()
            } else {
                showHorseButton = true
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
    
    private func fetchAvailableBuses() {
        guard let credentials = UserDataManager.shared.getUserCredentials() else {
            LogManager.shared.addLog("获取班车信息失：未找用户凭证")
            return
        }

        LoginService.shared.login(username: credentials.username, password: credentials.password) { result in
            switch result {
            case .success(let loginResponse):
                if loginResponse.success, let token = loginResponse.token {
                    self.token = token
                    self.getResources(token: token)
                } else {
                    LogManager.shared.addLog("登录失败：用户名或密码无效")
                }
            case .failure(let error):
                LogManager.shared.addLog("登录失败：\(error.localizedDescription)")
            }
        }
    }

    private func getResources(token: String) {
        LoginService.shared.getResources(token: token) { result in
            switch result {
            case .success(let resources):
                self.resources = resources
                self.getReservationResult()
            case .failure(let error):
                LogManager.shared.addLog("获取资源失败：\(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "获取资源失败：\(error.localizedDescription)"
                }
            }
        }
    }

    private func getReservationResult() {
        LoginService.shared.getReservationResult(resources: resources) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let reservationResult):
                    self.reservationResult = reservationResult
                    self.parseAvailableBuses(resources: self.resources)
                case .failure(let error):
                    self.errorMessage = "获取预约结果失败: \(error.localizedDescription)"
                }
                self.isLoading = false
            }
        }
    }

    private func parseAvailableBuses(resources: [LoginService.Resource]) {
        var toYanyuan: [BusInfo] = []
        var toChangping: [BusInfo] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let today = dateFormatter.string(from: Date())
        
        for resource in resources {
            LogManager.shared.addLog("处理资源: ID = \(resource.id), 名称 = \(resource.name)")
            for busInfo in resource.busInfos where busInfo.date == today && busInfo.margin > 0 {
                let time = busInfo.yaxis
                let direction: String
                if resource.id == 2 || resource.id == 4 {
                    direction = "去燕园"
                    toYanyuan.append(BusInfo(time: time, direction: direction, margin: busInfo.margin, resourceName: resource.name, date: today, timeId: busInfo.timeId, resourceId: resource.id))
                    LogManager.shared.addLog("添加去燕园班车: \(time), 余票: \(busInfo.margin), timeId: \(busInfo.timeId), resourceId: \(resource.id)")
                } else if resource.id == 5 || resource.id == 6 || resource.id == 7 {
                    direction = "去昌平"
                    toChangping.append(BusInfo(time: time, direction: direction, margin: busInfo.margin, resourceName: resource.name, date: today, timeId: busInfo.timeId, resourceId: resource.id))
                    LogManager.shared.addLog("添加去昌平班车: \(time), 余票: \(busInfo.margin), timeId: \(busInfo.timeId), resourceId: \(resource.id)")
                }
            }
        }
        
        DispatchQueue.main.async {
            self.availableBuses = [
                "去燕园": toYanyuan.sorted { $0.time < $1.time },
                "去昌平": toChangping.sorted { $0.time < $1.time }
            ]
            LogManager.shared.addLog("更新可用班车: 去燕园 \(toYanyuan.count) 辆, 去昌平 \(toChangping.count) 辆")
        }
    }
    
    private func performLogout() {
        UserDataManager.shared.clearRideHistory()
        
        rideHistory = nil
        isRideHistoryLoading = true
        isRideHistoryDataReady = false
        
        logout()
    }
}

struct ReservationResultView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    @Binding var resources: [LoginService.Resource]
    @Binding var showHorseButton: Bool
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
                                    SuccessView(result: result, isDeveloperMode: isDeveloperMode, showLogs: $showLogs, reservationResult: $reservationResult, refresh: refresh, showHorseButton: $showHorseButton)
                                } else if showHorseButton {
                                    HorseButtonView(refresh: refresh, showHorseButton: $showHorseButton)
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

struct HorseButtonView: View {
    let refresh: () async -> Void
    @Binding var showHorseButton: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var isAnimating = false
    @StateObject private var motionManager = MotionManager()
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 80/255, green: 180/255, blue: 255/255) : Color(hex: "519CAB")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                performRefresh()
            }) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.1))
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .stroke(accentColor.opacity(0.5), lineWidth: 2)
                        .frame(width: 200, height: 200)
                        .scaleEffect(isAnimating ? 1.5 : 1.0)
                        .opacity(isAnimating ? 0 : 1)
                    
                    Text("🐴")
                        .font(.system(size: 100))
                }
                .frame(width: 300, height: 300)
            }
            .buttonStyle(ScaleButtonStyle())
            
            HStack(spacing: 10) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                Text("摇一摇跳转到马池口")
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(accentColor)
        }
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 2).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
            motionManager.startMonitoring()
        }
        .onDisappear {
            motionManager.stopMonitoring()
        }
        .onReceive(motionManager.$isShaking) { isShaking in
            if isShaking {
                performRefresh()
            }
        }
    }
    
    private func performRefresh() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        Task {
            await refresh()
            showHorseButton = false
        }
    }
}

class MotionManager: ObservableObject {
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    @Published var isShaking = false
    
    func startMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: queue) { [weak self] (data, error) in
            guard let data = data else { return }
            let threshold: Double = 2.0
            
            if abs(data.acceleration.x) > threshold || abs(data.acceleration.y) > threshold || abs(data.acceleration.z) > threshold {
                DispatchQueue.main.async {
                    self?.isShaking = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self?.isShaking = false
                    }
                }
            }
        }
    }
    
    func stopMonitoring() {
        motionManager.stopAccelerometerUpdates()
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
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
