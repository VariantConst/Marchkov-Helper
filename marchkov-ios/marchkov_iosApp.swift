import SwiftUI
import SwiftData

@main
struct marchkov_iosApp: App {
    @StateObject private var brightnessManager = BrightnessManager()

    var body: some Scene {
        WindowGroup {
            LoginView()
                .environmentObject(brightnessManager)
        }
    }
}
