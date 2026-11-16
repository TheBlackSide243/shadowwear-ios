import SwiftUI

/// One piece: its photos to swipe through, what it is, and the actions on it.
struct ItemDetailView: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    let id: Item.ID

    @State private var page: Photo.ID?
    @State private var editing: Item?
    @State private var source: PhotoSource?
    @State private var working: String?
    @State private var confirmDelete = false

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
        .photoSource($source) { images in Task { await addPhotos(images) } }
        .sheet(item: $editing) { draft in
            NavigationStack {
                ItemEditor(item: Binding(get: { editing ?? draft }, set: { editing = $0 }))
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
                    Text(item.displayName).font(.title2.bold()).foregroundStyle(Theme.text)
                    Label(item.category.label, systemImage: item.category.symbol)
                        .font(.subheadline).foregroundStyle(Theme.sub)
                }
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
                    InfoRow("Foto", "\(item.photos.count)")
                    InfoRow("Aggiunto il", item.created.formatted(date: .long, time: .omitted))
                }
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
                    Image(systemName: item.favorite ? "star.fill" : "star")
                }
                .accessibilityLabel(Text(LocalizedStringKey(item.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti")))
                Menu {
                    Button { editing = item } label: { Label("Modifica", systemImage: "pencil") }
                    Menu {
                        PhotoSourceButtons(source: $source)
                    } label: { Label("Aggiungi foto", systemImage: "photo.badge.plus") }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Elimina", systemImage: "trash") }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel(Text("Azioni"))
            }
        }
    }

    private func gallery(_ item: Item) -> some View {
        VStack(spacing: 8) {
            if item.photos.isEmpty {
                ZStack {
                    Theme.photo
                    Image(systemName: item.category.symbol).font(.system(size: 50)).foregroundStyle(Theme.sub)
                }
                .frame(height: 320)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else {
                TabView(selection: $page) {
                    ForEach(item.photos) { photo in
                        ZStack(alignment: .bottomTrailing) {
                            Theme.photo
                            if let image = closet.image(of: photo) {
                                Image(uiImage: image).resizable().scaledToFit()
                                    .padding(photo.usesCutout ? 18 : 0)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            photoMenu(item, photo)
                        }
                        .tag(Optional(photo.id))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: item.photos.count > 1 ? .always : .never))
                .frame(height: 420)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.line, lineWidth: 1))
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
                .background(Theme.bg.opacity(0.75), in: Circle())
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
