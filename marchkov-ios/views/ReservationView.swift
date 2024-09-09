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
    @State private var isRefreshing = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var currentPage = 0 // 0 表示今天，1 表示明天
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("加载中...")
                } else {
                    VStack(spacing: 0) {
                        // 自定义的日期选择器
                        DateSelectorView(currentPage: $currentPage)
                            .padding(.bottom, 8)  // 添加加一些底部间距
                        
                        // 使用 TabView 来实现滑动效果
                        TabView(selection: $currentPage) {
                            busListView(for: Date()).tag(0)
                            busListView(for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!).tag(1)
                        }
                        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    let threshold: CGFloat = 50
                                    if value.translation.width > threshold {
                                        withAnimation { currentPage = max(0, currentPage - 1) }
                                    } else if value.translation.width < -threshold {
                                        withAnimation { currentPage = min(1, currentPage + 1) }
                                    }
                                }
                        )
                    }
                }
            }
            .onAppear(perform: {
                loadCachedBusInfo()
                Task {
                    do {
                        try await fetchReservationStatus()
                    } catch {
                        await MainActor.run {
                            alertMessage = "获取预约状态失败：\(error.localizedDescription)"
                            showAlert = true
                        }
                    }
                }
            })
            .refreshable {
                await refreshReservationStatus()
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("预约结果"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
            }
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
    
    private func filteredBuses(for direction: String, on date: Date) -> [BusInfo] {
        var calendar = Calendar.current
        let timeZone = TimeZone(identifier: "Asia/Shanghai")!
        calendar.timeZone = timeZone
        
        let now = Date()
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let filteredBuses = availableBuses[direction]?.filter { busInfo in
            guard let busDate = dateFromString(busInfo.date, in: timeZone) else { return false }
            
            if calendar.isDate(date, inSameDayAs: now) {
                // 对于今天的班车，只显示未过期的
                let busTime = calendar.date(bySettingHour: Int(busInfo.time.prefix(2)) ?? 0,
                                            minute: Int(busInfo.time.suffix(2)) ?? 0,
                                            second: 0, of: busDate) ?? busDate
                return busTime > now && busTime >= startOfDay && busTime < endOfDay
            } else {
                // 对于非今天的班车，确保日期在指定日期范围内
                return busDate >= startOfDay && busDate < endOfDay
            }
        } ?? []
        
        return filteredBuses.sorted { $0.time < $1.time }
    }
    
    // 更新 dateFromString 函数以支持时区
    private func dateFromString(_ dateString: String, in timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.date(from: dateString)
    }
    
    private func refreshReservationStatus() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            try await fetchReservationStatus()
        } catch {
            await MainActor.run {
                alertMessage = "刷新失败：\(error.localizedDescription)"
                showAlert = true
            }
        }
    }
    
    private func fetchReservationStatus() async throws {
        guard let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/my-list-time?p=1&status=2") else {
            throw NSError(domain: "无效的URL", code: 0, userInfo: nil)
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let reservationInfo = try JSONDecoder().decode(ReservationResponse.self, from: data)

        await MainActor.run {
            updateBusInfoWithReservation(reservationInfo)
        }
        LogManager.shared.addLog("成功获取预约状态：\(reservationInfo)")
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
                } else {
                    updatedBus.isReserved = false
                    updatedBus.hallAppointmentDataId = nil
                    updatedBus.appointmentId = nil
                }
                return updatedBus
            }
        }
    }
    
    private func reserveBus(busInfo: BusInfo) {
        Task {
            do {
                try await performReservation(busInfo: busInfo)
            } catch {
                await MainActor.run {
                    self.alertMessage = "预约失败：\(error.localizedDescription)"
                    self.showAlert = true
                    self.playErrorHaptic()
                }
                LogManager.shared.addLog("预约失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func performReservation(busInfo: BusInfo) async throws {
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
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        
        if let responseString = String(data: responseData, encoding: .utf8) {
            if responseString.contains("\"m\":\"操作成功\"") {
                await MainActor.run {
                    self.playSuccessHaptic()
                    self.updateBusInfoAfterSuccessfulReservation(busInfo)
                }
                LogManager.shared.addLog("预约成功：\(responseString)")
            } else {
                throw NSError(domain: "预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: responseString])
            }
        } else {
            throw NSError(domain: "预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])
        }
        
        // 无论成功与否，都获取最新的预约状态
        try await fetchReservationStatus()
    }
    
    private func cancelReservation(busInfo: BusInfo) {
        Task {
            do {
                try await performCancellation(busInfo: busInfo)
            } catch {
                await MainActor.run {
                    self.alertMessage = "取消预约失败：\(error.localizedDescription)"
                    self.showAlert = true
                    self.playErrorHaptic()
                }
                LogManager.shared.addLog("取消预约失败：\(error.localizedDescription)")
            }
        }
    }
    
    private func performCancellation(busInfo: BusInfo) async throws {
        guard let appointmentId = busInfo.appointmentId,
              let hallAppointmentDataId = busInfo.hallAppointmentDataId else {
            throw NSError(domain: "取消预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: "缺少必要信息"])
        }
        
        let url = URL(string: "https://wproc.pku.edu.cn/site/reservation/single-time-cancel")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let postData = "appointment_id=\(appointmentId)&data_id[0]=\(hallAppointmentDataId)"
        request.httpBody = postData.data(using: .utf8)
        
        LogManager.shared.addLog("发起取消预约请求：URL: \(url.absoluteString), Body: \(postData)")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.contains("\"m\":\"操作成功\"") {
                await MainActor.run {
                    self.playSuccessHaptic()
                    self.updateBusInfoAfterSuccessfulCancellation(busInfo)
                }
                LogManager.shared.addLog("取消预约成功：\(responseString)")
            } else {
                throw NSError(domain: "取消预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: responseString])
            }
        } else {
            throw NSError(domain: "取消预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解析响应"])
        }
        
        // 无论成功与否，都获取最新的预约状态
        try await fetchReservationStatus()
    }
    
    private func updateBusInfoAfterSuccessfulReservation(_ busInfo: BusInfo) {
        if let index = availableBuses[busInfo.direction]?.firstIndex(where: { $0.id == busInfo.id }) {
            availableBuses[busInfo.direction]?[index].isReserved = true
        }
    }
    
    private func updateBusInfoAfterSuccessfulCancellation(_ busInfo: BusInfo) {
        if let index = availableBuses[busInfo.direction]?.firstIndex(where: { $0.id == busInfo.id }) {
            availableBuses[busInfo.direction]?[index].isReserved = false
            availableBuses[busInfo.direction]?[index].hallAppointmentDataId = nil
            availableBuses[busInfo.direction]?[index].appointmentId = nil
        }
    }
    
    private func playSuccessHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    private func playErrorHaptic() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error)
    }
    
    private func busListView(for date: Date) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(["去燕园", "去昌平"], id: \.self) { direction in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(direction)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .padding(.leading)
                            .padding(.top, 8)
                        
                        ForEach(filteredBuses(for: direction, on: date), id: \.id) { busInfo in
                            BusButton(busInfo: busInfo, reserveAction: reserveBus, cancelAction: cancelReservation)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

struct DateSelectorView: View {
    @Binding var currentPage: Int
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            dateButton(title: "今", tag: 0)
            dateButton(title: "明", tag: 1)
        }
        .frame(height: 40)
        .padding(.horizontal, 12) // 增加平内边距
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: 5, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(borderColor, lineWidth: 1)
        )
        .padding(.horizontal)
        .padding(.top)
    }
    
    private func dateButton(title: String, tag: Int) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                currentPage = tag
            }
        }) {
            Text(title)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(currentPage == tag ? .white : textColor)
                .frame(maxWidth: .infinity) // 使用最大宽度
                .frame(height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(currentPage == tag ? accentColor : Color.clear)
                        .shadow(color: currentPage == tag ? accentColor.opacity(0.3) : Color.clear, radius: 3, x: 0, y: 2)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(.systemGray6) : Color.white
    }
    
    private var borderColor: Color {
        colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1)
    }
    
    private var textColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.8) : Color.black.opacity(0.6)
    }
    
    private var accentColor: Color {
        Color.accentColor
    }
}

