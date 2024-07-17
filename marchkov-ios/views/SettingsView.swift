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
    @AppStorage("commuteDirection") private var commuteDirection: CommuteDirection = .morningToYanyuan
    @AppStorage("isDeveloperMode") private var isDeveloperMode: Bool = false
    
    @State private var isResetAlertPresented = false
    @Environment(\.colorScheme) private var colorScheme
    
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
                    busSettingsSection
                    generalSettingsSection
                    actionButtonsSection
                }
                .padding(.horizontal)
                .padding(.vertical, 30)
            }
        }
        .alert(isPresented: $isResetAlertPresented) {
            Alert(
                title: Text("确认重置"),
                message: Text("您确定要恢复默认设置吗？这将重置所有设置项。"),
                primaryButton: .destructive(Text("重置")) {
                    resetToDefaultSettings()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    private var busSettingsSection: some View {
        VStack(alignment: .leading, spacing: 25) {
            SectionHeader(title: "班车设置")
            
            VStack(alignment: .leading, spacing: 15) {
                Text("通勤方向")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(Color(.secondaryLabel))
                
                Picker("通勤方向", selection: $commuteDirection) {
                    ForEach(CommuteDirection.allCases, id: \.self) { direction in
                        Text(direction.rawValue).tag(direction)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            ElegantSlider(value: $prevInterval, title: "过期班车追溯", range: 0...114, unit: "分钟")
            ElegantSlider(value: $nextInterval, title: "未来班车预约", range: 0...514, unit: "分钟")
            ElegantSlider(value: $criticalTime, title: "临界时刻", range: 0...1439, unit: "", formatter: minutesToTimeString)
        }
        .padding(25)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
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
            
            ElegantToggle(isOn: $isDeveloperMode, title: "开发者模式")
        }
        .padding(25)
        .background(cardBackgroundColor)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
    }
    
    private var actionButtonsSection: some View {
        VStack(spacing: 20) {
            Button(action: { isResetAlertPresented = true }) {
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
            
            Button(action: logout) {
                Text("退出登录")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(15)
            }
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05), radius: 15, x: 0, y: 8)
    }
    
    private func resetToDefaultSettings() {
        UserDataManager.shared.resetToDefaultSettings()
        prevInterval = UserDataManager.shared.getPrevInterval()
        nextInterval = UserDataManager.shared.getNextInterval()
        criticalTime = UserDataManager.shared.getCriticalTime()
        commuteDirection = .morningToYanyuan
        isDeveloperMode = false
        themeMode = .system
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
