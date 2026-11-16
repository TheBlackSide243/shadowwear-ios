import SwiftUI

@main
struct ShadowWearApp: App {
    @State private var closet = Demo.isOn ? Demo.closet() : Closet()
    @State private var weather = Demo.isOn ? WeatherService(defaults: UserDefaults(suiteName: "demo") ?? .standard, demo: Demo.forecast) : WeatherService()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(closet)
                .environment(weather)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
        }
    }
}

/// Settings stored with @AppStorage.
enum Prefs {
    /// Cut the piece out of its background as photos are added.
    static let removeBackground = "removeBackground"
    static let sortOrder = "sortOrder"
}
