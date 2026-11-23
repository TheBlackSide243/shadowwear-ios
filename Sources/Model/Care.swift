import Foundation

/// Taking care of the closet: what needs a wash, what to put away for the season, what is never
/// worn, and what the diary says about it all. Pure functions, so they can be tested.
enum Care {
    // MARK: Washing

    /// Wears between two washes for each kind, when the piece does not say: nil for the kinds that
    /// are not washed after wearing (shoes, bags, accessories).
    static func defaultWashEvery(_ category: Category) -> Int? {
        switch category {
        case .top, .dress: 2
        case .bottom: 4
        case .outerwear: 12
        case .shoes, .bag, .accessory, .ski, .other: nil
        }
    }

    static func washEvery(_ item: Item) -> Int? {
        if let every = item.washEvery { return every > 0 ? every : nil }
        return defaultWashEvery(item.category)
    }

    /// Days a piece was worn after its last wash (each day once).
    static func wearsSinceWash(_ item: Item, wears: [Wear]) -> Int {
        let since = item.washed.map { Day.key($0) } ?? ""
        return Set(wears.filter { $0.day > since && $0.items.contains(item.id) }.map(\.day)).count
    }

    static func needsWash(_ item: Item, wears: [Wear]) -> Bool {
        guard let every = washEvery(item) else { return false }
        return wearsSinceWash(item, wears: wears) >= every
    }

    /// The pieces to wash, the most worn first.
    static func laundry(_ items: [Item], wears: [Wear]) -> [Item] {
        items.filter { needsWash($0, wears: wears) }
            .sorted { wearsSinceWash($0, wears: wears) > wearsSinceWash($1, wears: wears) }
    }

    // MARK: Seasons

    /// What to put away and what to bring out for the season of `date` and the next one.
    struct Swap: Equatable {
        var season: Season
        var putAway: [Item]
        var bringOut: [Item]
    }

    static func swap(_ items: [Item], on date: Date = Date(), south: Bool = false) -> Swap {
        let now = Season.of(date, south: south)
        // A month before the change, the next season counts too.
        let soon = Season.of(Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date, south: south)
        let wanted: Set<Season> = [now, soon]
        // The ski gear is kept apart: it is not the season that puts it away.
        let everyday = items.filter { !$0.category.apart }
        let putAway = everyday.filter { !$0.stored && $0.effectiveSeasons.isDisjoint(with: wanted) }
        let bringOut = everyday.filter { $0.stored && !$0.effectiveSeasons.isDisjoint(with: wanted) }
        return Swap(season: now, putAway: putAway, bringOut: bringOut)
    }

    // MARK: Clear-out

    /// A piece that is not worn: since when, and how many times it ever was.
    struct Unworn: Identifiable, Equatable {
        var item: Item
        /// The last day it was worn, nil when never.
        var lastWorn: String?
        var times: Int
        var id: Item.ID { item.id }
    }

    /// The pieces not worn for `months` (or never, after `months` in the closet), the oldest first.
    /// Pieces put away, pieces kept recently and the ski gear (worn a week a year) are left out.
    static func clearOut(_ items: [Item], wears: [Wear], months: Int, today: Date = Date()) -> [Unworn] {
        guard let limit = Calendar.current.date(byAdding: .month, value: -months, to: today) else { return [] }
        let limitKey = Day.key(limit)
        var last: [Item.ID: String] = [:]
        var times: [Item.ID: Set<String>] = [:]
        for wear in wears {
            for id in wear.items {
                if (last[id] ?? "") < wear.day { last[id] = wear.day }
                times[id, default: []].insert(wear.day)
            }
        }
        return items.compactMap { item -> Unworn? in
            if item.stored || item.category.apart { return nil }
            if let keep = item.keepUntil, keep > today { return nil }
            if let day = last[item.id] {
                guard day < limitKey else { return nil }
            } else {
                guard item.created < limit else { return nil }
            }
            return Unworn(item: item, lastWorn: last[item.id], times: times[item.id]?.count ?? 0)
        }
        .sorted { ($0.lastWorn ?? "") < ($1.lastWorn ?? "") }
    }

    // MARK: What the diary says

    /// Liked minus not liked, for each piece: the ideas of the day lean on it.
    static func affinity(_ wears: [Wear]) -> [Item.ID: Int] {
        var out: [Item.ID: Int] = [:]
        for wear in wears {
            guard let rating = wear.rating, rating != 0 else { continue }
            for id in wear.items { out[id, default: 0] += rating > 0 ? 1 : -1 }
        }
        return out
    }

