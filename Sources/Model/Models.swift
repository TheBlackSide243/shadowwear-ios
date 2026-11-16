import Foundation

/// What kind of garment a piece is. The raw values are stored in items.json: never rename them.
enum Category: String, Codable, CaseIterable, Identifiable {
    case top, bottom, dress, outerwear, shoes, bag, accessory, other

    var id: String { rawValue }

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
        case .other: "square.grid.2x2"
        }
    }

    /// Words of Vision's image classifier, in the order they are tried on each label: "dress_shirt"
    /// is a shirt, so the tops come before the dresses.
    private static let keywords: [(String, Category)] = [
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
    /// The first one is the cover, in the grid.
    var photos: [Photo] = []
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
        photos = try c.decodeIfPresent([Photo].self, forKey: .photos) ?? []
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
        let fields = [name, brand, size, notes, category.label] + colors.compactMap { PaletteColor.named($0)?.name }
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
