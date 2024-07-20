import SwiftUI
import UIKit

func hapticFeedback() {
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
}

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
    
    private var cardBackgroundColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.white.opacity(0.5)
    }
    
    var body: some View {
        ZStack {
            gradientBackground.edgesIgnoringSafeArea(.all)
            
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
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
                Spacer()
                Picker("通勤方向", selection: $flagMorningToYanyuan.onChange { newValue in
                    hapticFeedback()  // 添加震动反馈
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
                    ElegantSlider(value: $prevInterval, title: "过期班车追溯", range: 1...114, unit: "分钟", step: 10, specialValues: [1, 114])
                    ElegantSlider(value: $nextInterval, title: "未来班车预约", range: 1...514, unit: "分钟", step: 10, specialValues: [1, 514])
                    ElegantSlider(
                        value: $criticalTime,
                        title: "临界时刻",
                        range: 360...1320,  // 调整范围
                        unit: "",
                        step: 60,  // 设置步长为 60 分钟
                        formatter: minutesToTimeString,
                        valueConverter: { Double($0) },
                        valueReverter: { Int($0) }
                    )
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
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        .animation(.easeInOut(duration: animationDuration), value: showAdvancedOptions)
    }

    private var generalSettingsSection: some View {
        VStack(alignment: .leading, spacing: 25) {
            SectionHeader(title: "通用设置")
            
            HStack {
                Text("主题模式")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
                Spacer()
                Picker("", selection: $themeMode.onChange { newValue in
                    hapticFeedback()  // 添加震动反馈
                }) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            ElegantToggle(isOn: $isDeveloperMode.onChange { newValue in
                hapticFeedback()  // 添加震动反馈
            }, title: "显示日志")
            
            ElegantToggle(isOn: Binding(
                get: { showAdvancedOptions },
                set: { newValue in
                    hapticFeedback()  // 添加震动反馈
                    withAnimation(newValue ? .spring(response: 0.35, dampingFraction: 0.7) : .none) {
                        showAdvancedOptions = newValue
                    }
                    animationDuration = newValue ? 0.35 : 0
                }
            ), title: "显示高级选项")
        }
        .padding(25)
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    }

    
    private func resetToDefaultSettings() {
        UserDataManager.shared.resetToDefaultSettings()
        prevInterval = UserDataManager.shared.getPrevInterval()
        nextInterval = UserDataManager.shared.getNextInterval()
        criticalTime = UserDataManager.shared.getCriticalTime()
        flagMorningToYanyuan = UserDataManager.shared.getFlagMorningToYanyuan()
        isDeveloperMode = false
        themeMode = .system
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
            if showAdvancedOptions {
                Button(action: { showResetConfirmation = true }) {
                    buttonContent(icon: "arrow.counterclockwise", text: "恢复默认设置")
                }
                .buttonStyle(FlatButtonStyle(isAccent: false))
            }

            Link(destination: URL(string: "https://github.com/VariantConst/3-2-1-Marchkov")!) {
                buttonContent(icon: "link", text: "审查应用源码")
            }
            .buttonStyle(FlatButtonStyle(isAccent: true))
        }
    }

    private func buttonContent(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.headline)
            Text(text)
                .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

        
    private func minutesToTimeString(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        return String(format: "%02d:%02d", hours, mins)
    }
}

struct FlatButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    var isAccent: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(textColor)
            .background(backgroundColor)
            .cornerRadius(15)
            .shadow(color: shadowColor, radius: 3, x: 0, y: 2)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
    
    private var backgroundColor: Color {
        if isAccent {
            return colorScheme == .dark ? Color(hex: "#1B263B") : Color(hex: "#4A90E2")
        } else {
            return colorScheme == .dark ? Color(hex: "#2C3E50") : Color(hex: "#D3D3D3") // 调整为高雅浅灰色
        }
    }
    
    private var textColor: Color {
        if isAccent {
            return .white
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1)
    }
}


struct ElegantSlider: View {
    @Binding var value: Int
    let title: String
    let range: ClosedRange<Int>
    let unit: String
    let step: Int
    var specialValues: [Int] = []
    var formatter: ((Int) -> String)? = nil
    var valueConverter: ((Int) -> Double)? = nil
    var valueReverter: ((Double) -> Int)? = nil
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            titleView
            sliderWithValueView
        }
    }
    
    private var titleView: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .foregroundColor(textColor)
    }
    
    private var sliderWithValueView: some View {
        HStack {
            sliderView
            valueLabel
        }
    }
    
    private var sliderView: some View {
        Slider(value: sliderBinding, in: sliderRange, step: Double(step))
            .accentColor(accentColor)
            .onChange(of: sliderBinding.wrappedValue, initial: true) { oldValue, newValue in
                if newValue != oldValue {
                    hapticFeedback()
                }
            }
    }
    
    private var valueLabel: some View {
        Text(formattedValue)
            .font(.system(.body, design: .rounded).weight(.medium))
            .foregroundColor(textColor)
            .frame(width: 80, alignment: .trailing)
    }
    
    private var sliderBinding: Binding<Double> {
        Binding(
            get: { valueConverter?(value) ?? Double(value) },
            set: { newValue in
                let convertedValue = valueReverter?(newValue) ?? Int(newValue)
                let lowerBound = range.lowerBound
                let upperBound = range.upperBound
                
                // 处理最小值、最大值和步长
                if convertedValue <= lowerBound + step / 2 {
                    value = lowerBound
                } else if convertedValue >= upperBound - step / 2 {
                    value = upperBound
                } else {
                    let roundedValue = round(Double(convertedValue) / Double(step)) * Double(step)
                    value = Int(roundedValue)
                }
            }
        )
    }

    private var sliderRange: ClosedRange<Double> {
        let lowerBound = valueConverter?(range.lowerBound) ?? Double(range.lowerBound)
        let upperBound = valueConverter?(range.upperBound) ?? Double(range.upperBound)
        return lowerBound...upperBound
    }
    
    private var formattedValue: String {
        formatter?(value) ?? "\(value)\(unit)"
    }
}


struct SectionHeader: View {
    let title: String
    @Environment(\.colorScheme) private var colorScheme
    
    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }
    
    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundColor(textColor)
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
                .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
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

struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        return UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}
