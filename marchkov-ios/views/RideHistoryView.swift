import Foundation
import SwiftUI
import Charts

struct RideHistoryView: View {
    @Binding var rideHistory: [LoginService.RideInfo]?
    @Binding var isLoading: Bool
    @State private var validRideCount: Int = 0
    @State private var resourceNameStats: [RouteStats] = []
    @State private var timeStats: [TimeStats] = []
    @State private var statusStats: [StatusStats] = []
    @State private var highlightedSlice: String?
    @State private var errorMessage: String = ""
    @State private var showLongLoadingMessage: Bool = false
    @State private var isDataReady: Bool = false // 新增状态变量
    @State private var loadingTimer: Timer?
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
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
                } else if isDataReady && rideHistory != nil && !rideHistory!.isEmpty {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("有效乘车次数：\(validRideCount)")
                                .font(.title)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("按路线统计：")
                                    .font(.headline)
                                Chart(resourceNameStats) {
                                    BarMark(
                                        x: .value("次数", $0.count),
                                        y: .value("路线", $0.route)
                                    )
                                    .foregroundStyle(Color.blue.gradient)
                                }
                                .frame(height: CGFloat(resourceNameStats.count * 30))
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("按时间统计：")
                                    .font(.headline)
                                Chart(timeStats) {
                                    BarMark(
                                        x: .value("次数", $0.count),
                                        y: .value("时间", $0.time)
                                    )
                                    .foregroundStyle(Color.green.gradient)
                                }
                                .frame(height: CGFloat(timeStats.count * 25))
                                .chartXAxis {
                                    AxisMarks(position: .bottom)
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading)
                                }
                            }
                            
                            VStack(alignment: .center, spacing: 10) {
                                Text("预约状态统计")
                                    .font(.headline)
                                Text("已预约和已签到的比例")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                PieChartView(data: statusStats, highlightedSlice: $highlightedSlice)
                                    .frame(height: 250)
                            }
                            .frame(maxWidth: .infinity)
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
            .navigationTitle("乘车历史")
            .onAppear {
                if !isLoading && (rideHistory == nil || rideHistory!.isEmpty) {
                    fetchRideHistory()
                } else {
                    processRideHistory()
                }
            }
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
        var timeDict: [String: Int] = [:]
        var statusDict: [String: Int] = [:]
        
        for ride in rides {
            if ride.statusName != "已撤销" {
                validRideCount += 1
                
                resourceNameDict[ride.resourceName, default: 0] += 1
                
                if let timeComponent = ride.appointmentTime.components(separatedBy: " ").last?.components(separatedBy: ":").prefix(2).joined(separator: ":") {
                    timeDict[timeComponent, default: 0] += 1
                }
                
                statusDict[ride.statusName, default: 0] += 1
            }
        }
        
        resourceNameStats = resourceNameDict.map { RouteStats(route: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
        
        timeStats = timeDict.map { TimeStats(time: $0.key, count: $0.value) }
            .sorted { $0.time < $1.time }
        
        statusStats = statusDict.map { StatusStats(status: $0.key, count: $0.value) }
        
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
}

struct RouteStats: Identifiable {
    let id = UUID()
    let route: String
    let count: Int
}

struct TimeStats: Identifiable {
    let id = UUID()
    let time: String
    let count: Int
}

struct StatusStats: Identifiable {
    let id = UUID()
    let status: String
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

