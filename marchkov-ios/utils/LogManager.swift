import Foundation

class LogManager {
    static let shared = LogManager()
    private init() {}
    
    private var logs: [(date: Date, message: String)] = []
    
    func addLog(_ message: String) {
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.locale = Locale(identifier: "zh_CN")
        
        let timestamp = formatter.string(from: date)
        logs.append((date: date, message: "[\(timestamp) ] \(message)"))
        
        removeOldLogs()
    }
    
    func getLogs() -> String {
        return logs.map { $0.message }.joined(separator: "\n")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    private func removeOldLogs() {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        
        logs = logs.filter { $0.date >= sevenDaysAgo }
    }
}
