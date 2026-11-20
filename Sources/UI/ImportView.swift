import SwiftUI

/// Photos on their way into the closet: each becomes a new piece.
struct ImportBatch: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

/// Processes the picked photos one by one (background, colors, kind), then lets the user check
/// the piece before saving it. Several photos: first the question whether they are one piece seen
/// from more sides (front, back…) or a piece each; pieces of their own are saved straight away and listed.
struct ImportView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    let batch: ImportBatch
    /// Called when the sheet is done, with the piece to open if there is one.
    var done: (Item.ID?) -> Void

    @State private var processed = 0
    @State private var draft: Item?
    @State private var added: [Item] = []
    /// The AI is naming the pieces (after the photos are ready).
    @State private var tagging: Int?
    @State private var tagProblem: String?
    /// The photo of the single new piece, as taken: what the AI looks at from the editor.
    @State private var original: UIImage?
    /// The AI is describing the piece open in the editor.
    @State private var describing = false
    /// The AI already filled in the piece open in the editor.
    @State private var described = false
    /// Several photos: all of one piece (true) or a piece each (false). Asked first.
    @State private var together: Bool?

    private var choosing: Bool { batch.images.count > 1 && together == nil }

    var body: some View {
        NavigationStack {
            Group {
                if choosing {
                    chooser
                } else if processed < batch.images.count || tagging != nil {
                    progress
                } else if draft != nil {
                    ItemEditor(item: Binding(get: { draft! }, set: { draft = $0 }), underPhotos: AnyView(aiTick), isNew: true)
                } else {
                    summary
                }
            }
            .screen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if choosing {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annulla") { done(nil) }
                    }
                } else if processed >= batch.images.count && tagging == nil {
                    if let item = draft {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Annulla") {
                                closet.discard(item.photos)
                                done(nil)
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salva") {
                                closet.add(item)
                                done(item.id)
                            }
                            .bold()
                        }
                    } else {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fatto") { done(nil) }.bold()
                        }
                    }
                }
            }
        }
        .task(id: together) { await run() }
    }

    private var title: String {
        if choosing { return String(localized: "Nuove foto") }
        if processed < batch.images.count { return String(localized: "Preparo i capi") }
        return draft != nil ? String(localized: "Nuovo capo") : String(localized: "Capi aggiunti")
    }

    private var progress: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().controlSize(.large).tint(Theme.accent)
            if let tagging {
                if batch.images.count > 1 && together != true {
                    Text("Capo \(tagging + 1) di \(batch.images.count)").font(.headline).foregroundStyle(Theme.text)
                    Bar(value: Double(tagging) / Double(batch.images.count)).frame(maxWidth: 260)
                }
                Label("L'IA riconosce il capo: tipo, marca, colori e tessuto…", systemImage: "sparkles")
                    .font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
            } else {
                if batch.images.count > 1 {
                    Text("Foto \(processed + 1) di \(batch.images.count)").font(.headline).foregroundStyle(Theme.text)
                    Bar(value: Double(processed) / Double(batch.images.count)).frame(maxWidth: 260)
                }
                Text(LocalizedStringKey(removeBackground ? "Tolgo lo sfondo e riconosco colore e tipo…" : "Riconosco colore e tipo…"))
                    .font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    /// Several photos: one piece from more sides, or a piece each.
    private var chooser: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "photo.stack").font(.system(size: 44)).foregroundStyle(Theme.accent)
            Text("\(batch.images.count) foto").font(.title3.bold()).foregroundStyle(Theme.text)
            Text("Sono lo stesso capo visto da più lati, o capi diversi?").prose()
                .font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button { together = true } label: { Label("Un solo capo: fronte, retro…", systemImage: "square.stack") }
                    .buttonStyle(PrimaryButtonStyle())
                Button { together = false } label: { Label("Un capo per ogni foto", systemImage: "square.grid.2x2") }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(.top, 6)
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    if added.count == 1 { Text("1 capo aggiunto all'armadio.") } else { Text("\(added.count) capi aggiunti all'armadio.") }
                }
                .font(.headline).foregroundStyle(Theme.text)
                Text("Puoi correggere nome, tipo e colori aprendo ogni capo.").prose()
                    .font(.subheadline).foregroundStyle(Theme.sub)
                if let tagProblem {
                    Label(tagProblem, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(Theme.warn)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(added) { item in
                        Button { done(item.id) } label: { ItemCard(item: item) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
    }

    /// "Descrivi con l'IA" on the new piece: turning it on describes the piece now, and the next
    /// ones as they are added (the same switch as in the + menu and in Settings).
    private var aiTick: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { ai.config.autoTag && ai.canSee }, set: { value in
                ai.update { $0.autoTag = value }
                if value && !described { Task { await describeDraft() } }
            })) {
                Label("Descrivi con l'IA", systemImage: "sparkles").foregroundStyle(Theme.text)
            }
            .tint(Theme.accent)
            .disabled(!ai.canSee || describing)
            Group {
                if describing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("L'IA guarda la foto…")
                    }
                } else if let tagProblem {
                    Label(tagProblem, systemImage: "exclamationmark.triangle").foregroundStyle(Theme.warn)
                    if ai.canSee && original != nil {
                        Button("Riprova") { Task { await describeDraft() } }
                            .font(.caption.bold()).foregroundStyle(Theme.accent)
                    }
                } else if !ai.canSee {
                    Text("Per usarla scegli un'IA che vede le foto in Impostazioni → Intelligenza artificiale.").prose()
                } else if described {
                    Text("Compilato dall'IA: controlla nome, marca, taglia, tipo e colori prima di salvare.").prose()
                } else {
                    Text("Tipo, marca, taglia, colori e tessuto, letti dalla foto.").prose()
                }
            }
            .font(.caption).foregroundStyle(Theme.sub)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    /// Describes the piece open in the editor, keeping the name the user wrote and the measured colors.
    private func describeDraft() async {
        guard let original, draft != nil, !describing else { return }
        describing = true
        tagProblem = nil
        defer { describing = false }
        do {
            let answer = try await ai.describe(original)
            guard var item = draft else { return }
            let name = item.name
            let colors = item.colors
            answer.apply(to: &item)
            if !name.isEmpty { item.name = name }
            if !colors.isEmpty { item.colors = colors }
            draft = item
            described = true
        } catch {
            tagProblem = String(localized: "L'IA non ha risposto: \(error.localizedDescription)")
        }
    }

    private func run() async {
        guard !choosing, processed == 0, draft == nil, added.isEmpty else { return }
        var items: [Item] = []
        var originals: [UIImage] = []
        for image in batch.images {
            let result = await PhotoProcessor.process(image, removeBackground: removeBackground)
            if let photo = closet.store(result) {
                if together == true, !items.isEmpty {
                    // The back, a detail: more photos of the first piece; kind and colors from the first.
                    items[0].photos.append(photo)
                } else {
                    let category = result.category ?? .other
                    items.append(Item(name: "", category: category, colors: result.colors, photos: [photo]))
                    originals.append(result.original)
                }
            }
            processed += 1
        }
        // The AI names and tags each piece; what it cannot do stays as the phone guessed.
        if ai.config.autoTag && ai.canSee {
            var failures = 0
            for i in items.indices {
                tagging = i
                do {
                    let answer = try await ai.describe(originals[i])
                    // The colors measured on the cut-out are more exact than the AI's words: kept when there are some.
                    let colors = items[i].colors
                    answer.apply(to: &items[i])
                    if !colors.isEmpty { items[i].colors = colors }
                    if items.count == 1 { described = true }
                } catch {
                    failures += 1
                    // With one piece the problem is written under the tick, in the editor.
                    if failures == 1 { tagProblem = String(localized: "L'IA non ha risposto: \(error.localizedDescription)") }
                    // The same problem for the next ones: no use waiting.
                    if failures >= 2 { break }
                }
            }
            tagging = nil
        }
        if items.count == 1 {
            original = originals.first
            draft = items[0]
        } else {
            for item in items { closet.add(item) }
            added = items
        }
    }
}
