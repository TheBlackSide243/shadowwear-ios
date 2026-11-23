import Foundation

/// What kind of garment a piece is. The raw values are stored in items.json: never rename them.
enum Category: String, Codable, CaseIterable, Identifiable {
    case top, bottom, dress, outerwear, shoes, bag, accessory, ski, other

    var id: String { rawValue }

    /// Kept apart from the everyday closet: the ski gear has its own section, and the ideas of the
    /// day, the laundry, the change of season and the clear-out leave it alone.
    var apart: Bool { self == .ski }

    /// What a piece of ski gear usually is: names to tap instead of writing them.
    static var skiNames: [String] {
        [String(localized: "Tuta da sci"), String(localized: "Giacca da sci"), String(localized: "Pantaloni da sci"),
         String(localized: "Maschera"), String(localized: "Casco"), String(localized: "Guanti da sci"),
         String(localized: "Scarponi"), String(localized: "Sci"), String(localized: "Snowboard"),
         String(localized: "Bastoncini"), String(localized: "Maglia termica"), String(localized: "Calze da sci")]
    }

    /// The name of the group, on the filter chips and in the picker.
    var label: String {
        switch self {
        case .top: String(localized: "Maglie e camicie")
        case .bottom: String(localized: "Pantaloni e gonne")
        case .dress: String(localized: "Vestiti")
        case .outerwear: String(localized: "Giacche e cappotti")
        case .shoes: String(localized: "Scarpe")
        case .bag: String(localized: "Borse")
        case .accessory: String(localized: "Accessori")
        case .ski: String(localized: "Sci e neve")
        case .other: String(localized: "Altro")
        }
    }

    /// The name a new piece gets until the user writes one.
    var defaultName: String {
        switch self {
        case .top: String(localized: "Maglia")
        case .bottom: String(localized: "Pantaloni")
        case .dress: String(localized: "Vestito")
        case .outerwear: String(localized: "Giacca")
        case .shoes: String(localized: "Scarpe")
        case .bag: String(localized: "Borsa")
        case .accessory: String(localized: "Accessorio")
        case .ski: String(localized: "Capo da sci")
        case .other: String(localized: "Capo")
        }
    }

    var symbol: String {
        switch self {
        case .top: "tshirt"
        case .bottom: "square.split.1x2"
        case .dress: "sparkles"
        case .outerwear: "wind"
        case .shoes: "shoeprints.fill"
        case .bag: "bag"
        case .accessory: "eyeglasses"
        case .ski: "snowflake"
        case .other: "square.grid.2x2"
        }
    }

    /// Words of Vision's image classifier, in the order they are tried on each label: "dress_shirt"
    /// is a shirt, so the tops come before the dresses.
    private static let keywords: [(String, Category)] = [
        ("ski", .ski), ("snowboard", .ski), ("goggles", .ski), ("helmet", .ski), ("snowsuit", .ski),
        ("shirt", .top), ("blouse", .top), ("sweater", .top), ("sweatshirt", .top), ("hoodie", .top),
        ("polo", .top), ("jersey", .top), ("cardigan", .top), ("tank", .top), ("top", .top), ("tee", .top),
        ("jeans", .bottom), ("pants", .bottom), ("trousers", .bottom), ("shorts", .bottom),
        ("skirt", .bottom), ("leggings", .bottom), ("denim", .bottom),
        ("coat", .outerwear), ("jacket", .outerwear), ("parka", .outerwear), ("blazer", .outerwear),
        ("raincoat", .outerwear), ("windbreaker", .outerwear),
        ("dress", .dress), ("gown", .dress), ("jumpsuit", .dress),
        ("shoe", .shoes), ("sneaker", .shoes), ("boot", .shoes), ("sandal", .shoes), ("footwear", .shoes),
        ("heel", .shoes), ("loafer", .shoes), ("slipper", .shoes),
        ("bag", .bag), ("handbag", .bag), ("purse", .bag), ("backpack", .bag), ("wallet", .bag), ("luggage", .bag),
        ("hat", .accessory), ("cap", .accessory), ("scarf", .accessory), ("glove", .accessory),
        ("belt", .accessory), ("tie", .accessory), ("sunglasses", .accessory), ("eyeglasses", .accessory),
        ("watch", .accessory), ("jewelry", .accessory), ("necklace", .accessory), ("bracelet", .accessory),
        ("earring", .accessory), ("sock", .accessory),
    ]

