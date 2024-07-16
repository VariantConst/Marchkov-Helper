import Foundation

class UserDataManager {
    static let shared = UserDataManager()
    
    private init() {}
    
    private let userDefaultsUsernameKey = "username"
    private let userDefaultsPasswordKey = "password"
    
    func saveUserCredentials(username: String, password: String) {
        UserDefaults.standard.set(username, forKey: userDefaultsUsernameKey)
        UserDefaults.standard.set(password, forKey: userDefaultsPasswordKey)
    }
    
    func getUserCredentials() -> (username: String, password: String)? {
        guard let username = UserDefaults.standard.string(forKey: userDefaultsUsernameKey),
              let password = UserDefaults.standard.string(forKey: userDefaultsPasswordKey) else {
            return nil
        }
        return (username, password)
    }
    
    func clearUserCredentials() {
        UserDefaults.standard.removeObject(forKey: userDefaultsUsernameKey)
        UserDefaults.standard.removeObject(forKey: userDefaultsPasswordKey)
    }
    
    func isUserLoggedIn() -> Bool {
        return getUserCredentials() != nil
    }
    
    // Default settings
    private let defaultPrevInterval = 10
    private let defaultNextInterval = 60
    private let defaultCriticalTime = 14
    private let defaultFlagMorningToYanyuan = true
    
    func getPrevInterval() -> Int {
        return UserDefaults.standard.integer(forKey: "prevInterval") != 0 ?
            UserDefaults.standard.integer(forKey: "prevInterval") : defaultPrevInterval
    }
    
    func getNextInterval() -> Int {
        return UserDefaults.standard.integer(forKey: "nextInterval") != 0 ?
            UserDefaults.standard.integer(forKey: "nextInterval") : defaultNextInterval
    }
    
    func getCriticalTime() -> Int {
        return UserDefaults.standard.integer(forKey: "criticalTime") != 0 ?
            UserDefaults.standard.integer(forKey: "criticalTime") : defaultCriticalTime
    }
    
    func getFlagMorningToYanyuan() -> Bool {
        return UserDefaults.standard.object(forKey: "flagMorningToYanyuan") as? Bool ?? defaultFlagMorningToYanyuan
    }
    
    func resetToDefaultSettings() {
        UserDefaults.standard.set(defaultPrevInterval, forKey: "prevInterval")
        UserDefaults.standard.set(defaultNextInterval, forKey: "nextInterval")
        UserDefaults.standard.set(defaultCriticalTime, forKey: "criticalTime")
        UserDefaults.standard.set(defaultFlagMorningToYanyuan, forKey: "flagMorningToYanyuan")
    }
}
