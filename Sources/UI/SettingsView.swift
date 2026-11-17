import SwiftUI

struct SettingsView: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    @State private var bytes: Int64 = 0
    /// The pages of the first launch, again.
    @State private var introAgain = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Foto") {
                        Toggle(isOn: $removeBackground) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Togli lo sfondo").foregroundStyle(Theme.text)
                                Text("Quando aggiungi un capo, ShadowWear lo ritaglia dallo sfondo. La foto originale resta: puoi rimetterla quando vuoi.")
                                    .font(.caption).foregroundStyle(Theme.sub)
                            }
                        }
                        .tint(Theme.accent)
                    }
                    ServerPanel()
                    Panel("Archivio") {
                        InfoRow("Capi", "\(closet.items.count)")
                        InfoRow("Foto", "\(closet.photoCount)")
                        InfoRow("Outfit", "\(closet.outfits.count)")
                        InfoRow("Giorni nel diario", "\(Set(closet.wears.map(\.day)).count)")
                        InfoRow("Spazio usato", ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                        Text("I capi e le foto sono anche nell'app File, nella cartella ShadowWear → Armadio: puoi copiarli per un backup.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    Panel("Info") {
                        InfoRow("Versione", Self.version)
                        Button { introAgain = true } label: {
                            Label("Rivedi l'introduzione", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                        }
                        Text("© 2026 TheBlackSide243. Tutti i diritti riservati.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Impostazioni")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fatto") { dismiss() }.bold() }
            }
            .task { bytes = closet.diskUsage() }
            .fullScreenCover(isPresented: $introAgain) {
                WelcomeView(replay: true) { introAgain = false }
            }
        }
    }

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }
}
