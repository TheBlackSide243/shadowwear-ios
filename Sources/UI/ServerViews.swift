import SwiftUI
import CoreImage.CIFilterBuiltins
import VisionKit

/// The server part of the settings: connect, sync now, disconnect.
struct ServerPanel: View {
    @Environment(SyncService.self) private var sync
    @State private var connecting = false
    @State private var confirmDisconnect = false
    /// Showing a code (and its QR) for another device.
    @State private var pairing = Demo.screen == "pair"

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
                    Text(error).prose().font(.caption).foregroundStyle(Theme.warn)
                }
                Text(LocalizedStringKey(sync.aiReady
                     ? "IA del server pronta: nel menu di un capo trovi Descrivi con l'IA."
                     : "Per l'IA: sul sito del server, in Impostazioni, scegli un modello di Ollama."))
                    .font(.caption).foregroundStyle(Theme.sub)
                Button { pairing = true } label: { Label("Collega un altro dispositivo", systemImage: "qrcode") }
                    .buttonStyle(SecondaryButtonStyle())
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
                Text("Collega l'app al server ShadowWear sulla tua NAS: l'armadio resta uguale su iPhone, iPad e sul sito da aprire sul PC, e l'IA del server può descrivere i capi.").prose()
                    .font(.caption).foregroundStyle(Theme.sub)
                if let error = sync.error {
                    Text(error).prose().font(.caption).foregroundStyle(Theme.warn)
                }
                Button { connecting = true } label: { Label("Collega al server", systemImage: "server.rack") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(isPresented: $connecting) { ServerConnectView() }
        .sheet(isPresented: $pairing) { LinkCodeView() }
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
    /// The new server is reached from the internet: its account needs the setup code of its log.
    @State private var needsCode = false
    @State private var setupCode = ""
    @State private var working = false
    @State private var error: String?
    @State private var scanning = false
    /// Address and code came from a QR code read in the app.
    @State private var scanned = false

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
                            if QRScanner.available {
                                Button { scanning = true } label: { Label("Inquadra il QR", systemImage: "qrcode.viewfinder") }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        } else {
                            Field(title: "Nome utente", text: $user, keyboard: .asciiCapable)
                            Field(title: "Password", text: $password, secure: true)
                            if creating {
                                Field(title: "Ripeti la password", text: $repeated, secure: true)
                                if needsCode {
                                    Field(title: "Codice di installazione", text: $setupCode, prompt: "XXXXXXXXXXXX", keyboard: .asciiCapable)
                                }
                            }
                        }
                        Text(LocalizedStringKey(help))
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    if link != nil || scanned {
                        Label("Collega solo un server tuo: l'armadio di questo iPhone andrà anche lì.", systemImage: "exclamationmark.shield")
                            .font(.footnote).foregroundStyle(Theme.warn)
                    }
                    if let error {
                        Text(error).prose().font(.footnote).foregroundStyle(Theme.bad)
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
            .onChange(of: address) { if link == nil { creating = false; needsCode = false } }
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
            .sheet(isPresented: $scanning) {
                QRScanner { text in
                    scanning = false
                    if let url = URL(string: text), let request = SyncService.LinkRequest(url) {
                        address = request.server
                        code = request.code
                        scanned = true
                        error = nil
                    } else {
                        error = String(localized: "Questo QR non è un codice di ShadowWear.")
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    private var help: String {
        if way == .code {
            return "Crea un codice sul sito del server (Impostazioni → Collega un dispositivo) o su un iPhone già collegato (Impostazioni → Server → Collega un altro dispositivo): vale 10 minuti e una volta sola. Puoi anche inquadrare il suo QR. Nessuna password da scrivere qui."
        }
        if creating {
            if needsCode {
                return "Questo server è nuovo: scegli adesso il nome utente e la password (almeno 10 caratteri, meglio qualche parola). Lo stai aprendo da internet, quindi serve anche il codice di installazione: il server lo scrive nel suo log al primo avvio (per esempio con docker logs)."
            }
            return "Questo server è nuovo: scegli adesso il nome utente e la password (almeno 10 caratteri, meglio qualche parola). Serviranno anche sul sito e sugli altri dispositivi."
        }
        return "Indirizzo del server, per esempio quello della NAS con la porta 30320, oppure il suo dominio. Se il server è nuovo, qui crei anche il suo account. La prima volta l'armadio di questo iPhone e quello del server si uniscono: non si perde niente."
    }

    private var ready: Bool {
        if address.isEmpty { return false }
        if way == .code { return code.filter { $0.isLetter || $0.isNumber }.count == 12 }
        return !user.isEmpty && !password.isEmpty && (!creating || !repeated.isEmpty) && (!creating || !needsCode || !setupCode.isEmpty)
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
                try await sync.connect(address: address, user: user, password: password, create: creating, setupCode: setupCode)
            }
            dismiss()
        } catch SyncService.SyncError.needsAccount {
            // A new server: the same form, with the password to repeat, creates its account.
            error = nil
            repeated = ""
            needsCode = sync.newServerNeedsCode
            withAnimation { creating = true }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// A code (and its QR) made by this iPhone, already connected, for another iPhone, iPad or browser.
/// It works for ten minutes, once; closing this screen cancels it.
struct LinkCodeView: View {
    @Environment(SyncService.self) private var sync
    @Environment(\.dismiss) private var dismiss
    @State private var link: SyncService.LinkCode? = Demo.screen == "pair"
        ? SyncService.LinkCode(code: "K7QM-4XPA-9TRC", expires: Date().addingTimeInterval(9 * 60 + 42), server: "https://shadowwear.example.org")
        : nil
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("Sull'altro iPhone o iPad inquadra questo QR con la fotocamera, oppure nell'app scegli Collega al server → Codice dal sito e scrivi il codice. Niente password da scrivere là.").prose()
                        .font(.subheadline)
                        .foregroundStyle(Theme.sub)
                        .multilineTextAlignment(.center)
                    if let link {
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            let left = Int(link.expires.timeIntervalSince(context.date).rounded(.down))
                            if left > 0 {
                                VStack(spacing: 12) {
                                    if let url = link.url, let image = QRCode.image(url.absoluteString) {
                                        Image(uiImage: image)
                                            .interpolation(.none)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 220, height: 220)
                                            .padding(14)
                                            .background(.white, in: Theme.roundSmall)
                                            .accessibilityLabel(Text(link.code))
                                    }
                                    Text(link.code)
                                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(Theme.accent)
                                        .textSelection(.enabled)
                                    Text("Vale ancora \(left / 60):\(String(format: "%02d", left % 60)), una volta sola.")
                                        .font(.footnote)
                                        .foregroundStyle(Theme.sub)
                                }
                            } else {
                                Text("Codice scaduto: creane un altro.")
                                    .foregroundStyle(Theme.warn)
                            }
                        }
                    } else if let error {
                        Text(error).prose().font(.footnote).foregroundStyle(Theme.bad)
                    } else {
                        ProgressView().tint(Theme.accent).padding(40)
                    }
                    Button { Task { await make() } } label: { Label("Nuovo codice", systemImage: "arrow.clockwise") }
                        .buttonStyle(SecondaryButtonStyle())
                    Text("Chiudendo questa schermata il codice smette di valere.").prose()
                        .font(.caption)
                        .foregroundStyle(Theme.sub)
                }
                .padding(20)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .screen()
            .navigationTitle("Collega un altro dispositivo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Fine") { dismiss() } }
            }
            .task {
                if link == nil { await make() }
            }
            .onDisappear {
                guard !Demo.isOn else { return }
                Task { await sync.cancelLink() }
            }
        }
    }

    private func make() async {
        guard !Demo.isOn else { return }
        do {
            error = nil
            link = try await sync.makeLink()
        } catch {
            link = nil
            self.error = error.localizedDescription
        }
    }
}

/// A QR code as a sharp image.
enum QRCode {
    static func image(_ text: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 12, y: 12)),
              let cg = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// The camera, reading the first QR code it sees (VisionKit).
struct QRScanner: UIViewControllerRepresentable {
    let found: (String) -> Void

    @MainActor static var available: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])],
                                                qualityLevel: .balanced, isHighlightingEnabled: true)
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        if !scanner.isScanning { try? scanner.startScanning() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(found: found) }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let found: (String) -> Void
        private var done = false

        init(found: @escaping (String) -> Void) { self.found = found }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let code) = item, let text = code.payloadStringValue, !done {
                    done = true
                    dataScanner.stopScanning()
                    found(text)
                    return
                }
            }
        }
    }
}
