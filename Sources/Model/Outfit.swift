import Foundation

/// What an outfit is for. The raw values are stored in outfits.json: never rename them.
enum Occasion: String, Codable, CaseIterable, Identifiable {
    case everyday, work, sport, evening, home

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyday: String(localized: "Tutti i giorni")
        case .work: String(localized: "Lavoro")
        case .sport: String(localized: "Sport")
        case .evening: String(localized: "Sera")
        case .home: String(localized: "Casa")
        }
    }

    var symbol: String {
        switch self {
        case .everyday: "sun.max"
        case .work: "briefcase"
        case .sport: "figure.run"
        case .evening: "moon.stars"
        case .home: "house"
        }
    }
}

/// How warm a piece is, for the weather. Stored in items.json: never renumber.
enum Warmth: Int, Codable, CaseIterable, Identifiable {
    case light = 0, medium = 1, warm = 2

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .light: String(localized: "Leggero")
        case .medium: String(localized: "Medio")
        case .warm: String(localized: "Pesante")
        }
    }

    /// What a piece is when nobody said: coats are warm, the rest in between.
    static func guess(for category: Category) -> Warmth {
        category == .outerwear ? .warm : .medium
    }
}

extension Item {
    var effectiveWarmth: Warmth { warmth ?? Warmth.guess(for: category) }
}

/// Pieces put together to wear.
struct Outfit: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// The pieces, in the order they were picked.
    var items: [Item.ID]
    var occasion: Occasion?
    var favorite = false
    var notes = ""
    var created = Date()
    var updated = Date()

    init(name: String, items: [Item.ID], occasion: Occasion? = nil) {
        self.name = name
        self.items = items
        self.occasion = occasion
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        items = try c.decodeIfPresent([Item.ID].self, forKey: .items) ?? []
        occasion = try? c.decodeIfPresent(Occasion.self, forKey: .occasion)
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? created
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Outfit senza nome") : trimmed
    }
}

/// What was worn on a day: an outfit, or just some pieces. The pieces are kept even when the
/// outfit is later deleted, so the diary does not lose the day.
struct Wear: Codable, Hashable, Identifiable {
    var id = UUID()
    /// The day as yyyy-MM-dd in the calendar of the phone.
    var day: String
    var outfit: Outfit.ID?
    var items: [Item.ID]

    init(day: String, outfit: Outfit.ID? = nil, items: [Item.ID]) {
        self.day = day
        self.outfit = outfit
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        day = try c.decode(String.self, forKey: .day)
        outfit = try c.decodeIfPresent(UUID.self, forKey: .outfit)
        items = try c.decodeIfPresent([Item.ID].self, forKey: .items) ?? []
    }
}

/// Days as yyyy-MM-dd strings: what the diary stores, and easy to sort.
enum Day {
    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(_ key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Whole days from `key` to `today` (0 for today, 1 for yesterday).
    static func distance(from key: String, to today: Date, calendar: Calendar = .current) -> Int? {
        guard let date = date(key, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: today)).day
    }
}
