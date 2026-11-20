import SwiftUI

/// The fields of a piece: its photos (with or without background), name, kind, colors, brand,
/// size, notes and favorite. Used for a new piece and to edit one.
struct ItemEditor: View {
    @Environment(Closet.self) private var closet
    @AppStorage(Prefs.removeBackground) private var removeBackground = true
    @Binding var item: Item
    /// Shown under the photos: for a new piece, the tick that describes it with the AI.
    var underPhotos: AnyView? = nil
    /// A piece not saved yet: a photo taken away is deleted at once (Annulla deletes the others).
    var isNew = false
    @State private var priceText = ""
    @State private var source: PhotoSource?
    @State private var preparing = false
    /// Photos added on this screen: deleted at once when taken away again.
    @State private var addedHere: Set<Photo.ID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                photos
                if let underPhotos { underPhotos }
                Panel("Capo") {
                    Field(title: "Nome", text: $item.name, prompt: item.category.defaultName)
                    Field(title: "Marca", text: $item.brand, prompt: "Facoltativa")
                    Field(title: "Taglia", text: $item.size, prompt: "Facoltativa")
                    Toggle(isOn: $item.favorite) { Label("Preferito", systemImage: "star") }
                        .tint(Theme.accent)
                        .foregroundStyle(Theme.text)
                }
                Panel("Tipo") {
                    CategoryGrid(selection: $item.category)
                }
                Panel("Peso") {
                    Picker("Peso", selection: $item.warmth) {
                        Text("Automatico").tag(Warmth?.none)
                        ForEach(Warmth.allCases) { Text($0.label).tag(Warmth?.some($0)) }
                    }
                    .pickerStyle(.segmented)
                    Text("Serve per il meteo: i capi pesanti nei giorni freddi, quelli leggeri quando fa caldo. Automatico: giacche e cappotti pesanti, il resto medio.")
                        .font(.caption).foregroundStyle(Theme.sub)
                }
                Panel("Colori") {
                    ColorPickerGrid(selection: $item.colors)
                    Text("Il primo che scegli è il colore principale.").font(.caption).foregroundStyle(Theme.sub)
                }
                Panel("Com'è") {
                    Field(title: "Tessuto", text: $item.material, prompt: "Per esempio cotone, lana")
                    Field(title: "Fantasia", text: $item.pattern, prompt: "Tinta unita, righe, quadri…")
                    Field(title: "Stile", text: $item.style, prompt: "Casual, elegante, sportivo…")
                    Text("Quanto è elegante").font(.caption.weight(.semibold)).foregroundStyle(Theme.sub)
                    FlowLayout(spacing: 8) {
                        ForEach(Formality.allCases) { level in
                            Chip(text: level.label, selected: item.formality == level) {
                                item.formality = item.formality == level ? nil : level
                            }
                        }
                    }
                }
                Panel("Stagioni") {
                    FlowLayout(spacing: 8) {
                        ForEach(Season.allCases) { season in
                            Chip(text: season.label, systemImage: season.symbol, selected: item.seasons.contains(season)) {
                                if let i = item.seasons.firstIndex(of: season) { item.seasons.remove(at: i) } else { item.seasons.append(season) }
                                item.seasons.sort { $0.order < $1.order }
                            }
                        }
                    }
                    Text(item.seasons.isEmpty
                         ? String(localized: "Nessuna scelta: valgono quelle del peso (\(Season.allCases.filter { item.effectiveSeasons.contains($0) }.map(\.label).joined(separator: ", "))).")
                         : String(localized: "Serve per il cambio di stagione."))
                        .font(.caption).foregroundStyle(Theme.sub)
                    Toggle(isOn: $item.stored) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Messo via").foregroundStyle(Theme.text)
                            Text("Fuori stagione: non compare nelle idee del giorno.").font(.caption).foregroundStyle(Theme.sub)
                        }
                    }
                    .tint(Theme.accent)
                }
                Panel("Prezzo e lavaggi") {
                    Field(title: "Prezzo", text: $priceText, prompt: "Facoltativo, per il costo per uso", keyboard: .decimalPad)
                        .onChange(of: priceText) { _, text in item.price = LinkPreview.number(text) }
                    HStack {
                        Text("Da lavare dopo").font(.subheadline).foregroundStyle(Theme.sub)
                        Spacer()
                        Menu {
                            Button(washLabel(nil)) { item.washEvery = nil }
                            Button(washLabel(0)) { item.washEvery = 0 }
                            ForEach([1, 2, 3, 4, 5, 6, 8, 10, 12, 15], id: \.self) { n in
                                Button(washLabel(n)) { item.washEvery = n }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(washLabel(item.washEvery))
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .font(.subheadline.weight(.semibold))
                        }
                    }
                }
                Panel("Note") {
                    TextField("Dove l'hai comprato, come si lava…", text: $item.notes, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(11)
                        .background(Theme.input, in: Rectangle())
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .photoSource($source) { images in Task { await add(images) } }
        .onAppear {
            if priceText.isEmpty, let price = item.price { priceText = String(format: "%.2f", price) }
        }
    }

    private func washLabel(_ every: Int?) -> String {
        switch every {
        case nil:
            let usual = Care.defaultWashEvery(item.category)
            return usual.map { String(localized: "Automatico (\($0) volte)") } ?? String(localized: "Automatico (non si conta)")
        case 0?: return String(localized: "Non contare")
        case 1?: return String(localized: "1 volta")
        case let n?: return String(localized: "\(n) volte")
        }
    }

    /// The photos of the piece (front, back, a detail…) and a tile to add more.
    private var photos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                // By id, not ForEach($item.photos): a binding by position crashes when the list gets
                // shorter under a view still on screen (the edit sheet closing on the saved piece).
                ForEach(item.photos) { photo in
                    VStack(spacing: 8) {
                        ZStack {
                            Theme.stage
                            if let image = closet.image(of: photo, thumbnail: true) {
                                Image(uiImage: image).resizable().scaledToFit().padding(photo.usesCutout ? 10 : 0)
                            }
                        }
                        .frame(width: 170, height: 210)
                        .clipShape(Rectangle())
                        .overlay(alignment: .topLeading) {
                            if item.photos.count > 1 && item.photos.first?.id == photo.id {
                                Text("Copertina").font(.caption2.bold()).foregroundStyle(Theme.text)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Theme.bg.opacity(0.75), in: Capsule())
                                    .padding(8)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            if item.photos.count > 1 { photoMenu(photo) }
                        }
                        if photo.hasCutout {
                            Toggle(isOn: cutoutShown(photo)) { Text("Senza sfondo").font(.caption) }
                                .tint(Theme.accent)
                                .frame(width: 170)
                        } else {
                            Text("Sfondo non tolto").font(.caption).foregroundStyle(Theme.sub)
                        }
                    }
                }
                addTile
            }
        }
        .scrollClipDisabled()
    }

    /// "Senza sfondo" of one photo, found by id each time: still right after photos are added,
    /// moved or taken away.
    private func cutoutShown(_ photo: Photo) -> Binding<Bool> {
        Binding(
            get: { item.photos.first { $0.id == photo.id }?.showCutout ?? photo.showCutout },
            set: { value in
                guard let i = item.photos.firstIndex(where: { $0.id == photo.id }) else { return }
                item.photos[i].showCutout = value
            }
        )
    }

    private func photoMenu(_ photo: Photo) -> some View {
        Menu {
            if item.photos.first?.id != photo.id {
                Button {
                    item.photos.removeAll { $0.id == photo.id }
                    item.photos.insert(photo, at: 0)
                } label: { Label("Usa come copertina", systemImage: "rectangle.stack") }
            }
            Button(role: .destructive) { remove(photo) } label: { Label("Togli la foto", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .font(.footnote.bold())
                .foregroundStyle(Theme.text)
                .frame(width: 30, height: 30)
                .background(Theme.bg.opacity(0.75), in: Circle())
        }
        .padding(8)
        .accessibilityLabel(Text("Foto"))
    }

    /// Another photo of the same piece: the back, a detail…
    private var addTile: some View {
        Menu {
            PhotoSourceButtons(source: $source)
        } label: {
            VStack(spacing: 8) {
                if preparing {
                    ProgressView().tint(Theme.accent)
                    Text("Preparo le foto…").font(.caption).foregroundStyle(Theme.sub)
                } else {
                    Image(systemName: "photo.badge.plus").font(.title2)
                    Text("Aggiungi foto").font(.subheadline.weight(.semibold))
                    Text("Il retro, un dettaglio…").font(.caption).foregroundStyle(Theme.sub)
                }
            }
            .foregroundStyle(Theme.accent)
            .multilineTextAlignment(.center)
            .padding(10)
            .frame(width: item.photos.isEmpty ? 170 : 130, height: 210)
            .background(Theme.input, in: Rectangle())
            .overlay(Rectangle()
                .strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [6, 5])))
        }
        .disabled(preparing)
    }

    private func add(_ images: [UIImage]) async {
        preparing = true
        defer { preparing = false }
        for image in images {
            let result = await PhotoProcessor.process(image, removeBackground: removeBackground)
            if let photo = closet.store(result) {
                item.photos.append(photo)
                addedHere.insert(photo.id)
            }
        }
    }

    private func remove(_ photo: Photo) {
        item.photos.removeAll { $0.id == photo.id }
        // A photo of a saved piece stays until Salva: Annulla brings it back.
        if isNew || addedHere.contains(photo.id) { closet.discard([photo]) }
    }
}