    struct Stats: Equatable {
        struct Count: Identifiable, Equatable {
            var key: String
            var count: Int
            var id: String { key }
        }
        struct CostPerWear: Identifiable, Equatable {
            var item: Item
            var cost: Double
            var times: Int
            var id: Item.ID { item.id }
        }

        var pieces = 0
        var outfits = 0
        var daysWritten = 0
        /// Pieces worn at least once in the period.
        var wornPieces = 0
        var neverWorn: [Item] = []
        /// Times worn by kind, by main color (of what was worn) and the most worn pieces.
        var byCategory: [Count] = []
        var byColor: [Count] = []
        var closetColors: [Count] = []
        var mostWorn: [(item: Item, times: Int)] = []
        var liked: [Item] = []
        var costPerWear: [CostPerWear] = []
        var closetValue: Double = 0

        static func == (a: Stats, b: Stats) -> Bool {
            a.pieces == b.pieces && a.daysWritten == b.daysWritten && a.byCategory == b.byCategory && a.byColor == b.byColor
                && a.mostWorn.map(\.item.id) == b.mostWorn.map(\.item.id)
        }
    }

    /// The numbers of the closet and the diary, for all time (`since` nil) or from a day on.
    static func stats(items: [Item], outfits: [Outfit], wears: [Wear], since: String? = nil) -> Stats {
        let period = wears.filter { since == nil || $0.day >= since! }
        var stats = Stats()
        stats.pieces = items.count
        stats.outfits = outfits.count
        stats.daysWritten = Set(period.map(\.day)).count

        var times: [Item.ID: Set<String>] = [:]
        for wear in period { for id in wear.items { times[id, default: []].insert(wear.day) } }
        let allTimes = wears.reduce(into: [Item.ID: Set<String>]()) { result, wear in
            for id in wear.items { result[id, default: []].insert(wear.day) }
        }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        stats.wornPieces = times.keys.filter { byID[$0] != nil }.count
        stats.neverWorn = items.filter { (allTimes[$0.id]?.isEmpty ?? true) }

        var categories: [String: Int] = [:]
        var colors: [String: Int] = [:]
        for (id, days) in times {
            guard let item = byID[id] else { continue }
            categories[item.category.rawValue, default: 0] += days.count
            if let color = item.colors.first { colors[color, default: 0] += days.count }
        }
        stats.byCategory = Category.allCases.compactMap { c in categories[c.rawValue].map { Stats.Count(key: c.rawValue, count: $0) } }
            .sorted { $0.count > $1.count }
        stats.byColor = colors.map { Stats.Count(key: $0.key, count: $0.value) }.sorted { $0.count > $1.count || ($0.count == $1.count && $0.key < $1.key) }
        var owned: [String: Int] = [:]
        for item in items { if let color = item.colors.first { owned[color, default: 0] += 1 } }
        stats.closetColors = owned.map { Stats.Count(key: $0.key, count: $0.value) }.sorted { $0.count > $1.count || ($0.count == $1.count && $0.key < $1.key) }

        var worn: [(item: Item, times: Int)] = []
        for (id, days) in times {
            if let item = byID[id] { worn.append((item: item, times: days.count)) }
        }
        worn.sort { a, b in
            if a.times != b.times { return a.times > b.times }
            return a.item.displayName < b.item.displayName
        }
        stats.mostWorn = Array(worn.prefix(5))
        let liking = Care.affinity(wears)
        let likedIDs: [Item.ID] = liking.filter { $0.value > 0 }.sorted { $0.value > $1.value }.map(\.key)
        stats.liked = Array(likedIDs.compactMap { byID[$0] }.prefix(5))
        stats.closetValue = items.compactMap(\.price).reduce(0, +)
        stats.costPerWear = items.compactMap { item -> Stats.CostPerWear? in
            guard let price = item.price, price > 0 else { return nil }
            let n = allTimes[item.id]?.count ?? 0
            return Stats.CostPerWear(item: item, cost: n > 0 ? price / Double(n) : price, times: n)
        }
        .sorted { $0.cost > $1.cost }
        return stats
    }

    // MARK: Money and the year

    /// What was spent in a month: the prices of the pieces that came into the closet in it.
    struct MonthSpend: Identifiable, Equatable {
        /// yyyy-MM
        var month: String
        var total: Double = 0
        var pieces = 0
        var id: String { month }
    }

