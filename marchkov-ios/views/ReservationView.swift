import SwiftUI

struct BusInfo: Identifiable {
    let id = UUID()
    let time: String
    let direction: String
    let margin: Int
    let resourceName: String
    let date: String  // 新增日期字段
}

struct ReservationView: View {
    @State private var availableBuses: [String: [BusInfo]] = [:]
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else {
                    List {
                        ForEach(["去燕园", "去昌平"], id: \.self) { direction in
                            Section(header: Text(direction)) {
                                ForEach(availableBuses[direction] ?? [], id: \.id) { busInfo in
                                    BusButton(busInfo: busInfo)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("今日可预约班车")
            .background(gradientBackground.edgesIgnoringSafeArea(.all))
            .onAppear(perform: loadCachedBusInfo)
            .refreshable {
                await refreshBusInfo()
            }
        }
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
    
    private func loadCachedBusInfo() {
        if let cachedInfo = LoginService.shared.getCachedBusInfo() {
            let toYanyuan = processBusInfo(resources: cachedInfo.resources, ids: [2, 4], direction: "去燕园")
            let toChangping = processBusInfo(resources: cachedInfo.resources, ids: [5, 6, 7], direction: "去昌平")
            
            self.availableBuses = [
                "去燕园": toYanyuan,
                "去昌平": toChangping
            ]
            isLoading = false
        }
    }
    
    private func processBusInfo(resources: [LoginService.Resource], ids: [Int], direction: String) -> [BusInfo] {
        return resources.filter { ids.contains($0.id) }.flatMap { resource in
            resource.busInfos.map { 
                BusInfo(
                    time: $0.yaxis, 
                    direction: direction, 
                    margin: $0.margin, 
                    resourceName: resource.name,
                    date: $0.date
                ) 
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM月dd日"
        return formatter.string(from: date)
    }
    
    private func refreshBusInfo() async {
        isLoading = true
        // 这里可以添加刷新逻辑,例如重新从服务器获取数据
        // 完成后,调用loadCachedBusInfo()来更新视图
        loadCachedBusInfo()
    }
}

struct BusButton: View {
    let busInfo: BusInfo
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            // 这里可以添加预约逻辑
            print("预约 \(busInfo.direction) \(busInfo.time)")
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(busInfo.time)
                        .font(.headline)
                    Spacer()
                    Text(getBusRoute(for: busInfo.direction))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Text(busInfo.resourceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Text("余票: \(busInfo.margin)")
                        .font(.caption)
                        .foregroundColor(busInfo.margin > 5 ? .green : .orange)
                    Spacer()
                    Text(busInfo.date)  // 显示日期
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(BusButtonStyle(colorScheme: colorScheme))
    }

    private func getBusRoute(for direction: String) -> String {
        switch direction {
        case "去燕园":
            return "昌平 → 燕园"
        case "去昌平":
            return "燕园 → 昌平"
        default:
            return ""
        }
    }
}

struct BusButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

// 如果需要,可以将gradientBackground扩展移到这里
// extension View {
//     func gradientBackground(colorScheme: ColorScheme) -> LinearGradient {
//         // ... 实现 ...
//     }
// }
