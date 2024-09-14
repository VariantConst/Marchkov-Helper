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
    @State private var selectedDirection = "去燕园"
    @State private var currentPage = 0
    
    var body: some View {
        ZStack {
            gradientBackground.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                directionSelector
                
                if isLoading {
                    loadingView
                } else {
                    TabView(selection: $currentPage) {
                        busListView(for: "去燕园").tag(0)
                        busListView(for: "去昌平").tag(1)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                    .onChange(of: currentPage) { _, newValue in
                        selectedDirection = newValue == 0 ? "去燕园" : "去昌平"
                    }
                }
            }
        }
        .onAppear(perform: loadData)
        .refreshable { await refreshReservationStatus() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("预约结果"), message: Text(alertMessage), dismissButton: .default(Text("确定")))
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
    
    private var directionSelector: some View {
        HStack(spacing: 0) {
            DirectionButton(title: "去燕园", isSelected: selectedDirection == "去燕园") {
                withAnimation {
                    selectedDirection = "去燕园"
                    currentPage = 0
                }
            }
            DirectionButton(title: "去昌平", isSelected: selectedDirection == "去昌平") {
                withAnimation {
                    selectedDirection = "去昌平"
                    currentPage = 1
                }
            }
        }
        .padding(4)
        .background(BlurView(style: .systemMaterial))
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private func busListView(for direction: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                sectionView(for: "今天", direction: direction)
                    .padding(.top, 20)
                
                sectionView(for: "明天", direction: direction)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal)
        }
    }
    
    private func sectionView(for day: String, direction: String) -> some View {
        VStack(alignment: .leading, spacing: 15) {
            Text(day)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .padding(.leading, 5)
            
            if filteredBuses(for: direction, on: day == "今天" ? Date() : Date().addingTimeInterval(86400)).isEmpty {
                Text("暂无班车")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(filteredBuses(for: direction, on: day == "今天" ? Date() : Date().addingTimeInterval(86400)), id: \.id) { busInfo in
                        BusCard(busInfo: busInfo, action: { bus in
                            if bus.isReserved {
                                cancelReservation(busInfo: bus)
                            } else {
                                reserveBus(busInfo: bus)
                            }
                        })
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("加载中...")
                .foregroundColor(.secondary)
        }
    }
    
    private func loadData() {
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
    }
    
    private func loadCachedBusInfo() {
        if let cachedInfo = LoginService.shared.getCachedBusInfo() {
            let today = Date()
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            
            let toYanyuanToday = processBusInfo(resources: cachedInfo.resources, ids: [2, 4], direction: "去燕园", date: today)
            let toYanyuanTomorrow = processBusInfo(resources: cachedInfo.resources, ids: [2, 4], direction: "去燕园", date: tomorrow)
            
            let toChangpingToday = processBusInfo(resources: cachedInfo.resources, ids: [5, 6, 7], direction: "去昌平", date: today)
            let toChangpingTomorrow = processBusInfo(resources: cachedInfo.resources, ids: [5, 6, 7], direction: "去昌平", date: tomorrow)
            
            self.availableBuses = [
                "去燕园": toYanyuanToday + toYanyuanTomorrow,
                "去昌平": toChangpingToday + toChangpingTomorrow
            ]
            isLoading = false
        }
    }
    
    private func processBusInfo(resources: [LoginService.Resource], ids: [Int], direction: String, date: Date) -> [BusInfo] {
        let calendar = Calendar.current
        let dateString = formattedDate(date)
        
        return resources.filter { ids.contains($0.id) }.flatMap { resource in
            resource.busInfos.compactMap { busInfo in
                guard let busDate = dateFromString(busInfo.date),
                      calendar.isDate(busDate, inSameDayAs: date),
                      busInfo.margin > 0 else {
                    return nil
                }
                return BusInfo(
                    time: busInfo.yaxis,
                    direction: direction,
                    margin: busInfo.margin,
                    resourceName: resource.name,
                    date: dateString,
                    timeId: busInfo.timeId,
                    resourceId: resource.id
                )
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func dateFromString(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai") // 添加时区
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString)
    }
    
    private func filteredBuses(for direction: String, on date: Date) -> [BusInfo] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let currentTime = Date() // 获取当前时间

        return availableBuses[direction]?.filter { busInfo in
            guard let busDate = dateFromString(busInfo.date) else { return false }
            if calendar.isDate(busDate, inSameDayAs: date) {
                if calendar.isDate(date, inSameDayAs: Date()) {
                    // 今天的班车需检查时间
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm"
                    guard let busDateTime = formatter.date(from: "\(busInfo.date) \(busInfo.time)") else { return false }
                    return busDateTime >= currentTime // 仅显示未过时的班车
                }
                return true // 明���的班车直接显示
            }
            return false
        }.sorted { $0.time < $1.time } ?? []
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
        LogManager.shared.addLog("成功获取预约状：\(reservationInfo)")
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
        
        LogManager.shared.addLog("发起消预约请求：URL: \(url.absoluteString), Body: \(postData)")
        
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
            throw NSError(domain: "取消预约失败", code: 0, userInfo: [NSLocalizedDescriptionKey: "无法解响应"])
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
}

struct BusCard: View {
    let busInfo: BusInfo
    let action: (BusInfo) -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    private var accentColor: Color {
        colorScheme == .dark ? Color(red: 100/255, green: 210/255, blue: 255/255) : Color(red: 60/255, green: 120/255, blue: 180/255)
    }
    
    private var selectedGreenColor: Color {
        colorScheme == .dark ? Color(red: 76/255, green: 175/255, blue: 80/255) : Color(red: 56/255, green: 142/255, blue: 60/255)
    }
    
    var body: some View {
        Button(action: {
            action(busInfo)
        }) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(busInfo.time)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                    Spacer()
                    Image(systemName: busInfo.isReserved ? "checkmark.circle.fill" : "clock")
                        .foregroundColor(busInfo.isReserved ? selectedGreenColor : accentColor)
                }
                
                Text(busInfo.resourceName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .frame(height: 32)
                    .minimumScaleFactor(busInfo.resourceName.count > 18 ? 0.8 : 1.0)
            }
            .frame(height: 80)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                ZStack {
                    BlurView(style: .systemMaterial)
                    if busInfo.isReserved {
                        selectedGreenColor.opacity(0.1)
                    }
                }
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(busInfo.isReserved ? selectedGreenColor : Color.gray.opacity(0.2), lineWidth: busInfo.isReserved ? 2 : 1)
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 3, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
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

struct DirectionButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    Group {
                        if isSelected {
                            Capsule()
                                .fill(Color.accentColor)
                                .shadow(color: Color.accentColor.opacity(0.3), radius: 3, x: 0, y: 2)
                        }
                    }
                )
                .foregroundColor(isSelected ? .white : (colorScheme == .dark ? .white : .primary))
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}