    /// The category of the most confident classifier label that names a garment, if any does.
    /// A label matches on whole words, plurals included: "sneakers" is a sneaker, "landscape" no cap.
    static func guess(from labels: [(identifier: String, confidence: Float)], minimum: Float = 0.05) -> Category? {
        for label in labels.sorted(by: { $0.confidence > $1.confidence }) where label.confidence >= minimum {
            let words = label.identifier.lowercased().split(whereSeparator: { $0 == "_" || $0 == " " || $0 == "-" }).map(String.init)
            for (keyword, category) in keywords
            where words.contains(where: { $0 == keyword || $0 == keyword + "s" || $0 == keyword + "es" }) {
                return category
            }
        }
        return nil
    }
}

extension Optional where Wrapped == Category {
    /// The filter of the grids: a kind shows its pieces; no kind shows the everyday closet, without
    /// the ski gear, which has its own section.
    func shows(_ item: Item) -> Bool {
        map { item.category == $0 } ?? !item.category.apart
    }
}

/// One photo of a piece. On disk: <id>.jpg the photo as taken, <id>.png the piece without its
/// background when the cut-out worked (Closet keeps the files).
struct Photo: Codable, Hashable, Identifiable {
    var id = UUID()
    var hasCutout = false
    /// Show the piece without background, when there is one.
    var showCutout = true

    init(id: UUID = UUID(), hasCutout: Bool = false, showCutout: Bool = true) {
        self.id = id
        self.hasCutout = hasCutout
        self.showCutout = showCutout
    }

    // Every field optional when reading, so files written by another version still open.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        hasCutout = try c.decodeIfPresent(Bool.self, forKey: .hasCutout) ?? false
        showCutout = try c.decodeIfPresent(Bool.self, forKey: .showCutout) ?? true
    }

    var usesCutout: Bool { hasCutout && showCutout }
}

/// A piece of clothing in the closet.
struct Item: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var category: Category
    /// PaletteColor keys, the main one first.
    var colors: [String] = []
    var brand = ""
    var size = ""
    var notes = ""
    var favorite = false
    /// How warm it is; nil means guessed from the category (see Warmth.guess).
    var warmth: Warmth?
    /// The first one is the cover, in the grid.
    var photos: [Photo] = []
    /// What it is made of, its pattern and its style, in a few words (written by hand or by the AI).
    var material = ""
    var pattern = ""
    var style = ""
    /// The seasons it is for; empty means guessed from how warm it is (see effectiveSeasons).
    var seasons: [Season] = []
    var formality: Formality?
    /// What it cost, for the cost per wear.
    var price: Double?
    /// The last wash; the wears after it count towards the next one.
    var washed: Date?
    /// Wears between two washes; nil means the usual for its kind (see Care.washEvery).
    var washEvery: Int?
    /// Put away for the season: not in the ideas of the day until it is brought out again.
    var stored = false
    /// "I keep it" in the clear-out: not proposed again before this date.
    var keepUntil: Date?
    var created = Date()
    var updated = Date()

    init(name: String, category: Category, colors: [String] = [], photos: [Photo] = []) {
        self.name = name
        self.category = category
        self.colors = colors
        self.photos = photos
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        // A category this version does not know reads as Other instead of losing the piece.
        category = (try? c.decodeIfPresent(Category.self, forKey: .category)) ?? .other
        colors = try c.decodeIfPresent([String].self, forKey: .colors) ?? []
        brand = try c.decodeIfPresent(String.self, forKey: .brand) ?? ""
        size = try c.decodeIfPresent(String.self, forKey: .size) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        favorite = try c.decodeIfPresent(Bool.self, forKey: .favorite) ?? false
        warmth = try? c.decodeIfPresent(Warmth.self, forKey: .warmth)
        photos = try c.decodeIfPresent([Photo].self, forKey: .photos) ?? []
        material = try c.decodeIfPresent(String.self, forKey: .material) ?? ""
        pattern = try c.decodeIfPresent(String.self, forKey: .pattern) ?? ""
        style = try c.decodeIfPresent(String.self, forKey: .style) ?? ""
        // Seasons this version does not know are skipped, not the whole piece.
        seasons = ((try? c.decodeIfPresent([String].self, forKey: .seasons)) ?? nil)?.compactMap(Season.init(rawValue:)) ?? []
        formality = try? c.decodeIfPresent(Formality.self, forKey: .formality)
        price = try? c.decodeIfPresent(Double.self, forKey: .price)
        washed = try? c.decodeIfPresent(Date.self, forKey: .washed)
        washEvery = try? c.decodeIfPresent(Int.self, forKey: .washEvery)
        stored = (try? c.decodeIfPresent(Bool.self, forKey: .stored)) ?? false
        keepUntil = try? c.decodeIfPresent(Date.self, forKey: .keepUntil)
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? created
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? category.defaultName : trimmed
    }

    /// Whether the piece matches what was typed in the search: name, brand, size, notes, category
    /// or a color name, ignoring case and accents.
    func matches(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let fields = [name, brand, size, notes, material, pattern, style, category.label] + colors.compactMap { PaletteColor.named($0)?.name }
        return fields.contains { $0.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }
}

