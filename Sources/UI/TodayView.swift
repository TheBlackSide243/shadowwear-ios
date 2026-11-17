import SwiftUI

/// The day: the weather, what you are wearing, and an idea of what to wear.
struct TodayView: View {
    @Environment(Closet.self) private var closet
    @Environment(WeatherService.self) private var weather
    let goToCloset: () -> Void

    @State private var shuffle = 0
    @State private var index = 0
    @State private var choosingPlace = false
    @State private var saving: OutfitDraft?
    @State private var path: [AppRoute] = []

    private var today: String { Day.key(Date()) }

    private var outfitLastWorn: [Outfit.ID: String] {
        var last: [Outfit.ID: String] = [:]
        for entry in closet.wears {
            if let id = entry.outfit, (last[id] ?? "") < entry.day { last[id] = entry.day }
        }
        return last
    }

    private var ideas: [Suggestion] {
        // Pieces put away for the season stay out; pieces to wash and the liked ones weigh in.
        Stylist.suggestions(items: closet.items.filter { !$0.stored }, outfits: closet.outfits, lastWorn: closet.lastWorn,
                            outfitLastWorn: outfitLastWorn, conditions: weather.today,
                            seed: SeededRandom.seed(for: today, shuffle: shuffle),
                            taste: Taste(dirty: Set(closet.laundry.map(\.id)), affinity: Care.affinity(closet.wears)))
    }

