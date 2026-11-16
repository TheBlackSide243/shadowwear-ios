import SwiftUI

/// The fields of a piece: its photos (with or without background), name, kind, colors, brand,
/// size, notes and favorite. Used for a new piece and to edit one.
struct ItemEditor: View {
    @Environment(Closet.self) private var closet
    @Binding var item: Item

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
                Panel("Colori") {
                    ColorPickerGrid(selection: $item.colors)
                    Text("Il primo che scegli è il colore principale.").font(.caption).foregroundStyle(Theme.sub)
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
