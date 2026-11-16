import SwiftUI

@main
struct ShadowWearApp: App {
    @State private var closet = Closet()

    var body: some Scene {
        WindowGroup {
            ClosetView()
                .environment(closet)
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
