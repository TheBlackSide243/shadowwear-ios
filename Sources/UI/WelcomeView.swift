import SwiftUI

/// First launch: the closet only on this iPhone (no sign-in at all) or on the ShadowWear server
/// (address, user name and password). Either can be changed later in Settings → Server.
struct WelcomeView: View {
    @Environment(SyncService.self) private var sync
    /// Called once the choice is made.
    let done: () -> Void
    @State private var connecting = ["newserver", "code"].contains(Demo.screen)

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 30)
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Theme.accent.opacity(0.18))
                        .frame(width: 92, height: 92)
                    Image(systemName: "hanger")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                }
                VStack(spacing: 8) {
                    Text("Benvenuto in ShadowWear")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)
                    Text("Dove vuoi tenere il tuo armadio?")
                        .foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center)
                }
                VStack(spacing: 12) {
                    Choice(icon: "iphone",
                           title: "Usa in locale",
                           detail: "L'armadio resta solo su questo iPhone. Nessun account e nessun login, funziona anche senza internet.") {
                        done()
                    }
                    Choice(icon: "server.rack",
                           title: "Usa un server",
                           detail: "Collega l'app al server ShadowWear con indirizzo, nome utente e password: l'armadio è uguale su iPhone, iPad e sul sito, e l'IA del server può descrivere i capi.") {
                        connecting = true
                    }
                }
                Text("Puoi cambiare idea quando vuoi da Impostazioni → Server.")
                    .font(.footnote)
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
            }
            .padding(20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .screen()
        .sheet(isPresented: $connecting, onDismiss: {
            // Connected: the choice is made. Cancelled: back to the two choices.
            if sync.isOn { done() }
        }) {
            ServerConnectView()
        }
    }
}

/// One of the two big buttons of the first launch.
private struct Choice: View {
    let icon: String
    let title: String
    let detail: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 40, height: 40)
                    .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title))
                        .font(.headline)
                        .foregroundStyle(Theme.text)
                    Text(LocalizedStringKey(detail))
                        .font(.subheadline)
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.sub)
                    .padding(.top, 12)
            }
            .padding(16)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.line, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
