import SwiftUI


struct SettingsView: View {
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @AppStorage("prevInterval") private var prevInterval: Int = UserDataManager.shared.getPrevInterval()
    @AppStorage("nextInterval") private var nextInterval: Int = UserDataManager.shared.getNextInterval()
    @AppStorage("criticalTime") private var criticalTime: Int = UserDataManager.shared.getCriticalTime()
    @AppStorage("flagMorningToYanyuan") private var flagMorningToYanyuan: Bool = UserDataManager.shared.getFlagMorningToYanyuan()
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    @State private var criticalHour: Int = 6
    @State private var criticalMinute: Int = 30
            
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("时间设置").textCase(.uppercase)) {
                    TimeSettingView(value: $prevInterval, title: "过期班车追溯", range: 0...999)
                    TimeSettingView(value: $nextInterval, title: "未来班车预约", range: 0...999)
                    CriticalTimeSettingView(hour: $criticalHour, minute: $criticalMinute)
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

struct TimeSettingView: View {
    @Binding var value: Int
    let title: String
    let range: ClosedRange<Int>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Slider(value: Binding(get: {
                    Double(value)
                }, set: { newValue in
                    value = Int(newValue)
                }), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .accentColor(.blue)
                
                Text("\(value) 分钟")
                    .frame(minWidth: 70, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

struct CriticalTimeSettingView: View {
    @Binding var hour: Int
    @Binding var minute: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("临界时刻")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                Slider(value: Binding(get: {
                    Double(hour) + Double(minute) / 60
                }, set: { newValue in
                    hour = Int(newValue)
                    minute = Int((newValue.truncatingRemainder(dividingBy: 1) * 6).rounded()) * 10
                }), in: 6.5...22, step: 1/6)
                .accentColor(.blue)
                
                Text(String(format: "%02d:%02d", hour, minute))
                    .frame(minWidth: 70, alignment: .trailing)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
