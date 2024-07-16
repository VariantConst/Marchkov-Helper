import SwiftUI


struct SettingsView: View {
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @AppStorage("prevInterval") private var prevInterval: Int = UserDataManager.shared.getPrevInterval()
    @AppStorage("nextInterval") private var nextInterval: Int = UserDataManager.shared.getNextInterval()
    @AppStorage("criticalTime") private var criticalTime: Int = UserDataManager.shared.getCriticalTime()
    @AppStorage("flagMorningToYanyuan") private var flagMorningToYanyuan: Bool = UserDataManager.shared.getFlagMorningToYanyuan()
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
            
    
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
                            ForEach(6...22, id: \.self) { hour in
                                Text("\(hour):00").tag(hour)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section(header: Text("方向设置")) {
                    Toggle("上午去燕园", isOn: $flagMorningToYanyuan)
                }
                
                
                Section(header: Text("开发者选项")) {
                    Toggle("开发者模式", isOn: $isDeveloperMode)
                }
                
                Section(header: Text("外观")) {
                    Picker("主题模式", selection: $themeMode) {
                        ForEach(ThemeMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
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

