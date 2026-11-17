import UIKit

/// Screenshots for the README: launched with `-demo -screen <name>`, the app opens a closet of
/// drawn pieces in its own folder (never the real one) on the screen asked for.
enum Demo {
    static var isOn: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static var screen: String? {
        let args = ProcessInfo.processInfo.arguments
        guard isOn, let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    /// The tab the demo screen is on.
    static var tab: AppTab? {
        switch screen {
        case nil: nil
        case "today": .today
        case "outfits", "outfit", "compose": .outfits
        case "diary": .diary
        case "more", "stylist", "packing", "laundry", "season", "clearout", "wishlist", "stats", "ai", "selfie": .more
        default: .closet
        }
    }

    /// The tool open on the Altro tab.
    static var moreTool: MoreView.Tool? {
        switch screen {
        case "stylist": .stylist
        case "packing": .packing
        case "laundry": .laundry
        case "season": .season
        case "clearout": .clearOut
        case "wishlist": .wishlist
        case "stats": .stats
        case "ai": .ai
        case "selfie": .selfie
        default: nil
        }
    }

    /// A conversation with the stylist, for its picture. The numbers are the places of the demo
    /// pieces in the closet (added last first: [10] is the black T-shirt).
    static var chat: [ChatMessage] {
        guard screen == "stylist" else { return [] }
        return [
            ChatMessage(fromUser: true, text: String(localized: "Cosa mi metto per un aperitivo stasera? Fa freschino.")),
            ChatMessage(fromUser: false, text: String(localized: "Con 8-15 °C punterei su [10] con [9]: semplice ma curato. Sopra metti [7], che scalda senza essere pesante, e chiudi con [6]. Se vuoi qualcosa di più elegante, al posto dei jeans vanno benissimo [3].")),
        ]
    }

    /// Fixed weather, so the pictures do not depend on the day they are taken.
    static var forecast: Forecast {
        Forecast(place: "Milano", fetched: Date(), day: Day.key(Date()), now: 13, high: 15, low: 8, rain: 20, code: 2)
    }

    /// A closet in Library/Caches/Demo, filled with the demo pieces on every launch.
    @MainActor static func closet() -> Closet {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Demo", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let closet = Closet(root: root)
        guard screen != "empty" else { return closet }
        let now = Date()
        var ids: [Int: Item.ID] = [:]
        for (index, piece) in pieces.enumerated().reversed() {
            let cutout = draw(piece.shape, color: piece.color)
            let original = backdrop(cutout)
            guard let photo = closet.store(ProcessedPhoto(original: original, cutout: cutout, colors: piece.colors, category: piece.category))
            else { continue }
            var item = Item(name: String(localized: String.LocalizationValue(piece.name)), category: piece.category, colors: piece.colors, photos: [photo])
            item.brand = piece.brand
            item.size = piece.size
            item.favorite = piece.favorite
            item.notes = piece.notes.isEmpty ? "" : String(localized: String.LocalizationValue(piece.notes))
            item.price = piece.price
            item.warmth = piece.warmth
            if !piece.material.isEmpty { item.material = String(localized: String.LocalizationValue(piece.material)) }
            if !piece.style.isEmpty { item.style = String(localized: String.LocalizationValue(piece.style)) }
            item.formality = piece.formality
            item.created = now.addingTimeInterval(-Double(index) * 86_400 * 3)
            closet.add(item)
            ids[index] = item.id
        }
        // Three outfits and two weeks of diary, made of the pieces above (by their place in the list).
        let outfits: [(String, [Int], Occasion, Bool)] = [
            ("Ufficio", [2, 7, 3, 4], .work, false),
            ("Weekend", [0, 1, 4, 9], .everyday, true),
            ("Cena fuori", [6, 8], .evening, false),
        ]
        var made: [Outfit] = []
        for (offset, entry) in outfits.enumerated() {
            var outfit = Outfit(name: String(localized: String.LocalizationValue(entry.0)), items: entry.1.compactMap { ids[$0] }, occasion: entry.2)
            outfit.favorite = entry.3
            outfit.created = now.addingTimeInterval(-Double(offset) * 86_400)
            closet.add(outfit)
            made.append(outfit)
        }
        let calendar = Calendar.current
        let diary: [(Int, Int?, [Int])] = [(1, 0, []), (2, 1, []), (3, nil, [5, 1, 4]), (5, 0, []), (6, 2, []),
                                          (8, 1, []), (9, nil, [5, 7, 4]), (12, 0, []), (13, 1, [])]
        for (daysAgo, outfit, pieces) in diary {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: now) else { continue }
            if let outfit { closet.wear(made[outfit], on: date) } else { closet.wear(pieces.compactMap { ids[$0] }, on: date) }
        }
        // A few days liked or not, for the numbers.
        for (n, entry) in closet.wears.enumerated() where n % 3 != 2 {
            closet.rate(entry.id, n % 4 == 3 ? -1 : 1)
        }
        // Things to buy (no pictures: the demo goes to no shop).
        var coat = Wish(title: String(localized: "Cappotto di lana cammello"), link: "https://example.org/cappotto")
        coat.price = 149
        coat.previousPrice = 189
        coat.currency = "EUR"
        coat.category = .outerwear
        closet.add(coat)
        var boots = Wish(title: String(localized: "Stivaletti in pelle"), link: "https://example.org/stivaletti")
        boots.price = 119.9
        boots.currency = "EUR"
        boots.category = .shoes
        closet.add(boots)
        var scarf = Wish(title: String(localized: "Sciarpa a righe"))
        scarf.category = .accessory
        closet.add(scarf)
        if screen == "packing" { demoTrip(closet, ids: ids) }
        return closet
    }

