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
    @State private var animationDuration: Double = 0.25 // 适合高刷新率的动画持续时间
    
    var body: some View {
        NavigationView {
            ZStack {
                gradientBackground.edgesIgnoringSafeArea(.all)
                
                Group {
                    if isLoading {
                        ProgressView("加载中...")
                    } else {
                        VStack(spacing: 0) {
                            DateSelectorView(currentPage: $currentPage, animationDuration: animationDuration)
                                .padding(.horizontal)
                                .padding(.bottom, 16)
                            
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
                                            withAnimation(.easeInOut(duration: animationDuration)) {
                                                currentPage = max(0, currentPage - 1)
                                            }
                                        } else if value.translation.width < -threshold {
                                            withAnimation(.easeInOut(duration: animationDuration)) {
                                                currentPage = min(1, currentPage + 1)
                                            }
                                        }
                                    }
                            )
                        }
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
                            alertMessage = "获取预约状态败：\(error.localizedDescription)"
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
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            // 根据设备的刷新率动态设置动画持续时间
            if let window = UIApplication.shared.windows.first {
                let refreshRate = window.screen.maximumFramesPerSecond
                animationDuration = refreshRate > 60 ? 0.2 : 0.25
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
                // 对于今天的班车，只显示未过期��
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
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(filteredBuses(for: direction, on: date), id: \.id) { busInfo in
                                BusButton(busInfo: busInfo, reserveAction: reserveBus, cancelAction: cancelReservation)
                                    .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
    
    private var gradientBackground: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 25/255, green: 25/255, blue: 30/255), Color(red: 45/255, green: 45/255, blue: 55/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color(red: 245/255, green: 245/255, blue: 250/255), Color(red: 235/255, green: 235/255, blue: 240/255)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

struct DateSelectorView: View {
    @Binding var currentPage: Int
    @Environment(\.colorScheme) private var colorScheme
    let animationDuration: Double
    
    var body: some View {
        HStack(spacing: 12) {
            dateButton(title: "今天", tag: 0)
            dateButton(title: "明天", tag: 1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 5, x: 0, y: 2)
    }
    
    private func dateButton(title: String, tag: Int) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: animationDuration)) {
                currentPage = tag
            }
        }) {
            Text(formattedDateString(for: tag))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(currentPage == tag ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Group {
                        if currentPage == tag {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(accentColor)
                        }
                    }
                )
        }
    }
    
    private func formattedDateString(for tag: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: tag, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return "\(tag == 0 ? "今天" : "明天")(\(formatter.string(from: date)))"
    }
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.95, green: 0.95, blue: 0.97)
    }
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
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
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(busInfo.time)
                        .font(.system(size: 22, weight: .bold))
                    Spacer()
                    Image(systemName: busInfo.isReserved ? "checkmark.circle.fill" : "clock.fill")
                        .font(.system(size: 20))
                        .foregroundColor(busInfo.isReserved ? .green : buttonColor)
                }
                if busInfo.resourceName.count > 9 {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(firstLine)
                        Text(secondLine)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                } else {
                    Text(busInfo.resourceName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(height: 80)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(busInfo.isReserved ? Color.green.opacity(0.5) : buttonColor.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 3, x: 0, y: 1)
        }
    }

    private var firstLine: String {
        let midIndex = busInfo.resourceName.index(busInfo.resourceName.startIndex, offsetBy: (busInfo.resourceName.count + 1) / 2)
        return String(busInfo.resourceName[..<midIndex])
    }

    private var secondLine: String {
        let midIndex = busInfo.resourceName.index(busInfo.resourceName.startIndex, offsetBy: (busInfo.resourceName.count + 1) / 2)
        return String(busInfo.resourceName[midIndex...])
    }

    private func playHaptic() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    private var buttonColor: Color {
        colorScheme == .dark ? Color(red: 0.4, green: 0.5, blue: 0.6) : Color(red: 0.5, green: 0.6, blue: 0.7)
    }
    
    private var backgroundColor: Color {
        if busInfo.isReserved {
            return colorScheme == .dark ? Color.green.opacity(0.1) : Color.green.opacity(0.05)
        } else {
            return colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.25) : Color(red: 0.95, green: 0.95, blue: 0.97)
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
