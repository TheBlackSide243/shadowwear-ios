import SwiftUI

/// The closet: every piece in a grid, with search, category and color filters, favorites and
/// the order. The + adds pieces from the camera or the photo library.
struct ClosetView: View {
    @Environment(Closet.self) private var closet
    @AppStorage(Prefs.sortOrder) private var sortRaw = SortOrder.newest.rawValue
    @State private var query = ""
    @State private var category: Category?
    @State private var color: String?
    @State private var favoritesOnly = false
    @State private var source: PhotoSource?
    @State private var importing: ImportBatch?
    @State private var showSettings = false
    @State private var path: [Item.ID] = []

    private var sort: SortOrder { SortOrder(rawValue: sortRaw) ?? .newest }

    private var shown: [Item] {
        sort.sort(closet.items.filter { item in
            (category == nil || item.category == category)
                && (color == nil || item.colors.contains(color!))
                && (!favoritesOnly || item.favorite)
                && item.matches(query)
        })
    }

    var body: some View {
        @Bindable var closet = closet
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ErrorBanner(error: $closet.error)
                    if closet.items.isEmpty {
                        EmptyCloset(source: $source)
                    } else {
                        CategoryChips(selection: $category, counts: counts)
                        if hasFilters {
                            filterSummary
                        }
                        if shown.isEmpty {
                            Text("Nessun capo corrisponde.")
                                .foregroundStyle(Theme.sub)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 12)], spacing: 18) {
                                ForEach(shown) { item in
                                    NavigationLink(value: item.id) { ItemCard(item: item) }
                                        .buttonStyle(PressStyle())
                                        .contextMenu { cardMenu(item) }
                                }
                            }
                            // A filter chosen or taken off: the pieces move to their new places.
                            .animation(.snappy(duration: 0.3), value: shown.map(\.id))
                        }
                    }
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Armadio")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Cerca nell'armadio"))
            .toolbar {
                // Only ☰ on the left (Settings is in its menu): on the open iPhone Duo the bar runs
                // down the right side, and with one more button iOS folds + and the filters into a
                // menu whose submenus come up empty.
                ToolbarItem(placement: .topBarLeading) { SideMenuButton() }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !closet.items.isEmpty { filterMenu }
                    Menu {
                        PhotoSourceButtons(source: $source)
                        AITagToggle()
                    } label: { Label("Aggiungi capi", systemImage: "plus") }
                }
            }
            .navigationDestination(for: Item.ID.self) { id in ItemDetailView(id: id) }
            .appDestinations()
        }
        .photoSource($source) { images in importing = ImportBatch(images: images) }
        .sheet(item: $importing) { batch in
            ImportView(batch: batch) { opened in
                importing = nil
                if let opened { path = [opened] }
            }
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
        .task { showDemoScreen() }
    }

    /// The screen asked for by `-demo -screen <name>`, for the README pictures.
    private func showDemoScreen() {
        guard let screen = Demo.screen, let first = shown.first?.id else { return }
        switch screen {
        case "detail", "edit": path = [first]
        case "shoes": category = .shoes
        case "search": query = String(localized: "nero")
        case "favorites": favoritesOnly = true
        case "settings", "pair": showSettings = true
        default: break
        }
    }

    private var counts: [Category: Int] {
        Dictionary(grouping: closet.items, by: \.category).mapValues(\.count)
    }

    private var hasFilters: Bool { color != nil || favoritesOnly }

    private var filterSummary: some View {
        HStack(spacing: 8) {
            if favoritesOnly {
                FilterTag(text: String(localized: "Preferiti"), systemImage: "star.fill") { favoritesOnly = false }
            }
            if let key = color, let swatch = PaletteColor.named(key) {
                FilterTag(text: swatch.name, swatch: swatch.color) { color = nil }
            }
            Spacer()
            Text("\(shown.count) capi").font(.caption).foregroundStyle(Theme.sub)
        }
    }

    private var filterMenu: some View {
        Menu {
            Picker(selection: $sortRaw) {
                ForEach(SortOrder.allCases) { Text($0.label).tag($0.rawValue) }
            } label: { Label("Ordina", systemImage: "arrow.up.arrow.down") }
            Toggle(isOn: $favoritesOnly) { Label("Solo preferiti", systemImage: "star") }
            Menu {
                Button("Tutti i colori") { color = nil }
                ForEach(PaletteColor.all.filter { key in closet.items.contains { $0.colors.contains(key.key) } }) { swatch in
                    Button {
                        color = swatch.key
                    } label: {
                        if color == swatch.key { Label(swatch.name, systemImage: "checkmark") } else { Text(swatch.name) }
                    }
                }
            } label: { Label("Colore", systemImage: "paintpalette") }
        } label: {
            Label("Ordina e filtra", systemImage: hasFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
        }
    }

    @ViewBuilder private func cardMenu(_ item: Item) -> some View {
        Button {
            closet.toggleFavorite(item.id)
        } label: {
            Label(LocalizedStringKey(item.favorite ? "Togli dai preferiti" : "Aggiungi ai preferiti"),
                  systemImage: item.favorite ? "star.slash" : "star")
        }
        Button(role: .destructive) {
            closet.delete(item.id)
        } label: { Label("Elimina", systemImage: "trash") }
    }
}

/// A piece in the grid: its cover photo on a light panel, name and category.
struct ItemCard: View {
    @Environment(Closet.self) private var closet
    let item: Item

