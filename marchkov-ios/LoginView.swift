import SwiftUI

struct LoginView: View {
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var loginResult: String = ""
    @State private var isLoggedIn: Bool = false
    @State private var currentTab: Int = 0
    @State private var isLoading: Bool = false
    @State private var resources: [LoginService.Resource] = []
    @State private var errorMessage: String = ""
    @AppStorage("isDarkMode") private var isDarkMode = false
    
    var body: some View {
        Group {
            if isLoggedIn {
                MainTabView(
                    currentTab: $currentTab,
                    isLoading: $isLoading,
                    errorMessage: $errorMessage,
                    resources: $resources,
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
        LoginService.login(username: username, password: password) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let loginResponse):
                    if loginResponse.success, let token = loginResponse.token {
                        self.loginResult = "Login successful!"
                        self.isLoggedIn = true
                        self.getResources(token: token)
                    } else {
                        self.isLoading = false
                        self.loginResult = "Login failed: Invalid username or password."
                    }
                case .failure(let error):
                    self.isLoading = false
                    self.loginResult = "Login failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getResources(token: String) {
        LoginService.getResources(token: token) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let resources):
                    self.resources = resources
                    self.errorMessage = ""
                case .failure(let error):
                    self.errorMessage = "Failed to fetch bus information: \(error.localizedDescription)"
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
    }
}

struct MainTabView: View {
    @Binding var currentTab: Int
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var resources: [LoginService.Resource]
    let logout: () -> Void
    @Binding var isDarkMode: Bool
    
    var body: some View {
        TabView(selection: $currentTab) {
            BusInfoView(isLoading: $isLoading, errorMessage: $errorMessage, resources: $resources)
                .tabItem {
                    Image(systemName: "bus")
                    Text("班车信息")
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

struct BusInfoView: View {
    @Binding var isLoading: Bool
    @Binding var errorMessage: String
    @Binding var resources: [LoginService.Resource]
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else {
                    List {
                        ForEach(resources, id: \.id) { resource in
                            Section(header: Text(resource.name).font(.headline)) {
                                ForEach(resource.busInfos, id: \.timeId) { busInfo in
                                    BusInfoRow(busInfo: busInfo)
                                }
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            }
            .navigationTitle("班车信息")
        }
    }
}

struct BusInfoRow: View {
    let busInfo: LoginService.BusInfo
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(busInfo.yaxis)
                    .font(.headline)
                Text(busInfo.date)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("可用座位: \(busInfo.margin)")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
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
                            ForEach(6...23, id: \.self) { hour in
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
