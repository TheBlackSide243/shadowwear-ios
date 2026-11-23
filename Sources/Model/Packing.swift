import Foundation

/// A trip to pack for: where, when, how long and for what.
struct TripPlan: Codable, Equatable {
    struct Day: Codable, Equatable {
        /// yyyy-MM-dd
        var day: String
        var high: Double?
        var low: Double?
        var rain: Int?

        var conditions: Conditions? {
            guard let high, let low else { return nil }
            return Conditions(high: high, low: low, rain: rain ?? 0)
        }
    }

    var place: Place
    var start: Date
    var nights: Int
    var occasions: [Occasion]
    /// The forecast of each day, when it is near enough to be known (about two weeks).
    var days: [Day] = []
    /// The pieces ticked as already in the suitcase.
    var packed: [Item.ID] = []
    /// The pieces chosen, by kind (the user can swap them).
    var chosen: [Item.ID] = []
    var tips = ""
    /// Packed by hand: the suitcase starts empty and the user chooses every piece.
    var manual = false
    /// Occasions written by the user ("Serata romantica"), beside the ones of the list.
    var otherOccasions: [String] = []

    var dayCount: Int { max(1, nights + 1) }

    /// All the occasions, as they are read: the ones of the list, then the user's own.
    var occasionNames: [String] { occasions.map(\.label) + otherOccasions }
}

extension TripPlan {
    // Every field but the place and the dates may be missing: a suitcase saved by an older version
    // still opens.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        place = try c.decode(Place.self, forKey: .place)
        start = try c.decode(Date.self, forKey: .start)
        nights = try c.decodeIfPresent(Int.self, forKey: .nights) ?? 1
        occasions = ((try? c.decodeIfPresent([String].self, forKey: .occasions)) ?? nil)?.compactMap(Occasion.init(rawValue:)) ?? []
        days = (try? c.decodeIfPresent([Day].self, forKey: .days)) ?? []
        packed = (try? c.decodeIfPresent([Item.ID].self, forKey: .packed)) ?? []
        chosen = (try? c.decodeIfPresent([Item.ID].self, forKey: .chosen)) ?? []
        tips = (try? c.decodeIfPresent(String.self, forKey: .tips)) ?? ""
        manual = (try? c.decodeIfPresent(Bool.self, forKey: .manual)) ?? false
        otherOccasions = (try? c.decodeIfPresent([String].self, forKey: .otherOccasions)) ?? []
    }
}

/// One line of the suitcase: how many of a kind, and which pieces of the closet.
struct PackingLine: Identifiable, Equatable {
    var category: Category
    var count: Int
    var items: [Item.ID]
    var id: Category { category }
    /// Fewer pieces of this kind in the closet than the trip needs.
    var short: Bool { items.count < count }
}

/// Makes the suitcase from the closet: how many of each kind the length and the weather call for,
/// then the pieces that suit the weather and the occasions best. Pure functions, so they can be tested.
enum Packer {
    static func counts(days: Int, conditions: [Conditions], occasions: Set<Occasion>, items: [Item]) -> [Category: Int] {
        let has = Set(items.map(\.category))
        let bands = Set(conditions.map(\.band))
        let rainy = conditions.contains(where: \.rainy)
        var out: [Category: Int] = [:]
        // Up to a week without washing; longer trips wash once.
        let wearDays = min(days, 7)
        out[.top] = wearDays
        out[.bottom] = max(1, Int((Double(wearDays) / 3).rounded(.up)))
        if has.contains(.dress) && (occasions.contains(.evening) || !has.contains(.top)) {
            out[.dress] = occasions.contains(.evening) ? min(2, max(1, days / 3)) : max(1, wearDays / 2)
        }
        let cold = bands.contains(.cold) || bands.contains(.cool) || rainy || conditions.isEmpty
        out[.outerwear] = cold ? 1 : 0
        var shoes = 1
        if occasions.contains(.sport) { shoes += 1 }
        if occasions.contains(.evening) || occasions.contains(.work) { shoes += 1 }
        out[.shoes] = min(3, shoes)
        out[.bag] = 1
        out[.accessory] = bands.contains(.cold) ? 2 : 1
        if occasions.contains(.sport) { out[.top, default: 0] += min(2, days / 2 + 1) }
        return out.filter { $0.value > 0 }
    }

