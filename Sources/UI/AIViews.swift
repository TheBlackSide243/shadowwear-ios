import SwiftUI

/// Settings → Intelligenza artificiale, and the AI step of the first launch: where the AI runs.
/// In local mode it says so first: the closet stays on the iPhone, and only what each question
/// needs goes to the AI chosen here.
struct AISettingsView: View {
    @Environment(AIService.self) private var ai
    @Environment(SyncService.self) private var sync
    /// At the first launch: a "Continua" button instead of the navigation bar.
    var firstRun = false
    var done: () -> Void = {}

    @State private var url = ""
    @State private var key = ""
    @State private var models: [String] = []
    @State private var testing = false
    @State private var message: String?
    @State private var failed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if firstRun {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 64, height: 64)
                            .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("Vuoi usare l'intelligenza artificiale?")
                            .font(.title2.bold()).foregroundStyle(Theme.text)
                        Text("Con l'IA i capi si etichettano da soli quando li fotografi, e hai lo stylist, gli abbinamenti, il selfie e i consigli per la valigia. Senza, l'app funziona lo stesso.")
                            .foregroundStyle(Theme.sub)
                    }
                }
                modeNote
                Panel("Dove gira l'IA") {
                    ForEach(choices) { provider in
                        ProviderRow(provider: provider, selected: ai.config.provider == provider,
                                    detail: detail(provider), disabled: disabled(provider)) {
                            ai.update { $0.provider = provider; $0.chosen = true }
                            message = nil
                        }
                    }
                }
                if ai.config.provider == .custom { customPanel }
                if ai.config.provider == .server { serverPanel }
                if ai.config.provider == .device { devicePanel }
                if ai.config.provider != .off {
                    Panel("Quando aggiungi un capo") {
                        Toggle(isOn: Binding(get: { ai.config.autoTag }, set: { value in ai.update { $0.autoTag = value } })) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Etichetta con l'IA").foregroundStyle(Theme.text)
                                Text("Nome, tipo, colori, tessuto, fantasia, stile e stagioni scritti dall'IA guardando la foto. Li controlli prima di salvare.")
                                    .font(.caption).foregroundStyle(Theme.sub)
                            }
                        }
                        .tint(Theme.accent)
                        .disabled(!ai.canSee)
                        if !ai.canSee {
                            Text("Serve un'IA che guarda le foto: il server ShadowWear o un tuo servizio con un modello per le immagini.")
                                .font(.caption).foregroundStyle(Theme.warn)
                        }
                    }
                }
                Panel("Lo sfondo delle foto") {
                    Label("Lo toglie l'IA dell'iPhone (Vision), sempre sul telefono e anche senza internet, qualunque scelta fai qui.", systemImage: "scissors")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                }
                if firstRun {
                    Button(action: finish) {
                        Text(ai.config.provider == .off ? "Continua senza IA" : "Continua")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    Text("Puoi cambiare quando vuoi da Impostazioni → Intelligenza artificiale.")
                        .font(.footnote).foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .screen()
        .navigationTitle("Intelligenza artificiale")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            url = ai.config.customURL
            key = ai.apiKey
            if firstRun, !ai.config.chosen {
                // A sensible start: the server's AI when connected, Apple's when the iPhone has it.
                let start: AIProvider = sync.isOn ? .server : (AIService.deviceAvailable ? .device : .off)
                ai.update { $0.provider = start }
            }
        }
        .onDisappear(perform: saveCustom)
    }

    private var choices: [AIProvider] { [.server, .device, .custom, .off] }

    /// Local or server: said plainly, before the choice.
    @ViewBuilder private var modeNote: some View {
        if sync.isOn {
            Label {
                Text("Usi ShadowWear con il server: l'IA più comoda è quella del server, che usa il modello scelto sul sito. Puoi anche usare Apple Intelligence o un tuo servizio IA.")
            } icon: { Image(systemName: "server.rack") }
                .font(.subheadline).foregroundStyle(Theme.text)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Label("Stai usando ShadowWear in locale", systemImage: "iphone")
                    .font(.headline).foregroundStyle(Theme.text)
                Text("L'armadio resta solo su questo iPhone e non c'è un server ShadowWear. Per l'IA puoi usare Apple Intelligence, che gira sull'iPhone, oppure un tuo servizio IA (per esempio Ollama sul computer o sulla NAS): l'iPhone gli manda solo la foto o la domanda di quel momento, con l'elenco dei capi quando serve.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func detail(_ provider: AIProvider) -> String {
        switch provider {
        case .off: String(localized: "Niente IA: l'app propone gli outfit con le sue regole, senza modelli.")
        case .server: sync.isOn
            ? (sync.aiReady ? String(localized: "Il modello scelto sul sito del server. Guarda le foto e scrive.") : String(localized: "Il server non ha ancora un modello: sceglilo sul sito, in Impostazioni."))
            : String(localized: "Solo con l'app collegata al server ShadowWear.")
        case .device: AIService.deviceAvailable
            ? String(localized: "Sull'iPhone, senza internet. Scrive (stylist, abbinamenti, valigia) ma non guarda le foto.")
            : (AIService.deviceProblem ?? "")
        case .custom: String(localized: "Ollama, LM Studio, OpenAI o un servizio compatibile: indirizzo, modello ed eventuale chiave.")
        }
    }

    private func disabled(_ provider: AIProvider) -> Bool {
        switch provider {
        case .server: !sync.isOn
        case .device: !AIService.deviceAvailable
        default: false
        }
    }

    private var serverPanel: some View {
        Panel("Server") {
            HStack(spacing: 8) {
                StatusDot(color: ai.canSee ? Theme.good : Theme.warn)
                Text(ai.summary).font(.subheadline).foregroundStyle(Theme.text)
            }
            Text("Il modello si sceglie sul sito del server, in Impostazioni → Intelligenza artificiale: serve un modello che vede le immagini (per esempio gemma3 o qwen2.5vl).")
                .font(.caption).foregroundStyle(Theme.sub)
        }
    }

    private var devicePanel: some View {
        Panel("Apple Intelligence") {
            Text("Le domande restano sull'iPhone. Il modello di Apple è piccolo: allo stylist arrivano solo i primi 60 capi, e non può guardare le foto (etichette e selfie restano spenti).")
                .font(.subheadline).foregroundStyle(Theme.sub)
        }
    }

    private var customPanel: some View {
        Panel("Il tuo servizio IA") {
            Field(title: "Indirizzo", text: $url, prompt: "http://192.168.1.10:11434", keyboard: .URL)
                .onSubmit(saveCustom)
            Field(title: "Chiave (facoltativa)", text: $key, prompt: "Solo per OpenAI e servizi simili", secure: true)
                .onSubmit(saveCustom)
            Text("Per Ollama basta l'indirizzo con la porta 11434. La chiave resta nel portachiavi di questo iPhone.")
                .font(.caption).foregroundStyle(Theme.sub)
            Button {
                Task { await test() }
            } label: {
                HStack {
                    if testing { ProgressView().tint(Theme.accent) }
                    Text(testing ? "Provo…" : "Prova e mostra i modelli")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .disabled(testing || url.trimmingCharacters(in: .whitespaces).isEmpty)
            if let message {
                Text(message).font(.caption).foregroundStyle(failed ? Theme.bad : Theme.good)
            }
            if !models.isEmpty || !ai.config.visionModel.isEmpty || !ai.config.textModel.isEmpty {
                modelPicker(title: "Modello per le foto", value: ai.config.visionModel) { value in ai.update { $0.visionModel = value } }
                modelPicker(title: "Modello per scrivere", value: ai.config.textModel) { value in ai.update { $0.textModel = value } }
                Text("Per le foto serve un modello che vede le immagini (per esempio gemma3, qwen2.5vl, llava o gpt-4o-mini). Per scrivere va bene lo stesso: lascia «Uguale» se ne usi uno solo.")
                    .font(.caption).foregroundStyle(Theme.sub)
            }
        }
    }

    private func modelPicker(title: String, value: String, set: @escaping (String) -> Void) -> some View {
        HStack {
            Text(LocalizedStringKey(title)).font(.subheadline).foregroundStyle(Theme.sub)
            Spacer()
            Menu {
                Button("Uguale all'altro") { set("") }
                ForEach(models, id: \.self) { model in
                    Button(model) { set(model) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value.isEmpty ? String(localized: "Uguale") : value).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private func saveCustom() {
        ai.update { $0.customURL = url.trimmingCharacters(in: .whitespacesAndNewlines) }
        ai.apiKey = key
    }

    private func test() async {
        saveCustom()
        testing = true
        defer { testing = false }
        do {
            models = try await ai.customModels(url: url, key: key)
            failed = false
            message = models.isEmpty
                ? String(localized: "Il servizio risponde ma non ha modelli.")
                : String(localized: "Collegato: \(models.count) modelli.")
            if ai.config.visionModel.isEmpty && ai.config.textModel.isEmpty, let first = models.first {
                ai.update { $0.visionModel = first }
            }
        } catch {
            failed = true
            message = error.localizedDescription
        }
    }

    private func finish() {
        saveCustom()
        ai.update { $0.chosen = true }
        done()
    }
}

private struct ProviderRow: View {
    let provider: AIProvider
    let selected: Bool
    let detail: String
    let disabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: provider.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(selected ? Theme.bg : Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(selected ? Theme.accent : Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(provider.label).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                    Text(detail).font(.caption).foregroundStyle(Theme.sub).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Theme.accent : Theme.line)
                    .font(.title3)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled && !selected)
        .opacity(disabled && !selected ? 0.5 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A small line under the AI buttons when the AI is off or cannot do this.
struct AINeeded: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "sparkles")
            .font(.caption)
            .foregroundStyle(Theme.sub)
    }
}
