import SwiftUI

/// The fifth tab: the tools around the closet (stylist, suitcase, laundry, seasons, clear-out,
/// things to buy, selfie, numbers) and the settings.
struct MoreView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    /// The open tool: kept by RootView, so the side menu can open To buy and Statistics.
    @Binding var path: [Tool]
    @State private var showSettings = false

    enum Tool: String, Hashable, CaseIterable {
        case stylist, selfie, packing, laundry, season, clearOut, wishlist, stats, ai
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Con l'IA", trailing: AnyView(aiBadge)) {
                        row(.stylist, "Chiedi allo stylist", "Cosa metto stasera? Cosa manca nel mio armadio?", "bubble.left.and.text.bubble.right")
                        row(.selfie, "Selfie dell'outfit", "Fatti una foto: l'IA riconosce i tuoi capi e li segna nel diario.", "person.crop.square.badge.camera")
                    }
                    Panel("Il tuo armadio") {
                        row(.packing, "Valigia", "La lista per un viaggio, con il meteo del posto.", "suitcase")
                        row(.laundry, "Da lavare", laundryText, "washer")
                        row(.season, "Cambio di stagione", "Cosa mettere via e cosa tirare fuori.", "arrow.triangle.2.circlepath")
                        row(.clearOut, "Pulizia dell'armadio", "I capi che non metti da tanto: tienili o lasciali andare.", "archivebox")
                        row(.wishlist, "Cosa comprare", wishText, "cart")
                        row(.stats, "Statistiche", "Cosa metti, cosa no, i colori e il costo per uso.", "chart.bar")
                    }
                    Panel("Impostazioni") {
                        row(.ai, "Intelligenza artificiale", ai.summary, "sparkles")
                        Button { showSettings = true } label: {
                            ToolRow(title: "Impostazioni", detail: "Foto, server, promemoria e archivio.", symbol: "gearshape")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .screen()
            .navigationTitle("Strumenti")
            .navigationBarTitleDisplayMode(.inline)
            .sideMenuButton()
            .navigationDestination(for: Tool.self) { tool in
                switch tool {
                case .stylist: StylistChatView()
                case .selfie: SelfieView()
                case .packing: PackingView()
                case .laundry: LaundryView()
                case .season: SeasonView()
                case .clearOut: ClearOutView()
                case .wishlist: WishlistView()
                case .stats: StatsView()
                case .ai: AISettingsView()
                }
            }
            .appDestinations()
        }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var aiBadge: some View {
        HStack(spacing: 5) {
            StatusDot(color: ai.isOn ? Theme.good : Theme.sub)
            Text(ai.isOn ? String(localized: "Attiva") : String(localized: "Spenta")).font(.caption).foregroundStyle(Theme.sub)
        }
    }

    private var laundryText: String {
        let n = closet.laundry.count
        return n == 0 ? String(localized: "Niente da lavare.") : (n == 1 ? String(localized: "1 capo da lavare.") : String(localized: "\(n) capi da lavare."))
    }

    private var wishText: String {
        let n = closet.wishes.filter { !$0.bought }.count
        return n == 0 ? String(localized: "Link e prezzi delle cose che vuoi.") : String(localized: "\(n) nella lista, con i prezzi controllati.")
    }

    private func row(_ tool: Tool, _ title: String, _ detail: String, _ symbol: String) -> some View {
        NavigationLink(value: tool) { ToolRow(title: title, detail: detail, symbol: symbol) }
            .buttonStyle(.plain)
    }
}

struct ToolRow: View {
    let title: String
    let detail: String
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(title)).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                Text(LocalizedStringKey(detail)).font(.caption).foregroundStyle(Theme.sub).lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.sub)
        }
        .contentShape(Rectangle())
    }
}

