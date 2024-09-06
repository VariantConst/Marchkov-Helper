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
                        rideCalendarView
                        timeStatsView
                        signInTimeStatsView
                        statusStatsView
                        routeStatsView
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
    
    // 首先,定义一个通用的卡片标题样式
    private func cardTitle(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
    
    // 定义一个通用的卡片副标题样式
    private func cardSubtitle(_ subtitle: String) -> some View {
        Text(subtitle)
            .font(.subheadline)
            .foregroundColor(.secondary)
    }
    
    // 修改 rideCalendarView
    private var rideCalendarView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("乘车日历")
                cardSubtitle(getRideCalendarSubtitle())
                RideCalendarView(selectedDate: $selectedDate, 
                                 calendarDates: calendarDates, 
                                 earliestDate: earliestDate ?? latestDate, 
                                 latestDate: latestDate)
                    .frame(height: 300)
            }
        }
    }
    
    // 添加新的方法来计算乘车日历的副标题
    private func getRideCalendarSubtitle() -> String {
        let calendar = Calendar.current
        let today = Date()
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: today)!
        let sixtyDaysAgo = calendar.date(byAdding: .day, value: -60, to: today)!
        
        let last30DaysRides = calendarDates.filter { $0 >= thirtyDaysAgo && $0 <= today }
        let previous30DaysRides = calendarDates.filter { $0 >= sixtyDaysAgo && $0 < thirtyDaysAgo }
        
        let last30DaysRideCount = last30DaysRides.count
        let last30DaysPercentage = Double(last30DaysRideCount) / 30.0 * 100
        
        if last30DaysPercentage > 60 {
            return String(format: "刻苦如你，过去30天有%.1f%%的天数乘坐了班车。", last30DaysPercentage)
        } else if last30DaysRideCount > 0 {
            let comparisonText = last30DaysRideCount > previous30DaysRides.count ? "多" : "少"
            let encouragementText = comparisonText == "多" ? "辛苦！" : "馨园吃腻了吗？"
            return "你最近乘坐班车比以前更\(comparisonText)了。\(encouragementText)"
        } else {
            return "过去一个月你一次班车都没坐过。开摆！"
        }
    }
    
    // 修改 timeStatsView
    private var timeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("乘车时间统计")
                cardSubtitle(getTimeStatsSubtitle())
                timeStatsChart
            }
        }
    }
    
    private func getTimeStatsSubtitle() -> String {
        let maxToYanyuan = timeStats.max(by: { $0.countToYanyuan < $1.countToYanyuan })
        let maxToChangping = timeStats.max(by: { $0.countToChangping < $1.countToChangping })
        
        if let maxYanyuan = maxToYanyuan, (11...17).contains(maxYanyuan.hour) {
            return "你习惯日上三竿时再去燕园。年轻人要少熬夜。"
        } else if let maxChangping = maxToChangping, maxChangping.hour >= 21 {
            return "你习惯工作到深夜才休息。真是个卷王！"
        } else if let maxYanyuan = maxToYanyuan, maxYanyuan.hour < 10 {
            return "你习惯早起去燕园工作。早起的鸟儿有丹炼！"
        } else {
            return " " // 空行
        }
    }
    
    private var timeStatsChart: some View {
        Chart {
            ForEach(timeStats) { stat in
                BarMark(
                    x: .value("时间", stat.hour),
                    y: .value("去燕园", -stat.countToYanyuan)
                )
                .foregroundStyle(Color.green.gradient)
                .cornerRadius(5)
                
                BarMark(
                    x: .value("时间", stat.hour),
                    y: .value("回昌平", stat.countToChangping)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(5)
            }
        }
        .frame(height: 300)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                if let count = value.as(Int.self) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        Text("\(abs(count))")
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: 3)) { value in
                if let hour = value.as(Int.self) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        Text("\(hour):00")
                    }
                }
            }
        }
        .chartYScale(domain: -maxCount...maxCount)
        .chartXScale(domain: 5...23)
        .chartLegend(position: .bottom, spacing: 10)
        .chartForegroundStyleScale(timeStatsColorScale)
    }
    
    private var maxCount: Int {
        timeStats.map { max($0.countToChangping, $0.countToYanyuan) }.max() ?? 0
    }
    
    private var timeStatsColorScale: KeyValuePairs<String, Color> {
        [
            "回昌平": Color.blue,
            "去燕园": Color.green
        ]
    }
    
    // 修改 signInTimeStatsView
    private var signInTimeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("签到时间差")
                cardSubtitle(getSignInTimeStatsSubtitle())
                signInTimeStatsChart
                signInTimeStatsFooter
            }
        }
    }
    
    private func getSignInTimeStatsSubtitle() -> String {
        if let maxStat = signInTimeStats.max(by: { $0.count < $1.count }) {
            if maxStat.timeDiff >= -3 && maxStat.timeDiff <= 0 {
                return "统计上讲，你可能是一个ddl战士。"
            } else if maxStat.timeDiff < -3 {
                return "统计上讲，你喜欢留足提前量。"
            } else if maxStat.timeDiff > 0 {
                return "统计上讲，你几乎每次都是最后几个上车的。"
            }
        }
        return " " // 如果没有数据，返回空行
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
        .chartYScale(domain: 0...(maxSignInTimeCount * 1.1))
    }
    
    private var signInTimeStatsFooter: some View {
        Text("时间差（分钟）")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var maxSignInTimeCount: Double {
        signInTimeStats.map { Double($0.count) }.max() ?? 0
    }
    
    // 修改 statusStatsView
    private var statusStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("爽约分析")
                
                let noShowCount = statusStats.first(where: { $0.status == "已预约" })?.count ?? 0
                let noShowRate = Double(noShowCount) / Double(validRideCount)
                
                if noShowRate > 0.3 {
                    cardSubtitle("你爽约了\(validRideCount)次预约中的\(noShowCount)次。咕咕咕？")
                } else {
                    cardSubtitle("你在\(validRideCount)次预约中只爽约了\(noShowCount)次。很有精神！")
                }
                
                PieChartView(data: statusStats, highlightedSlice: $highlightedSlice)
                    .frame(height: 200)
            }
        }
    }
    
    // 修改 routeStatsView
    private var routeStatsView: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                cardTitle("路线统计")
                if let mostFrequentRoute = resourceNameStats.first {
                    cardSubtitle("你最常坐的路线是: \(mostFrequentRoute.route)")
                }
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
                .chartXScale(domain: 0...(maxRouteCount * 1.1))
            }
        }
    }
    
    // 在 RideHistoryView 结构体内添加这个计算属性
    private var maxRouteCount: Double {
        resourceNameStats.map { Double($0.count) }.max() ?? 0
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
        var hourlyDict: [Int: (toChangping: Int, toYanyuan: Int)] = [:]
        
        // 处理日历数据
        var allDates: [Date] = []
        for ride in rides {
            if ride.statusName != "已撤销" {
                validRideCount += 1
                
                resourceNameDict[ride.resourceName, default: 0] += 1
                
                statusDict[ride.statusName, default: 0] += 1
                
                if let date = Self.appointmentDateFormatter.date(from: ride.appointmentTime) {
                    let hour = Calendar.current.component(.hour, from: date)
                    if hour >= 5 && hour <= 23 {
                        let isToChangping = isRouteToChangping(ride.resourceName)
                        if isToChangping {
                            hourlyDict[hour, default: (0, 0)].toChangping += 1
                        } else {
                            hourlyDict[hour, default: (0, 0)].toYanyuan += 1
                        }
                    }
                    
                    let startOfDay = Calendar.current.startOfDay(for: date)
                    calendarDates.insert(startOfDay)
                    allDates.append(startOfDay)
                }
            }
        }
        
        earliestDate = allDates.min()
        latestDate = Date() // 设置为今天
        
        resourceNameStats = resourceNameDict.map { RouteStats(route: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        timeStats = (5...23).map { hour in
            let counts = hourlyDict[hour] ?? (0, 0)
            return HourlyStats(hour: hour, countToChangping: counts.toChangping, countToYanyuan: counts.toYanyuan)
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
    
    // 在 RideHistoryView 结构体内添加这个私有方法
    private func isRouteToChangping(_ routeName: String) -> Bool {
        let yanIndex = routeName.firstIndex(of: "燕") ?? routeName.endIndex
        let xinIndex = routeName.firstIndex(of: "新") ?? routeName.endIndex
        return yanIndex < xinIndex
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
    let countToChangping: Int
    let countToYanyuan: Int
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
                            status: stat.status == "已预约" ? "已爽约" : stat.status,
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

// 修改 PieChartLabel 结构体,调整文字位置
struct PieChartLabel: View {
    let status: String
    let count: Int
    let angle: Angle
    let highlighted: Bool
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                Text(status)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .background(GeometryReader { labelGeometry in
                Color.clear.preference(key: LabelSizePreferenceKey.self, value: labelGeometry.size)
            })
            .position(
                x: geometry.size.width / 2 + cos(angle.radians - .pi / 2) * geometry.size.width * 0.18,
                y: geometry.size.height / 2 + sin(angle.radians - .pi / 2) * geometry.size.height * 0.18
            )
        }
    }
}

struct LabelSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
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
                .frame(height: 240) // 固定高度，确保6行时不会影响部栏
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

