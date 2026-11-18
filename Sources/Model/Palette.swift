import SwiftUI

/// The colors a piece can be tagged with. The keys are stored in items.json: never rename them.
struct PaletteColor: Identifiable, Hashable {
    let key: String
    let red: Double
    let green: Double
    let blue: Double

    var id: String { key }
    var color: Color { Color(red: red / 255, green: green / 255, blue: blue / 255) }

    /// The key of a color word the AI wrote: the key itself, or a color named in Italian or English
    /// ("bianca", "rossi", "gray", "dark blue"…). Nil for a word that is not one of the palette's colors.
    static func key(forWord word: String) -> String? {
        let w = word.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if all.contains(where: { $0.key == w }) { return w }
        let words: [String: String] = [
            "nero": "black", "nera": "black", "neri": "black", "nere": "black",
            "bianco": "white", "bianca": "white", "bianchi": "white", "bianche": "white", "panna": "white", "off-white": "white", "cream": "beige",
            "grigio": "grey", "grigia": "grey", "grigi": "grey", "grigie": "grey", "gray": "grey", "antracite": "grey", "charcoal": "grey",
            "beige": "beige", "sabbia": "beige", "cammello": "beige", "camel": "beige", "tan": "beige", "crema": "beige",
            "marrone": "brown", "marroni": "brown", "cuoio": "brown", "cioccolato": "brown",
            "rosso": "red", "rossa": "red", "rossi": "red", "rosse": "red",
            "bordeaux": "burgundy", "bordò": "burgundy", "maroon": "burgundy", "wine": "burgundy",
            "rosa": "pink", "fucsia": "pink",
            "arancione": "orange", "arancio": "orange", "arancioni": "orange",
            "giallo": "yellow", "gialla": "yellow", "gialli": "yellow", "gialle": "yellow", "senape": "yellow", "mustard": "yellow",
            "verde oliva": "olive", "oliva": "olive", "kaki": "olive", "khaki": "olive", "verde militare": "olive",
            "verde": "green", "verdi": "green",
            "azzurro": "lightblue", "azzurra": "lightblue", "azzurri": "lightblue", "azzurre": "lightblue", "celeste": "lightblue",
            "light blue": "lightblue", "sky blue": "lightblue",
            "blu": "blue", "denim": "blue", "jeans": "blue",
            "blu scuro": "navy", "blu navy": "navy", "navy blue": "navy", "dark blue": "navy",
            "viola": "purple", "lilla": "purple", "lavanda": "purple", "violet": "purple", "lilac": "purple",
        ]
        return words[w]
    }

    var name: String {
        switch key {
        case "black": String(localized: "Nero")
        case "white": String(localized: "Bianco")
        case "grey": String(localized: "Grigio")
        case "beige": String(localized: "Beige")
        case "brown": String(localized: "Marrone")
        case "red": String(localized: "Rosso")
        case "burgundy": String(localized: "Bordeaux")
        case "pink": String(localized: "Rosa")
        case "orange": String(localized: "Arancione")
        case "yellow": String(localized: "Giallo")
        case "olive": String(localized: "Verde oliva")
        case "green": String(localized: "Verde")
        case "lightblue": String(localized: "Azzurro")
        case "blue": String(localized: "Blu")
        case "navy": String(localized: "Blu scuro")
        case "purple": String(localized: "Viola")
        default: key
        }
    }

    static let all: [PaletteColor] = [
        PaletteColor(key: "black", red: 24, green: 24, blue: 26),
        PaletteColor(key: "white", red: 244, green: 244, blue: 240),
        PaletteColor(key: "grey", red: 140, green: 140, blue: 146),
        PaletteColor(key: "beige", red: 214, green: 194, blue: 158),
        PaletteColor(key: "brown", red: 118, green: 78, blue: 48),
        PaletteColor(key: "red", red: 204, green: 38, blue: 44),
        PaletteColor(key: "burgundy", red: 112, green: 28, blue: 44),
        PaletteColor(key: "pink", red: 240, green: 152, blue: 182),
        PaletteColor(key: "orange", red: 240, green: 128, blue: 40),
        PaletteColor(key: "yellow", red: 242, green: 206, blue: 58),
        PaletteColor(key: "olive", red: 110, green: 114, blue: 58),
        PaletteColor(key: "green", red: 56, green: 140, blue: 72),
        PaletteColor(key: "lightblue", red: 138, green: 184, blue: 226),
        PaletteColor(key: "blue", red: 44, green: 90, blue: 172),
        PaletteColor(key: "navy", red: 30, green: 40, blue: 78),
        PaletteColor(key: "purple", red: 120, green: 70, blue: 160),
    ]

    static func named(_ key: String) -> PaletteColor? { all.first { $0.key == key } }

    /// The palette color closest to an sRGB color (0...255), measured in CIE Lab, where distance
    /// follows how different two colors look.
    static func nearest(red: Double, green: Double, blue: Double) -> PaletteColor {
        let lab = Lab(red: red, green: green, blue: blue)
        return all.min { lab.distance(to: $0.lab) < lab.distance(to: $1.lab) }!
    }

    var lab: Lab { Lab(red: red, green: green, blue: blue) }

    /// The main colors of a set of pixels: each pixel counts for its nearest palette color, and the
    /// colors that cover at least `share` of them come back, the biggest first, at most `limit`.
    /// The biggest always comes back, however small.
    static func dominant(pixels: [(red: Double, green: Double, blue: Double)], share: Double = 0.15, limit: Int = 3) -> [String] {
        guard !pixels.isEmpty else { return [] }
        var counts: [String: Int] = [:]
        for p in pixels { counts[nearest(red: p.red, green: p.green, blue: p.blue).key, default: 0] += 1 }
        let ranked = counts.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        let total = Double(pixels.count)
        var keys = ranked.filter { Double($0.value) / total >= share }.prefix(limit).map(\.key)
        if keys.isEmpty, let first = ranked.first { keys = [first.key] }
        return keys
    }
}

/// CIE L*a*b* (D65) of an sRGB color.
struct Lab: Hashable {
    let l: Double
    let a: Double
    let b: Double

    init(red: Double, green: Double, blue: Double) {
        func linear(_ c: Double) -> Double {
            let v = c / 255
            return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        let r = linear(red), g = linear(green), bl = linear(blue)
        let x = (r * 0.4124 + g * 0.3576 + bl * 0.1805) / 0.95047
        let y = r * 0.2126 + g * 0.7152 + bl * 0.0722
        let z = (r * 0.0193 + g * 0.1192 + bl * 0.9505) / 1.08883
        func f(_ t: Double) -> Double { t > 0.008856 ? cbrt(t) : 7.787 * t + 16.0 / 116.0 }
        l = 116 * f(y) - 16
        a = 500 * (f(x) - f(y))
        b = 200 * (f(y) - f(z))
    }

    func distance(to other: Lab) -> Double {
        let dl = l - other.l, da = a - other.a, db = b - other.b
        return (dl * dl + da * da + db * db).squareRoot()
    }
}
