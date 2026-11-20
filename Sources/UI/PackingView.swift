import SwiftUI

/// The suitcase for a trip: where, when, how long and for what; the app reads the forecast of the
/// place and picks the pieces, and the user ticks them as they go in. One trip at a time, kept on
/// this device.
struct PackingView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @AppStorage("packingTrip") private var saved: Data?
    @State private var trip: TripPlan?
    @State private var planning = false

    var body: some View {
        Group {
            if let trip {
                SuitcaseView(trip: Binding(get: { trip }, set: { self.trip = $0; store($0) }),
                             newTrip: { planning = true })
            } else {
                ScrollView {
                    VStack(spacing: 18) {
                        Empty(symbol: "suitcase", title: "Prepara la valigia",
                              text: "Dimmi dove vai, quando e per quanto: guardo il meteo del posto e scelgo i capi dal tuo armadio. Poi li spunti mentre li metti in valigia.")
                        Button { planning = true } label: { Label("Nuova valigia", systemImage: "plus") }
                            .buttonStyle(PrimaryButtonStyle())
                    }
                    .padding(16)
                }
            }
        }
        .screen()
        .navigationTitle("Valigia")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $planning) {
            TripForm { made in
                planning = false
                if let made {
                    trip = made
                    store(made)
                }
            }
        }
        .onAppear {
            if trip == nil, let saved { trip = try? Closet.decoder.decode(TripPlan.self, from: saved) }
        }
    }

    private func store(_ trip: TripPlan) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        saved = try? encoder.encode(trip)
    }
}

/// Where, when, how long and what for.
private struct TripForm: View {
    @Environment(Closet.self) private var closet
    @Environment(WeatherService.self) private var weather
    let done: (TripPlan?) -> Void

    @State private var query = ""
    @State private var results: [Place] = []
    @State private var place: Place?
    @State private var start = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var nights = 3
    @State private var occasions: Set<Occasion> = [.everyday]
    @State private var working = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Panel("Dove vai") {
                        if let place {
                            HStack {
                                Label(place.name, systemImage: "mappin.and.ellipse").foregroundStyle(Theme.text)
                                Spacer()
                                Button("Cambia") { self.place = nil }.font(.caption.bold())
                            }
                        } else {
                            Field(title: "Città", text: $query, prompt: "Per esempio Lisbona")
                                .onChange(of: query) { _, text in Task { await search(text) } }
                            ForEach(results, id: \.self) { result in
                                Button {
                                    place = result
                                    results = []
                                } label: {
                                    Label(result.name, systemImage: "mappin").frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.text)
                            }
                        }
                    }
                    Panel("Quando") {
                        DatePicker("Partenza", selection: $start, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                            .foregroundStyle(Theme.text)
                        Stepper(value: $nights, in: 1...30) {
                            Text(nights == 1 ? String(localized: "1 notte") : String(localized: "\(nights) notti")).foregroundStyle(Theme.text)
                        }
                        Text("Il meteo si conosce per i prossimi 16 giorni: per un viaggio più lontano la valigia si fa senza.").prose()
                            .font(.caption).foregroundStyle(Theme.sub)
                    }
                    Panel("Per cosa") {
                        FlowLayout(spacing: 8) {
                            ForEach(Occasion.allCases.filter { $0 != .home }) { occasion in
                                Chip(text: occasion.label, systemImage: occasion.symbol, selected: occasions.contains(occasion)) {
                                    if occasions.contains(occasion) { occasions.remove(occasion) } else { occasions.insert(occasion) }
                                }
                            }
                        }
                    }
                    ErrorBanner(error: $error)
                }
                .padding(16)
            }
            .screen()
            .navigationTitle("Nuova valigia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { done(nil) } }
                ToolbarItem(placement: .confirmationAction) {
                    if working { ProgressView() } else {
                        Button("Prepara") { Task { await make() } }.bold().disabled(place == nil)
                    }
                }
            }
        }
    }

    private func search(_ text: String) async {
        guard text.count >= 2 else { results = []; return }
        results = (try? await WeatherService.search(text)) ?? []
    }

    private func make() async {
        guard let place else { return }
        working = true
        defer { working = false }
        var trip = TripPlan(place: place, start: start, nights: nights,
                            occasions: Occasion.allCases.filter { occasions.contains($0) })
        do {
            trip.days = try await WeatherService.trip(place, start: start, days: trip.dayCount)
        } catch {
            // No forecast: the suitcase is made without it.
            trip.days = []
        }
        trip.chosen = Packer.plan(items: closet.items, trip: trip, affinity: Care.affinity(closet.wears)).flatMap(\.items)
        done(trip)
    }
}