/// A piece in a list: its picture, name and a line under it, with a trailing view.
struct PieceLine<Trailing: View>: View {
    let item: Item
    var detail: String = ""
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            PieceImage(item: item)
                .frame(width: 54, height: 62)
                .background(Theme.photo, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.displayName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text).lineLimit(1)
                if !detail.isEmpty {
                    Text(detail).font(.caption).foregroundStyle(Theme.sub).lineLimit(2)
                }
            }
            Spacer(minLength: 6)
            trailing
        }
    }
}

// MARK: - Laundry

/// The pieces worn enough times since their last wash, and the button to say they are washed.
struct LaundryView: View {
    @Environment(Closet.self) private var closet

    var body: some View {
        let laundry = closet.laundry
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if laundry.isEmpty {
                    Empty(symbol: "washer", title: "Niente da lavare",
                          text: "Quando segni nel diario cosa indossi, i capi messi abbastanza volte finiscono qui. Le volte si cambiano nella scheda di ogni capo.")
                } else {
                    Panel(String(localized: "Da lavare: \(laundry.count)")) {
                        ForEach(laundry) { item in
                            HStack(spacing: 8) {
                                NavigationLink(value: AppRoute.item(item.id)) {
                                    PieceLine(item: item, detail: String(localized: "Messo \(closet.wearsSinceWash(item)) volte dall'ultimo lavaggio")) { EmptyView() }
                                }
                                .buttonStyle(.plain)
                                Button { closet.markWashed([item.id]) } label: { Text("Lavato") }
                                    .buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                    Button { closet.markWashed(laundry.map(\.id)) } label: { Label("Li ho lavati tutti", systemImage: "checkmark.circle") }
                        .buttonStyle(PrimaryButtonStyle())
                }
                Text("Magliette e vestiti dopo 2 volte, pantaloni dopo 4, giacche dopo 12. Scarpe, borse e accessori non si contano.")
                    .font(.caption).foregroundStyle(Theme.sub)
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Da lavare")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Seasons

/// What to put away and what to bring out for the season: put-away pieces leave the ideas of the day.
struct SeasonView: View {
    @Environment(Closet.self) private var closet
    @Environment(WeatherService.self) private var weather

    var body: some View {
        let swap = Care.swap(closet.items, south: (weather.place?.latitude ?? 1) < 0)
        let stored = closet.items.filter(\.stored)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(String(localized: "Ora è \(swap.season.label.lowercased())"), systemImage: swap.season.symbol)
                    .font(.title3.bold()).foregroundStyle(Theme.text)
                Text("I capi messi via non compaiono nelle idee del giorno né nella valigia. Le stagioni di un capo le scrive l'IA o le scegli nella sua scheda; senza, contano quanto è pesante.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                if swap.putAway.isEmpty && swap.bringOut.isEmpty {
                    Empty(symbol: "checkmark.seal", title: "L'armadio è già di stagione", text: "Niente da mettere via o da tirare fuori adesso.")
                }
                if !swap.bringOut.isEmpty {
                    Panel(String(localized: "Da tirare fuori: \(swap.bringOut.count)"),
                          trailing: AnyView(Button("Tutti") { closet.setStored(swap.bringOut.map(\.id), false) }.font(.caption.bold()))) {
                        ForEach(swap.bringOut) { item in
                            PieceLine(item: item, detail: seasons(item)) {
                                Button { closet.setStored([item.id], false) } label: { Text("Tira fuori") }.buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
                if !swap.putAway.isEmpty {
                    Panel(String(localized: "Da mettere via: \(swap.putAway.count)"),
                          trailing: AnyView(Button("Tutti") { closet.setStored(swap.putAway.map(\.id), true) }.font(.caption.bold()))) {
                        ForEach(swap.putAway) { item in
                            PieceLine(item: item, detail: seasons(item)) {
                                Button { closet.setStored([item.id], true) } label: { Text("Metti via") }.buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
                let other = stored.filter { s in !swap.bringOut.contains(where: { $0.id == s.id }) }
                if !other.isEmpty {
                    Panel(String(localized: "Messi via: \(other.count)")) {
                        ForEach(other) { item in
                            PieceLine(item: item, detail: seasons(item)) {
                                Button { closet.setStored([item.id], false) } label: { Text("Tira fuori") }.buttonStyle(SecondaryButtonStyle())
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Cambio di stagione")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func seasons(_ item: Item) -> String {
        Season.allCases.filter { item.effectiveSeasons.contains($0) }.map(\.label).joined(separator: ", ")
    }
}

// MARK: - Clear-out

/// Pieces not worn for a long time: keep them for six months more, or let them go.
struct ClearOutView: View {
    @Environment(Closet.self) private var closet
    @State private var months = 6
    @State private var deleting: Item?

    var body: some View {
        let list = Care.clearOut(closet.items, wears: closet.wears, months: months)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("Da quanto", selection: $months) {
                    Text("3 mesi").tag(3)
                    Text("6 mesi").tag(6)
                    Text("1 anno").tag(12)
                    Text("2 anni").tag(24)
                }
                .pickerStyle(.segmented)
                Text("I capi che non hai messo in questo tempo (o mai, se sono nell'armadio da così tanto). «Lo tengo» li toglie da qui per sei mesi.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                if list.isEmpty {
                    Empty(symbol: "sparkles", title: "Niente da sistemare", text: "Ogni capo è stato messo di recente. Il diario serve proprio a questo: segna cosa indossi.")
                } else {
                    Panel(String(localized: "Da decidere: \(list.count)")) {
                        ForEach(list) { entry in
                            VStack(alignment: .leading, spacing: 10) {
                                NavigationLink(value: AppRoute.item(entry.item.id)) {
                                    PieceLine(item: entry.item, detail: detail(entry)) { EmptyView() }
                                }
                                .buttonStyle(.plain)
                                HStack(spacing: 8) {
                                    Button {
                                        closet.keep(entry.item.id, until: Calendar.current.date(byAdding: .month, value: 6, to: Date()) ?? Date())
                                    } label: { Label("Lo tengo", systemImage: "heart") }
                                        .buttonStyle(SecondaryButtonStyle())
                                    Button {
                                        closet.setStored([entry.item.id], true)
                                    } label: { Label("Metti via", systemImage: "archivebox") }
                                        .buttonStyle(SecondaryButtonStyle())
                                    Button {
                                        deleting = entry.item
                                    } label: { Label("Via", systemImage: "trash") }
                                        .buttonStyle(SecondaryButtonStyle(color: Theme.bad))
                                }
                                .labelStyle(.titleAndIcon)
                            }
                            if entry.id != list.last?.id { Divider().overlay(Theme.line) }
                        }
                    }
                }
            }
            .padding(16)
        }
        .screen()
        .navigationTitle("Pulizia dell'armadio")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Eliminare questo capo?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
                            titleVisibility: .visible, presenting: deleting) { item in
            Button("Elimina \(item.displayName)", role: .destructive) { closet.delete(item.id) }
        } message: { _ in
            Text("Esce dall'armadio con le sue foto. Se l'hai regalato o venduto, i giorni del diario restano.")
        }
    }

    private func detail(_ entry: Care.Unworn) -> String {
        if let day = entry.lastWorn, let date = Day.date(day) {
            return String(localized: "Ultima volta: \(date.formatted(date: .abbreviated, time: .omitted)) · \(entry.times) volte in tutto")
        }
        return String(localized: "Mai messo, nell'armadio dal \(entry.item.created.formatted(date: .abbreviated, time: .omitted))")
    }
}

/// An empty state: a symbol, a title and a sentence.
struct Empty: View {
    let symbol: String
    let title: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 34)).foregroundStyle(Theme.accent)
            Text(LocalizedStringKey(title)).font(.headline).foregroundStyle(Theme.text)
            Text(LocalizedStringKey(text)).font(.subheadline).foregroundStyle(Theme.sub).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .padding(.horizontal, 12)
    }
}
