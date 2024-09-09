import SwiftUI

struct BusInfo: Identifiable {
    let id = UUID()
    let time: String
    let direction: String
    let margin: Int
    let resourceName: String
    let date: String
    let timeId: Int
    let resourceId: Int
    var isReserved: Bool = false
    var hallAppointmentDataId: Int?
    var appointmentId: Int?
}

struct ReservationView: View {
    @State private var availableBuses: [String: [BusInfo]] = [:]
    @State private var isLoading = true
    @Environment(\.colorScheme) private var colorScheme
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedDate = Date()
    
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
            .onAppear(perform: {
                loadCachedBusInfo()
                fetchReservationStatus()
            })
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
            LogManager.shared.addLog("加载缓存数据：\(cachedInfo)")
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
                    timeId: busInfo.timeId,
                    resourceId: resource.id
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
        let filteredBuses = availableBuses[direction]?.filter { busInfo in
            guard let date = dateFromString(busInfo.date) else { return false }
            return calendar.isDate(date, inSameDayAs: selectedDate)
        } ?? []
        
        // 按时间排序
        return filteredBuses.sorted { (bus1, bus2) -> Bool in
            return bus1.time < bus2.time
        }
    }
    
    private func refreshBusInfo() async {
        isLoading = true
        // 这里可以添加刷新逻辑,例如重新从服务器获取数据
        // 完成后,调用loadCachedBusInfo()来更新视图
        loadCachedBusInfo()
    }
    
    private func fetchReservationStatus() {
        guard let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&status=2") else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let reservationInfo = try? JSONDecoder().decode(ReservationResponse.self, from: data) {
                DispatchQueue.main.async {
                    self.updateBusInfoWithReservation(reservationInfo)
                }
            }
        }.resume()
    }
    
    private func updateBusInfoWithReservation(_ reservationInfo: ReservationResponse) {
        for (direction, buses) in availableBuses {
            availableBuses[direction] = buses.map { bus in
                var updatedBus = bus
                if let matchedReservation = reservationInfo.d.data.first(where: {
                    $0.resource_id == bus.resourceId &&
                    $0.periodList.contains(where: { $0.time == "\(bus.date) \(bus.time)" })
                }) {
                    updatedBus.isReserved = true
                    updatedBus.hallAppointmentDataId = matchedReservation.hall_appointment_data_id
                    updatedBus.appointmentId = matchedReservation.id
                }
                return updatedBus
            }
        }
    }
    
    private func reserveBus(busInfo: BusInfo) {
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/launch")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        let resourceId = String(busInfo.resourceId)
        
        let data = "[{\"date\": \"\(busInfo.date)\", \"period\": \(busInfo.timeId), \"sub_resource_id\": 0}]"
        
        let postData = "resource_id=\(resourceId)&data=\(data)"
        let encodedPostData = postData.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        request.httpBody = encodedPostData.data(using: .utf8)
        
        LogManager.shared.addLog("发起预约请求（解码后）：URL: \(url.absoluteString), Body: \(postData)")
        
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.fetchReservationStatus()
                }
            }
        }.resume()
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
                HStack {
                    Text("Time ID: \(busInfo.timeId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Resource ID: \(busInfo.resourceId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if busInfo.isReserved {
                    Text("已预约")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(BusButtonStyle(colorScheme: colorScheme, isReserved: busInfo.isReserved))
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
    let isReserved: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(backgroundColor)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
    
    private var backgroundColor: Color {
        if isReserved {
            return colorScheme == .dark ? Color.green.opacity(0.3) : Color.green.opacity(0.1)
        } else {
            return colorScheme == .dark ? Color.gray.opacity(0.3) : Color.white
        }
    }
}

struct ReservationResponse: Codable {
    let e: Int
    let m: String
    let d: ReservationData
}

struct ReservationData: Codable {
    let total: Int
    let data: [ReservationItem]
}

struct ReservationItem: Codable {
    let id: Int
    let resource_id: Int
    let hall_appointment_data_id: Int
    let periodList: [PeriodInfo]
}

struct PeriodInfo: Codable {
    let id: Int
    let time: String
    let status: Int
}
