import Foundation
import SwiftUI
import Charts

struct RideHistoryView: View {
    @Binding var rideHistory: [LoginService.RideInfo]?
    @Binding var isLoading: Bool
    @State private var validRideCount: Int = 0
    @State private var resourceNameStats: [RouteStats] = []
    @State private var timeStats: [HourlyStats] = []
    @State private var statusStats: [StatusStats] = []
    @State private var highlightedSlice: String?
    @State private var errorMessage: String = ""
    @State private var showLongLoadingMessage: Bool = false
    @State private var isDataReady: Bool = false // 新增状态变量
    @State private var loadingTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedDate: Date = Date()
    @State private var calendarDates: Set<Date> = []
    @State private var earliestDate: Date?
    @State private var latestDate: Date = Date()
    @State private var signInTimeStats: [SignInTimeStats] = []
    @State private var signInTimeRange: (Int, Int) = (0, 0)
    @State private var highlightedTimeDiff: Int?
    @State private var selectedHour: Int?
    
    private static let appointmentDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            content
        }
        .navigationTitle("乘车历史")
        .onAppear(perform: onAppear)
        .onChange(of: rideHistory) { _, _ in
            processRideHistory()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            if newPhase == .active && oldPhase == .background {
                silentRefresh()
            }
        }
        .refreshable {
            await refreshRideHistory()
        }
        .onTapGesture {
            highlightedSlice = nil
        }
    }
    
    @ViewBuilder
    private var content: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground).edgesIgnoringSafeArea(.all)
            
            if isLoading {
                loadingView
            } else if isDataReady && rideHistory != nil && !rideHistory!.isEmpty {
                ScrollView {
                    VStack(spacing: 20) {
                        validRideCountView
                        routeStatsView
                        timeStatsView
                        statusStatsView
                        rideCalendarView
                        signInTimeStatsView
                    }
                    .padding()
                }
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            } else {
                Text("暂无数据")
                    .padding()
            }
        }
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView("加载中...")
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
                .scaleEffect(1.2)
            
            if showLongLoadingMessage {
                Text("首次加载可能需要稍长时间")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top)
            }
        }
    }
    
    private var validRideCountView: some View {
        CardView {
            Text("有效乘车次数：\(validRideCount)")
                .font(.title2)
                .fontWeight(.bold)
        }
    }
    
    private var routeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("按路线统计")
                    .font(.headline)
                Chart(resourceNameStats) {
                    BarMark(
                        x: .value("次数", $0.count),
                        y: .value("路线", $0.route)
                    )
                    .foregroundStyle(Color.blue.gradient)
                    .cornerRadius(5)
                }
                .frame(height: CGFloat(resourceNameStats.count * 30))
                .chartXAxis {
                    AxisMarks(position: .bottom) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
            }
        }
    }
    
    private var timeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("按时间统计")
                    .font(.headline)
                Chart(timeStats) { stat in
                    BarMark(
                        x: .value("时间", stat.hour),
                        y: .value("次数", stat.count)
                    )
                    .foregroundStyle(Color.green.gradient)
                    .cornerRadius(5)
                    .annotation(position: .top) {
                        if stat.hour == selectedHour {
                            Text("\(stat.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: 2)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let hour = value.as(Int.self) {
                                Text("\(hour):00")
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .chartXScale(domain: 6...22)
                .chartYScale(domain: 0...(maxCount * 1.1))
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                                        if let hour: Int = proxy.value(atX: x) {
                                            selectedHour = hour
                                        }
                                    }
                                    .onEnded { _ in
                                        selectedHour = nil
                                    }
                            )
                    }
                }
            }
        }
    }
    
    private var maxCount: Double {
        timeStats.map { Double($0.count) }.max() ?? 0
    }
    
    private var statusStatsView: some View {
        CardView {
            VStack(alignment: .center, spacing: 10) {
                Text("预约状态统计")
                    .font(.headline)
                Text("已预约和已签的比例")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                PieChartView(data: statusStats, highlightedSlice: $highlightedSlice)
                    .frame(height: 250)
            }
        }
    }
    
    private var rideCalendarView: some View {
        CardView {
            VStack(alignment: .center, spacing: 10) {
                Text("乘车日历")
                    .font(.headline)
                RideCalendarView(selectedDate: $selectedDate, 
                                 calendarDates: calendarDates, 
                                 earliestDate: earliestDate ?? latestDate, 
                                 latestDate: latestDate)
                    .frame(height: 300)
            }
        }
    }
    
    private var signInTimeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                signInTimeStatsHeader
                signInTimeStatsChart
                signInTimeStatsFooter
            }
        }
    }
    
    private var signInTimeStatsHeader: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("签到时间差统计")
                .font(.headline)
            Text("负值表示提前签到，正值表示迟到")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var signInTimeStatsChart: some View {
        Chart(signInTimeStats) { stat in
            BarMark(
                x: .value("时间差", stat.timeDiff),
                y: .value("次数", stat.count)
            )
            .foregroundStyle(Color.purple.gradient)
            .cornerRadius(5)
        }
        .frame(height: 200)
        .chartXAxis {
            AxisMarks(position: .bottom) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: IntegerFormatStyle<Int>())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartXScale(domain: Double(signInTimeRange.0)...Double(signInTimeRange.1))
        .chartOverlay(content: chartOverlay)
        .chartBackground(content: chartBackground)
    }
    
    private var signInTimeStatsFooter: some View {
        Text("时间差（分钟）")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func chartOverlay(proxy: ChartProxy) -> some View {
        GeometryReader { geometry in
            Rectangle().fill(.clear).contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let x = value.location.x - geometry[proxy.plotAreaFrame].origin.x
                            if let timeDiff = proxy.value(atX: x, as: Int.self) {
                                highlightedTimeDiff = timeDiff
                            }
                        }
                        .onEnded { _ in
                            highlightedTimeDiff = nil
                        }
                )
        }
    }
    
    @ViewBuilder
    private func chartBackground(proxy: ChartProxy) -> some View {
        ZStack(alignment: .topLeading) {
            GeometryReader { geometry in
                if let highlightedTimeDiff = highlightedTimeDiff,
                   let stat = signInTimeStats.first(where: { $0.timeDiff == highlightedTimeDiff }) {
                    let x = proxy.position(forX: Double(highlightedTimeDiff)) ?? 0
                    let y = proxy.position(forY: Double(stat.count)) ?? 0
                    
                    VStack(alignment: .leading) {
                        Text("时间差: \(highlightedTimeDiff) 分钟")
                        Text("次数: \(stat.count)")
                    }
                    .padding(6)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(6)
                    .offset(x: x, y: y)
                }
            }
        }
    }
    
    private func fetchRideHistory() {
        isLoading = true
        showLongLoadingMessage = false
        isDataReady = false // 重置数据准备状态
        
        // 设置一个3秒后显示长时间加载消息的计时器
        loadingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            DispatchQueue.main.async {
                if self.isLoading {
                    self.showLongLoadingMessage = true
                }
            }
        }
        
        LoginService.shared.getRideHistory { result in
            DispatchQueue.main.async {
                // 取消计时器
                self.loadingTimer?.invalidate()
                
                switch result {
                case .success(let history):
                    self.rideHistory = history
                    self.processRideHistory()
                case .failure(let error):
                    self.errorMessage = "加载失败: \(error.localizedDescription)"
                }
                self.isLoading = false
                self.showLongLoadingMessage = false
            }
        }
    }
    
    private func silentRefresh() {
        LoginService.shared.getRideHistory { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let history):
                    self.rideHistory = history
                    self.processRideHistory()
                case .failure:
                    // 静默失败，不更新 errorMessage
                    break
                }
                self.isLoading = false
            }
        }
    }
    
    private func processRideHistory() {
        guard let rides = rideHistory else { return }
        
        validRideCount = 0
        var resourceNameDict: [String: Int] = [:]
        var statusDict: [String: Int] = [:]
        
        // 处理日历数据
        var allDates: [Date] = []
        for ride in rides {
            if ride.statusName != "已撤销" {
                validRideCount += 1
                
                resourceNameDict[ride.resourceName, default: 0] += 1
                
                statusDict[ride.statusName, default: 0] += 1
            }
            
            if ride.statusName != "已撤销", let date = Self.appointmentDateFormatter.date(from: ride.appointmentTime) {
                let startOfDay = Calendar.current.startOfDay(for: date)
                calendarDates.insert(startOfDay)
                allDates.append(startOfDay)
            }
        }
        
        earliestDate = allDates.min()
        latestDate = Date() // 设置为今天
        
        resourceNameStats = resourceNameDict.map { RouteStats(route: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        // 处理时间统计
        var hourlyDict: [Int: Int] = [:]
        for ride in rides {
            if ride.statusName != "已撤销", let date = Self.appointmentDateFormatter.date(from: ride.appointmentTime) {
                let hour = Calendar.current.component(.hour, from: date)
                if hour >= 6 && hour < 22 {
                    hourlyDict[hour, default: 0] += 1
                }
            }
        }
        
        timeStats = (6...21).map { hour in
            HourlyStats(hour: hour, count: hourlyDict[hour] ?? 0)
        }
        
        statusStats = statusDict.map { StatusStats(status: $0.key, count: $0.value) }
        
        // 处理签到时间差
        var signInTimeDiffs: [Int] = []
        let appointmentFormatter = DateFormatter()
        appointmentFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        let signFormatter = DateFormatter()
        signFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        for ride in rides {
            if let signTime = ride.appointmentSignTime, !signTime.isEmpty,
               let appointmentDate = appointmentFormatter.date(from: ride.appointmentTime.trimmingCharacters(in: .whitespaces)),
               let signDate = signFormatter.date(from: signTime) {
                let diff = Int(signDate.timeIntervalSince(appointmentDate) / 60)
                signInTimeDiffs.append(diff)
            }
        }
        
        // 计算95%的数据范围
        let sortedDiffs = signInTimeDiffs.sorted()
        let lowerIndex = Int(Double(sortedDiffs.count) * 0.025)
        let upperIndex = Int(Double(sortedDiffs.count) * 0.975)
        var lowerBound = sortedDiffs[lowerIndex]
        var upperBound = sortedDiffs[upperIndex]
        
        // 确保0居中，并向两边扩展
        let maxAbsValue = max(abs(lowerBound), abs(upperBound))
        lowerBound = -maxAbsValue
        upperBound = maxAbsValue
        
        // 两边各延长2分钟
        lowerBound -= 2
        upperBound += 2
        
        signInTimeRange = (lowerBound, upperBound)
        
        // 统计签到时间差
        let groupedDiffs = Dictionary(grouping: signInTimeDiffs, by: { max(min($0, upperBound), lowerBound) })
        signInTimeStats = groupedDiffs.map { SignInTimeStats(timeDiff: $0.key, count: $0.value.count) }
            .sorted { $0.timeDiff < $1.timeDiff }
        
        isDataReady = true // 数据处理完成，标记为准备就绪
    }
    
    private func refreshRideHistory() async {
        do {
            let result = try await withCheckedThrowingContinuation { continuation in
                LoginService.shared.getRideHistory { result in
                    continuation.resume(with: result)
                }
            }
            
            await MainActor.run {
                self.rideHistory = result
                self.processRideHistory()
                self.errorMessage = ""
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "刷新失败: \(error.localizedDescription)"
            }
        }
    }
    
    private func onAppear() {
        if !isLoading && (rideHistory == nil || rideHistory!.isEmpty) {
            fetchRideHistory()
        } else {
            processRideHistory()
        }
    }
}

struct RouteStats: Identifiable {
    let id = UUID()
    let route: String
    let count: Int
}

struct HourlyStats: Identifiable {
    let id = UUID()
    let hour: Int
    let count: Int
}

struct StatusStats: Identifiable {
    let id = UUID()
    let status: String
    let count: Int
}

struct SignInTimeStats: Identifiable {
    let id = UUID()
    let timeDiff: Int
    let count: Int
}

struct PieChartView: View {
    let data: [StatusStats]
    @Binding var highlightedSlice: String?
    
    var body: some View {
        ZStack {
            ForEach(data) { stat in
                PieSlice(startAngle: startAngle(for: stat), endAngle: endAngle(for: stat))
                    .fill(colorForStatus(stat.status))
                    .overlay(
                        PieSlice(startAngle: startAngle(for: stat), endAngle: endAngle(for: stat))
                            .stroke(Color.white, lineWidth: highlightedSlice == stat.status ? 3 : 1)
                    )
                    .overlay(
                        PieChartLabel(
                            status: stat.status,
                            count: stat.count,
                            angle: midAngle(for: stat),
                            highlighted: highlightedSlice == stat.status
                        )
                    )
                    .onTapGesture {
                        withAnimation {
                            highlightedSlice = (highlightedSlice == stat.status) ? nil : stat.status
                        }
                    }
            }
        }
    }
    
    private func startAngle(for stat: StatusStats) -> Angle {
        let index = data.firstIndex(where: { $0.id == stat.id }) ?? 0
        let precedingTotal = data.prefix(index).reduce(0) { $0 + $1.count }
        return .degrees(Double(precedingTotal) / Double(total) * 360)
    }
    
    private func endAngle(for stat: StatusStats) -> Angle {
        let index = data.firstIndex(where: { $0.id == stat.id }) ?? 0
        let precedingTotal = data.prefix(index + 1).reduce(0) { $0 + $1.count }
        return .degrees(Double(precedingTotal) / Double(total) * 360)
    }
    
    private var total: Int {
        data.reduce(0) { $0 + $1.count }
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "已预约":
            return Color(hex: "#4A90E2") // 柔和的蓝色
        case "已签到":
            return Color(hex: "#50E3C2") // 清新的绿色
        default:
            return Color(hex: "#C7C7CC") // 浅灰色
        }
    }
    
    private func midAngle(for stat: StatusStats) -> Angle {
        let start = startAngle(for: stat)
        let end = endAngle(for: stat)
        return .degrees(start.degrees + (end.degrees - start.degrees) / 2)
    }
}