    /// How well a piece suits the trip: the weather, the occasions, what the user likes.
    static func fit(_ item: Item, conditions: [Conditions], occasions: Set<Occasion>, affinity: [Item.ID: Int]) -> Double {
        var s = 0.0
        if !conditions.isEmpty {
            let warmth = item.effectiveWarmth
            let hot = conditions.filter { $0.band == .hot }.count
            let cold = conditions.filter { $0.band == .cold }.count
            if hot * 2 > conditions.count { s += warmth == .light ? 1.2 : (warmth == .warm ? -1.5 : 0) }
            if cold * 2 > conditions.count { s += warmth == .warm ? 1.2 : (warmth == .light ? -1.2 : 0) }
        }
        switch item.formality {
        case .formal?, .smart?: s += (occasions.contains(.work) || occasions.contains(.evening)) ? 0.8 : -0.2
        case .sporty?: s += occasions.contains(.sport) ? 0.8 : -0.3
        case .casual?: s += occasions.contains(.everyday) ? 0.3 : 0
        case nil: break
        }
        if item.favorite { s += 0.5 }
        s += Double(affinity[item.id] ?? 0) * 0.3
        if item.stored { s -= 0.4 }
        return s
    }

    static func plan(items: [Item], trip: TripPlan, affinity: [Item.ID: Int] = [:]) -> [PackingLine] {
        let conditions = trip.days.compactMap(\.conditions)
        let occasions = Set(trip.occasions.isEmpty ? [.everyday] : trip.occasions)
        let wanted = counts(days: trip.dayCount, conditions: conditions, occasions: occasions, items: items)
        let order: [Category] = [.top, .bottom, .dress, .outerwear, .shoes, .bag, .accessory]
        return order.compactMap { category in
            guard let count = wanted[category] else { return nil }
            let options = items.filter { $0.category == category }
            guard !options.isEmpty else { return nil }
            let best = options.sorted {
                let a = fit($0, conditions: conditions, occasions: occasions, affinity: affinity)
                let b = fit($1, conditions: conditions, occasions: occasions, affinity: affinity)
                return a != b ? a > b : $0.displayName < $1.displayName
            }
            return PackingLine(category: category, count: count, items: Array(best.prefix(count).map(\.id)))
        }
    }

    /// The suitcase as it is shown: for each kind, the pieces chosen and how many the trip calls for.
    /// Packed by hand there is no count to reach: a kind shows when it has pieces.
    static func lines(items: [Item], trip: TripPlan) -> [PackingLine] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let chosen = trip.chosen.compactMap { byID[$0] }
        let wanted = trip.manual ? [:] : counts(days: trip.dayCount, conditions: trip.days.compactMap(\.conditions),
                                                 occasions: Set(trip.occasions.isEmpty ? [.everyday] : trip.occasions), items: items)
        let order: [Category] = [.top, .bottom, .dress, .outerwear, .shoes, .bag, .accessory, .other]
        return order.compactMap { category in
            let pieces = chosen.filter { $0.category == category }.map(\.id)
            guard let count = wanted[category] ?? (pieces.isEmpty ? nil : pieces.count) else { return nil }
            return PackingLine(category: category, count: count, items: pieces)
        }
    }

    /// Things that are not in the closet but go in the suitcase.
    static func reminders(trip: TripPlan) -> [String] {
        let conditions = trip.days.compactMap(\.conditions)
        var out = [
            String(localized: "Biancheria e calze: \(trip.dayCount + 1)"),
            String(localized: "Pigiama"),
            String(localized: "Caricabatterie e documenti"),
        ]
        if conditions.contains(where: \.rainy) { out.append(String(localized: "Ombrello: è prevista pioggia")) }
        if conditions.contains(where: { $0.band == .hot }) { out.append(String(localized: "Occhiali da sole e crema solare")) }
        if conditions.contains(where: { $0.band == .cold }) { out.append(String(localized: "Sciarpa, guanti e berretto")) }
        if trip.occasions.contains(.sport) { out.append(String(localized: "Calze e borraccia per lo sport")) }
        if trip.nights > 7 { out.append(String(localized: "Un sacchetto per i panni sporchi: oltre una settimana conviene un lavaggio")) }
        return out
    }
}