    var body: some View {
        // The piece on its stage, and its name under it on the page: no box around the two.
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topTrailing) {
                Theme.stage
                if let photo = item.photos.first, let image = closet.image(of: photo, thumbnail: true) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .pieceShadow(photo.usesCutout)
                        .padding(photo.usesCutout ? 16 : 0)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: item.category.symbol).font(.largeTitle).foregroundStyle(Theme.sub)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if item.favorite { FavoriteMark() }
            }
            .aspectRatio(0.82, contentMode: .fit)
            .clipShape(Theme.round)
            .overlay(Theme.round.strokeBorder(Theme.line, lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                HStack(spacing: 5) {
                    ForEach(item.colors.prefix(3), id: \.self) { key in
                        if let swatch = PaletteColor.named(key) { ColorDot(color: swatch.color, size: 10) }
                    }
                    Text(item.brand.isEmpty ? item.category.label : item.brand)
                        .font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
                }
            }
            .padding(.horizontal, 4)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// The star on the corner of a favorite piece or outfit.
struct FavoriteMark: View {
    var body: some View {
        Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.accent)
            .padding(7)
            .background(Theme.deep.opacity(0.85), in: Circle())
            .overlay(Circle().strokeBorder(Theme.accent.opacity(0.55), lineWidth: 1))
            .padding(9)
            .accessibilityLabel(Text("Preferiti"))
    }
}

/// The category filter: All, then every category that has pieces, with how many.
struct CategoryChips: View {
    @Binding var selection: Category?
    let counts: [Category: Int]
    /// The padding around it, which the scroll runs into.
    var margin: CGFloat = 16

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: String(localized: "Tutti"), count: counts.values.reduce(0, +), selected: selection == nil) { selection = nil }
                ForEach(Category.allCases.filter { (counts[$0] ?? 0) > 0 }) { category in
                    Chip(text: category.label, systemImage: category.symbol, count: counts[category] ?? 0, selected: selection == category) {
                        selection = selection == category ? nil : category
                    }
                }
            }
        }
        // Runs to the edge of the safe area (not past it: on the closed iPhone Duo the status
        // column sits on the right), with the page margin inside the scroll.
        .contentMargins(.horizontal, margin, for: .scrollContent)
        .padding(.horizontal, -margin)
        // A scroll view draws into the safe area by itself: cut it at its own frame.
        .clipped()
        .sensoryFeedback(.selection, trigger: selection)
    }
}

struct Chip: View {
    let text: String
    var systemImage: String?
    var count: Int?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).font(.caption) }
                Text(text).font(.subheadline.weight(.medium))
                if let count { Text("\(count)").font(.caption).foregroundStyle(selected ? Theme.onAccent.opacity(0.7) : Theme.sub) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(selected ? Theme.accent : Theme.input, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? .clear : Theme.line, lineWidth: 1))
            .foregroundStyle(selected ? Theme.onAccent : Theme.text)
            .contentShape(Capsule())
            .animation(.snappy(duration: 0.2), value: selected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// An active filter, with an x to remove it.
struct FilterTag: View {
    let text: String
    var systemImage: String?
    var swatch: Color?
    let remove: () -> Void

    var body: some View {
        Button(action: remove) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage).foregroundStyle(Theme.accent) }
                if let swatch { ColorDot(color: swatch, size: 12) }
                Text(text)
                Image(systemName: "xmark").font(.caption2.bold()).foregroundStyle(Theme.sub)
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Theme.input, in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.line, lineWidth: 1))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(.plain)
    }
}

struct ColorDot: View {
    let color: Color
    var size: CGFloat = 14

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.text.opacity(0.25), lineWidth: 1))
    }
}

/// The first screen, before there is anything in the closet.
struct EmptyCloset: View {
    @Binding var source: PhotoSource?

    var body: some View {
        VStack(spacing: 16) {
            EmptyMark(symbol: "hanger")
                .padding(.top, 40)
            Text("Il tuo armadio è vuoto").font(.title2.bold()).foregroundStyle(Theme.text)
            Text("Fotografa un capo o sceglilo dalle foto: ShadowWear toglie lo sfondo e riconosce colore e tipo, tutto sul telefono.").prose()
                .font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            VStack(spacing: 10) {
                if CameraPicker.isAvailable {
                    Button { source = .camera } label: { Label("Scatta una foto", systemImage: "camera") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Button { source = .library } label: { Label("Scegli dalle foto", systemImage: "photo.on.rectangle") }
                    .buttonStyle(CameraPicker.isAvailable ? AnyButtonStyle(SecondaryButtonStyle()) : AnyButtonStyle(PrimaryButtonStyle()))
            }
            .frame(maxWidth: 360)
            .padding(.top, 6)
            AITagToggle(boxed: true).frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity)
    }
}

/// The tick, next to the buttons that add photos, for the AI to recognise each new piece:
/// the exact kind (T-shirt, jeans…), the brand and size when it can read them, colors and fabric.
/// The same switch as in Settings → Artificial intelligence; hidden when no AI can see photos.
struct AITagToggle: View {
    @Environment(AIService.self) private var ai
    /// On a screen rather than in a menu: with a line on what it does.
    var boxed = false

    private var isOn: Binding<Bool> {
        Binding(get: { ai.config.autoTag }, set: { value in ai.update { $0.autoTag = value } })
    }

    var body: some View {
        if ai.canSee {
            if boxed {
                Toggle(isOn: isOn) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Riconosci con l'IA", systemImage: "sparkles").foregroundStyle(Theme.text)
                        Text("Tipo, marca, taglia, colori e tessuto, letti dalla foto.").prose()
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                }
                .tint(Theme.accent)
                .padding(.top, 4)
            } else {
                Section {
                    Toggle(isOn: isOn) { Label("Riconosci con l'IA", systemImage: "sparkles") }
                }
            }
        }
    }
}

/// A ButtonStyle chosen at run time.
struct AnyButtonStyle: ButtonStyle {
    private let make: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { make = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { make(configuration) }
}