/// The kinds of garment as a grid of buttons.
struct CategoryGrid: View {
    @Binding var selection: Category

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
            ForEach(Category.allCases) { category in
                Button {
                    selection = category
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: category.symbol).frame(width: 18)
                        Text(category.label).font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(selection == category ? Theme.accent.opacity(0.18) : Theme.input,
                                in: Rectangle())
                    .overlay(Rectangle()
                        .stroke(selection == category ? Theme.accent : Theme.line, lineWidth: 1))
                    .foregroundStyle(selection == category ? Theme.accent : Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The palette as swatches: tap to add or remove a color, in the order tapped.
struct ColorPickerGrid: View {
    @Binding var selection: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 10)], spacing: 12) {
            ForEach(PaletteColor.all) { swatch in
                let index = selection.firstIndex(of: swatch.key)
                Button {
                    if let index { selection.remove(at: index) } else { selection.append(swatch.key) }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            ColorDot(color: swatch.color, size: 34)
                            if let index {
                                Circle().stroke(Theme.accent, lineWidth: 3).frame(width: 42, height: 42)
                                Text("\(index + 1)").font(.caption2.bold())
                                    .foregroundStyle(swatch.lab.l > 60 ? Theme.bg : Color.white)
                            }
                        }
                        .frame(width: 44, height: 44)
                        Text(swatch.name).font(.system(size: 9)).foregroundStyle(Theme.sub).lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(swatch.name))
                .accessibilityAddTraits(index != nil ? .isSelected : [])
            }
        }
    }
}
