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
    @State private var showLogoutConfirmation = false
    @State private var showResetConfirmation = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationDuration: Double = 0.3
    @State private var showSettingsInfo = false
    
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
                resetBusSettings()
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("您确定要恢复默认班车设置吗？")
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
            HStack {
                SectionHeader(title: "班车设置")
                Button(action: { showSettingsInfo = true }) {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(accentColor)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                }
                Spacer()
                Button(action: { showResetConfirmation = true }) {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundColor(accentColor)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.bottom, 15)

            HStack {
                Text("通勤方向")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
                Spacer()
                Picker("通勤方向", selection: $flagMorningToYanyuan.onChange { newValue in
                    hapticFeedback()
                    UserDefaults.standard.set(newValue, forKey: "flagMorningToYanyuan")
                }) {
                    Text("上午去燕园").tag(true)
                    Text("上午去昌平").tag(false)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            .padding(.bottom, 15)

            VStack(spacing: 15) {
                ElegantSlider(value: $prevInterval, title: "过期班车追溯", range: 1...114, unit: "分钟", step: 10, specialValues: [1, 114])
                ElegantSlider(value: $nextInterval, title: "未来班车预约", range: 1...514, unit: "分钟", step: 10, specialValues: [1, 514])
                ElegantSlider(
                    value: $criticalTime,
                    title: "临界时刻",
                    range: 360...1320,
                    unit: "",
                    step: 60,
                    formatter: minutesToTimeString,
                    valueConverter: { Double($0) },
                    valueReverter: { Int($0) }
                )
            }
        }
        .padding(25)
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
        .sheet(isPresented: $showSettingsInfo) {
            BusSettingsInfoView()
        }
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
                    hapticFeedback()
                }) {
                    ForEach(ThemeMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }
            
            ElegantToggle(isOn: $isDeveloperMode.onChange { newValue in
                hapticFeedback()
            }, title: "显示日志")
        }
        .padding(25)
        .background(BlurView(style: .systemMaterial))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
    }
    
    private func resetBusSettings() {
        UserDataManager.shared.resetToDefaultSettings()
        prevInterval = UserDataManager.shared.getPrevInterval()
        nextInterval = UserDataManager.shared.getNextInterval()
        criticalTime = UserDataManager.shared.getCriticalTime()
        flagMorningToYanyuan = UserDataManager.shared.getFlagMorningToYanyuan()
        
        // 清空历史缓存
        UserDefaults.standard.removeObject(forKey: "cachedBusInfo")
        UserDefaults.standard.removeObject(forKey: "cachedRideHistory")
        
        // 可选：添加日志
        LogManager.shared.addLog("已重置班车设置并清空历史缓存")
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
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

struct BusSettingsInfoView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.95, green: 0.95, blue: 0.95)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white : Color.black
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                backgroundColor.edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 20) {
                        infoSection(title: "通勤方向", description: "选择您的主要通勤方向。默认设置为'上午去燕园'，即14点前去燕园，14点后回昌平。", example: "如果您选择'上午回昌平'，则会相反。")
                        infoSection(title: "过期班车追溯", description: "设置可查看多久之前的过期班车。默认为10分钟，范围：1-114分钟。", example: "例如，设置为30分钟时，您可以查看半小时内已经发车的班车信息。")
                        infoSection(title: "未来班车预约", description: "设置可预约多久之后的未来班车。默认为60分钟，范围：1-514分钟。", example: "例如，设置为120分钟时，您可以预约两小时内即将发车的班车。")
                        infoSection(title: "临界时刻", description: "设置一天中转换通勤方向的时间点。默认为14:00，范围：06:00-22:00。", example: "例如，如果您设置为12:00，则在中午12点前的班车被视为去程，12点后的班车被视为返程。")
                        
                        defaultSettingTip
                    }
                    .padding()
                }
            }
            .navigationBarTitle("班车设置说明", displayMode: .inline)
            .navigationBarItems(trailing: Button("关闭") {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .accentColor(accentColor)
    }
    
    private func infoSection(title: String, description: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundColor(accentColor)
            
            Text(description)
                .font(.body)
                .foregroundColor(textColor.opacity(0.8))
            
            exampleView(example)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.white)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
    }
    
    private func exampleView(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundColor(accentColor.opacity(0.8))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(accentColor.opacity(0.1))
            )
    }
    
    private var defaultSettingTip: some View {
        HStack(spacing: 12) {
            Image(systemName: "lightbulb")
                .foregroundColor(accentColor)
            Text("提示：如果不确定如何设置，建议保留默认设置。")
                .font(.footnote)
                .foregroundColor(textColor.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .stroke(accentColor.opacity(0.3), lineWidth: 1)
        )
    }
}
