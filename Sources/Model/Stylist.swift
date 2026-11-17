import Foundation

/// The weather of the day, as far as clothes care.
struct Conditions: Equatable {
    /// Highest and lowest temperature of the day, °C.
    var high: Double
    var low: Double
    /// Highest chance of rain in the day, 0–100.
    var rain: Int = 0

    enum Band: Equatable { case cold, cool, mild, hot }

    /// What the day feels like during the hours spent out: mostly the highest temperature.
    var band: Band {
        let day = high * 0.7 + low * 0.3
        switch day {
        case ..<9: return .cold
        case ..<17: return .cool
        case ..<25: return .mild
        default: return .hot
        }
    }

    var rainy: Bool { rain >= 50 }
}

/// What the diary adds to the ideas: pieces waiting for a wash, and how much each piece is liked.
struct Taste: Equatable {
    var dirty: Set<Item.ID> = []
    var affinity: [Item.ID: Int] = [:]

    static let none = Taste()
}

/// One idea of what to wear: a saved outfit, or pieces put together by the Stylist.
struct Suggestion: Identifiable, Equatable {
    var items: [Item.ID]
    var outfit: Outfit.ID?
    var score: Double

    var id: String { outfit?.uuidString ?? items.map(\.uuidString).sorted().joined(separator: ",") }
}

/// Picks what to wear from the closet: the weather, what was worn lately and colors that go
/// together. Pure functions, so they can be tested.
enum Stylist {
    /// Colors that go with everything.
    static let neutrals: Set<String> = ["black", "white", "grey", "beige", "brown", "navy"]

    /// The ideas for the day, best first: saved outfits and new combinations together.
    static func suggestions(items: [Item], outfits: [Outfit], lastWorn: [Item.ID: String],
                            outfitLastWorn: [Outfit.ID: String] = [:], today: Date = Date(),
                            conditions: Conditions?, seed: UInt64, count: Int = 8, taste: Taste = .none) -> [Suggestion] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var ideas: [Suggestion] = []

        for outfit in outfits {
            let pieces = outfit.items.compactMap { byID[$0] }
            guard !pieces.isEmpty, wearable(pieces) else { continue }
            var score = score(pieces, lastWorn: lastWorn, today: today, conditions: conditions, taste: taste)
            if outfit.favorite { score += 0.5 }
            if let day = outfitLastWorn[outfit.id], let gap = Day.distance(from: day, to: today), gap < 7 {
                score -= gap < 2 ? 3 : 1.5
            }
            ideas.append(Suggestion(items: pieces.map(\.id), outfit: outfit.id, score: score))
        }

        var random = SeededRandom(seed: seed)
        for _ in 0..<24 {
            guard let pieces = combine(items, lastWorn: lastWorn, today: today, conditions: conditions, random: &random, taste: taste)
            else { break }
            let s = score(pieces, lastWorn: lastWorn, today: today, conditions: conditions, taste: taste)
            ideas.append(Suggestion(items: pieces.map(\.id), score: s))
        }

