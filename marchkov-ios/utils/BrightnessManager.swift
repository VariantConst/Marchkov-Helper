import SwiftUI
import Combine

class BrightnessManager: ObservableObject {
    @Published var isInForeground: Bool = true
    @Published var isShowingQRCode: Bool = false
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var lastCapturedBrightness: CGFloat = UIScreen.main.brightness
    private var cancellables: Set<AnyCancellable> = []
    
    init() {
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleEnterForeground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleEnterBackground()
            }
            .store(in: &cancellables)
    }
    
    private func handleEnterForeground() {
        isInForeground = true
        if isShowingQRCode {
            setMaxBrightness()
        } else {
            updateOriginalBrightness()
        }
    }
    
    private func handleEnterBackground() {
        isInForeground = false
        if !isShowingQRCode {
            restoreOriginalBrightness()
        }
    }
    
    func updateOriginalBrightness() {
        if !isShowingQRCode {
            originalBrightness = UIScreen.main.brightness
        }
    }
    
    func captureCurrentBrightness() {
        lastCapturedBrightness = UIScreen.main.brightness
    }
    
    func setMaxBrightness() {
        if isInForeground {
            isShowingQRCode = true
            UIScreen.main.brightness = 1.0
        }
    }
    
    func restoreOriginalBrightness() {
        UIScreen.main.brightness = isShowingQRCode ? lastCapturedBrightness : originalBrightness
        isShowingQRCode = false
    }
}
