import SwiftUI

/// A chat with the AI about the closet: it knows the pieces (by number), the weather and the diary.
/// The pieces it names show up under its answer, to open.
struct StylistChatView: View {
    @Environment(Closet.self) private var closet
    @Environment(WeatherService.self) private var weather
    @Environment(AIService.self) private var ai
    @State private var messages: [ChatMessage] = Demo.chat
    @State private var draft = ""
    @State private var thinking = false
    @State private var error: String?
    @FocusState private var typing: Bool

    private let starters = [
        "Cosa mi metto oggi?",
        "Cosa sta bene con i jeans?",
        "Cosa manca nel mio armadio?",
        "Un outfit per una cena elegante",
    ]

    /// The pieces in the order the AI saw them (the same filter as in AIService.stylist).
    private var listed: [Item] {
        Array(closet.items.filter { !$0.stored }.prefix(ai.config.provider == .device ? 60 : 300))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { reader in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if !ai.canTalk {
                            Panel {
                                AINeeded(text: String(localized: "Lo stylist ha bisogno dell'IA: accendila in Strumenti → Intelligenza artificiale."))
                                NavigationLink(value: MoreView.Tool.ai) { Text("Imposta l'IA") }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        } else if messages.isEmpty {
                            Text("Chiedi qualcosa sul tuo armadio: lo stylist conosce i tuoi capi, il meteo di oggi e cosa hai messo di recente.").prose()
                                .font(.subheadline).foregroundStyle(Theme.sub)
                            FlowLayout(spacing: 8) {
                                ForEach(starters, id: \.self) { text in
                                    Button { send(String(localized: String.LocalizationValue(text))) } label: {
                                        Text(LocalizedStringKey(text)).font(.subheadline)
                                            .padding(.horizontal, 12).padding(.vertical, 8)
                                            .background(Theme.input, in: Capsule())
                                            .foregroundStyle(Theme.text)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                        if thinking {
                            HStack(spacing: 8) {
                                ProgressView().tint(Theme.accent)
                                Text("Lo stylist ci pensa…").font(.subheadline).foregroundStyle(Theme.sub)
                            }
                            .id("thinking")
                        }
                        ErrorBanner(error: $error)
                    }
                    .padding(16)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) { _, _ in
                    withAnimation { reader.scrollTo(messages.last?.id, anchor: .bottom) }
                }
                .onChange(of: thinking) { _, now in
                    if now { withAnimation { reader.scrollTo("thinking", anchor: .bottom) } }
                }
            }
            if ai.canTalk { inputBar }
        }
        .screen()
        .navigationTitle("Stylist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !messages.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { messages = [] } label: { Label("Nuova conversazione", systemImage: "square.and.pencil") }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Scrivi allo stylist…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($typing)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.deep, in: Theme.round)
                .overlay(Theme.round.strokeBorder(Theme.line, lineWidth: 1))
            Button { send(draft) } label: {
                Image(systemName: "arrow.up").font(.headline)
                    .frame(width: 38, height: 38)
                    .background(Theme.accent, in: Circle())
                    .foregroundStyle(Theme.onAccent)
            }
            .disabled(thinking || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text("Invia"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.bg)
    }

    @ViewBuilder private func bubble(_ message: ChatMessage) -> some View {
        if message.fromUser {
            HStack {
                Spacer(minLength: 50)
                Text(message.text).prose()
                    .padding(12)
                    .background(Theme.accent.opacity(0.25), in: Theme.round)
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
            }
        } else {
            let pieces = Self.mentioned(message.text, in: listed)
            VStack(alignment: .leading, spacing: 10) {
                Text(Self.readable(message.text, pieces: listed)).prose()
                    .foregroundStyle(Theme.text)
                    .textSelection(.enabled)
                if !pieces.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(pieces) { item in
                                NavigationLink(value: AppRoute.item(item.id)) {
                                    VStack(spacing: 4) {
                                        PieceImage(item: item)
                                            .frame(width: 64, height: 74)
                                            .background(Theme.stage, in: Theme.roundSmall)
                                            .clipShape(Theme.roundSmall)
                                        Text(item.displayName).font(.caption2).foregroundStyle(Theme.sub).lineLimit(1).frame(width: 70)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
    }

    /// The pieces named as [n] in an answer, each once, in order.
    static func mentioned(_ text: String, in items: [Item]) -> [Item] {
        guard let regex = try? NSRegularExpression(pattern: #"\[(\d{1,3})\]"#) else { return [] }
        var out: [Item] = []
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range(at: 1), in: text), let n = Int(text[range]), n >= 1, n <= items.count else { continue }
            let item = items[n - 1]
            if !out.contains(where: { $0.id == item.id }) { out.append(item) }
        }
        return out
    }

    /// "[3]" becomes the name of piece 3, so the answer reads well.
    static func readable(_ text: String, pieces: [Item]) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\s?\[(\d{1,3})\]"#) else { return text }
        var out = text
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            guard let whole = Range(match.range, in: out), let number = Range(match.range(at: 1), in: text),
                  let n = Int(text[number]), n >= 1, n <= pieces.count else { continue }
            let name = pieces[n - 1].displayName
            // Already written by the AI just before: drop the number only.
            let before = out[..<whole.lowerBound].suffix(name.count + 2).lowercased()
            out.replaceSubrange(whole, with: before.contains(name.lowercased()) ? "" : " (\(name))")
        }
        return out
    }

    private func send(_ text: String) {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, !thinking else { return }
        draft = ""
        error = nil
        messages.append(ChatMessage(fromUser: true, text: question))
        thinking = true
        Task {
            defer { thinking = false }
            do {
                let answer = try await ai.stylist(messages, items: closet.items, wears: closet.wears, conditions: weather.today)
                messages.append(ChatMessage(fromUser: false, text: answer))
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - Selfie

/// A photo of the user in today's clothes: the AI finds which pieces of the closet they are, and
/// they go in the diary after a check.
struct SelfieView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @State private var source: PhotoSource?
    @State private var photo: UIImage?
    @State private var found: [Item.ID] = []
    @State private var picked: Set<Item.ID> = []
    @State private var looking = false
    @State private var error: String?
    @State private var saved = false
    @State private var choosing = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !ai.canSee {
                    Panel {
                        AINeeded(text: String(localized: "Il selfie ha bisogno di un'IA che guarda le foto: il server ShadowWear o un tuo servizio IA."))
                        NavigationLink(value: MoreView.Tool.ai) { Text("Imposta l'IA") }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                Text("Fatti una foto allo specchio con l'outfit di oggi: l'IA la confronta con i tuoi capi e ti propone quali sono. Controlli tu, poi va nel diario. La foto non viene salvata.").prose()
                    .font(.subheadline).foregroundStyle(Theme.sub)
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFit()
                        .frame(maxHeight: 360)
                        .frame(maxWidth: .infinity)
                        .clipShape(Theme.round)
                }
                Menu { PhotoSourceButtons(source: $source) } label: {
                    Label(photo == nil ? "Scatta o scegli la foto" : "Un'altra foto", systemImage: "camera")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Theme.accent, in: Capsule())
                        .foregroundStyle(Theme.onAccent)
                }
                .disabled(!ai.canSee || looking)
                .opacity(!ai.canSee || looking ? 0.5 : 1)
                if looking {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.accent)
                        Text("L'IA cerca i tuoi capi nella foto…").font(.subheadline).foregroundStyle(Theme.sub)
                    }
                }
                ErrorBanner(error: $error)
                if photo != nil && !looking {
                    Panel(found.isEmpty ? String(localized: "Nessun capo riconosciuto") : String(localized: "Riconosciuti: \(found.count)")) {
                        ForEach(found.compactMap(closet.item)) { item in
                            pickRow(item)
                        }
                        Button { choosing = true } label: { Label("Aggiungi un capo a mano", systemImage: "plus") }
                            .buttonStyle(SecondaryButtonStyle())
                        Button {
                            closet.wear(Array(picked).sorted { a, b in (found.firstIndex(of: a) ?? 99) < (found.firstIndex(of: b) ?? 99) })
                            saved = true
                        } label: { Label("Segna nel diario di oggi", systemImage: "checkmark.circle") }
                            .buttonStyle(PrimaryButtonStyle())
                            .disabled(picked.isEmpty || saved)
                        if saved {
                            Label("Fatto: è nel diario di oggi.", systemImage: "checkmark").font(.subheadline).foregroundStyle(Theme.good)
                        }
                    }
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Selfie dell'outfit")
        .navigationBarTitleDisplayMode(.inline)
        .photoSource($source, multiple: false) { images in
            guard let image = images.first else { return }
            Task { await look(image) }
        }
        .sheet(isPresented: $choosing) {
            PiecePicker(exclude: Set(found)) { id in
                found.append(id)
                picked.insert(id)
                saved = false
            }
        }
    }

    private func pickRow(_ item: Item) -> some View {
        Button {
            if picked.contains(item.id) { picked.remove(item.id) } else { picked.insert(item.id) }
            saved = false
        } label: {
            PieceLine(item: item, detail: item.category.label) {
                Image(systemName: picked.contains(item.id) ? "checkmark.circle.fill" : "circle")
                    .font(.title3).foregroundStyle(picked.contains(item.id) ? Theme.accent : Theme.line)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func look(_ image: UIImage) async {
        photo = image
        found = []
        picked = []
        saved = false
        error = nil
        looking = true
        defer { looking = false }
        do {
            found = try await ai.whichPieces(in: image, items: closet.items.filter { !$0.stored })
            picked = Set(found)
        } catch {
            self.error = error.localizedDescription
        }
    }
}

/// Picks one piece of the closet, with a search.
struct PiecePicker: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    var exclude: Set<Item.ID> = []
    let pick: (Item.ID) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                    ForEach(closet.items.filter { !exclude.contains($0.id) && $0.matches(query) }) { item in
                        Button {
                            pick(item.id)
                            dismiss()
                        } label: { ItemCard(item: item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .screen()
            .searchable(text: $query, prompt: Text("Cerca nell'armadio"))
            .navigationTitle("Scegli un capo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } } }
        }
    }
}
