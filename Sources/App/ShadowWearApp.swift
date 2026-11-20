import SwiftUI

@main
struct ShadowWearApp: App {
    @Environment(\.scenePhase) private var phase
    @State private var closet: Closet
    @State private var weather: WeatherService
    @State private var sync: SyncService
    @State private var ai: AIService
    /// The first-launch choice (on this iPhone or on a server) is made.
    @AppStorage(Prefs.welcomeDone) private var welcomed = false
    /// The QR code of the site was scanned: connect with its code.
    @State private var link: SyncService.LinkRequest?
    /// The first launch is under way: it stays up through the AI step even once the server is connected.
    @State private var welcoming = false

    init() {
        Theme.dressBars()
        let closet = Demo.isOn ? Demo.closet() : Closet()
        _closet = State(initialValue: closet)
        _weather = State(initialValue: Demo.isOn
            ? WeatherService(defaults: UserDefaults(suiteName: "demo") ?? .standard, demo: Demo.forecast)
            : WeatherService())
        let sync = SyncService(closet: closet, enabled: !Demo.isOn)
        _sync = State(initialValue: sync)
        _ai = State(initialValue: AIService(sync: sync, demo: Demo.isOn))
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showWelcome {
                    WelcomeView {
                        withAnimation {
                            welcomed = true
                            welcoming = false
                        }
                    }
                    .onAppear { welcoming = true }
                } else {
                    RootView()
                }
            }
                .environment(closet)
                .environment(weather)
                .environment(sync)
                .environment(ai)
                .onOpenURL { url in
                    if let request = SyncService.LinkRequest(url) { link = request }
                }
                .sheet(item: $link, onDismiss: {
                    if sync.isOn { withAnimation { welcomed = true } }
                }) { request in
                    ServerConnectView(link: request)
                        .environment(sync)
                        .environment(ai)
                }
                .onChange(of: phase) { _, now in
                    // Back in the app: what changed on the other devices, and today's weather.
                    if now == .active {
                        Task {
                            await sync.sync()
                            await refreshReminder()
                        }
                    }
                }
                .modifier(Dressed())
        }
    }
}

extension ShadowWearApp {
    /// The morning notification, written again with what is to wash now.
    @MainActor private func refreshReminder() async {
        let defaults = UserDefaults.standard
        guard !Demo.isOn, defaults.bool(forKey: Reminders.enabledKey) else { return }
        let hour = defaults.object(forKey: Reminders.hourKey) as? Int ?? 7
        let minute = defaults.object(forKey: Reminders.minuteKey) as? Int ?? 30
        await Reminders.schedule(enabled: true, hour: hour, minute: minute, idea: nil, laundry: closet.laundry.count)
    }

    private var showWelcome: Bool {
        if Demo.isOn { return ["welcome", "newserver", "code", "aisetup"].contains(Demo.screen) || Demo.screen?.hasPrefix("intro") == true }
        return !welcomed && (welcoming || !sync.isOn)
    }
}

/// Settings stored with @AppStorage.
enum Prefs {
    /// Cut the piece out of its background as photos are added.
    static let removeBackground = "removeBackground"
    static let sortOrder = "sortOrder"
    static let welcomeDone = "welcomeDone"
    /// The look chosen in Settings (`Palette.id`).
    static let theme = "theme"
}
