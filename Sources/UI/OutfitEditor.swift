import SwiftUI

/// What the editor is opened for: a new or existing outfit, or pieces to write in the diary.
struct OutfitDraft: Identifiable {
    let id = UUID()
    var outfit: Outfit
    var isNew: Bool
    /// When set, saving writes the pieces in the diary on that day instead of saving an outfit.
    var logDate: Date?

    init(outfit: Outfit = Outfit(name: "", items: []), isNew: Bool = true, logDate: Date? = nil) {
        self.outfit = outfit
        self.isNew = isNew
        self.logDate = logDate
    }
}

/// Puts an outfit together: tap the pieces to add or remove them, the collage shows the result.
struct OutfitEditor: View {
    @Environment(Closet.self) private var closet
    let draft: OutfitDraft
    /// The id of the saved outfit, or nil when cancelled (or only written in the diary).
    let done: (Outfit.ID?) -> Void

    @State private var outfit: Outfit
    @State private var category: Category?
    @State private var query = ""

    init(draft: OutfitDraft, done: @escaping (Outfit.ID?) -> Void) {
        self.draft = draft
        self.done = done
        _outfit = State(initialValue: draft.outfit)
    }

    private var pieces: [Item] { closet.pieces(of: outfit) }

    private var choices: [Item] {
        SortOrder.category.sort(closet.items.filter {
            category.shows($0) && $0.matches(query)
        })
    }

    private var title: String {
        if draft.logDate != nil { return String(localized: "Cosa hai messo") }
        return draft.isNew ? String(localized: "Nuovo outfit") : String(localized: "Modifica outfit")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    if draft.logDate == nil {
                        Panel("Dettagli") {
                            Field(title: "Nome", text: $outfit.name, prompt: "Per esempio: Ufficio, Weekend")
                            Text("Occasione").font(.caption.weight(.semibold)).foregroundStyle(Theme.sub)
                            FlowRow(items: Occasion.allCases) { o in
                                Chip(text: o.label, systemImage: o.symbol, selected: outfit.occasion == o) {
                                    outfit.occasion = outfit.occasion == o ? nil : o
                                }
                            }
                            Toggle(isOn: $outfit.favorite) { Label("Preferito", systemImage: "star") }
                                .tint(Theme.accent)
                                .foregroundStyle(Theme.text)
                        }
                    }
                    Panel("Capi", trailing: AnyView(Text("\(pieces.count) scelti").font(.caption).foregroundStyle(Theme.sub))) {
                        CategoryChips(selection: $category, counts: Dictionary(grouping: closet.items, by: \.category).mapValues(\.count), margin: 14)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96, maximum: 140), spacing: 10)], spacing: 10) {
                            ForEach(choices) { item in
                                PieceToggle(item: item, selected: outfit.items.contains(item.id)) { toggle(item) }
                            }
                        }
                    }
                    if draft.logDate == nil {
                        Panel("Note") {
                            TextField("Con cosa sta bene, quando metterlo…", text: $outfit.notes, axis: .vertical)
                                .lineLimit(2...6)
                                .padding(11)
                                .background(Theme.deep, in: Theme.round)
                                .overlay(Theme.round.strokeBorder(Theme.line, lineWidth: 1))
                        }
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text("Cerca un capo"))
            .screen()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: { Text(LocalizedStringKey(draft.logDate != nil ? "Annota" : "Salva")) }
                        .bold()
                        .disabled(outfit.items.isEmpty)
                }
            }
        }
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            OutfitCollage(items: pieces)
                .frame(height: 300)
                .clipShape(Theme.round)
                .overlay {
                    if pieces.isEmpty {
                        Text("Tocca i capi qui sotto per aggiungerli.")
                            .font(.subheadline).foregroundStyle(Theme.sub)
                            .padding(.top, 110)
                    }
                }
            if !pieces.isEmpty, !Stylist.wearable(pieces) {
                Label("Manca qualcosa: un vestito, oppure una maglia e dei pantaloni.", systemImage: "info.circle")
                    .font(.caption).foregroundStyle(Theme.warn)
            }
        }
    }

    private func toggle(_ item: Item) {
        if let i = outfit.items.firstIndex(of: item.id) {
            outfit.items.remove(at: i)
        } else {
            outfit.items.append(item.id)
        }
    }

    private func save() {
        if let date = draft.logDate {
            closet.wear(outfit.items, on: date)
            return done(nil)
        }
        var saved = outfit
        if saved.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // A name from the pieces, so the grid does not fill with "Outfit".
            saved.name = pieces.filter { [.top, .dress, .bottom].contains($0.category) }
                .prefix(2).map(\.displayName).joined(separator: " + ")
        }
        closet.update(saved)
        done(saved.id)
    }
}

/// A piece to tap in the editor, with a check when it is in.
struct PieceToggle: View {
    let item: Item
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    PieceImage(item: item)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(0.85, contentMode: .fit)
                        .background(Theme.stage, in: Theme.roundSmall)
                        .overlay(Theme.roundSmall
                            .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2.5 : 1))
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(Theme.bg, Theme.accent)
                            .padding(5)
                    }
                }
                Text(item.displayName).font(.caption).foregroundStyle(selected ? Theme.accent : Theme.text).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.displayName))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