    /// What was spent month by month, the last `months` up to the one of `today`: the price of each
    /// piece in the month it came into the closet.
    static func spending(_ items: [Item], months: Int = 12, today: Date = Date(), calendar: Calendar = .current) -> [MonthSpend] {
        func key(_ date: Date) -> String { String(Day.key(date, calendar: calendar).prefix(7)) }
        var out: [MonthSpend] = (0..<max(1, months)).reversed().compactMap { back in
            calendar.date(byAdding: .month, value: -back, to: today).map { MonthSpend(month: key($0)) }
        }
        for item in items {
            guard let price = item.price, price > 0, let i = out.firstIndex(where: { $0.month == key(item.created) }) else { continue }
            out[i].total += price
            out[i].pieces += 1
        }
        return out
    }

    /// Pieces in the closet for more than `days` and never worn, the dearest first.
    static func idle(_ items: [Item], wears: [Wear], days: Int = 60, today: Date = Date(), calendar: Calendar = .current) -> [Item] {
        guard let limit = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        let worn = Set(wears.flatMap(\.items))
        return items.filter { !worn.contains($0.id) && $0.created < limit && !$0.category.apart }
            .sorted { a, b in
                let pa = a.price ?? 0, pb = b.price ?? 0
                return pa != pb ? pa > pb : a.created < b.created
            }
    }

    /// A year in a few numbers, to look back on and to share.
    struct YearRecap: Equatable {
        struct Worn: Identifiable, Equatable {
            var item: Item
            var times: Int
            var id: Item.ID { item.id }
        }
        struct TopOutfit: Equatable {
            var outfit: Outfit
            var times: Int
        }

        var year: Int
        /// Days written in the diary, and pieces worn at least once, in the year.
        var days = 0
        var wornPieces = 0
        var pieces = 0
        var mostWorn: [Worn] = []
        /// The main colors worn, the most worn first.
        var colors: [Stats.Count] = []
        var topOutfit: TopOutfit?
        /// Pieces that came into the closet in the year, and what they cost.
        var added = 0
        var spent: Double = 0
        /// The piece that paid for itself best: the lowest cost per wear, with the wears of the year.
        var best: Stats.CostPerWear?
    }

    /// The years that have something to tell: the ones with days in the diary, the latest first.
    static func recapYears(_ wears: [Wear]) -> [Int] {
        Set(wears.compactMap { Int($0.day.prefix(4)) }).filter { $0 > 2000 }.sorted(by: >)
    }

    static func yearRecap(items: [Item], outfits: [Outfit], wears: [Wear], year: Int, calendar: Calendar = .current) -> YearRecap {
        let prefix = String(format: "%04d-", year)
        let period = wears.filter { $0.day.hasPrefix(prefix) }
        var recap = YearRecap(year: year)
        recap.days = Set(period.map(\.day)).count
        recap.pieces = items.count

        var times: [Item.ID: Set<String>] = [:]
        for wear in period { for id in wear.items { times[id, default: []].insert(wear.day) } }
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let worn = times.compactMap { id, days in byID[id].map { YearRecap.Worn(item: $0, times: days.count) } }
            .sorted { a, b in a.times != b.times ? a.times > b.times : a.item.displayName < b.item.displayName }
        recap.wornPieces = worn.count
        recap.mostWorn = Array(worn.prefix(3))

        var colors: [String: Int] = [:]
        for entry in worn { if let color = entry.item.colors.first { colors[color, default: 0] += entry.times } }
        recap.colors = Array(colors.map { Stats.Count(key: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.key < $1.key) }.prefix(5))

        var outfitDays: [Outfit.ID: Set<String>] = [:]
        for wear in period { if let id = wear.outfit { outfitDays[id, default: []].insert(wear.day) } }
        recap.topOutfit = outfitDays.compactMap { id, days in outfits.first { $0.id == id }.map { YearRecap.TopOutfit(outfit: $0, times: days.count) } }
            .sorted { a, b in a.times != b.times ? a.times > b.times : a.outfit.displayName < b.outfit.displayName }.first

        let added = items.filter { calendar.component(.year, from: $0.created) == year }
        recap.added = added.count
        recap.spent = added.compactMap(\.price).filter { $0 > 0 }.reduce(0, +)
        recap.best = worn.compactMap { entry -> Stats.CostPerWear? in
            guard let price = entry.item.price, price > 0 else { return nil }
            return Stats.CostPerWear(item: entry.item, cost: price / Double(entry.times), times: entry.times)
        }
        .sorted { $0.cost < $1.cost }.first
        return recap
    }
}
