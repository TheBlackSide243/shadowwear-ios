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

/// Address, then user name and password, or the code shown by the site (only for the server: the
/// app alone has no sign-in at all).
struct ServerConnectView: View {
    enum Way: Hashable { case password, code }

    @Environment(SyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss
    /// Opened from the QR code of the site: address and code already there.
    var link: SyncService.LinkRequest?
    @State private var way: Way = Demo.screen == "code" ? .code : .password
    @State private var address = ["newserver", "code"].contains(Demo.screen) ? "192.168.1.10:30320" : ""
    @State private var user = Demo.screen == "newserver" ? "armadio" : ""
    @State private var password = ""
    @State private var repeated = ""
    @State private var code = Demo.screen == "code" ? "K7QM-4XPA-9TRC" : ""
    /// The server is new: the form creates its account instead of signing in.
    @State private var creating = Demo.screen == "newserver"
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !creating && link == nil {
                        Picker("Accesso", selection: $way) {
                            Text("Password").tag(Way.password)
                            Text("Codice dal sito").tag(Way.code)
                        }
                        .pickerStyle(.segmented)
                    }
                    Panel("Server") {
                        Field(title: "Indirizzo", text: $address, prompt: "192.168.1.10:30320", keyboard: .URL)
                        if way == .code {
                            Field(title: "Codice", text: $code, prompt: "XXXX-XXXX-XXXX", keyboard: .asciiCapable)
                        } else {
                            Field(title: "Nome utente", text: $user, keyboard: .asciiCapable)
                            Field(title: "Password", text: $password, secure: true)
                            if creating {
                                Field(title: "Ripeti la password", text: $repeated, secure: true)
                            }
                        }
                        Text(LocalizedStringKey(help))
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    if link != nil {
                        Label("Collega solo un server tuo: l'armadio di questo iPhone andrà anche lì.", systemImage: "exclamationmark.shield")
                            .font(.footnote).foregroundStyle(Theme.warn)
                    }
                    if let error {
                        Text(error).font(.footnote).foregroundStyle(Theme.bad)
                    }
                    Button {
                        Task { await connect() }
                    } label: {
                        if working { ProgressView().tint(Theme.bg) } else { Text(LocalizedStringKey(creating ? "Crea l'account e collega" : "Collega")) }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(working || !ready)
                }
                .padding(16)
            }
            .screen()
            .navigationTitle(LocalizedStringKey(creating ? "Nuovo server" : "Collega al server"))
            .onChange(of: address) { if link == nil { creating = false } }
            .onChange(of: way) { error = nil }
            .onAppear {
                if let link {
                    way = .code
                    address = link.server
                    code = link.code
                }
                if address.isEmpty, let server = sync.server { address = server.absoluteString }
                if user.isEmpty { user = sync.lastUser }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
        }
    }

    private var help: String {
        if way == .code {
            return "Sul sito del server, in Impostazioni → Collega un dispositivo, crea un codice: vale 10 minuti e una volta sola. Puoi anche inquadrare il suo QR con la fotocamera dell'iPhone. Nessuna password da scrivere qui."
        }
        if creating {
            return "Questo server è nuovo: scegli adesso il nome utente e la password (almeno 10 caratteri, meglio qualche parola). Serviranno anche sul sito e sugli altri dispositivi. L'account si crea solo dalla rete di casa, con l'indirizzo della NAS."
        }
        return "Indirizzo del server, per esempio quello della NAS con la porta 30320, oppure il suo dominio. Se il server è nuovo, qui crei anche il suo account. La prima volta l'armadio di questo iPhone e quello del server si uniscono: non si perde niente."
    }

    private var ready: Bool {
        if address.isEmpty { return false }
        if way == .code { return code.filter { $0.isLetter || $0.isNumber }.count == 12 }
        return !user.isEmpty && !password.isEmpty && (!creating || !repeated.isEmpty)
    }

    private func connect() async {
        if way == .password && creating {
            if password.count < 10 {
                error = String(localized: "La password deve avere almeno 10 caratteri.")
                return
            }
            if password != repeated {
                error = String(localized: "Le password non sono uguali.")
                return
            }
        }
        working = true
        defer { working = false }
        do {
            if way == .code {
                try await sync.connect(address: address, code: code)
            } else {
                try await sync.connect(address: address, user: user, password: password, create: creating)
            }
            dismiss()
        } catch SyncService.SyncError.needsAccount {
            // A new server: the same form, with the password to repeat, creates its account.
            error = nil
            repeated = ""
            withAnimation { creating = true }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
