import SwiftUI

/// One piece: its photos to swipe through, what it is, and the actions on it.
struct ItemDetailView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    let id: Item.ID

    @State private var page: Photo.ID?
    @State private var editing: Item?
    @State private var source: PhotoSource?
    /// The photo being picked is of the label, for the AI to read, not one to add.
    @State private var forLabel = false
    /// The photos in the editor: the ones added there are deleted if the piece is not saved.
    @State private var editedPhotos: [Photo] = []
    @State private var working: String?
    @State private var confirmDelete = false
    @State private var saving: OutfitDraft?
    @State private var aiIdeas: [AIOutfit] = []
    @State private var thinking = false

    var body: some View {
        Group {
            if let item = closet.item(id) {
                content(item)
            } else {
                Text("Questo capo non c'è più.").foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .screen()
        .navigationBarTitleDisplayMode(.inline)
        .photoSource($source) { images in
            let label = forLabel
            forLabel = false
            Task {
                if label, let image = images.first { await readLabel(image) } else { await addPhotos(images) }
            }
        }
        .sheet(item: $editing, onDismiss: dropUnsavedPhotos) { draft in
            NavigationStack {
                // While the sheet closes `editing` is already nil: the piece as saved, not the one
                // the sheet opened with (fewer photos).
                ItemEditor(item: Binding(get: { editing ?? closet.item(draft.id) ?? draft }, set: { editing = $0; editedPhotos = $0.photos }))
                    .screen()
                    .navigationTitle("Modifica")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annulla") { editing = nil } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Salva") {
                                if let edited = editing { closet.update(edited) }
                                editing = nil
                            }
                            .bold()
                        }
                    }
            }
        }
        .task {
            if Demo.screen == "edit", let item = closet.item(id) { editing = item }
        }
        .sheet(item: $saving) { draft in
            OutfitEditor(draft: draft) { _ in saving = nil }
        }
        .confirmationDialog("Eliminare questo capo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Elimina il capo e le sue foto", role: .destructive) {
                closet.delete(id)
                dismiss()
            }
        }
    }

    private func content(_ item: Item) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gallery(item)
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.displayName).font(.title.bold()).foregroundStyle(Theme.text)
                    Label(item.brand.isEmpty ? item.category.label : "\(item.category.label), \(item.brand)", systemImage: item.category.symbol)
                        .font(.subheadline).foregroundStyle(Theme.sub)
                }
                numbers(item)
                if !item.colors.isEmpty {
                    Panel("Colori") {
                        FlowRow(items: item.colors.compactMap(PaletteColor.named)) { swatch in
                            HStack(spacing: 6) {
                                ColorDot(color: swatch.color, size: 14)
                                Text(swatch.name).font(.subheadline).foregroundStyle(Theme.text)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Theme.input, in: Capsule())
                        }
                    }
                }
                Panel("Dettagli") {
                    InfoRow("Marca", item.brand.isEmpty ? "—" : item.brand)
                    InfoRow("Taglia", item.size.isEmpty ? "—" : item.size)
                    InfoRow("Peso", item.warmth == nil ? String(localized: "\(item.effectiveWarmth.label) (automatico)") : item.effectiveWarmth.label)
                    if !item.material.isEmpty { InfoRow("Tessuto", item.material) }
                    if !item.pattern.isEmpty { InfoRow("Fantasia", item.pattern) }
                    if !item.style.isEmpty { InfoRow("Stile", item.style) }
                    if let formality = item.formality { InfoRow("Quanto è elegante", formality.label) }
                    InfoRow("Stagioni", Season.allCases.filter { item.effectiveSeasons.contains($0) }.map(\.label).joined(separator: ", ")
                            + (item.seasons.isEmpty ? String(localized: " (dal peso)") : ""))
                    if let price = item.price { InfoRow("Prezzo", Wish.format(price, currency: "")) }
                    if item.stored { InfoRow("Stato", String(localized: "Messo via per la stagione")) }
                    InfoRow("Foto", "\(item.photos.count)")
                    InfoRow("Aggiunto il", item.created.formatted(date: .long, time: .omitted))
                }
                worn(item)
                pairings(item)
                if !item.notes.isEmpty {
                    Panel("Note") {
                        Text(item.notes).font(.subheadline).foregroundStyle(Theme.text).textSelection(.enabled)
                    }
                }
                if let working {
                    HStack(spacing: 10) {
                        ProgressView().tint(Theme.accent)
                        Text(working).font(.subheadline).foregroundStyle(Theme.sub)
                    }
                }
            }
            .padding(16)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    closet.toggleFavorite(item.id)
                } label: {
                    Label(LocalizedStringKey(item.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti"),
                          systemImage: item.favorite ? "star.fill" : "star")
                }
                Menu {
                    Button { editing = item } label: { Label("Modifica", systemImage: "pencil") }
                    if ai.canSee, !item.photos.isEmpty {
                        Button { Task { await describe(item) } } label: { Label("Descrivi con l'IA", systemImage: "sparkles") }
                    }
                    if ai.canSee {
                        Menu {
                            if CameraPicker.isAvailable {
                                Button { forLabel = true; source = .camera } label: { Label("Scatta una foto", systemImage: "camera") }
                            }
                            Button { forLabel = true; source = .library } label: { Label("Scegli dalle foto", systemImage: "photo.on.rectangle") }
                        } label: { Label("Leggi l'etichetta", systemImage: "tag") }
                    }
                    Menu {
                        PhotoSourceButtons(source: Binding(get: { source }, set: { forLabel = false; source = $0 }))
                    } label: { Label("Aggiungi foto", systemImage: "photo.badge.plus") }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina", systemImage: "trash") }
                } label: { Label("Azioni", systemImage: "ellipsis.circle") }
            }
        }
    }

    /// How often it was worn, and the outfits it is in.
    @ViewBuilder private func worn(_ item: Item) -> some View {
        let days = closet.days(worn: item.id)
        let outfits = closet.outfits.filter { $0.items.contains(item.id) }
        Panel("Diario") {
            if let every = Care.washEvery(item) {
                let since = closet.wearsSinceWash(item)
                InfoRow("Dall'ultimo lavaggio", String(localized: "\(since) di \(every) volte"),
                        color: since >= every ? Theme.warn : Theme.text)
            }
            HStack(spacing: 8) {
                Button {
                    closet.wear([item.id])
                } label: { Label("L'ho messo oggi", systemImage: "checkmark.circle") }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(days.first == Day.key(Date()))
                if Care.washEvery(item) != nil {
                    Button {
                        closet.markWashed([item.id])
                    } label: { Label("Lavato", systemImage: "washer") }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(closet.wearsSinceWash(item) == 0)
                }
            }
        }
        if !outfits.isEmpty {
            Panel("Negli outfit") {
                ForEach(outfits) { outfit in
                    NavigationLink(value: AppRoute.outfit(outfit.id)) {
                        HStack(spacing: 12) {
                            OutfitCollage(items: closet.pieces(of: outfit), spacing: 3)
                                .frame(width: 54, height: 66)
                                .clipShape(Rectangle())
                            Text(outfit.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.sub)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// The piece in three numbers: how often it was worn, when last, and what each wear cost.
    private func numbers(_ item: Item) -> some View {
        let days = closet.days(worn: item.id)
        let last = days.first.flatMap { Day.date($0) }
        return HStack(spacing: 10) {
            StatTile(value: "\(days.count)", label: "Volte messo")
            StatTile(value: last.map { $0.formatted(.dateTime.day().month(.abbreviated)) } ?? "—", label: "L'ultima volta")
            if let price = item.price, !days.isEmpty {
                StatTile(value: Wish.format(price / Double(days.count), currency: ""), label: "Costo per uso")
            }
        }
    }

    private func gallery(_ item: Item) -> some View {
        VStack(spacing: 8) {
            if item.photos.isEmpty {
                ZStack {
                    Theme.stage
                    Image(systemName: item.category.symbol).font(.system(size: 50)).foregroundStyle(Theme.sub)
                }
                .frame(height: 320)
                .clipShape(Rectangle())
            } else {
                TabView(selection: $page) {
                    ForEach(item.photos) { photo in
                        ZStack(alignment: .bottomTrailing) {
                            Theme.stage
                            if let image = closet.image(of: photo) {
                                Image(uiImage: image).resizable().scaledToFit()
                                    .pieceShadow(photo.usesCutout)
                                    .padding(photo.usesCutout ? 26 : 0)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            photoMenu(item, photo)
                        }
                        .tag(Optional(photo.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: item.photos.count > 1 ? .always : .never))
                .frame(height: 420)
                .clipShape(Rectangle())
                .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
            }
        }
    }

    private func photoMenu(_ item: Item, _ photo: Photo) -> some View {
        Menu {
            if photo.hasCutout {
                Button {
                    change(item, photo) { $0.showCutout.toggle() }
                } label: {
                    Label(LocalizedStringKey(photo.showCutout ? "Mostra con lo sfondo" : "Mostra senza sfondo"),
                          systemImage: photo.showCutout ? "photo" : "person.crop.rectangle")
                }
            } else {
                Button { Task { await cutout(item, photo) } } label: { Label("Togli lo sfondo", systemImage: "scissors") }
            }
            if item.photos.first?.id != photo.id {
                Button {
                    var changed = item
                    changed.photos.removeAll { $0.id == photo.id }
                    changed.photos.insert(photo, at: 0)
                    closet.update(changed)
                } label: { Label("Usa come copertina", systemImage: "rectangle.stack") }
            }
            if item.photos.count > 1 {
                Button(role: .destructive) {
                    var changed = item
                    changed.photos.removeAll { $0.id == photo.id }
                    closet.update(changed)
                } label: { Label("Elimina questa foto", systemImage: "trash") }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.bold())
                .foregroundStyle(Theme.text)
                .frame(width: 36, height: 36)
                .background(Theme.input, in: Circle())
                .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
        }
        .padding(12)
        .padding(.bottom, item.photos.count > 1 ? 22 : 0)
        .accessibilityLabel(Text("Foto"))
    }

    private func change(_ item: Item, _ photo: Photo, _ edit: (inout Photo) -> Void) {
        var changed = item
        guard let i = changed.photos.firstIndex(where: { $0.id == photo.id }) else { return }
        edit(&changed.photos[i])
        closet.update(changed)
    }

    private func cutout(_ item: Item, _ photo: Photo) async {
        guard let original = closet.original(of: photo) else { return }
        working = String(localized: "Tolgo lo sfondo…")
        defer { working = nil }
        let cut = await Task.detached(priority: .userInitiated) { PhotoProcessor.cutout(original) }.value
        guard let cut else {
            closet.error = String(localized: "Non ho trovato il capo in questa foto. Prova con una foto su uno sfondo semplice.")
            return
        }
        guard let updated = closet.storeCutout(cut, for: photo), let current = closet.item(item.id) else { return }
        var changed = current
        if let i = changed.photos.firstIndex(where: { $0.id == photo.id }) { changed.photos[i] = updated }
        closet.update(changed)
    }

    /// Outfits around this piece: the app's own at once, the AI's when asked.
    @ViewBuilder private func pairings(_ item: Item) -> some View {
        let own = Stylist.pairings(for: item, items: closet.items, lastWorn: closet.lastWorn, conditions: weather.today,
                                   taste: Taste(dirty: Set(closet.laundry.map(\.id)), affinity: Care.affinity(closet.wears)))
        if !own.isEmpty || ai.canTalk {
            Panel("Abbinamenti") {
                if !aiIdeas.isEmpty {
                    ForEach(aiIdeas) { idea in pairingRow(idea.items, why: idea.why, fromAI: true) }
                }
                ForEach(own, id: \.self) { ids in pairingRow(ids, why: "", fromAI: false) }
                if ai.canTalk {
                    Button { Task { await askPairings(item) } } label: {
                        HStack {
                            if thinking { ProgressView().tint(Theme.accent) }
                            Label(aiIdeas.isEmpty ? "Chiedi abbinamenti all'IA" : "Altri abbinamenti dall'IA", systemImage: "sparkles")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(thinking)
                }
            }
        }
    }

    private func pairingRow(_ ids: [Item.ID], why: String, fromAI: Bool) -> some View {
        let pieces = ids.compactMap(closet.item)
        return HStack(alignment: .top, spacing: 12) {
            OutfitCollage(items: pieces, spacing: 3)
                .frame(width: 74, height: 90)
                .background(Theme.stage, in: Rectangle())
                .clipShape(Rectangle())
            VStack(alignment: .leading, spacing: 6) {
                if fromAI { Label("Dall'IA", systemImage: "sparkles").font(.caption2.bold()).foregroundStyle(Theme.accent) }
                Text(pieces.map(\.displayName).joined(separator: " · ")).font(.caption).foregroundStyle(Theme.text).lineLimit(3)
                if !why.isEmpty { Text(why).font(.caption).foregroundStyle(Theme.sub) }
                HStack(spacing: 8) {
                    Button { closet.wear(ids) } label: { Text("Lo metto oggi") }
                    Button { saving = OutfitDraft(outfit: Outfit(name: "", items: ids)) } label: { Text("Salva") }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.borderless)
            }
            Spacer(minLength: 0)
        }
    }

    private func askPairings(_ item: Item) async {
        thinking = true
        defer { thinking = false }
        do {
            aiIdeas = try await ai.pairings(for: item, items: closet.items, conditions: weather.today)
            if aiIdeas.isEmpty { closet.error = String(localized: "L'IA non ha trovato abbinamenti: riprova.") }
        } catch {
            closet.error = error.localizedDescription
        }
    }

    /// The AI looks at the cover photo; its answer opens in the editor, to check and save.
    private func describe(_ item: Item) async {
        guard let photo = item.photos.first, let image = closet.original(of: photo) ?? closet.image(of: photo) else { return }
        working = String(localized: "L'IA sta guardando la foto…")
        defer { working = nil }
        do {
            let answer = try await ai.describe(image)
            var draft = closet.item(item.id) ?? item
            answer.apply(to: &draft)
            editing = draft
        } catch {
            closet.error = error.localizedDescription
        }
    }

    /// The AI reads the label inside the piece (brand, size, fabric, washing); the answer opens in the editor.
    /// The photo of the label is not kept.
    private func readLabel(_ image: UIImage) async {
        guard let item = closet.item(id) else { return }
        working = String(localized: "L'IA sta leggendo l'etichetta…")
        defer { working = nil }
        do {
            let label = try await ai.readLabel(image)
            var draft = item
            label.apply(to: &draft)
            editing = draft
        } catch {
            closet.error = error.localizedDescription
        }
    }

    /// After the editor closes: photos added there but not saved (Annulla, or the sheet pulled down).
    private func dropUnsavedPhotos() {
        let kept = Set((closet.item(id)?.photos ?? []).map(\.id))
        closet.discard(editedPhotos.filter { !kept.contains($0.id) })
        editedPhotos = []
    }

    private func addPhotos(_ images: [UIImage]) async {
        working = String(localized: "Preparo le foto…")
        defer { working = nil }
        var photos: [Photo] = []
        for image in images {
            let result = await PhotoProcessor.process(image, removeBackground: removeBackground)
            if let photo = closet.store(result) { photos.append(photo) }
        }
        guard var item = closet.item(id) else { return closet.discard(photos) }
        item.photos.append(contentsOf: photos)
        closet.update(item)
        page = photos.first?.id
    }
}

/// Views laid out in rows that wrap.
struct FlowRow<Element: Identifiable, Cell: View>: View {
    let items: [Element]
    @ViewBuilder let cell: (Element) -> Cell

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(items) { cell($0) }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let next = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if next > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row()
            }
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}