/// The suitcase: the forecast, the pieces by kind to tick, the reminders and the AI's tips.
private struct SuitcaseView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @Binding var trip: TripPlan
    let newTrip: () -> Void
    @State private var swapping: Category?
    @State private var thinking = false
    @State private var error: String?

    private var lines: [PackingLine] {
        let wanted = Packer.counts(days: trip.dayCount, conditions: trip.days.compactMap(\.conditions),
                                   occasions: Set(trip.occasions.isEmpty ? [.everyday] : trip.occasions), items: closet.items)
        let chosen = trip.chosen.compactMap(closet.item)
        return [Category.top, .bottom, .dress, .outerwear, .shoes, .bag, .accessory].compactMap { category in
            let pieces = chosen.filter { $0.category == category }.map(\.id)
            guard let count = wanted[category] ?? (pieces.isEmpty ? nil : pieces.count) else { return nil }
            return PackingLine(category: category, count: count, items: pieces)
        }
    }

    var body: some View {
        let lines = lines
        let total = lines.flatMap(\.items).count
        let packed = trip.packed.filter { trip.chosen.contains($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.place.name).font(.title2.bold()).foregroundStyle(Theme.text)
                    Text("\(trip.start.formatted(date: .abbreviated, time: .omitted)) · \(trip.nights == 1 ? String(localized: "1 notte") : String(localized: "\(trip.nights) notti")) · \(trip.occasions.map(\.label).joined(separator: ", "))")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                }
                forecast
                Panel(String(localized: "In valigia: \(packed) di \(total)")) {
                    Bar(value: total == 0 ? 0 : Double(packed) / Double(total))
                }
                ForEach(lines) { line in
                    Panel("\(line.category.label) · \(line.items.count)/\(line.count)",
                          trailing: AnyView(Button { swapping = line.category } label: { Image(systemName: "plus.circle") }
                              .accessibilityLabel(Text("Aggiungi")))) {
                        ForEach(line.items.compactMap(closet.item)) { item in
                            let inside = trip.packed.contains(item.id)
                            HStack(spacing: 8) {
                                Button { toggle(item.id) } label: {
                                    PieceLine(item: item, detail: inside ? String(localized: "In valigia") : "") {
                                        Image(systemName: inside ? "checkmark.circle.fill" : "circle")
                                            .font(.title3).foregroundStyle(inside ? Theme.accent : Theme.line)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                Button { remove(item.id) } label: { Image(systemName: "xmark").font(.caption.bold()).foregroundStyle(Theme.sub) }
                                    .accessibilityLabel(Text("Togli"))
                            }
                        }
                        if line.short {
                            Text(String(localized: "Ne servirebbero \(line.count): nell'armadio non ce ne sono abbastanza."))
                                .font(.caption).foregroundStyle(Theme.warn)
                        }
                    }
                }
                Panel("Non dimenticare") {
                    ForEach(Packer.reminders(trip: trip), id: \.self) { text in
                        Label(text, systemImage: "checklist").font(.subheadline).foregroundStyle(Theme.text)
                    }
                }
                Panel("Consigli dell'IA") {
                    if !trip.tips.isEmpty {
                        Text(trip.tips).prose().font(.subheadline).foregroundStyle(Theme.text).textSelection(.enabled)
                    }
                    if ai.canTalk {
                        Button { Task { await tips(lines) } } label: {
                            HStack {
                                if thinking { ProgressView().tint(Theme.accent) }
                                Label(trip.tips.isEmpty ? "Chiedi consigli all'IA" : "Altri consigli", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(thinking)
                    } else {
                        AINeeded(text: String(localized: "Con l'IA accesa ti dà qualche consiglio su cosa aggiungere."))
                    }
                    ErrorBanner(error: $error)
                }
                Button { newTrip() } label: { Label("Nuova valigia", systemImage: "suitcase") }
                    .buttonStyle(SecondaryButtonStyle())
            }
            .padding(16)
        }
        .sheet(item: $swapping) { category in
            PiecePicker(exclude: Set(trip.chosen)) { id in
                trip.chosen.append(id)
            }
            .presentationDetents([.large])
            .id(category)
        }
    }

    @ViewBuilder private var forecast: some View {
        let known = trip.days.filter { $0.conditions != nil }
        if known.isEmpty {
            Label("Meteo non ancora disponibile: la valigia è fatta per un tempo mite.", systemImage: "cloud")
                .font(.subheadline).foregroundStyle(Theme.sub)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(known, id: \.day) { day in
                        VStack(spacing: 4) {
                            Text(Day.date(day.day)?.formatted(.dateTime.weekday(.abbreviated).day()) ?? day.day)
                                .font(.caption2).foregroundStyle(Theme.sub)
                            Image(systemName: (day.rain ?? 0) >= 50 ? "cloud.rain.fill" : "sun.max.fill")
                                .foregroundStyle(Theme.accent)
                            Text("\(Int(day.high ?? 0))°/\(Int(day.low ?? 0))°").font(.caption.monospacedDigit()).foregroundStyle(Theme.text)
                        }
                        .padding(10)
                        .card()
                    }
                }
            }
        }
    }

    private func toggle(_ id: Item.ID) {
        if let i = trip.packed.firstIndex(of: id) { trip.packed.remove(at: i) } else { trip.packed.append(id) }
    }

    private func remove(_ id: Item.ID) {
        trip.chosen.removeAll { $0 == id }
        trip.packed.removeAll { $0 == id }
    }

    private func tips(_ lines: [PackingLine]) async {
        thinking = true
        defer { thinking = false }
        do {
            trip.tips = try await ai.packingTips(trip: trip, list: lines)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
