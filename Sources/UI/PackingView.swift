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
            if Demo.screen == "tripform" { planning = true }
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
    /// Occasions written by hand ("Serata romantica"), and the one being written.
    @State private var others: [String] = []
    @State private var newOccasion = ""
    /// A trip to the snow: the ski gear goes too.
    @State private var ski = false
    /// Packed by hand (the suitcase starts empty) or by the app; the last choice is kept.
    @AppStorage("packingByHand") private var byHand = false
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
                            Chip(text: String(localized: "Neve"), systemImage: Category.ski.symbol, selected: ski) { ski.toggle() }
                            // The user's own: selected; a tap takes one away.
                            ForEach(others, id: \.self) { name in
                                Chip(text: name, systemImage: "xmark", selected: true) { others.removeAll { $0 == name } }
                                    .accessibilityHint(Text("Toglie questa occasione"))
                            }
                        }
                        HStack(alignment: .bottom, spacing: 8) {
                            Field(title: "Un'altra occasione", text: $newOccasion, prompt: "Per esempio Serata romantica")
                                .onSubmit(addOccasion)
                                .submitLabel(.done)
                            Button(action: addOccasion) {
                                Image(systemName: "plus").font(.headline)
                                    .frame(width: 46, height: 46)
                                    .background(Theme.input, in: Circle())
                                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1))
                            }
                            .disabled(newOccasion.trimmingCharacters(in: .whitespaces).isEmpty)
                            .accessibilityLabel(Text("Aggiungi l'occasione"))
                        }
                    }
                    Panel("Come la prepari") {
                        Picker("Come la prepari", selection: $byHand) {
                            Text("La preparo io").tag(true)
                            Text("La prepara l'app").tag(false)
                        }
                        .pickerStyle(.segmented)
                        Text(byHand
                             ? "La valigia parte vuota: scegli tu ogni capo, uno alla volta o un outfit intero."
                             : "L'app sceglie i capi dal tuo armadio per il meteo e le occasioni; poi li cambi come vuoi.")
                            .prose().font(.caption).foregroundStyle(Theme.sub)
                    }
                    ErrorBanner(error: $error)
                }
                .padding(16)
            }
            .screen()
            .onAppear {
                // The picture of the README: a trip filled in, packed by hand.
                guard Demo.screen == "tripform", place == nil else { return }
                place = Place(name: "Lisbona, Portogallo", latitude: 38.72, longitude: -9.14)
                occasions = [.everyday, .evening]
                others = [String(localized: "Serata romantica")]
                byHand = true
            }
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

    private func addOccasion() {
        let name = newOccasion.trimmingCharacters(in: .whitespacesAndNewlines)
        newOccasion = ""
        guard !name.isEmpty, name.count <= 40,
              !others.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        others.append(name)
    }

    private func search(_ text: String) async {
        guard text.count >= 2 else { results = []; return }
        results = (try? await WeatherService.search(text)) ?? []
    }

    private func make() async {
        guard let place else { return }
        working = true
        defer { working = false }
        // An occasion still being written counts too.
        addOccasion()
        var trip = TripPlan(place: place, start: start, nights: nights,
                            occasions: Occasion.allCases.filter { occasions.contains($0) })
        trip.otherOccasions = others
        trip.manual = byHand
        trip.ski = ski
        do {
            trip.days = try await WeatherService.trip(place, start: start, days: trip.dayCount)
        } catch {
            // No forecast: the suitcase is made without it.
            trip.days = []
        }
        if !byHand {
            trip.chosen = Packer.plan(items: closet.items, trip: trip, affinity: Care.affinity(closet.wears)).flatMap(\.items)
        }
        done(trip)
    }
}

/// The suitcase: the forecast, the pieces by kind to tick, the reminders and the AI's tips.
private struct SuitcaseView: View {
    @Environment(Closet.self) private var closet
    @Environment(AIService.self) private var ai
    @Binding var trip: TripPlan
    let newTrip: () -> Void
    /// The picker of pieces is open; with a kind, it starts on that kind.
    @State private var adding = false
    @State private var addingKind: Category?
    @State private var thinking = false
    @State private var error: String?

    private var lines: [PackingLine] { Packer.lines(items: closet.items, trip: trip) }

    private func add(kind: Category? = nil) {
        addingKind = kind
        adding = true
    }

