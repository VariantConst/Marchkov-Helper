import SwiftUI
import CoreImage.CIFilterBuiltins

enum ThemeMode: String, CaseIterable {
    case light = "浅色"
    case dark = "深色"
    case system = "跟随系统"
}

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginResult: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var currentTab: Int = 0
    @State private var isLoading: Bool = false
    @State private var resources: [LoginService.Resource] = []
    @State private var errorMessage: String = ""
    @State private var reservationResult: ReservationResult?
    @AppStorage("themeMode") private var themeMode: ThemeMode = .system
    @Environment(\.colorScheme) var systemColorScheme
    @State private var token: String?
    @State private var lastNetworkActivityTime = Date()
    @StateObject private var brightnessManager = BrightnessManager()
    @AppStorage("isAutoReservationEnabled") private var isAutoReservationEnabled: Bool = true
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(
                    currentTab: $currentTab,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage,
                    reservationResult: $reservationResult,
                    logout: logout,
                    themeMode: $themeMode
                )
            } else {
                LoginFormView(
                    username: $username,
                    password: $password,
                    loginResult: $loginResult,
                    login: login
                )
            }
        }
        .onAppear {
            checkLoginStatus()
        }
        .preferredColorScheme(getPreferredColorScheme())
    }
    
    private func getPreferredColorScheme() -> ColorScheme? {
        switch themeMode {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil
        }
    }
    
    private func checkLoginStatus() {
        if UserDataManager.shared.isUserLoggedIn() {
            isLoggedIn = true
            isLoading = true
            if let credentials = UserDataManager.shared.getUserCredentials() {
                username = credentials.username
                password = credentials.password
                login()
            }
        }
    }
    
    private func login() {
        isLoading = true
        LogManager.shared.clearLogs()
        LogManager.shared.addLog("开始登录流程")
        LoginService.shared.login(username: username, password: password) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loginResponse):
                    if loginResponse.success, let token = loginResponse.token {
                        self.loginResult = "登录成功!"
                        self.isLoggedIn = true
                        self.token = token
                        LogManager.shared.addLog("登录和重定向成功")
                        UserDataManager.shared.saveUserCredentials(username: username, password: password)
                        self.isLoading = false
                        // 不再在这里处理 isAutoReservationEnabled，而是将其传递给 MainTabView
                    } else {
                        self.loginResult = "登录失败: 用户名或密码无效。"
                        LogManager.shared.addLog("登录失败：用户名或密码无效")
                        self.isLoading = false
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.loginResult = "登录失败: \(error.localizedDescription)"
                    LogManager.shared.addLog("登录失败：\(error.localizedDescription)")
                }
                self.updateLastNetworkActivityTime()
            }
        }
    }
    
    private func getResources(token: String) {
        LoginService.shared.getResources(token: token) { [self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let resources):
                    self.resources = resources
                    self.errorMessage = ""
                    self.getReservationResult()
                case .failure(let error):
                    self.isLoading = false
                    self.errorMessage = "获取班车信息失败: \(error.localizedDescription)"
                }
                self.updateLastNetworkActivityTime()
            }
        }
    }
    
    private func getReservationResult() {
        LoginService.shared.getReservationResult(resources: resources) { [self] result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let reservationResult):
                    self.reservationResult = reservationResult
                case .failure(let error):
                    self.errorMessage = "获取预约结果失败: \(error.localizedDescription)"
                }
                self.updateLastNetworkActivityTime()
            }
        }
    }
    
    private func logout() {
        UserDataManager.shared.clearUserCredentials()
        isLoggedIn = false
        username = ""
        password = ""
        loginResult = ""
        currentTab = 0
        resources = []
        errorMessage = ""
        reservationResult = nil
        token = nil
    }
    
    private func updateLastNetworkActivityTime() {
        lastNetworkActivityTime = Date()
    }
}

#Preview {
    LoginView()
}