        // The same pieces only once: a saved outfit wins over the same combination made up.
        var seen = Set<Set<Item.ID>>()
        var unique: [Suggestion] = []
        let savedFirst = ideas.sorted { a, b in
            if (a.outfit != nil) != (b.outfit != nil) { return a.outfit != nil }
            return a.score > b.score
        }
        for idea in savedFirst {
            if seen.insert(Set(idea.items)).inserted { unique.append(idea) }
        }
        return Array(unique.sorted { $0.score > $1.score }.prefix(count))
    }

    /// Something to wear on the body and on the legs: a dress, or a top with a bottom.
    static func wearable(_ pieces: [Item]) -> Bool {
        let kinds = Set(pieces.map(\.category))
        return kinds.contains(.dress) || (kinds.contains(.top) && kinds.contains(.bottom))
    }

    /// How good the pieces are for today: higher is better, around 0 is fine.
    static func score(_ pieces: [Item], lastWorn: [Item.ID: String], today: Date, conditions: Conditions?, taste: Taste = .none) -> Double {
        guard !pieces.isEmpty else { return -10 }
        var total = pieces.map { score($0, lastWorn: lastWorn, today: today, conditions: conditions, taste: taste) }.reduce(0, +)
        total /= Double(pieces.count)
        let coat = pieces.contains { $0.category == .outerwear }
        switch conditions?.band {
        case .cold?: total += coat ? 1.5 : -3
        case .cool?: total += coat ? 1 : -1
        case .mild?: total += coat ? -0.5 : 0.3
        case .hot?: total += coat ? -2.5 : 0.5
        case nil: break
        }
        total -= clash(pieces)
        return total
    }

    static func score(_ item: Item, lastWorn: [Item.ID: String], today: Date, conditions: Conditions?, taste: Taste = .none) -> Double {
        var s = 0.0
        // Waiting for a wash: only if nothing else will do.
        if taste.dirty.contains(item.id) { s -= 2.5 }
        // Liked days lift a piece, days not liked lower it (a little each, up to a point).
        s += Double(max(-3, min(3, taste.affinity[item.id] ?? 0))) * 0.25
        if let band = conditions?.band {
            switch (band, item.effectiveWarmth) {
            case (.cold, .warm), (.hot, .light): s += 1
            case (.cold, .light), (.hot, .warm): s -= 1.5
            case (.cool, .light): s -= 0.5
            case (.mild, .warm): s -= 0.7
            default: break
            }
        }
        if let day = lastWorn[item.id], let gap = Day.distance(from: day, to: today) {
            switch gap {
            case ..<2: s -= 2
            case ..<4: s -= 1
            case ..<8: s -= 0.4
            default: s += 0.2
            }
        } else {
            s += 0.4  // never worn: give it a go
        }
        if item.favorite { s += 0.3 }
        return s
    }

    /// How much the main colors fight: two strong colors that are not the same.
    static func clash(_ pieces: [Item]) -> Double {
        let strong = Set(pieces.filter { [.top, .bottom, .dress, .outerwear].contains($0.category) }
            .compactMap(\.colors.first)
            .filter { !neutrals.contains($0) && $0 != "blue" && $0 != "lightblue" })  // denim goes with anything
        return strong.count > 1 ? Double(strong.count - 1) * 1.2 : 0
    }

    /// Combinations around one piece, best first, without the AI: the other pieces are picked as for
    /// the idea of the day, with this one always in.
    static func pairings(for item: Item, items: [Item], lastWorn: [Item.ID: String], today: Date = Date(),
                         conditions: Conditions?, taste: Taste = .none, count: Int = 3) -> [[Item.ID]] {
        let others = items.filter { $0.id != item.id && !$0.stored }
        // A dress stands for top and bottom; a top needs a bottom and the other way round.
        let replaced: Set<Category> = switch item.category {
        case .dress: [.dress, .top, .bottom]
        default: [item.category]
        }
        let pool = others.filter { !replaced.contains($0.category) || ![.top, .bottom, .dress, .shoes, .outerwear, .bag].contains($0.category) }
        var random = SeededRandom(seed: SeededRandom.seed(for: item.id.uuidString))
        var seen = Set<Set<Item.ID>>()
        var found: [(ids: [Item.ID], score: Double)] = []
        for _ in 0..<30 {
            var chosen: [Item] = [item]
            // A stand-in so combine() makes the rest of the outfit around the piece.
            let base = pool + (item.category == .dress || item.category == .top || item.category == .bottom ? [item] : [])
            guard let made = combine(base, lastWorn: lastWorn, today: today, conditions: conditions, random: &random, taste: taste) else { break }
            for piece in made where piece.id != item.id && !chosen.contains(where: { $0.category == piece.category && piece.category != .accessory }) {
                if item.category == .dress && (piece.category == .top || piece.category == .bottom) { continue }
                if (item.category == .top || item.category == .bottom) && piece.category == .dress { continue }
                chosen.append(piece)
            }
            guard chosen.count > 1, wearable(chosen) || ![.top, .bottom, .dress].contains(item.category) else { continue }
            let ids = chosen.map(\.id)
            guard seen.insert(Set(ids)).inserted else { continue }
            found.append((ids, score(chosen, lastWorn: lastWorn, today: today, conditions: conditions, taste: taste)))
        }
        return found.sorted { $0.score > $1.score }.prefix(count).map(\.ids)
    }

    /// A new combination from the closet, or nil when there is nothing to make one with.
    static func combine(_ items: [Item], lastWorn: [Item.ID: String], today: Date, conditions: Conditions?,
                        random: inout SeededRandom, taste: Taste = .none) -> [Item]? {
        func pick(_ category: Category, with chosen: [Item]) -> Item? {
            let options = items.filter { $0.category == category }
            guard !options.isEmpty else { return nil }
            // Better pieces are likelier, but every one has a chance.
            let weights = options.map { option -> Double in
                let s = score(option, lastWorn: lastWorn, today: today, conditions: conditions, taste: taste) - clash(chosen + [option])
                return exp(s)
            }
            var r = random.nextDouble() * weights.reduce(0, +)
            for (option, weight) in zip(options, weights) {
                r -= weight
                if r <= 0 { return option }
            }
            return options.last
        }

        let dresses = items.filter { $0.category == .dress }.count
        let tops = items.filter { $0.category == .top }.count
        let bottoms = items.filter { $0.category == .bottom }.count
        let canSplit = tops > 0 && bottoms > 0
        guard dresses > 0 || canSplit else { return nil }

        var chosen: [Item] = []
        let dressShare = canSplit ? Double(dresses) / Double(dresses + tops) : 1
        if dresses > 0, random.nextDouble() < dressShare, let dress = pick(.dress, with: chosen) {
            chosen.append(dress)
        } else {
            if let top = pick(.top, with: chosen) { chosen.append(top) }
            if let bottom = pick(.bottom, with: chosen) { chosen.append(bottom) }
        }
        switch conditions?.band {
        case .cold?, .cool?:
            if let coat = pick(.outerwear, with: chosen) { chosen.append(coat) }
        case .mild?:
            if random.nextDouble() < 0.25, let coat = pick(.outerwear, with: chosen) { chosen.append(coat) }
        case .hot?: break
        case nil:
            if random.nextDouble() < 0.4, let coat = pick(.outerwear, with: chosen) { chosen.append(coat) }
        }
        if let shoes = pick(.shoes, with: chosen) { chosen.append(shoes) }
        if random.nextDouble() < 0.4, let bag = pick(.bag, with: chosen) { chosen.append(bag) }
        if random.nextDouble() < 0.4, let extra = pick(.accessory, with: chosen) { chosen.append(extra) }
        return chosen
    }
}

/// A small random generator that gives the same numbers for the same seed (SplitMix64), so the
/// idea of the day stays put until "Another one" is tapped.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double { Double(next() >> 11) / Double(1 << 53) }

    /// The seed for a day: the same all day long, different the next.
    static func seed(for day: String, shuffle: Int = 0) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in day.utf8 { hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211 }
        return hash &+ UInt64(shuffle) &* 0x9E37_79B9
    }
}
