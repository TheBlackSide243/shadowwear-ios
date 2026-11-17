import Foundation

/// Something to buy: a link to a shop (or just a name), with its picture and price read from the
/// page, and the price it had before when it changed.
struct Wish: Codable, Hashable, Identifiable {
    var id = UUID()
    var title: String
    var link = ""
    var image = ""
    var price: Double?
    var currency = ""
    /// The price before the last change, to show whether it went down or up.
    var previousPrice: Double?
    /// When the shop page was last read.
    var checked: Date?
    var category: Category?
    var notes = ""
    var bought = false
    var created = Date()
    var updated = Date()

    init(title: String, link: String = "") {
        self.title = title
        self.link = link
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        link = try c.decodeIfPresent(String.self, forKey: .link) ?? ""
        image = try c.decodeIfPresent(String.self, forKey: .image) ?? ""
        price = try? c.decodeIfPresent(Double.self, forKey: .price)
        currency = try c.decodeIfPresent(String.self, forKey: .currency) ?? ""
        previousPrice = try? c.decodeIfPresent(Double.self, forKey: .previousPrice)
        checked = try? c.decodeIfPresent(Date.self, forKey: .checked)
        category = try? c.decodeIfPresent(Category.self, forKey: .category)
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        bought = try c.decodeIfPresent(Bool.self, forKey: .bought) ?? false
        created = try c.decodeIfPresent(Date.self, forKey: .created) ?? Date()
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? created
    }

    var displayTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !t.isEmpty { return t }
        return URL(string: link)?.host ?? String(localized: "Senza nome")
    }

    var url: URL? {
        guard let url = URL(string: link.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    var imageURL: URL? {
        guard let url = URL(string: image), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    /// The price as the shop writes it: 49,90 €.
    static func format(_ price: Double, currency: String) -> String {
        let code = currency.isEmpty ? "EUR" : currency
        return price.formatted(.currency(code: code))
    }

    /// Down, up or the same since the page was read before.
    var trend: Int {
        guard let price, let previousPrice, price != previousPrice else { return 0 }
        return price < previousPrice ? -1 : 1
    }
}

/// Title, picture and price of a shop page, from the tags shops put there for link previews
/// (Open Graph, product meta tags, schema.org JSON-LD). Read on this iPhone: the link goes nowhere else.
struct LinkPreview: Equatable {
    var title: String?
    var image: String?
    var price: Double?
    var currency: String?

    static func fetch(_ url: URL) async throws -> LinkPreview {
        var request = URLRequest(url: url, timeoutInterval: 20)
        // Some shops send a page without prices to programs that do not look like a browser.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.first ?? "it", forHTTPHeaderField: "Accept-Language")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        // Only the start of the page: the tags are in the head, and some pages are huge.
        let head = data.prefix(1_500_000)
        let html = String(data: head, encoding: .utf8) ?? String(decoding: head, as: UTF8.self)
        return parse(html, base: http.url ?? url)
    }

    static func parse(_ html: String, base: URL) -> LinkPreview {
        var meta: [String: String] = [:]
        for tag in matches(#"<meta\b[^>]*>"#, in: html) {
            let attributes = attributes(of: tag)
            guard let key = (attributes["property"] ?? attributes["name"] ?? attributes["itemprop"])?.lowercased(),
                  let content = attributes["content"], !content.isEmpty, meta[key] == nil else { continue }
            meta[key] = decodeEntities(content)
        }
        var out = LinkPreview()
        out.title = meta["og:title"] ?? meta["twitter:title"] ?? matches(#"<title[^>]*>([\s\S]*?)</title>"#, in: html, group: 1).first.map(decodeEntities)
        out.title = out.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let image = meta["og:image"] ?? meta["og:image:url"] ?? meta["twitter:image"] ?? meta["image"] {
            out.image = URL(string: image, relativeTo: base)?.absoluteString
        }
        let priceText = meta["product:price:amount"] ?? meta["og:price:amount"] ?? meta["price"]
        out.price = priceText.flatMap(number)
        out.currency = meta["product:price:currency"] ?? meta["og:price:currency"] ?? meta["pricecurrency"]
        if out.price == nil {
            // schema.org in JSON-LD: "price": "49.90" (or a number), next to "priceCurrency".
            if let found = matches(#""price"\s*:\s*"?([0-9][0-9.,]*)"?"#, in: html, group: 1).first {
                out.price = number(found)
            }
            if out.currency == nil, let code = matches(#""priceCurrency"\s*:\s*"([A-Za-z]{3})""#, in: html, group: 1).first {
                out.currency = code
            }
        }
        out.currency = out.currency?.uppercased()
        if out.title?.isEmpty == true { out.title = nil }
        return out
    }

    /// "1.299,00", "1,299.00", "49.9" or "49,90" as a number.
    static func number(_ text: String) -> Double? {
        var t = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard !t.isEmpty else { return nil }
        let lastDot = t.lastIndex(of: "."), lastComma = t.lastIndex(of: ",")
        if let lastDot, let lastComma {
            // Both: the later one is the decimal mark, the other one groups thousands.
            t = lastComma > lastDot
                ? t.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
                : t.replacingOccurrences(of: ",", with: "")
        } else if let mark = lastComma ?? lastDot {
            // One kind only: thousands when it comes more than once or has three digits after it
            // ("1.299", "1,299", "1.299.000"), the decimal mark otherwise ("49,90", "49.9").
            let symbol = t[mark]
            let count = t.filter { $0 == symbol }.count
            let after = t.distance(from: mark, to: t.endIndex) - 1
            t = count > 1 || after == 3
                ? t.replacingOccurrences(of: String(symbol), with: "")
                : t.replacingOccurrences(of: String(symbol), with: ".")
        }
        guard let value = Double(t), value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func matches(_ pattern: String, in text: String, group: Int = 0) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            Range(match.range(at: group), in: text).map { String(text[$0]) }
        }
    }

    private static func attributes(of tag: String) -> [String: String] {
        guard let regex = try? NSRegularExpression(pattern: #"([a-zA-Z:_-]+)\s*=\s*("([^"]*)"|'([^']*)')"#) else { return [:] }
        var out: [String: String] = [:]
        for match in regex.matches(in: tag, range: NSRange(tag.startIndex..., in: tag)) {
            guard let name = Range(match.range(at: 1), in: tag) else { continue }
            let value = Range(match.range(at: 3), in: tag) ?? Range(match.range(at: 4), in: tag)
            out[tag[name].lowercased()] = value.map { String(tag[$0]) } ?? ""
        }
        return out
    }

    private static func decodeEntities(_ text: String) -> String {
        var t = text
        for (entity, value) in [("&amp;", "&"), ("&quot;", "\""), ("&#39;", "'"), ("&#x27;", "'"), ("&apos;", "'"),
                                ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&euro;", "€")] {
            t = t.replacingOccurrences(of: entity, with: value)
        }
        return t
    }
}
