import SwiftUI

@main
struct ShadowWearApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var closet: Closet
    @State private var weather: WeatherService
    @State private var sync: SyncService

    init() {
        let closet = Demo.isOn ? Demo.closet() : Closet()
        _closet = State(initialValue: closet)
        _weather = State(initialValue: Demo.isOn
            ? WeatherService(defaults: UserDefaults(suiteName: "demo") ?? .standard, demo: Demo.forecast)
            : WeatherService())
        _sync = State(initialValue: SyncService(closet: closet, enabled: !Demo.isOn))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(closet)
                .environment(weather)
                .environment(sync)
                .onChange(of: phase) { _, now in
                    // Back in the app: what changed on the other devices, and today's weather.
                    if now == .active { Task { await sync.sync() } }
                }
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
