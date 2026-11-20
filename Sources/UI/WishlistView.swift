import SwiftUI

/// Things to buy: a link to the shop (its picture and price read from the page) or just a name.
/// "Controlla i prezzi" reads every page again and shows what went down or up.
struct WishlistView: View {
    @Environment(Closet.self) private var closet
    @State private var editing: Wish?
    @State private var checking = false
    @State private var report: String?
    @State private var showBought = false

    var body: some View {
        let open = closet.wishes.filter { !$0.bought }.sorted { $0.created > $1.created }
        let bought = closet.wishes.filter(\.bought).sorted { $0.updated > $1.updated }
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if closet.wishes.isEmpty {
                    Empty(symbol: "cart", title: "Cosa vuoi comprare?",
                          text: "Incolla il link di un negozio: prendo nome, foto e prezzo dalla pagina, e quando controlli i prezzi vedi se sono scesi. Il link lo legge solo questo iPhone.")
                }
                if !open.isEmpty {
                    if open.contains(where: { $0.url != nil }) {
                        Button { Task { await checkPrices(open) } } label: {
                            HStack {
                                if checking { ProgressView().tint(Theme.accent) }
                                Label(checking ? "Controllo i prezzi…" : "Controlla i prezzi", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(checking)
                    }
                    if let report {
                        Text(report).font(.caption).foregroundStyle(Theme.sub)
                    }
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 260), spacing: 12)], spacing: 12) {
                        ForEach(open) { wish in
                            Button { editing = wish } label: { WishCard(wish: wish) }.buttonStyle(.plain)
                        }
                    }
                }
                if !bought.isEmpty {
                    DisclosureGroup(isExpanded: $showBought) {
                        ForEach(bought) { wish in
                            Button { editing = wish } label: {
                                HStack {
                                    Text(wish.displayTitle).foregroundStyle(Theme.text).lineLimit(1)
                                    Spacer()
                                    if let price = wish.price { Text(Wish.format(price, currency: wish.currency)).foregroundStyle(Theme.sub) }
                                }
                                .font(.subheadline)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        Text("Comprati: \(bought.count)").font(.subheadline.weight(.semibold)).foregroundStyle(Theme.sub)
                    }
                    .tint(Theme.sub)
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Cosa comprare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { editing = Wish(title: "") } label: { Label("Aggiungi", systemImage: "plus") }
            }
        }
        .sheet(item: $editing) { wish in
            WishEditor(wish: wish, isNew: closet.wish(wish.id) == nil)
        }
    }

    private func checkPrices(_ wishes: [Wish]) async {
        checking = true
        defer { checking = false }
        var down = 0, up = 0, failed = 0
        for wish in wishes {
            guard let url = wish.url else { continue }
            guard let preview = try? await LinkPreview.fetch(url) else { failed += 1; continue }
            var changed = closet.wish(wish.id) ?? wish
            changed.checked = Date()
            if let price = preview.price {
                if let old = changed.price, old != price {
                    changed.previousPrice = old
                    if price < old { down += 1 } else { up += 1 }
                }
                changed.price = price
                if let currency = preview.currency { changed.currency = currency }
            }
            if changed.image.isEmpty, let image = preview.image { changed.image = image }
            closet.update(changed)
        }
        var parts: [String] = []
        if down > 0 { parts.append(String(localized: "\(down) scesi")) }
        if up > 0 { parts.append(String(localized: "\(up) saliti")) }
        if failed > 0 { parts.append(String(localized: "\(failed) pagine non lette")) }
        report = parts.isEmpty ? String(localized: "Nessun prezzo cambiato.") : parts.joined(separator: " · ")
    }
}

private struct WishCard: View {
    let wish: Wish

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Theme.stage
                if let url = wish.imageURL {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image { image.resizable().scaledToFit() } else { Image(systemName: "cart").foregroundStyle(Theme.sub) }
                    }
                } else {
                    Image(systemName: wish.category?.symbol ?? "cart").font(.title2).foregroundStyle(Theme.sub)
                }
            }
            .frame(height: 150)
            .clipShape(Rectangle())
            Text(wish.displayTitle).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(2)
            HStack(spacing: 6) {
                if let price = wish.price {
                    Text(Wish.format(price, currency: wish.currency)).font(.subheadline.monospacedDigit()).foregroundStyle(Theme.text)
                }
                if wish.trend != 0, let previous = wish.previousPrice {
                    Label(Wish.format(previous, currency: wish.currency), systemImage: wish.trend < 0 ? "arrow.down" : "arrow.up")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(wish.trend < 0 ? Theme.good : Theme.bad)
                }
            }
        }
        .padding(10)
        .card()
    }
}

