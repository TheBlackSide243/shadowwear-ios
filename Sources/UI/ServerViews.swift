import SwiftUI

/// The server part of the settings: connect, sync now, disconnect.
struct ServerPanel: View {
    @Environment(SyncService.self) private var sync
    @State private var connecting = false
    @State private var confirmDisconnect = false

    var body: some View {
        Panel("Server") {
            if sync.isOn, let server = sync.server {
                HStack(spacing: 8) {
                    StatusDot(color: sync.error == nil ? Theme.good : Theme.warn)
                    Text(server.host ?? server.absoluteString).foregroundStyle(Theme.text).lineLimit(1)
                    Spacer()
                    if sync.syncing { ProgressView().controlSize(.small).tint(Theme.accent) }
                }
                if let progress = sync.progress {
                    Text(progress).font(.caption).foregroundStyle(Theme.sub)
                } else if let last = sync.lastSync {
                    Text("Ultima sincronizzazione: \(last.formatted(.relative(presentation: .named)))")
                        .font(.caption).foregroundStyle(Theme.sub)
                }
                if let error = sync.error {
                    Text(error).font(.caption).foregroundStyle(Theme.warn)
                }
                Text(LocalizedStringKey(sync.aiReady
                     ? "IA del server pronta: nel menu di un capo trovi Descrivi con l'IA."
                     : "Per l'IA: sul sito del server, in Impostazioni, scegli un modello di Ollama."))
                    .font(.caption).foregroundStyle(Theme.sub)
                HStack(spacing: 10) {
                    Button { Task { await sync.sync() } } label: { Label("Sincronizza ora", systemImage: "arrow.triangle.2.circlepath") }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(sync.syncing)
                    Button { confirmDisconnect = true } label: { Text("Scollega") }
                        .buttonStyle(SecondaryButtonStyle(color: Theme.bad))
                }
            } else {
                HStack(spacing: 8) {
                    StatusDot(color: Theme.sub)
                    Text("Solo su questo iPhone").foregroundStyle(Theme.text)
                }
                Text("Collega l'app al server ShadowWear sulla tua NAS: l'armadio resta uguale su iPhone, iPad e sul sito da aprire sul PC, e l'IA del server può descrivere i capi.")
                    .font(.caption).foregroundStyle(Theme.sub)
                if let error = sync.error {
                    Text(error).font(.caption).foregroundStyle(Theme.warn)
                }
                Button { connecting = true } label: { Label("Collega al server", systemImage: "server.rack") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(isPresented: $connecting) { ServerConnectView() }
        .confirmationDialog("Scollegare il server?", isPresented: $confirmDisconnect, titleVisibility: .visible) {
            Button("Scollega (l'armadio resta sull'iPhone)", role: .destructive) { Task { await sync.disconnect() } }
        }
    }
}

/// Address and password of the server.
struct ServerConnectView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var password = ""
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Server") {
                        Field(title: "Indirizzo", text: $address, prompt: "192.168.1.10:30320", keyboard: .URL)
                        Field(title: "Password", text: $password, secure: true)
                        Text("L'indirizzo e la password del server li trovi sul sito di ShadowWear, in Impostazioni → Collegare l'iPhone. La prima volta l'armadio di questo iPhone e quello del server si uniscono: non si perde niente.")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                    }
                    Button {
                        Task { await connect() }
                    } label: {
                        if working { ProgressView().tint(Theme.bg) } else { Text("Collega") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(working || address.isEmpty || password.isEmpty)
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Collega al server")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
        }
    }

    private func connect() async {
        working = true
        defer { working = false }
        do {
            try await sync.connect(address: address, password: password)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
