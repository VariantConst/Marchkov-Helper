import SwiftUI

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @State private var resources: [LoginService.Resource] = []
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 22/255) : Color(red: 245/255, green: 245/255, blue: 250/255)
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

            SettingsView(logout: logout, themeMode: $themeMode)
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(1)
        }
        .accentColor(accentColor)
        .background(backgroundColor)
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
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 22/255) : Color(red: 245/255, green: 245/255, blue: 250/255)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    backgroundColor.edgesIgnoringSafeArea(.all)
                    
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
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部窄条
            HStack {
                Text(result.isPastBus ? "临时码" : "乘车码")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                Spacer()
                Text(result.name) // 添加班车名称
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(result.isPastBus ? Color.orange : accentColor)
            
            // 主要内容
            VStack(spacing: 25) {
                Text("欢迎，\(result.username)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Color(.label))
                    .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 15) {
                    InfoRow(title: "发车时间", value: result.yaxis)
                }
                .padding()
                .background(Color(UIColor.tertiarySystemBackground))
                .cornerRadius(12)
                
                QRCodeView(qrCode: result.qrCode)
                    .frame(width: 200, height: 200)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
                
                Button(action: {
                    reverseReservation()
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text(isReverseReserving ? "预约中..." : "预约反向班车")
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(isReverseReserving ? Color.gray : (result.isPastBus ? Color.orange : accentColor))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isReverseReserving)
            }
            .padding(20)
        }
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 10)
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

struct NoResultView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }
    
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
        .background(cardBackgroundColor)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
    }
}