/// How the closet grid is ordered.
enum SortOrder: String, CaseIterable, Identifiable {
    case newest, oldest, name, category

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: String(localized: "Più recenti")
        case .oldest: String(localized: "Meno recenti")
        case .name: String(localized: "Nome")
        case .category: String(localized: "Categoria")
        }
    }

    func sort(_ items: [Item]) -> [Item] {
        switch self {
        case .newest: items.sorted { $0.created > $1.created }
        case .oldest: items.sorted { $0.created < $1.created }
        case .name: items.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .category:
            items.sorted {
                let a = Category.allCases.firstIndex(of: $0.category) ?? 0
                let b = Category.allCases.firstIndex(of: $1.category) ?? 0
                return a != b ? a < b : $0.created > $1.created
            }
        }
    }
}

/// The seasons of the year. Stored in items.json: never rename.
enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, autumn, winter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spring: String(localized: "Primavera")
        case .summer: String(localized: "Estate")
        case .autumn: String(localized: "Autunno")
        case .winter: String(localized: "Inverno")
        }
    }

    var symbol: String {
        switch self {
        case .spring: "leaf"
        case .summer: "sun.max"
        case .autumn: "wind"
        case .winter: "snowflake"
        }
    }

    /// The season of a date, the other way round south of the equator.
    static func of(_ date: Date, south: Bool = false, calendar: Calendar = .current) -> Season {
        let month = calendar.component(.month, from: date)
        let north: Season = switch month {
        case 3...5: .spring
        case 6...8: .summer
        case 9...11: .autumn
        default: .winter
        }
        guard south else { return north }
        switch north {
        case .spring: return .autumn
        case .summer: return .winter
        case .autumn: return .spring
        case .winter: return .summer
        }
    }

    /// Spring first, for sorting.
    var order: Int { Season.allCases.firstIndex(of: self) ?? 0 }

    var next: Season {
        switch self {
        case .spring: .summer
        case .summer: .autumn
        case .autumn: .winter
        case .winter: .spring
        }
    }
}

/// How dressed up a piece is. Stored in items.json: never rename.
enum Formality: String, Codable, CaseIterable, Identifiable {
    case casual, smart, formal, sporty

    var id: String { rawValue }

    var label: String {
        switch self {
        case .casual: String(localized: "Casual")
        case .smart: String(localized: "Curato")
        case .formal: String(localized: "Elegante")
        case .sporty: String(localized: "Sportivo")
        }
    }
}

extension Item {
    /// The seasons it is for: the ones chosen, or from how warm it is.
    var effectiveSeasons: Set<Season> {
        if !seasons.isEmpty { return Set(seasons) }
        switch effectiveWarmth {
        case .light: return [.spring, .summer]
        case .medium: return [.spring, .autumn, .summer, .winter]
        case .warm: return [.autumn, .winter]
        }
    }
}
