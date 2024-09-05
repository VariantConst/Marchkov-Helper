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
    @State private var rideHistory: [String: Any]?
    
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

            RideHistoryView(rideHistory: $rideHistory)
                .tabItem {
                    Label("历史", systemImage: "clock.fill")
                }
                .tag(1)

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
            fetchRideHistory()
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
            
            LogManager.shared.addLog("重新登录成功，开始获取资��")
            
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
        LoginService.shared.getRideHistory { result in
            switch result {
            case .success(let history):
                DispatchQueue.main.async {
                    self.rideHistory = history
                }
            case .failure(let error):
                print("获取乘车历史失败: \(error.localizedDescription)")
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

struct RideHistoryView: View {
    @Binding var rideHistory: [String: Any]?
    @State private var validRideCount: Int = 0
    @State private var resourceNameStats: [RouteStats] = []
    @State private var timeStats: [TimeStats] = []
    @State private var statusStats: [StatusStats] = []
    @State private var highlightedSlice: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                if let _ = rideHistory {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("有效乘车次数：\(validRideCount)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("按路线统计：")
                                .font(.headline)
                            Chart(resourceNameStats) {
                                BarMark(
                                    x: .value("次数", $0.count),
                                    y: .value("路线", $0.route)
                                )
                                .foregroundStyle(Color.blue.gradient)
                            }
                            .frame(height: CGFloat(resourceNameStats.count * 30))
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("按时间统计：")
                                .font(.headline)
                            Chart(timeStats) {
                                BarMark(
                                    x: .value("次数", $0.count),
                                    y: .value("时间", $0.time)
                                )
                                .foregroundStyle(Color.green.gradient)
                            }
                            .frame(height: CGFloat(timeStats.count * 25))
                            .chartXAxis {
                                AxisMarks(position: .bottom)
                            }
                            .chartYAxis {
                                AxisMarks(position: .leading)
                            }
                        }
                        
                        VStack(alignment: .center, spacing: 10) {
                            Text("预约状态统计")
                                .font(.headline)
                            Text("已预约和已签到的比例")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            ZStack {
                                PieChartView(data: statusStats, highlightedSlice: $highlightedSlice)
                                    .frame(height: 200)
                                HStack {
                                    ForEach(statusStats) { stat in
                                        VStack {
                                            Text(stat.status)
                                                .font(.caption)
                                            Text("\(stat.count)")
                                                .font(.headline)
                                                .foregroundColor(colorForStatus(stat.status))
                                        }
                                        .frame(width: 80)
                                    }
                                }
                            }
                            .frame(height: 250)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding()
                } else {
                    Text("加载中...")
                }
            }
            .navigationTitle("乘车历史")
            .onAppear {
                processRideHistory()
            }
            .onTapGesture {
                highlightedSlice = nil
            }
        }
    }
    
    private func processRideHistory() {
        guard let history = rideHistory,
              let data = history["d"] as? [String: Any],
              let rides = data["data"] as? [[String: Any]] else {
            return
        }
        
        validRideCount = 0
        var resourceNameDict: [String: Int] = [:]
        var timeDict: [String: Int] = [:]
        var statusDict: [String: Int] = [:]
        
        for ride in rides {
            guard let statusName = ride["status_name"] as? String,
                  statusName != "已撤销",
                  let resourceName = ride["resource_name"] as? String,
                  let appointmentTime = ride["appointment_tim"] as? String else {
                continue
            }
            
            validRideCount += 1
            
            resourceNameDict[resourceName, default: 0] += 1
            
            if let timeComponent = appointmentTime.components(separatedBy: " ").last?.components(separatedBy: ":").prefix(2).joined(separator: ":") {
                timeDict[timeComponent, default: 0] += 1
            }
            
            statusDict[statusName, default: 0] += 1
        }
        
        resourceNameStats = resourceNameDict.map { RouteStats(route: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        timeStats = timeDict.map { TimeStats(time: $0.key, count: $0.value) }
            .sorted { $0.time < $1.time }
        
        statusStats = statusDict.map { StatusStats(status: $0.key, count: $0.value) }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "已预约":
            return Color(hex: "#4A90E2") // 柔和的蓝色
        case "已签到":
            return Color(hex: "#50E3C2") // 清新的绿色
        default:
            return Color(hex: "#C7C7CC") // 浅灰色
        }
    }
}

struct RouteStats: Identifiable {
    let id = UUID()
    let route: String
    let count: Int
}

struct TimeStats: Identifiable {
    let id = UUID()
    let time: String
    let count: Int
}

struct StatusStats: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
}

struct PieChartView: View {
    let data: [StatusStats]
    @Binding var highlightedSlice: String?
    
    var body: some View {
        ZStack {
            ForEach(data) { stat in
                PieSlice(startAngle: startAngle(for: stat), endAngle: endAngle(for: stat))
                    .fill(colorForStatus(stat.status))
                    .overlay(
                        PieSlice(startAngle: startAngle(for: stat), endAngle: endAngle(for: stat))
                            .stroke(Color.white, lineWidth: highlightedSlice == stat.status ? 3 : 1)
                    )
                    .scaleEffect(highlightedSlice == stat.status ? 1.05 : 1.0)
                    .animation(.spring(), value: highlightedSlice)
                    .onTapGesture {
                        withAnimation {
                            highlightedSlice = (highlightedSlice == stat.status) ? nil : stat.status
                        }
                    }
            }
        }
    }
    
    private func startAngle(for stat: StatusStats) -> Angle {
        let index = data.firstIndex(where: { $0.id == stat.id }) ?? 0
        let precedingTotal = data.prefix(index).reduce(0) { $0 + $1.count }
        return .degrees(Double(precedingTotal) / Double(total) * 360)
    }
    
    private func endAngle(for stat: StatusStats) -> Angle {
        let index = data.firstIndex(where: { $0.id == stat.id }) ?? 0
        let precedingTotal = data.prefix(index + 1).reduce(0) { $0 + $1.count }
        return .degrees(Double(precedingTotal) / Double(total) * 360)
    }
    
    private var total: Int {
        data.reduce(0) { $0 + $1.count }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "已预约":
            return Color(hex: "#4A90E2") // 柔和的蓝色
        case "已签到":
            return Color(hex: "#50E3C2") // 清新的绿色
        default:
            return Color(hex: "#C7C7CC") // 浅灰色
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        path.closeSubpath()
        return path
    }
}
