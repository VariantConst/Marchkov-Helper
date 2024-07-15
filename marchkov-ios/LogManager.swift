import Foundation

class LogManager {
    static let shared = LogManager()
    private init() {}
    
    private var logs: [String] = []
    
    func addLog(_ message: String) {
        logs.append("[\(Date())] \(message)")
    }
    
    func getLogs() -> String {
        return logs.joined(separator: "\n")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
}