struct BusButton: View {
    let busInfo: BusInfo
    let reserveAction: (BusInfo) -> Void
    let cancelAction: (BusInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: {
            if busInfo.isReserved {
                cancelAction(busInfo)
            } else {
                reserveAction(busInfo)
            }
            playHaptic()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(busInfo.time)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Text(busInfo.resourceName)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(colorScheme == .dark ? Color(red: 0.8, green: 0.8, blue: 0.8) : Color(red: 0.4, green: 0.4, blue: 0.4))
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: busInfo.isReserved ? "checkmark.circle.fill" : "clock")
                        .foregroundColor(busInfo.isReserved ? accentColor : (colorScheme == .dark ? .white.opacity(0.8) : .gray))
                    Text(busInfo.isReserved ? "已预约" : "可预约")
                        .font(.caption.weight(.medium))
                        .foregroundColor(busInfo.isReserved ? accentColor : (colorScheme == .dark ? .white.opacity(0.8) : .gray))
                }
            }
            .padding()
        }
        .buttonStyle(BusButtonStyle(colorScheme: colorScheme, isReserved: busInfo.isReserved))
    }

    private func playHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color(red: 0.2, green: 0.5, blue: 0.8)
    }
}

struct BusButtonStyle: ButtonStyle {
    let colorScheme: ColorScheme
    let isReserved: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(borderColor, lineWidth: 2)
            )
            .shadow(color: shadowColor, radius: 5, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
    
    private var backgroundColor: Color {
        isReserved ? (colorScheme == .dark ? Color(red: 0.4, green: 0.8, blue: 1.0).opacity(0.2) : Color(red: 0.2, green: 0.5, blue: 0.8).opacity(0.1)) :
                     (colorScheme == .dark ? Color(.systemGray6) : Color.white)
    }
    
    private var borderColor: Color {
        isReserved ? (colorScheme == .dark ? Color(red: 0.4, green: 0.8, blue: 1.0) : Color(red: 0.2, green: 0.5, blue: 0.8)) :
                     (colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2))
    }
    
    private var shadowColor: Color {
        colorScheme == .dark ? Color.black.opacity(0.2) : Color.black.opacity(0.1)
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