import SwiftUI

/// The fields of a piece: its photos (with or without background), name, kind, colors, brand,
/// size, notes and favorite. Used for a new piece and to edit one.
struct ItemEditor: View {
    @Environment(Closet.self) private var closet
    @Binding var item: Item
    @State private var priceText = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                photos
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
                        .background(Theme.input, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Theme.line, lineWidth: 1))
                }
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
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

    @ViewBuilder private var photos: some View {
        if !item.photos.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach($item.photos) { $photo in
                        VStack(spacing: 8) {
                            ZStack {
                                Theme.photo
                                if let image = closet.image(of: photo, thumbnail: true) {
                                    Image(uiImage: image).resizable().scaledToFit().padding(photo.usesCutout ? 10 : 0)
                                }
                            }
                            .frame(width: 170, height: 210)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
                            if photo.hasCutout {
                                Toggle(isOn: $photo.showCutout) { Text("Senza sfondo").font(.caption) }
                                    .tint(Theme.accent)
                                    .frame(width: 170)
                            } else {
                                Text("Sfondo non tolto").font(.caption).foregroundStyle(Theme.sub)
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
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
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
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
