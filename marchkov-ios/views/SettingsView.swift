import SwiftUI

enum CommuteDirection: String, CaseIterable {
    case morningToYanyuan = "上午去燕园"
    case morningToChangping = "上午去昌平"
}

struct SettingsView: View {
    let logout: () -> Void
    @Binding var themeMode: ThemeMode
    @AppStorage("prevInterval") private var prevInterval: Int = UserDataManager.shared.getPrevInterval()
    @AppStorage("nextInterval") private var nextInterval: Int = UserDataManager.shared.getNextInterval()
    @AppStorage("criticalTime") private var criticalTime: Int = UserDataManager.shared.getCriticalTime()
    @State private var flagMorningToYanyuan: Bool = UserDataManager.shared.getFlagMorningToYanyuan()
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    @AppStorage("showAdvancedOptions") private var showAdvancedOptions: Bool = false
    
    @State private var showLogoutConfirmation = false
    @State private var showResetConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationDuration: Double = 0.3
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 18/255, green: 18/255, blue: 22/255) : Color(red: 245/255, green: 245/255, blue: 250/255)
    }
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color(red: 30/255, green: 30/255, blue: 35/255) : .white
    }
    
    var body: some View {
        ZStack {
            backgroundColor.edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 30) {
                    UserInfoCard(
                        userInfo: getUserInfo(),
                        logout: logout,
                        showLogoutConfirmation: $showLogoutConfirmation
                    )
                    generalSettingsSection
                    busSettingsSection
                    actionButtonsSection
                }
                .padding(.horizontal)
                .padding(.vertical, 30)
            }
        }
        .confirmationDialog("确认退出登录", isPresented: $showLogoutConfirmation, titleVisibility: .visible) {
            Button("退出登录", role: .destructive, action: logout)
            Button("取消", role: .cancel) { }
        } message: {
            Text("您的班车设置将被保留。")
        }
        .confirmationDialog("确认重置设置", isPresented: $showResetConfirmation, titleVisibility: .visible) {
            Button("重置", role: .destructive) {
                resetToDefaultSettings()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("您确定要恢复默认设置吗？这将重置所有设置项。")
        }
    }
    
    private func getUserInfo() -> UserInfo {
        let userInfo = UserDataManager.shared.getUserInfo()
        return UserInfo(
            fullName: userInfo.fullName.isEmpty ? "马池口🐮🐴" : userInfo.fullName,
            studentId: userInfo.studentId.isEmpty ? (UserDefaults.standard.string(forKey: "username") ?? "未知学号") : userInfo.studentId,
            department: userInfo.department.isEmpty ? "这个需要你自己衡量！" : userInfo.department
        )
    }
    
    private var busSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "班车设置")
                .padding(.bottom, 15)

            HStack {
                Text("通勤方向")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(.secondaryLabel))
                Spacer()
                Picker("通勤方向", selection: $flagMorningToYanyuan.onChange { newValue in
                    UserDefaults.standard.set(newValue, forKey: "flagMorningToYanyuan")
                }) {
                    Text("上午去燕园").tag(true)
                    Text("上午去昌平").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding(.bottom, showAdvancedOptions ? 15 : 0)

            if showAdvancedOptions {
                VStack(spacing: 15) {
                    ElegantSlider(value: $prevInterval, title: "过期班车追溯", range: 0...114, unit: "分钟")
                    ElegantSlider(value: $nextInterval, title: "未来班车预约", range: 0...514, unit: "分钟")
                    ElegantSlider(value: $criticalTime, title: "临界时刻", range: 0...1439, unit: "", formatter: minutesToTimeString)
                }
                .padding(.top, 15)
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)).combined(with: .offset(y: -10)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(25)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
        .animation(.easeInOut(duration: animationDuration), value: showAdvancedOptions)
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 25) {
            SectionHeader(title: "通用设置")
            
            HStack {
                Text("主题模式")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Picker("", selection: $themeMode) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            ElegantToggle(isOn: Binding(
                get: { showAdvancedOptions },
                set: { newValue in
                    withAnimation(newValue ? .spring(response: 0.35, dampingFraction: 0.7) : .none) {
                        showAdvancedOptions = newValue
                    }
                    // Set animation duration for next toggle
                    animationDuration = newValue ? 0.35 : 0
                }
            ), title: "显示高级选项")
            
            ElegantToggle(isOn: $isDeveloperMode, title: "显示日志")
        }
        .padding(25)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
    }
    
    private func resetToDefaultSettings() {
        UserDataManager.shared.resetToDefaultSettings()
        prevInterval = UserDataManager.shared.getPrevInterval()
        nextInterval = UserDataManager.shared.getNextInterval()
        criticalTime = UserDataManager.shared.getCriticalTime()
        flagMorningToYanyuan = UserDataManager.shared.getFlagMorningToYanyuan()
        isDeveloperMode = false
        showAdvancedOptions = false
        themeMode = .system
    }
    
    private var actionButtonsSection: some View {
        Button(action: { showResetConfirmation = true }) {
            Text("恢复默认设置")
                .font(.headline)
                .foregroundColor(accentColor)
                .frame(maxWidth: .infinity)
                .padding()
                .background(cardBackgroundColor)
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(accentColor, lineWidth: 1)
                )
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
    }
    
    private func minutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
}

struct SectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? Color(red: 220/255, green: 220/255, blue: 230/255) : Color(red: 60/255, green: 60/255, blue: 70/255)
    }
    
    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundColor(textColor)
    }
}

struct ElegantSlider: View {
    @Binding var value: Int
    let title: String
    let range: ClosedRange<Int>
    let unit: String
    var formatter: ((Int) -> String)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color(.secondaryLabel))
            
            HStack {
                Slider(value: Binding(
                    get: { Double(value) },
                    set: { value = Int($0) }
                ), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
                .accentColor(accentColor)
                
                Text(formatter != nil ? formatter!(value) : "\(value)\(unit)")
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundColor(accentColor)
                    .frame(width: 80, alignment: .trailing)
            }
        }
    }
}

struct ElegantToggle: View {
    @Binding var isOn: Bool
    let title: String
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundColor(Color(.label))
        }
        .toggleStyle(SwitchToggleStyle(tint: accentColor))
    }
}

extension Binding {
    func onChange(_ handler: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(
            get: { self.wrappedValue },
            set: { newValue in
                self.wrappedValue = newValue
                handler(newValue)
            }
        )
    }
}
