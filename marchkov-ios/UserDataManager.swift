import Foundation

class UserDataManager {
    static let shared = UserDataManager()
    
    private let userDefaults = UserDefaults.standard
    private let usernameKey = "savedUsername"
    private let passwordKey = "savedPassword"
    private let prevIntervalKey = "prevInterval"
    private let nextIntervalKey = "nextInterval"
    private let criticalTimeKey = "criticalTime"
    private let flagMorningToYanyuanKey = "flagMorningToYanyuan"
    
    private init() {}
    
    func saveUserCredentials(username: String, password: String) {
        userDefaults.set(username, forKey: usernameKey)
        userDefaults.set(password, forKey: passwordKey)
    }
    
    func getUserCredentials() -> (username: String, password: String)? {
        guard let username = userDefaults.string(forKey: usernameKey),
              let password = userDefaults.string(forKey: passwordKey) else {
            return nil
        }
        return (username, password)
    }
    
    func clearUserCredentials() {
        userDefaults.removeObject(forKey: usernameKey)
        userDefaults.removeObject(forKey: passwordKey)
    }
    
    func isUserLoggedIn() -> Bool {
        return getUserCredentials() != nil
    }
    
    // New methods for additional settings
    
    func savePrevInterval(_ interval: Int) {
        userDefaults.set(interval, forKey: prevIntervalKey)
    }
    
    func getPrevInterval() -> Int {
        return userDefaults.integer(forKey: prevIntervalKey)
    }
    
    func saveNextInterval(_ interval: Int) {
        userDefaults.set(interval, forKey: nextIntervalKey)
    }
    
    func getNextInterval() -> Int {
        return userDefaults.integer(forKey: nextIntervalKey)
    }
    
    func saveCriticalTime(_ time: Int) {
        userDefaults.set(time, forKey: criticalTimeKey)
    }
    
    func getCriticalTime() -> Int {
        return userDefaults.integer(forKey: criticalTimeKey)
    }
    
    func saveFlagMorningToYanyuan(_ flag: Bool) {
        userDefaults.set(flag, forKey: flagMorningToYanyuanKey)
    }
    
    func getFlagMorningToYanyuan() -> Bool {
        return userDefaults.bool(forKey: flagMorningToYanyuanKey)
    }
    
    func resetToDefaultSettings() {
        userDefaults.set(10, forKey: prevIntervalKey)
        userDefaults.set(60, forKey: nextIntervalKey)
        userDefaults.set(14, forKey: criticalTimeKey)
        userDefaults.set(true, forKey: flagMorningToYanyuanKey)
    }
}