/// A new thing to buy, or one already in the list.
private struct WishEditor: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State var wish: Wish
    let isNew: Bool
    @State private var priceText = ""
    @State private var reading = false
    @State private var error: String?

    init(wish: Wish, isNew: Bool) {
        _wish = State(initialValue: wish)
        self.isNew = isNew
        _priceText = State(initialValue: wish.price.map { String(format: "%.2f", $0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Link del negozio") {
                        Field(title: "Indirizzo", text: $wish.link, prompt: "https://…", keyboard: .URL)
                        HStack {
                            Button { Task { await read() } } label: {
                                HStack {
                                    if reading { ProgressView().tint(Theme.accent) }
                                    Label("Leggi la pagina", systemImage: "doc.text.magnifyingglass")
                                }
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .disabled(reading || wish.url == nil)
                            if let url = wish.url {
                                Button { openURL(url) } label: { Label("Apri", systemImage: "safari") }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                        ErrorBanner(error: $error)
                    }
                    if let url = wish.imageURL {
                        AsyncImage(url: url) { image in image.resizable().scaledToFit() } placeholder: { ProgressView() }
                            .frame(maxHeight: 220)
                            .frame(maxWidth: .infinity)
                            .clipShape(Rectangle())
                    }
                    Panel("Cosa") {
                        Field(title: "Nome", text: $wish.title, prompt: "Per esempio giacca di lana")
                        Field(title: "Prezzo", text: $priceText, prompt: "Facoltativo", keyboard: .decimalPad)
                        Picker("Tipo", selection: $wish.category) {
                            Text("Nessuno").tag(Category?.none)
                            ForEach(Category.allCases) { Text($0.label).tag(Category?.some($0)) }
                        }
                        .tint(Theme.accent)
                        TextField("Note: taglia, colore, perché…", text: $wish.notes, axis: .vertical)
                            .lineLimit(2...5)
                            .padding(11)
                            .background(Theme.deep)
                            .overlay(Rectangle().strokeBorder(Theme.line, lineWidth: 1))
                    }
                    if !isNew {
                        Toggle(isOn: $wish.bought) { Label("Comprato", systemImage: "bag.badge.plus") }
                            .tint(Theme.accent)
                            .foregroundStyle(Theme.text)
                        if let checked = wish.checked {
                            Text("Prezzo controllato il \(checked.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption).foregroundStyle(Theme.sub)
                        }
                        Button(role: .destructive) {
                            closet.deleteWish(wish.id)
                            dismiss()
                        } label: { Label("Togli dalla lista", systemImage: "trash") }
                            .buttonStyle(SecondaryButtonStyle(color: Theme.bad))
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .screen()
            .navigationTitle(isNew ? "Da comprare" : wish.displayTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }.bold()
                        .disabled(wish.title.trimmingCharacters(in: .whitespaces).isEmpty && wish.url == nil)
                }
            }
        }
    }

    private func read() async {
        guard let url = wish.url else { return }
        reading = true
        defer { reading = false }
        do {
            let preview = try await LinkPreview.fetch(url)
            if wish.title.trimmingCharacters(in: .whitespaces).isEmpty, let title = preview.title { wish.title = String(title.prefix(120)) }
            if let image = preview.image { wish.image = image }
            if let price = preview.price {
                priceText = String(format: "%.2f", price)
                wish.currency = preview.currency ?? wish.currency
            }
            wish.checked = Date()
            error = preview.title == nil && preview.price == nil ? String(localized: "La pagina non dice nome né prezzo: scrivili tu.") : nil
        } catch {
            self.error = String(localized: "Non riesco a leggere la pagina: \(error.localizedDescription)")
        }
    }

    private func save() {
        let newPrice = LinkPreview.number(priceText)
        if let old = wish.price, let newPrice, old != newPrice { wish.previousPrice = old }
        wish.price = newPrice
        wish.link = wish.link.trimmingCharacters(in: .whitespacesAndNewlines)
        closet.update(wish)
        dismiss()
    }
}