    /// A weekend in Lisbon with its forecast, already half packed.
    @MainActor private static func demoTrip(_ closet: Closet, ids: [Int: Item.ID]) {
        let start = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        var trip = TripPlan(place: Place(name: "Lisbona, Portogallo", latitude: 38.72, longitude: -9.14), start: start, nights: 3,
                            occasions: [.everyday, .evening])
        trip.days = (0..<4).map { i in
            let day = Day.key(Calendar.current.date(byAdding: .day, value: i, to: start) ?? start)
            return TripPlan.Day(day: day, high: [19, 21, 18, 20][i], low: [12, 13, 12, 14][i], rain: [10, 0, 60, 20][i])
        }
        trip.chosen = Packer.plan(items: closet.items, trip: trip).flatMap(\.items)
        trip.packed = Array(trip.chosen.prefix(3))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        UserDefaults.standard.set(try? encoder.encode(trip), forKey: "packingTrip")
    }

    private struct Piece {
        let name: String
        let category: Category
        let shape: Shape
        let color: UIColor
        let colors: [String]
        var brand = ""
        var size = ""
        var favorite = false
        var notes = ""
        var price: Double?
        var warmth: Warmth?
        var material = ""
        var style = ""
        var formality: Formality?
    }

    private enum Shape { case tee, shirt, jeans, chinos, jacket, sweater, dress, sneaker, bag, cap }

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> UIColor {
        UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1)
    }

    private static let pieces: [Piece] = [
        Piece(name: "Maglietta nera", category: .top, shape: .tee, color: rgb(28, 28, 30), colors: ["black"],
              brand: "Basic Co.", size: "M", favorite: true, notes: "Lavare al rovescio, 30 gradi.",
              price: 15, material: "Cotone", style: "Casual", formality: .casual),
        Piece(name: "Jeans dritti", category: .bottom, shape: .jeans, color: rgb(52, 88, 150), colors: ["blue"],
              brand: "Denim Lab", size: "32", favorite: true, price: 79, material: "Denim", style: "Casual", formality: .casual),
        Piece(name: "Camicia di lino", category: .top, shape: .shirt, color: rgb(240, 238, 230), colors: ["white"],
              brand: "Linea", size: "M", price: 59, warmth: .light, material: "Lino", style: "Curato", formality: .smart),
        Piece(name: "Giacca blu", category: .outerwear, shape: .jacket, color: rgb(32, 42, 82), colors: ["navy"],
              brand: "Sartoria", size: "50", price: 220, material: "Lana", style: "Elegante", formality: .smart),
        Piece(name: "Sneakers bianche", category: .shoes, shape: .sneaker, color: rgb(244, 244, 240), colors: ["white", "grey"],
              brand: "Runner", size: "43", favorite: true),
        Piece(name: "Felpa grigia", category: .top, shape: .sweater, color: rgb(140, 140, 146), colors: ["grey"],
              brand: "Basic Co.", size: "L"),
        Piece(name: "Vestito rosso", category: .dress, shape: .dress, color: rgb(196, 40, 48), colors: ["red"],
              brand: "Atelier", size: "S", price: 140, warmth: .light, style: "Elegante", formality: .formal),
        Piece(name: "Pantaloni chino", category: .bottom, shape: .chinos, color: rgb(212, 190, 152), colors: ["beige"],
              brand: "Linea", size: "32"),
        Piece(name: "Borsa in pelle", category: .bag, shape: .bag, color: rgb(118, 76, 46), colors: ["brown"],
              brand: "Pellame"),
        Piece(name: "Cappellino", category: .accessory, shape: .cap, color: rgb(108, 112, 58), colors: ["olive"]),
    ]

    /// The piece as taken on a table: the cut-out on a light, slightly warm background.
    private static func backdrop(_ cutout: UIImage) -> UIImage {
        let size = CGSize(width: 900, height: 1100)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.86, green: 0.83, blue: 0.78, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            cutout.draw(in: CGRect(x: 150, y: 150, width: 600, height: 700))
        }
    }

    /// A flat drawing of a piece on a transparent background, 600 x 700.
    private static func draw(_ shape: Shape, color: UIColor) -> UIImage {
        let size = CGSize(width: 600, height: 700)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            let body = path(shape)
            color.setFill()
            body.fill()
            // A soft shade down one side, and the seams, so the drawing reads as cloth.
            cg.saveGState()
            body.addClip()
            UIColor.black.withAlphaComponent(0.12).setFill()
            UIBezierPath(rect: CGRect(x: 330, y: 0, width: 300, height: 700)).fill()
            cg.restoreGState()
            let detail = details(shape)
            let light = color.cgColor.components.map { ($0.prefix(3).reduce(0, +) / 3) > 0.6 } ?? false
            (light ? UIColor.black.withAlphaComponent(0.25) : UIColor.white.withAlphaComponent(0.22)).setStroke()
            detail.lineWidth = 5
            detail.lineCapStyle = .round
            detail.lineJoinStyle = .round
            detail.stroke()
        }
    }

    private static func poly(_ points: [(CGFloat, CGFloat)]) -> UIBezierPath {
        let p = UIBezierPath()
        p.move(to: CGPoint(x: points[0].0, y: points[0].1))
        for pt in points.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
        p.close()
        return p
    }

    private static func path(_ shape: Shape) -> UIBezierPath {
        switch shape {
        case .tee:
            return poly([(210, 90), (255, 75), (300, 105), (345, 75), (390, 90), (540, 180), (495, 290), (440, 260),
                         (440, 630), (160, 630), (160, 260), (105, 290), (60, 180)])
        case .shirt:
            return poly([(215, 80), (300, 120), (385, 80), (520, 150), (560, 520), (500, 530), (455, 260),
                         (455, 640), (145, 640), (145, 260), (100, 530), (40, 520), (80, 150)])
        case .sweater:
            return poly([(205, 85), (300, 115), (395, 85), (520, 150), (565, 560), (500, 575), (450, 270),
                         (455, 620), (145, 620), (150, 270), (100, 575), (35, 560), (80, 150)])
        case .jacket:
            return poly([(210, 70), (300, 100), (390, 70), (520, 140), (560, 560), (500, 570), (460, 270),
                         (465, 650), (135, 650), (140, 270), (100, 570), (40, 560), (80, 140)])
        case .jeans, .chinos:
            return poly([(170, 60), (430, 60), (450, 220), (470, 650), (330, 650), (300, 250), (270, 650),
                         (130, 650), (150, 220)])
        case .dress:
            return poly([(235, 60), (300, 95), (365, 60), (400, 70), (395, 230), (420, 270), (520, 650),
                         (80, 650), (180, 270), (205, 230), (200, 70)])
        case .sneaker:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 70, y: 470))
            p.addLine(to: CGPoint(x: 90, y: 330))
            p.addCurve(to: CGPoint(x: 260, y: 260), controlPoint1: CGPoint(x: 130, y: 300), controlPoint2: CGPoint(x: 200, y: 300))
            p.addCurve(to: CGPoint(x: 420, y: 360), controlPoint1: CGPoint(x: 310, y: 300), controlPoint2: CGPoint(x: 360, y: 350))
            p.addCurve(to: CGPoint(x: 540, y: 430), controlPoint1: CGPoint(x: 490, y: 370), controlPoint2: CGPoint(x: 540, y: 390))
            p.addLine(to: CGPoint(x: 540, y: 480))
            p.addLine(to: CGPoint(x: 70, y: 480))
            p.close()
            return p
        case .bag:
            let p = UIBezierPath(roundedRect: CGRect(x: 110, y: 260, width: 380, height: 330), cornerRadius: 36)
            let handle = UIBezierPath()
            handle.move(to: CGPoint(x: 200, y: 262))
            handle.addCurve(to: CGPoint(x: 400, y: 262), controlPoint1: CGPoint(x: 210, y: 120), controlPoint2: CGPoint(x: 390, y: 120))
            handle.addLine(to: CGPoint(x: 370, y: 262))
            handle.addCurve(to: CGPoint(x: 230, y: 262), controlPoint1: CGPoint(x: 360, y: 160), controlPoint2: CGPoint(x: 240, y: 160))
            handle.close()
            p.append(handle)
            return p
        case .cap:
            let p = UIBezierPath()
            p.move(to: CGPoint(x: 120, y: 420))
            p.addCurve(to: CGPoint(x: 460, y: 420), controlPoint1: CGPoint(x: 120, y: 190), controlPoint2: CGPoint(x: 460, y: 190))
            p.addCurve(to: CGPoint(x: 560, y: 470), controlPoint1: CGPoint(x: 520, y: 425), controlPoint2: CGPoint(x: 560, y: 440))
            p.addCurve(to: CGPoint(x: 120, y: 440), controlPoint1: CGPoint(x: 460, y: 480), controlPoint2: CGPoint(x: 200, y: 470))
            p.close()
            return p
        }
    }

    private static func details(_ shape: Shape) -> UIBezierPath {
        let p = UIBezierPath()
        func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) {
            p.move(to: CGPoint(x: a.0, y: a.1))
            p.addLine(to: CGPoint(x: b.0, y: b.1))
        }
        switch shape {
        case .tee:
            p.move(to: CGPoint(x: 255, y: 75)); p.addQuadCurve(to: CGPoint(x: 345, y: 75), controlPoint: CGPoint(x: 300, y: 135))
            line((160, 600), (440, 600))
        case .shirt:
            line((300, 120), (300, 640)); line((215, 80), (275, 190)); line((385, 80), (325, 190))
            for y in stride(from: 200, through: 600, by: 80) { p.append(UIBezierPath(ovalIn: CGRect(x: 312, y: CGFloat(y), width: 10, height: 10))) }
        case .sweater:
            p.move(to: CGPoint(x: 240, y: 95)); p.addQuadCurve(to: CGPoint(x: 360, y: 95), controlPoint: CGPoint(x: 300, y: 150))
            line((150, 580), (450, 580)); line((40, 525), (100, 520)); line((500, 520), (560, 525))
        case .jacket:
            line((300, 100), (300, 650)); line((210, 70), (300, 330)); line((390, 70), (300, 330))
            line((180, 470), (250, 470)); line((350, 470), (420, 470))
        case .jeans, .chinos:
            line((170, 110), (430, 110)); line((300, 110), (300, 240)); line((185, 140), (240, 200)); line((415, 140), (360, 200))
        case .dress:
            line((205, 230), (395, 230))
        case .sneaker:
            line((70, 445), (540, 445)); line((200, 300), (240, 340)); line((230, 290), (270, 330)); line((260, 285), (300, 325))
        case .bag:
            line((110, 360), (490, 360)); p.append(UIBezierPath(roundedRect: CGRect(x: 280, y: 380, width: 40, height: 26), cornerRadius: 6))
        case .cap:
            line((290, 250), (290, 420))
        }
        return p
    }
}
