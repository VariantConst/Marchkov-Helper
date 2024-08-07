import SwiftUI

@main
struct marchkov_iosApp: App {
    @StateObject private var brightnessManager = BrightnessManager()

    var body: some Scene {
        WindowGroup {
            LoginView()
                .environmentObject(brightnessManager)
                .navigationViewStyle(StackNavigationViewStyle()) // 禁用分屏模式
        }
    }
}