    var body: some View {
        let lines = lines
        let total = lines.flatMap(\.items).count
        let packed = trip.packed.filter { trip.chosen.contains($0) }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.place.name).font(.title2.bold()).foregroundStyle(Theme.text)
                    Text("\(trip.start.formatted(date: .abbreviated, time: .omitted)) · \(trip.nights == 1 ? String(localized: "1 notte") : String(localized: "\(trip.nights) notti")) · \(trip.occasionNames.joined(separator: ", "))")
                        .font(.subheadline).foregroundStyle(Theme.sub)
                }
                forecast
                Panel(String(localized: "In valigia: \(packed) di \(total)")) {
                    Bar(value: total == 0 ? 0 : Double(packed) / Double(total))
                }
                if trip.manual && lines.isEmpty {
                    Panel {
                        Empty(symbol: "suitcase", title: "La valigia è vuota",
                              text: "Scegli tu i capi: uno alla volta, oppure un outfit intero, per esempio quello per la serata.")
                    }
                }
                Button { add() } label: { Label("Aggiungi capi", systemImage: "plus") }
                    .buttonStyle(trip.manual && lines.isEmpty ? AnyButtonStyle(PrimaryButtonStyle()) : AnyButtonStyle(SecondaryButtonStyle()))
                ForEach(lines) { line in
                    // The ski gear is one kit: there is no number to reach, as when packing by hand.
                    Panel(trip.manual || line.category.apart ? "\(line.category.label) · \(line.items.count)" : "\(line.category.label) · \(line.items.count)/\(line.count)",
                          trailing: AnyView(Button { add(kind: line.category) } label: { Image(systemName: "plus.circle") }
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
                if trip.ski && !closet.items.contains(where: { $0.category == .ski }) {
                    Panel(Category.ski.label) {
                        Text("Nell'armadio non hai ancora capi da sci: aggiungili scegliendo il tipo Sci e neve, poi li metti in valigia da qui.").prose()
                            .font(.subheadline).foregroundStyle(Theme.sub)
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
        .sheet(isPresented: $adding) {
            PackPicker(kind: addingKind, exclude: Set(trip.chosen)) { ids in
                trip.chosen.append(contentsOf: ids.filter { !trip.chosen.contains($0) })
            }
            .presentationDetents([.large])
        }
        .onAppear { if Demo.screen == "packpick" { add() } }
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

/// Pieces for the suitcase, chosen by hand: one by one, or all the pieces of an outfit at once.
struct PackPicker: View {
    @Environment(Closet.self) private var closet
    @Environment(\.dismiss) private var dismiss
    /// The kind to start on (the + of a line), nil for all.
    var kind: Category?
    let exclude: Set<Item.ID>
    let add: ([Item.ID]) -> Void

    @State private var picked: [Item.ID] = []
    @State private var query = ""
    @State private var filter: Category?
    @State private var showOutfits = false

    private var available: [Item] { closet.items.filter { !exclude.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Picker("Cosa aggiungi", selection: $showOutfits) {
                        Text("Capi").tag(false)
                        Text("Outfit").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if showOutfits { outfits } else { pieces }
                }
                .padding(16)
            }
            .screen()
            .searchable(text: $query, prompt: Text("Cerca nell'armadio"))
            .navigationTitle("Aggiungi alla valigia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(picked.isEmpty ? String(localized: "Aggiungi") : String(localized: "Aggiungi \(picked.count)")) {
                        add(picked)
                        dismiss()
                    }
                    .bold()
                    .disabled(picked.isEmpty)
                }
            }
            .onAppear {
                filter = kind
                // The picture of the README: a few pieces already ticked.
                if Demo.screen == "packpick", picked.isEmpty { picked = Array(available.prefix(3).map(\.id)) }
            }
        }
        .sensoryFeedback(.selection, trigger: picked.count)
    }

    @ViewBuilder private var pieces: some View {
        // The ski gear last, apart, as in the closet.
        let kinds = (Category.allCases.filter { !$0.apart } + Category.allCases.filter(\.apart)).filter { k in available.contains { $0.category == k } }
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(text: String(localized: "Tutti"), selected: filter == nil) { filter = nil }
                ForEach(kinds) { k in
                    Chip(text: k.label, systemImage: k.symbol, selected: filter == k) { filter = filter == k ? nil : k }
                }
            }
        }
        let shown = available.filter { filter.shows($0) && $0.matches(query) }
        if shown.isEmpty {
            Text(available.isEmpty ? "Tutto l'armadio è già in valigia." : "Nessun capo corrisponde.").prose()
                .font(.subheadline).foregroundStyle(Theme.sub)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 14) {
            ForEach(shown) { item in
                let on = picked.contains(item.id)
                Button {
                    if on { picked.removeAll { $0 == item.id } } else { picked.append(item.id) }
                } label: {
                    ItemCard(item: item).overlay(alignment: .topLeading) { Self.mark(on).padding(8) }
                }
                .buttonStyle(PressStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .animation(.snappy(duration: 0.25), value: shown.map(\.id))
    }

    @ViewBuilder private var outfits: some View {
        let list = closet.outfits.filter { query.isEmpty || $0.displayName.localizedCaseInsensitiveContains(query) }
        if closet.outfits.isEmpty {
            Text("Non hai ancora outfit salvati: li crei nella scheda Outfit.").prose()
                .font(.subheadline).foregroundStyle(Theme.sub)
        } else {
            Text("Un outfit mette in valigia tutti i suoi capi.").prose()
                .font(.caption).foregroundStyle(Theme.sub)
        }
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 14) {
            ForEach(list) { outfit in
                // Its pieces not in the suitcase yet.
                let ids = outfit.items.filter { !exclude.contains($0) && closet.item($0) != nil }
                let on = !ids.isEmpty && ids.allSatisfy(picked.contains)
                Button {
                    if on {
                        picked.removeAll { ids.contains($0) }
                    } else {
                        for id in ids where !picked.contains(id) { picked.append(id) }
                    }
                } label: {
                    OutfitCard(outfit: outfit).overlay(alignment: .topLeading) { Self.mark(on).padding(8) }
                }
                .buttonStyle(PressStyle())
                .disabled(ids.isEmpty)
                .opacity(ids.isEmpty ? 0.45 : 1)
                .accessibilityAddTraits(on ? .isSelected : [])
                .accessibilityHint(ids.isEmpty ? Text("Già in valigia") : Text(""))
            }
        }
    }

    /// The tick on a piece or an outfit.
    static func mark(_ on: Bool) -> some View {
        Image(systemName: on ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(on ? Theme.onAccent : Theme.text, on ? Theme.accent : Theme.bg.opacity(0.55))
            .background(Circle().fill(on ? Theme.accent : Theme.bg.opacity(0.35)).padding(2))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityHidden(true)
    }
}
