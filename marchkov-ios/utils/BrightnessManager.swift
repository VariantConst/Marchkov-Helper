import SwiftUI
import Combine

class BrightnessManager: ObservableObject {
    @Published var isInForeground: Bool = true
    @Published var isShowingQRCode: Bool = false
    private var originalBrightness: CGFloat = UIScreen.main.brightness
    private var cancellables: Set<AnyCancellable> = []
    private var brightnessObserver: NSKeyValueObservation?
    
    init() {
        setupNotifications()
        setupBrightnessObserver()
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
    
    private func setupBrightnessObserver() {
        brightnessObserver = UIScreen.main.observe(\.brightness) { [weak self] screen, change in
            self?.handleBrightnessChange()
        }
    }
    
    private func handleBrightnessChange() {
        if !isShowingQRCode {
            originalBrightness = UIScreen.main.brightness
        }
    }
    
    private func handleEnterForeground() {
        isInForeground = true
        if isShowingQRCode {
            setMaxBrightness()
        }
    }
    
    private func handleEnterBackground() {
        isInForeground = false
        if !isShowingQRCode {
            updateOriginalBrightness()
        }
    }
    
    func updateOriginalBrightness() {
        if !isShowingQRCode {
            originalBrightness = UIScreen.main.brightness
        }
    }
    
    func setMaxBrightness() {
        if isInForeground {
            DispatchQueue.main.async {
                UIScreen.main.brightness = 1.0
            }
        }
    }
    
    func restoreOriginalBrightness() {
        DispatchQueue.main.async {
            UIScreen.main.brightness = self.originalBrightness
        }
    }
    
    func enterQRCodeView() {
        updateOriginalBrightness()
        isShowingQRCode = true
        setMaxBrightness()
    }
    
    func leaveQRCodeView() {
        isShowingQRCode = false
        restoreOriginalBrightness()
    }
}
