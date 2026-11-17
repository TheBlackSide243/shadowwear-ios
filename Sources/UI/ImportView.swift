import SwiftUI

/// Photos on their way into the closet: each becomes a new piece.
struct ImportBatch: Identifiable {
    let id = UUID()
    let images: [UIImage]
}

/// Processes the picked photos one by one (background, colors, kind), then lets the user check
/// the piece before saving it. Several photos are saved straight away, one piece each, and listed.
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

    var body: some View {
        NavigationStack {
            Group {
                if processed < batch.images.count || tagging != nil {
                    progress
                } else if draft != nil {
                    ItemEditor(item: Binding(get: { draft! }, set: { draft = $0 }))
                } else {
                    summary
                }
            }
            .screen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if processed >= batch.images.count && tagging == nil {
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
        .task { await run() }
    }

    private var title: String {
        if processed < batch.images.count { return String(localized: "Preparo i capi") }
        return draft != nil ? String(localized: "Nuovo capo") : String(localized: "Capi aggiunti")
    }

    private var progress: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().controlSize(.large).tint(Theme.accent)
            if let tagging {
                if batch.images.count > 1 {
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

    private var summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Group {
                    if added.count == 1 { Text("1 capo aggiunto all'armadio.") } else { Text("\(added.count) capi aggiunti all'armadio.") }
                }
                .font(.headline).foregroundStyle(Theme.text)
                Text("Puoi correggere nome, tipo e colori aprendo ogni capo.")
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

    private func run() async {
        guard processed == 0, draft == nil, added.isEmpty else { return }
        var items: [Item] = []
        var originals: [UIImage] = []
        for image in batch.images {
            let result = await PhotoProcessor.process(image, removeBackground: removeBackground)
            if let photo = closet.store(result) {
                let category = result.category ?? .other
                items.append(Item(name: "", category: category, colors: result.colors, photos: [photo]))
                originals.append(result.original)
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
                } catch {
                    failures += 1
                    if failures == 1 {
                        tagProblem = String(localized: "L'IA non ha risposto: \(error.localizedDescription)")
                        if items.count == 1 { closet.error = tagProblem }
                    }
                    // The same problem for the next ones: no use waiting.
                    if failures >= 2 { break }
                }
            }
            tagging = nil
        }
        if items.count == 1 {
            draft = items[0]
        } else {
            for item in items { closet.add(item) }
            added = items
        }
    }
}
