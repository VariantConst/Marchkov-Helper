import SwiftUI
import CoreImage.CIFilterBuiltins

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
    @AppStorage("isDarkMode") private var isDarkMode = false
    @State private var token: String?
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(
                    currentTab: $currentTab,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage,
                    reservationResult: $reservationResult,
                    logout: logout,
                    isDarkMode: $isDarkMode
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
        .preferredColorScheme(isDarkMode ? .dark : .light)
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
        LoginService.shared.login(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loginResponse):
                    if loginResponse.success, let token = loginResponse.token {
                        self.loginResult = "登录成功!"
                        self.isLoggedIn = true
                        self.token = token
                        LogManager.shared.addLog("登录成功，开始获取资源")
                        self.getResources(token: token)
                    } else {
                        self.isLoading = false
                        self.loginResult = "登录失败: 用户名或密码无效。"
                        LogManager.shared.addLog("登录失败：用户名或密码无效")
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.loginResult = "登录失败: \(error.localizedDescription)"
                    LogManager.shared.addLog("登录失败：\(error.localizedDescription)")
                }
            }
        }
    }
    
    private func getResources(token: String) {
        LoginService.shared.getResources(token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let resources):
                    self.resources = resources
                    self.errorMessage = ""
                    self.getReservationResult()
                case .failure(let error):
                    self.errorMessage = "获取班车信息失败: \(error.localizedDescription)"
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
                case .failure(let error):
                    self.errorMessage = "获取预约结果失败: \(error.localizedDescription)"
                }
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
}

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    let logout: () -> Void
    @Binding var isDarkMode: Bool
    
    var body: some View {
        TabView(selection: $currentTab) {
            ReservationResultView(isLoading: $isLoading, errorMessage: $errorMessage, reservationResult: $reservationResult)
                .tabItem {
                    Image(systemName: "ticket")
                    Text("预约结果")
                }
                .tag(0)
            
            SettingsView(logout: logout, isDarkMode: $isDarkMode)
                .tabItem {
                    Image(systemName: "gear")
                    Text("设置")
                }
                .tag(1)
        }
        .accentColor(.blue)
    }
}

struct ReservationResultView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var reservationResult: ReservationResult?
    @State private var showLogs: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("加载中...")
                    } else if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding()
                        
                        Button("显示日志") {
                            showLogs = true
                        }
                        .padding()
                    } else if let result = reservationResult {
                        Text(result.isPastBus ? "过期班车" : "未来班车")
                            .font(.headline)
                        
                        Text("班车名称: \(result.name)")
                        Text("发车时间: \(result.yaxis)")
                        
                        QRCodeView(qrCode: result.qrCode)
                            .frame(width: 200, height: 200)
                        
                        Text("请出示二维码乘车")
                            .font(.caption)
                    } else {
                        Text("暂无预约结果")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("预约结果")
            .sheet(isPresented: $showLogs) {
                LogView()
            }
        }
    }
}

struct LogView: View {
    @State private var logs: String = LogManager.shared.getLogs()
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(logs)
                    .padding()
            }
            .navigationTitle("日志")
            .navigationBarItems(trailing: Button("复制") {
                UIPasteboard.general.string = logs
            })
        }
    }
}

struct QRCodeView: View {
    let qrCode: String
    
    var body: some View {
        Image(uiImage: generateQRCode(from: qrCode))
            .interpolation(.none)
            .resizable()
            .scaledToFit()
    }
    
    func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }
        
        return UIImage(systemName: "xmark.circle") ?? UIImage()
    }
}

    struct SettingsView: View {
        let logout: () -> Void
        @Binding var isDarkMode: Bool
        @AppStorage("prevInterval") private var prevInterval: Int = UserDataManager.shared.getPrevInterval()
        @AppStorage("nextInterval") private var nextInterval: Int = UserDataManager.shared.getNextInterval()
        @AppStorage("criticalTime") private var criticalTime: Int = UserDataManager.shared.getCriticalTime()
        @AppStorage("flagMorningToYanyuan") private var flagMorningToYanyuan: Bool = UserDataManager.shared.getFlagMorningToYanyuan()
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("时间设置")) {
                        HStack {
                            Text("过期班车追溯")
                            Spacer()
                            TextField("分钟", value: $prevInterval, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("分钟")
                        }
                        
                        HStack {
                            Text("未来班车预约")
                            Spacer()
                            TextField("分钟", value: $nextInterval, formatter: NumberFormatter())
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                            Text("分钟")
                        }
                        
                        HStack {
                            Text("临界时刻")
                            Spacer()
                            Picker("", selection: $criticalTime) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text("\(hour):00").tag(hour)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    
                    Section(header: Text("方向设置")) {
                        Toggle("临界前往燕园", isOn: $flagMorningToYanyuan)
                    }
                    
                    Section(header: Text("外观")) {
                        Toggle("深色模式", isOn: $isDarkMode)
                    }
                    
                    Section {
                        Button(action: logout) {
                            Text("退出登录")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Section {
                        Button(action: resetToDefaultSettings) {
                            Text("恢复默认设置")
                        }
                    }
                }
                .navigationTitle("设置")
            }
        }
        
        private func resetToDefaultSettings() {
            UserDataManager.shared.resetToDefaultSettings()
            prevInterval = UserDataManager.shared.getPrevInterval()
            nextInterval = UserDataManager.shared.getNextInterval()
            criticalTime = UserDataManager.shared.getCriticalTime()
            flagMorningToYanyuan = UserDataManager.shared.getFlagMorningToYanyuan()
        }
    }

    struct LoginFormView: View {
        @Binding var username: String
        @Binding var password: String
        @Binding var loginResult: String
        let login: () -> Void
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("用户信息")) {
                        TextField("用户名", text: $username)
                            .autocapitalization(.none)
                        SecureField("密码", text: $password)
                    }
                    
                    Section {
                        Button(action: login) {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(username.isEmpty || password.isEmpty)
                    }
                    
                    if !loginResult.isEmpty {
                        Section {
                            Text(loginResult)
                                .foregroundColor(.red)
                        }
                    }
                }
                .navigationTitle("登录")
            }
        }
    }

    #Preview {
        LoginView()
    }