    var body: some View {
        @Bindable var closet = closet
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ErrorBanner(error: $closet.error)
                    Text(Date().formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                        .font(.title2.bold()).foregroundStyle(Theme.text)
                    WeatherCard(choosePlace: { choosingPlace = true })
                    wornToday
                    idea
                    laundryHint
                }
                .padding(16)
            }
            .refreshable { await weather.refresh(force: true) }
            .screen()
            .navigationTitle("Oggi")
            .navigationBarTitleDisplayMode(.inline)
            .appDestinations()
        }
        .sheet(isPresented: $choosingPlace) { PlacePicker() }
        .sheet(item: $saving) { draft in
            OutfitEditor(draft: draft) { saved in
                saving = nil
                if let saved { path = [.outfit(saved)] }
            }
        }
        .task { await weather.refresh() }
    }

    @ViewBuilder private var wornToday: some View {
        let entries = closet.wears(on: today)
        if !entries.isEmpty {
            Panel("Oggi indossi") {
                ForEach(entries) { entry in
                    let pieces = entry.items.compactMap(closet.item)
                    HStack(spacing: 12) {
                        OutfitCollage(items: pieces, spacing: 3)
                            .frame(width: 70, height: 86)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.outfit.flatMap(closet.outfit)?.displayName ?? String(localized: "Capi scelti"))
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Theme.text)
                            Text(pieces.map(\.displayName).joined(separator: ", "))
                                .font(.caption).foregroundStyle(Theme.sub).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                        RatingButtons(entry: entry)
                        Button { closet.removeWear(entry.id) } label: { Image(systemName: "xmark.circle.fill") }
                            .foregroundStyle(Theme.sub)
                            .accessibilityLabel(Text("Togli dal diario"))
                    }
                }
            }
        }
    }

    @ViewBuilder private var idea: some View {
        let list = ideas
        if closet.items.isEmpty {
            Panel("Idea per oggi") {
                Text("Il tuo armadio è vuoto: aggiungi i capi e qui trovi ogni giorno un'idea di cosa mettere, col meteo.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                Button(action: goToCloset) { Label("Vai all'armadio", systemImage: "hanger") }
                    .buttonStyle(PrimaryButtonStyle())
            }
        } else if list.isEmpty {
            Panel("Idea per oggi") {
                Text("Per avere un'idea al giorno servono almeno una maglia e dei pantaloni, oppure un vestito.")
                    .font(.subheadline).foregroundStyle(Theme.sub)
                Button(action: goToCloset) { Label("Aggiungi capi", systemImage: "plus") }
                    .buttonStyle(SecondaryButtonStyle())
            }
        } else {
            let suggestion = list[index % list.count]
            let pieces = suggestion.items.compactMap(closet.item)
            let outfit = suggestion.outfit.flatMap(closet.outfit)
            Panel("Idea per oggi", trailing: AnyView(Text("\(index % list.count + 1) di \(list.count)").font(.caption).foregroundStyle(Theme.sub))) {
                OutfitCollage(items: pieces, spacing: 8, thumbnail: false)
                    .frame(height: 340)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    if let outfit {
                        NavigationLink(value: AppRoute.outfit(outfit.id)) {
                            HStack(spacing: 6) {
                                Text(outfit.displayName).font(.headline).foregroundStyle(Theme.text)
                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(Theme.sub)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text("Nuova combinazione").font(.headline).foregroundStyle(Theme.text)
                    }
                    Text(pieces.map(\.displayName).joined(separator: " · "))
                        .font(.caption).foregroundStyle(Theme.sub)
                    if let tip = WeatherTip.text(weather.today) {
                        Text(tip).font(.caption).foregroundStyle(Theme.accent)
                    }
                }
                Button {
                    closet.wear(suggestion.items, outfit: suggestion.outfit)
                } label: { Label("Lo metto oggi", systemImage: "checkmark.circle") }
                    .buttonStyle(PrimaryButtonStyle())
                HStack(spacing: 10) {
                    Button {
                        if index + 1 >= list.count {
                            shuffle += 1
                            index = 0
                        } else {
                            index += 1
                        }
                    } label: { Label("Un'altra idea", systemImage: "arrow.triangle.2.circlepath").frame(maxWidth: .infinity) }
                        .buttonStyle(SecondaryButtonStyle())
                    if outfit == nil {
                        Button {
                            saving = OutfitDraft(outfit: Outfit(name: "", items: suggestion.items))
                        } label: { Label("Salva", systemImage: "square.and.arrow.down").frame(maxWidth: .infinity) }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }
        }
    }
}

extension TodayView {
    /// A line when pieces wait for a wash.
    @ViewBuilder var laundryHint: some View {
        let n = closet.laundry.count
        if n > 0 {
            Label(n == 1 ? String(localized: "1 capo è da lavare: lo trovi in Strumenti → Da lavare.")
                         : String(localized: "\(n) capi sono da lavare: li trovi in Strumenti → Da lavare."), systemImage: "washer")
                .font(.footnote).foregroundStyle(Theme.sub)
        }
    }
}

/// Thumbs up or down on a day of the diary: the ideas of the day learn from them.
struct RatingButtons: View {
    @Environment(Closet.self) private var closet
    let entry: Wear

    var body: some View {
        HStack(spacing: 6) {
            thumb(1, "hand.thumbsup", "Mi è piaciuto")
            thumb(-1, "hand.thumbsdown", "Non mi è piaciuto")
        }
    }

    private func thumb(_ value: Int, _ symbol: String, _ label: String) -> some View {
        let on = entry.rating == value
        return Button {
            closet.rate(entry.id, on ? nil : value)
        } label: {
            Image(systemName: on ? symbol + ".fill" : symbol)
                .font(.subheadline)
                .foregroundStyle(on ? (value > 0 ? Theme.good : Theme.bad) : Theme.sub)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(label)))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// A line of advice from the weather.
enum WeatherTip {
    static func text(_ conditions: Conditions?) -> String? {
        guard let conditions else { return nil }
        var parts: [String] = []
        switch conditions.band {
        case .cold: parts.append(String(localized: "Fa freddo: serve il cappotto."))
        case .cool: parts.append(String(localized: "È fresco: porta una giacca."))
        case .mild: parts.append(String(localized: "Temperatura mite."))
        case .hot: parts.append(String(localized: "Fa caldo: vestiti leggeri."))
        }
        if conditions.rainy { parts.append(String(localized: "Può piovere: prendi l'ombrello.")) }
        return parts.joined(separator: " ")
    }
}

/// Today's weather, or how to get it.
struct WeatherCard: View {
    @Environment(WeatherService.self) private var weather
    let choosePlace: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let forecast = weather.forecast, forecast.day == Day.key(Date()) {
                HStack(alignment: .center, spacing: 14) {
                    Image(systemName: forecast.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 40))
                        .frame(width: 54)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            if let now = forecast.now {
                                Text("\(Int(now.rounded()))°").font(.system(size: 34, weight: .semibold)).foregroundStyle(Theme.text)
                            }
                            Text(forecast.summary).font(.subheadline).foregroundStyle(Theme.text)
                        }
                        Text("Max \(Int(forecast.high.rounded()))° · min \(Int(forecast.low.rounded()))° · pioggia \(forecast.rain)%")
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 0)
                }
                HStack {
                    Label(forecast.place, systemImage: "location").font(.caption).foregroundStyle(Theme.sub).lineLimit(1)
                    Spacer()
                    if weather.loading { ProgressView().controlSize(.small).tint(Theme.accent) }
                    Button("Cambia", action: choosePlace).font(.caption.weight(.semibold))
                }
            } else if weather.place != nil {
                HStack(spacing: 10) {
                    if weather.loading {
                        ProgressView().tint(Theme.accent)
                        Text("Carico il meteo…").font(.subheadline).foregroundStyle(Theme.sub)
                    } else {
                        Image(systemName: "cloud.sun").foregroundStyle(Theme.sub)
                        Text("Meteo non ancora caricato.").font(.subheadline).foregroundStyle(Theme.sub)
                        Spacer()
                        Button("Riprova") { Task { await weather.refresh(force: true) } }.font(.caption.weight(.semibold))
                    }
                }
                Button("Cambia città", action: choosePlace).font(.caption.weight(.semibold))
            } else {
                Label("Aggiungi il meteo", systemImage: "cloud.sun").font(.headline).foregroundStyle(Theme.text)
                Text("Con il meteo del giorno, ShadowWear propone capi caldi o leggeri e ti avvisa se piove. Chiede a Open-Meteo solo la città, senza account.")
                    .font(.caption).foregroundStyle(Theme.sub)
                Button(action: choosePlace) { Label("Scegli la città", systemImage: "magnifyingglass") }
                    .buttonStyle(SecondaryButtonStyle())
            }
            if let error = weather.error {
                Text(error).font(.caption).foregroundStyle(Theme.warn)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// Picks the town for the weather: by name, or the phone's position.
struct PlacePicker: View {
    @Environment(WeatherService.self) private var weather
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [Place] = []
    @State private var searching = false
    @State private var failed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        Task {
                            await weather.useCurrentLocation()
                            if weather.error == nil { dismiss() }
                        }
                    } label: { Label("Usa la mia posizione", systemImage: "location.fill") }
                    if weather.place != nil {
                        Button(role: .destructive) {
                            Task {
                                await weather.setPlace(nil)
                                dismiss()
                            }
                        } label: { Label("Togli il meteo", systemImage: "cloud.slash") }
                    }
                }
                .listRowBackground(Theme.panel)
                if searching {
                    ProgressView().tint(Theme.accent).listRowBackground(Theme.bg)
                } else if failed {
                    Text("Ricerca non riuscita: controlla la connessione.").foregroundStyle(Theme.warn).listRowBackground(Theme.bg)
                }
                if !results.isEmpty {
                    Section {
                        ForEach(results, id: \.self) { place in
                            Button {
                                Task {
                                    await weather.setPlace(place)
                                    dismiss()
                                }
                            } label: { Text(place.name).foregroundStyle(Theme.text) }
                        }
                    }
                    .listRowBackground(Theme.panel)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.bg.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Cerca una città"))
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                searching = query.trimmingCharacters(in: .whitespaces).count >= 2
                defer { searching = false }
                do {
                    results = try await WeatherService.search(query)
                    failed = false
                } catch {
                    if !Task.isCancelled { failed = true }
                }
            }
            .navigationTitle("Città del meteo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
            }
        }
    }
}