struct PieChartLabel: View {
    let status: String
    let count: Int
    let angle: Angle
    let highlighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                Text(status)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(count)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .position(
                x: geometry.size.width / 2 + cos(angle.radians - .pi / 2) * geometry.size.width * 0.2,
                y: geometry.size.height / 2 + sin(angle.radians - .pi / 2) * geometry.size.height * 0.2
            )
        }
    }
}

struct PieSlice: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle - .degrees(90), endAngle: endAngle - .degrees(90), clockwise: false)
        path.closeSubpath()
        return path
    }
}

struct RideCalendarView: View {
    @Binding var selectedDate: Date
    let calendarDates: Set<Date>
    let earliestDate: Date
    let latestDate: Date
    
    @State private var currentMonth: Date
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年MM月"
        return formatter
    }()
    
    init(selectedDate: Binding<Date>, calendarDates: Set<Date>, earliestDate: Date, latestDate: Date) {
        self._selectedDate = selectedDate
        self.calendarDates = calendarDates
        self.earliestDate = earliestDate
        self.latestDate = latestDate
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { changeMonth(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.blue)
                }
                .disabled(!canGoToPreviousMonth())
                
                Spacer()
                Text(dateFormatter.string(from: currentMonth))
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                
                Button(action: { changeMonth(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.blue)
                }
                .disabled(!canGoToNextMonth())
            }
            .padding(.horizontal)
            .frame(height: 44)
            .background(Color.white)
            .zIndex(1)
            
            HStack {
                ForEach(["日", "一", "二", "三", "四", "五", "六"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color.white)
            .zIndex(1)
            
            calendarGrid(for: currentMonth)
                .frame(height: 240) // 固定高度，确保6行时不会影响顶部栏
        }
    }
    
    private func calendarGrid(for month: Date) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
            ForEach(getDaysInMonth(for: month), id: \.self) { date in
                if let date = date {
                    DayView(date: date, isSelected: calendarDates.contains(date))
                } else {
                    Text("")
                        .frame(height: 32)
                }
            }
        }
    }
    
    private func getDaysInMonth(for date: Date) -> [Date?] {
        let range = calendar.range(of: .day, in: .month, for: date)!
        let firstWeekday = calendar.component(.weekday, from: date.startOfMonth())
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...range.count {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: date.startOfMonth()) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func canGoToPreviousMonth() -> Bool {
        return currentMonth > earliestDate
    }
    
    private func canGoToNextMonth() -> Bool {
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            return nextMonth <= latestDate
        }
        return false
    }
}

struct DayView: View {
    let date: Date
    let isSelected: Bool
    
    private let calendar = Calendar.current
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color.blue : Color.clear)
            
            Text("\(calendar.component(.day, from: date))")
                .font(.system(size: 16, weight: isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
        }
        .frame(height: 32)
    }
}

extension Date {
    func startOfDay() -> Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    func startOfMonth() -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components)!
    }
}

struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

