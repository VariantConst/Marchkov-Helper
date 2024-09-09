import SwiftUI

struct BusInfo: Identifiable {
    let id = UUID()
    let time: String
    let direction: String
    let margin: Int
    let resourceName: String
    let date: String  // 新增日期字段
    let timeId: Int  // 新增 timeId 字段
}

struct ReservationView: View {
    @State private var availableBuses: [String: [BusInfo]] = [:]
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedDate = Date()  // 新增：用于选择日期
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else {
                    VStack {
                        Picker("选择日期", selection: $selectedDate) {
                            Text("今天").tag(Date())
                            Text("明天").tag(Calendar.current.date(byAdding: .day, value: 1, to: Date())!)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding()
                        
                        List {
                            ForEach(["去燕园", "去昌平"], id: \.self) { direction in
                                Section(header: Text(direction)) {
                                    ForEach(filteredBuses(for: direction), id: \.id) { busInfo in
                                        BusButton(busInfo: busInfo, reserveAction: reserveBus)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("可预约班车")
            .background(gradientBackground.edgesIgnoringSafeArea(.all))
            .onAppear(perform: loadCachedBusInfo)
            .refreshable {
                await refreshBusInfo()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("预约结果"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
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
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        return resources.filter { ids.contains($0.id) }.flatMap { resource in
            resource.busInfos.compactMap { busInfo in
                guard let date = dateFromString(busInfo.date),
                      (calendar.isDate(date, inSameDayAs: today) || calendar.isDate(date, inSameDayAs: tomorrow)),
                      busInfo.margin > 0 else {
                    return nil
                }
                return BusInfo(
                    time: busInfo.yaxis,
                    direction: direction,
                    margin: busInfo.margin,
                    resourceName: resource.name,
                    date: busInfo.date,
                    timeId: busInfo.timeId
                )
            }
        }
    }
    
    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func filteredBuses(for direction: String) -> [BusInfo] {
        let calendar = Calendar.current
        return availableBuses[direction]?.filter { busInfo in
            guard let date = dateFromString(busInfo.date) else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        } ?? []
    }
    
    private func refreshBusInfo() async {
        isLoading = true
        // 这里可以添加刷新逻辑,例如重新从服务器获取数据
        // 完成后,调用loadCachedBusInfo()来更新视图
        loadCachedBusInfo()
    }
    
    private func reserveBus(busInfo: BusInfo) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/launch")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let resourceId = getResourceId(for: busInfo.direction)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let formattedDate = dateFormatter.string(from: Date())
        
        let queryItems = [
            URLQueryItem(name: "resource_id", value: resourceId),
            URLQueryItem(name: "data", value: "[{\"date\": \"\(formattedDate)\", \"period\": \(busInfo.timeId), \"sub_resource_id\": 0}]")
        ]
        request.url?.append(queryItems: queryItems)
        
        // 在日志中显示解码后的完整请求URL
        if let fullURL = request.url?.absoluteString,
           let decodedURL = fullURL.removingPercentEncoding {
            LogManager.shared.addLog("发起预约请求（解码后）：\(decodedURL)")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    self.alertMessage = "预约失败：\(error.localizedDescription)"
                    LogManager.shared.addLog("预约失败：\(error.localizedDescription)")
                } else if let data = data, let responseString = String(data: data, encoding: .utf8) {
                    self.alertMessage = "预约结果：\(responseString)"
                    LogManager.shared.addLog("预约响应：\(responseString)")
                } else {
                    self.alertMessage = "预约失败：未知错误"
                    LogManager.shared.addLog("预约失败：未知错误")
                }
                self.showAlert = true
            }
        }.resume()
    }
    
    private func getResourceId(for direction: String) -> String {
        switch direction {
        case "去燕园":
            return "2"
        case "去昌平":
            return "7"
        default:
            return "0"
        }
    }
}

struct BusButton: View {
    let busInfo: BusInfo
    let reserveAction: (BusInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            reserveAction(busInfo)
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
                    Text(busInfo.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Text("Time ID: \(busInfo.timeId)")  // 添加 timeId 显示
                    .font(.caption)
                    .foregroundColor(.secondary)
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
