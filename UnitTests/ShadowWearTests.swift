import SwiftUI
import UIKit
import XCTest
@testable import ShadowWear

final class PaletteTests: XCTestCase {
    func testNearestColor() {
        XCTAssertEqual(PaletteColor.nearest(red: 0, green: 0, blue: 0).key, "black")
        XCTAssertEqual(PaletteColor.nearest(red: 255, green: 255, blue: 255).key, "white")
        XCTAssertEqual(PaletteColor.nearest(red: 25, green: 35, blue: 75).key, "navy")
        XCTAssertEqual(PaletteColor.nearest(red: 210, green: 30, blue: 40).key, "red")
        XCTAssertEqual(PaletteColor.nearest(red: 220, green: 200, blue: 165).key, "beige")
        XCTAssertEqual(PaletteColor.nearest(red: 60, green: 100, blue: 180).key, "blue")
    }

    func testDominantColorsKeepTheBigOnesBiggestFirst() {
        typealias Pixel = (red: Double, green: Double, blue: Double)
        var pixels: [Pixel] = Array(repeating: (red: 20, green: 20, blue: 22), count: 70)
        pixels += Array(repeating: (red: 245, green: 245, blue: 240) as Pixel, count: 25)
        pixels += Array(repeating: (red: 204, green: 38, blue: 44) as Pixel, count: 5)
        XCTAssertEqual(PaletteColor.dominant(pixels: pixels), ["black", "white"])
    }

    func testDominantColorAlwaysReturnsTheBiggest() {
        var pixels: [(red: Double, green: Double, blue: Double)] = []
        for i in 0..<20 {
            let step = Double(i)
            pixels.append((red: step * 12, green: 255 - step * 12, blue: step * 6))
        }
        XCTAssertEqual(PaletteColor.dominant(pixels: pixels, share: 0.9).count, 1)
        XCTAssertEqual(PaletteColor.dominant(pixels: []), [])
    }

    func testEveryColorHasAName() {
        for swatch in PaletteColor.all { XCTAssertNotEqual(swatch.name, swatch.key, swatch.key) }
    }
}

final class CategoryTests: XCTestCase {
    func testGuessFromClassifierLabels() {
        XCTAssertEqual(Category.guess(from: [("jeans", 0.8)]), .bottom)
        XCTAssertEqual(Category.guess(from: [("sneakers", 0.6)]), .shoes)
        XCTAssertEqual(Category.guess(from: [("dress_shirt", 0.7)]), .top)
        XCTAssertEqual(Category.guess(from: [("t_shirt", 0.7)]), .top)
        XCTAssertEqual(Category.guess(from: [("handbag", 0.5)]), .bag)
        XCTAssertEqual(Category.guess(from: [("coat", 0.5)]), .outerwear)
        XCTAssertEqual(Category.guess(from: [("dress", 0.5)]), .dress)
    }

    func testGuessUsesWholeWordsAndConfidence() {
        // "cap" is inside "landscape", but it is not a cap.
        XCTAssertNil(Category.guess(from: [("landscape", 0.9)]))
        // The most confident garment wins, whatever order the labels come in.
        XCTAssertEqual(Category.guess(from: [("hat", 0.2), ("boot", 0.7)]), .shoes)
        // Too unsure to count.
        XCTAssertNil(Category.guess(from: [("jeans", 0.01)]))
    }

    func testEveryCategoryHasNamesAndSymbol() {
        for category in Category.allCases {
            XCTAssertFalse(category.label.isEmpty)
            XCTAssertFalse(category.defaultName.isEmpty)
            XCTAssertFalse(category.symbol.isEmpty)
        }
    }
}

final class ItemTests: XCTestCase {
    func testOldOrPartialFilesStillDecode() throws {
        let json = """
        [{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Jeans","category":"future-kind",
          "photos":[{"id":"7F9619FF-8B86-D011-B42D-00C04FC964FF"}]}]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let items = try decoder.decode([Item].self, from: Data(json.utf8))
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].category, .other)
        XCTAssertEqual(items[0].colors, [])
        XCTAssertFalse(items[0].photos[0].hasCutout)
        XCTAssertTrue(items[0].photos[0].showCutout)
    }

    func testSearchMatchesFieldsAndColorNames() {
        var item = Item(name: "Camicia di lino", category: .top, colors: ["white"])
        item.brand = "Zara"
        XCTAssertTrue(item.matches("lino"))
        XCTAssertTrue(item.matches("zara"))
        XCTAssertTrue(item.matches(PaletteColor.named("white")!.name))
        XCTAssertTrue(item.matches(""))
        XCTAssertFalse(item.matches("scarpe"))
    }

    func testEmptyNameShowsTheCategory() {
        XCTAssertEqual(Item(name: "  ", category: .shoes).displayName, Category.shoes.defaultName)
    }

    func testSortOrders() {
        var a = Item(name: "Bravo", category: .shoes)
        a.created = Date(timeIntervalSince1970: 100)
        var b = Item(name: "alfa", category: .top)
        b.created = Date(timeIntervalSince1970: 200)
        XCTAssertEqual(SortOrder.newest.sort([a, b]).map(\.name), ["alfa", "Bravo"])
        XCTAssertEqual(SortOrder.oldest.sort([a, b]).map(\.name), ["Bravo", "alfa"])
        XCTAssertEqual(SortOrder.name.sort([a, b]).map(\.name), ["alfa", "Bravo"])
        XCTAssertEqual(SortOrder.category.sort([a, b]).map(\.name), ["alfa", "Bravo"])
    }
}

@MainActor
final class ClosetTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    func testItemsAndPhotosSurviveARestart() throws {
        let closet = Closet(root: root)
        let processed = ProcessedPhoto(original: image(.red), cutout: image(.blue), colors: ["red"], category: .top)
        let photo = try XCTUnwrap(closet.store(processed))
        XCTAssertTrue(photo.hasCutout)
        var item = Item(name: "Maglia rossa", category: .top, colors: ["red"], photos: [photo])
        item.favorite = true
        closet.add(item)

        let reopened = Closet(root: root)
        XCTAssertEqual(reopened.items.count, 1)
        XCTAssertEqual(reopened.items[0].name, "Maglia rossa")
        XCTAssertTrue(reopened.items[0].favorite)
        XCTAssertNotNil(reopened.image(of: photo))
        XCTAssertNotNil(reopened.original(of: photo))
        XCTAssertNil(reopened.error)
    }

    func testDeletingRemovesThePhotoFiles() throws {
        let closet = Closet(root: root)
        let photo = try XCTUnwrap(closet.store(ProcessedPhoto(original: image(.green), cutout: nil, colors: [], category: nil)))
        let item = Item(name: "", category: .other, photos: [photo])
        closet.add(item)
        let folder = root.appendingPathComponent("Foto")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 1)
        closet.delete(item.id)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: folder.path).count, 0)
        XCTAssertTrue(closet.items.isEmpty)
    }

    func testAnUnreadableFileIsKeptAside() throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: root.appendingPathComponent("items.json"))
        let closet = Closet(root: root)
        XCTAssertTrue(closet.items.isEmpty)
        XCTAssertNotNil(closet.error)
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("items-illeggibile-") })
    }

    func testDominantColorsOfAPlainImage() {
        XCTAssertEqual(PhotoProcessor.dominantColors(image(UIColor(red: 0.12, green: 0.16, blue: 0.31, alpha: 1)), ignoringBackground: true), ["navy"])
    }
}

@MainActor
final class OutfitTests: XCTestCase {
    private var root: URL!

    override func setUp() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testOutfitsAndDiarySurviveARestart() {
        let closet = Closet(root: root)
        let top = Item(name: "Maglia", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        closet.add(top)
        closet.add(jeans)
        let outfit = Outfit(name: "Weekend", items: [top.id, jeans.id], occasion: .everyday)
        closet.add(outfit)
        closet.wear(outfit)

        let reopened = Closet(root: root)
        XCTAssertEqual(reopened.outfits.map(\.name), ["Weekend"])
        XCTAssertEqual(reopened.outfits.first?.occasion, .everyday)
        XCTAssertEqual(reopened.days(wornOutfit: outfit.id), [Day.key(Date())])
        XCTAssertEqual(reopened.days(worn: jeans.id), [Day.key(Date())])
        XCTAssertNil(reopened.error)
    }

    func testDeletingAPieceTakesItOutOfOutfitsButNotTheDiary() {
        let closet = Closet(root: root)
        let top = Item(name: "Maglia", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        closet.add(top)
        closet.add(jeans)
        let outfit = Outfit(name: "", items: [top.id, jeans.id])
        closet.add(outfit)
        closet.wear(outfit)
        closet.delete(top.id)
        XCTAssertEqual(closet.outfit(outfit.id)?.items, [jeans.id])
        XCTAssertEqual(closet.wears.first?.items, [top.id, jeans.id])
        XCTAssertEqual(closet.pieces(of: closet.outfit(outfit.id)!).map(\.name), ["Jeans"])
    }

    func testOldOrPartialOutfitFilesStillDecode() throws {
        let json = #"[{"id":"6A9D6F1C-2E1B-4C55-9C4B-6C0F9D1E2A11","items":[],"occasion":"party"}]"#
        let outfits = try JSONDecoder().decode([Outfit].self, from: Data(json.utf8))
        XCTAssertEqual(outfits.count, 1)
        XCTAssertNil(outfits[0].occasion)
        XCTAssertFalse(outfits[0].displayName.isEmpty)
    }

    func testDayKeysAndDistances() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Rome")!
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 7, hour: 23)))
        XCTAssertEqual(Day.key(date, calendar: calendar), "2026-03-07")
        XCTAssertEqual(Day.distance(from: "2026-03-05", to: date, calendar: calendar), 2)
        XCTAssertEqual(Day.distance(from: "2026-03-07", to: date, calendar: calendar), 0)
        XCTAssertNil(Day.date("ieri"))
    }
}

final class StylistTests: XCTestCase {
    private func piece(_ name: String, _ category: ShadowWear.Category, _ color: String = "black", warmth: Warmth? = nil) -> Item {
        var item = Item(name: name, category: category, colors: [color])
        item.warmth = warmth
        return item
    }

    func testBands() {
        XCTAssertEqual(Conditions(high: 4, low: -2).band, .cold)
        XCTAssertEqual(Conditions(high: 14, low: 8).band, .cool)
        XCTAssertEqual(Conditions(high: 22, low: 15).band, .mild)
        XCTAssertEqual(Conditions(high: 33, low: 22).band, .hot)
        XCTAssertTrue(Conditions(high: 20, low: 10, rain: 70).rainy)
    }

    func testColdDaysWantACoatAndHotDaysDoNot() {
        let tee = piece("T-shirt", .top, warmth: .light)
        let jeans = piece("Jeans", .bottom, "blue")
        let coat = piece("Cappotto", .outerwear, "grey")
        let cold = Conditions(high: 3, low: -3)
        let hot = Conditions(high: 34, low: 24)
        let today = Date()
        XCTAssertGreaterThan(Stylist.score([tee, jeans, coat], lastWorn: [:], today: today, conditions: cold),
                             Stylist.score([tee, jeans], lastWorn: [:], today: today, conditions: cold))
        XCTAssertGreaterThan(Stylist.score([tee, jeans], lastWorn: [:], today: today, conditions: hot),
                             Stylist.score([tee, jeans, coat], lastWorn: [:], today: today, conditions: hot))
    }

    func testRecentlyWornPiecesScoreLower() {
        let shirt = piece("Camicia", .top, "white")
        let today = Date()
        let yesterday = Day.key(Calendar.current.date(byAdding: .day, value: -1, to: today)!)
        XCTAssertLessThan(Stylist.score(shirt, lastWorn: [shirt.id: yesterday], today: today, conditions: nil),
                          Stylist.score(shirt, lastWorn: [:], today: today, conditions: nil))
    }

    func testStrongColorsClash() {
        XCTAssertEqual(Stylist.clash([piece("A", .top, "red"), piece("B", .bottom, "black")]), 0)
        XCTAssertEqual(Stylist.clash([piece("A", .top, "white"), piece("B", .bottom, "blue")]), 0)
        XCTAssertGreaterThan(Stylist.clash([piece("A", .top, "red"), piece("B", .bottom, "green")]), 0)
    }

    func testSuggestionsAreWearableUniqueAndRepeatable() {
        let items = [piece("Maglia", .top), piece("Camicia", .top, "white"), piece("Jeans", .bottom, "blue"),
                     piece("Chino", .bottom, "beige"), piece("Scarpe", .shoes, "white"), piece("Giacca", .outerwear, "navy")]
        let a = Stylist.suggestions(items: items, outfits: [], lastWorn: [:], conditions: Conditions(high: 10, low: 4), seed: 42)
        let b = Stylist.suggestions(items: items, outfits: [], lastWorn: [:], conditions: Conditions(high: 10, low: 4), seed: 42)
        XCTAssertFalse(a.isEmpty)
        XCTAssertEqual(a, b)
        XCTAssertEqual(Set(a.map { Set($0.items) }).count, a.count)
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for idea in a {
            XCTAssertTrue(Stylist.wearable(idea.items.compactMap { byID[$0] }))
        }
    }

    func testNothingToSuggestWithoutBottoms() {
        let items = [piece("Maglia", .top), piece("Scarpe", .shoes)]
        XCTAssertTrue(Stylist.suggestions(items: items, outfits: [], lastWorn: [:], conditions: nil, seed: 1).isEmpty)
    }
}

/// Two phones syncing through a real ShadowWear server (started by the workflow; skipped without it).
@MainActor
final class SyncTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDown() async throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
    }

    private func phone(_ name: String) -> (Closet, SyncService) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        roots.append(root)
        let closet = Closet(root: root)
        let defaults = UserDefaults(suiteName: "sync-test-\(name)-\(UUID().uuidString)")!
        return (closet, SyncService(closet: closet, defaults: defaults, keychain: "sync-test-\(name)-\(UUID().uuidString)"))
    }

    private func image(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 40, height: 40)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 40))
        }
    }

    /// A new server: the first sign-in asks for the account, then the app creates it.
    func testTheAppCreatesTheAccountOfANewServer() async throws {
        guard let address = ProcessInfo.processInfo.environment["SW_TEST_NEW_SERVER"] else {
            throw XCTSkip("No new test server")
        }
        let (closet, sync) = phone("new")
        closet.add(Item(name: "Giacca", category: .outerwear))
        do {
            try await sync.connect(address: address, user: "nuovo", password: "password di prova")
            XCTFail("A new server has no account to sign in to")
        } catch SyncService.SyncError.needsAccount {
        }
        XCTAssertFalse(sync.isOn)
        try await sync.connect(address: address, user: "nuovo", password: "password di prova", create: true)
        XCTAssertTrue(sync.isOn)
        XCTAssertNil(sync.error)
        // From now on it is a normal server: a second phone signs in with the same account.
        let (other, otherSync) = phone("other")
        do {
            try await otherSync.connect(address: address, user: "nuovo", password: "sbagliata!!")
            XCTFail("Wrong password")
        } catch SyncService.SyncError.needsAccount {
            XCTFail("The server has an account now")
        } catch {
        }
        try await otherSync.connect(address: address, user: "Nuovo", password: "password di prova")
        XCTAssertEqual(other.items.map(\.name), ["Giacca"])
    }

    /// A phone connected with the code made on the site (as from its QR code), once only.
    func testAPhoneConnectsWithTheCodeOfTheSite() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let address = env["SW_TEST_SERVER"], let password = env["SW_TEST_PASSWORD"] else {
            throw XCTSkip("No test server")
        }
        // The code as the site makes it: sign in, then Collega un dispositivo (one code at a time,
        // so each test makes its own).
        let code = try await siteCode(address, password)
        let qr = try XCTUnwrap(URL(string: "shadowwear://link?server=\(address)&code=\(code)"))
        let link = try XCTUnwrap(SyncService.LinkRequest(qr))
        XCTAssertEqual(link.server, address)
        XCTAssertNil(SyncService.LinkRequest(try XCTUnwrap(URL(string: "shadowwear://link?server=\(address)&code=CORTO"))))
        XCTAssertNil(SyncService.LinkRequest(try XCTUnwrap(URL(string: "https://example.org/link?server=\(address)&code=\(code)"))))

        let (_, sync) = phone("code")
        try await sync.connect(address: link.server, code: link.code)
        XCTAssertTrue(sync.isOn)
        XCTAssertNil(sync.error)
        // The code is used up.
        let (_, again) = phone("again")
        do {
            try await again.connect(address: link.server, code: link.code)
            XCTFail("A code works once")
        } catch {
            XCTAssertFalse(again.isOn)
        }
    }

    private func siteCode(_ address: String, _ password: String) async throws -> String {
        func post(_ path: String, _ body: [String: Any], token: String? = nil) async throws -> [String: Any] {
            var request = URLRequest(url: try XCTUnwrap(URL(string: "\(address)/api/\(path)")))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let login = try await post("login", ["user": "ci", "password": password, "device": "Site test"])
        let token = try XCTUnwrap(login["token"] as? String)
        let link = try await post("link", [:], token: token)
        return try XCTUnwrap(link["code"] as? String)
    }

    /// A phone already connected makes the code (as its QR shows it), another phone uses it.
    func testAConnectedPhoneMakesTheCodeForAnother() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let address = env["SW_TEST_SERVER"], let password = env["SW_TEST_PASSWORD"] else {
            throw XCTSkip("No test server")
        }
        let (_, first) = phone("first")
        try await first.connect(address: address, user: "ci", password: password)
        let made = try await first.makeLink()
        XCTAssertGreaterThan(made.expires, Date().addingTimeInterval(8 * 60))
        let link = try XCTUnwrap(made.url.flatMap(SyncService.LinkRequest.init))
        XCTAssertEqual(link.code, made.code)

        let (_, second) = phone("second")
        try await second.connect(address: link.server, code: link.code)
        XCTAssertTrue(second.isOn)
        // A cancelled code no longer works.
        let cancelled = try await first.makeLink()
        await first.cancelLink()
        let (_, third) = phone("third")
        do {
            try await third.connect(address: address, code: cancelled.code)
            XCTFail("A cancelled code works no more")
        } catch {
            XCTAssertFalse(third.isOn)
        }
    }

    func testTwoPhonesShareTheCloset() async throws {
        let env = ProcessInfo.processInfo.environment
        guard let address = env["SW_TEST_SERVER"], let password = env["SW_TEST_PASSWORD"] else {
            throw XCTSkip("No test server")
        }
        let (a, syncA) = phone("a")
        let (b, syncB) = phone("b")

        let photo = try XCTUnwrap(a.store(ProcessedPhoto(original: image(.red), cutout: image(.blue), colors: ["red"], category: .top)))
        let top = Item(name: "Maglia", category: .top, colors: ["red"], photos: [photo])
        let jeans = Item(name: "Jeans", category: .bottom)
        a.add(top)
        a.add(jeans)
        let outfit = Outfit(name: "Weekend", items: [top.id, jeans.id], occasion: .everyday)
        a.add(outfit)
        a.wear(outfit)
        var wish = Wish(title: "Giacca", link: "https://example.org/giacca")
        wish.price = 89.9
        a.add(wish)

        try await syncA.connect(address: address, user: "ci", password: password)
        XCTAssertNil(syncA.error)
        try await syncB.connect(address: address, user: "CI", password: password)
        XCTAssertNil(syncB.error)
        XCTAssertEqual(Set(b.items.map(\.name)), ["Maglia", "Jeans"])
        XCTAssertEqual(b.outfit(outfit.id)?.name, "Weekend")
        XCTAssertEqual(b.wears.count, 1)
        XCTAssertEqual(b.wish(wish.id)?.price, 89.9)
        XCTAssertTrue(b.hasPhotoFile(photo.id.uuidString + ".jpg"))
        XCTAssertTrue(b.hasPhotoFile(photo.id.uuidString + ".png"))
        XCTAssertNotNil(b.image(of: photo))

        // The second phone renames one piece and deletes the other: the first one follows.
        var renamed = try XCTUnwrap(b.item(top.id))
        renamed.name = "Maglia blu"
        b.update(renamed)
        b.delete(jeans.id)
        await syncB.sync()
        XCTAssertNil(syncB.error)
        await syncA.sync()
        XCTAssertNil(syncA.error)
        XCTAssertEqual(a.item(top.id)?.name, "Maglia blu")
        XCTAssertNil(a.item(jeans.id))
        XCTAssertEqual(a.outfit(outfit.id)?.items, [top.id])
        XCTAssertTrue(a.pendingDeletes.isEmpty)
        XCTAssertTrue(b.pendingDeletes.isEmpty)

        // A day liked on one phone is liked on the other (the entry is replaced, not edited).
        let day = try XCTUnwrap(b.wears.first)
        b.rate(day.id, 1)
        await syncB.sync()
        await syncA.sync()
        XCTAssertEqual(a.wears.count, 1)
        XCTAssertEqual(a.wears.first?.rating, 1)
    }
}

/// The stamps that decide which copy of a piece wins, without a server: what one phone sends goes
/// through the same JSON the server keeps and gives to the other phone.
@MainActor
final class SyncStampTests: XCTestCase {
    private var roots: [URL] = []

    override func tearDown() async throws {
        for root in roots { try? FileManager.default.removeItem(at: root) }
    }

    private func closet() -> Closet {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        roots.append(root)
        return Closet(root: root)
    }

    /// Out of one phone, through the server, into the other.
    private func trip<T: Codable>(_ value: T) throws -> T {
        try Closet.decoder.decode(T.self, from: Closet.encoder.encode(value))
    }

    func testDatesGoToTheServerWithTheirMilliseconds() throws {
        let date = Date(timeIntervalSince1970: 1_763_548_810.345)
        XCTAssertEqual(Closet.isoString(date), "2025-11-19T10:40:10.345Z")
        XCTAssertEqual(Closet.isoString(Date(ms: 5)), "1970-01-01T00:00:00.005Z")
        XCTAssertEqual(Closet.isoDate("2025-11-19T10:40:10.345Z")?.ms, 1_763_548_810_345)
        // Files and servers of before: whole seconds still read.
        XCTAssertEqual(Closet.isoDate("2025-11-19T10:40:10Z")?.ms, 1_763_548_810_000)
        XCTAssertEqual(try trip([date])[0].ms, date.ms)
    }

    func testAStampKeepsItsMillisecondsOnDisk() {
        let here = closet()
        var piece = Item(name: "Maglia", category: .top)
        piece.updated = Date(timeIntervalSince1970: 1_763_548_810.345)
        here.add(piece)
        XCTAssertEqual(Closet(root: here.root).item(piece.id)?.updated.ms, 1_763_548_810_345)
    }

    /// testTwoPhonesShareTheCloset without the server and its timing: phone B renames a piece and
    /// deletes another in the same second phone A made them. With whole-second stamps the rename
    /// looked as old as A's copy and the deletion older than it, so A kept both.
    func testAnEditInTheSameSecondReachesTheOtherPhone() throws {
        let a = closet(), b = closet()
        let top = Item(name: "Maglia", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        a.add(top)
        a.add(jeans)
        let outfit = Outfit(name: "Weekend", items: [top.id, jeans.id], occasion: .everyday)
        a.add(outfit)
        b.applyRemote(items: try trip(a.items), outfits: try trip(a.outfits), wears: [], deleted: [])

        var renamed = try XCTUnwrap(b.item(top.id))
        renamed.name = "Maglia blu"
        b.update(renamed)
        b.delete(jeans.id)
        // What the server compares: B's copies are newer than A's, the deletion is after the jeans.
        let sentTop = try XCTUnwrap(trip(b.items).first { $0.id == top.id })
        let gone = try trip(b.pendingDeletes)
        XCTAssertGreaterThan(sentTop.updated.ms, try trip(a.items)[0].updated.ms)
        XCTAssertGreaterThan(try XCTUnwrap(gone.first).at.ms, try XCTUnwrap(a.item(jeans.id)).updated.ms)

        a.applyRemote(items: [sentTop], outfits: try trip(b.outfits), wears: [], deleted: gone)
        XCTAssertEqual(a.item(top.id)?.name, "Maglia blu")
        XCTAssertNil(a.item(jeans.id))
        XCTAssertEqual(a.outfit(outfit.id)?.items, [top.id])
    }

    /// A phone whose clock is behind still edits and deletes what another phone stamped "later".
    func testAnEditWinsOverTheCopyOfAClockAhead() throws {
        let a = closet(), b = closet()
        var top = Item(name: "Maglia", category: .top)
        top.updated = Date().addingTimeInterval(3600)
        a.add(top)
        b.applyRemote(items: try trip(a.items), outfits: [], wears: [], deleted: [])

        var renamed = try XCTUnwrap(b.item(top.id))
        renamed.name = "Maglia blu"
        b.update(renamed)
        a.applyRemote(items: try trip(b.items), outfits: [], wears: [], deleted: [])
        XCTAssertEqual(a.item(top.id)?.name, "Maglia blu")

        b.delete(top.id)
        a.applyRemote(items: [], outfits: [], wears: [], deleted: try trip(b.pendingDeletes))
        XCTAssertNil(a.item(top.id))
    }

    /// An older copy coming back (a phone that synced late) still loses.
    func testAnOlderCopyNeverWins() throws {
        let a = closet()
        var top = Item(name: "Maglia blu", category: .top)
        top.updated = Date(timeIntervalSince1970: 1_763_548_810.345)
        a.add(top)
        var old = top
        old.name = "Maglia"
        old.updated = Date(timeIntervalSince1970: 1_763_548_810.344)
        a.applyRemote(items: try trip([old]), outfits: [], wears: [], deleted: [])
        XCTAssertEqual(a.item(top.id)?.name, "Maglia blu")
        a.applyRemote(items: [], outfits: [], wears: [],
                      deleted: [Tombstone(kind: "items", id: top.id, at: Date(timeIntervalSince1970: 1_763_548_810.2))])
        XCTAssertNotNil(a.item(top.id))
    }
}

final class CareTests: XCTestCase {
    private func day(_ offset: Int) -> String {
        Day.key(Calendar.current.date(byAdding: .day, value: offset, to: Date())!)
    }

    func testPiecesNeedAWashAfterTheirWears() {
        var top = Item(name: "Maglia", category: .top)
        let shoes = Item(name: "Scarpe", category: .shoes)
        var jeans = Item(name: "Jeans", category: .bottom)
        jeans.washEvery = 1
        let wears = [Wear(day: day(-3), items: [top.id, shoes.id, jeans.id]), Wear(day: day(-1), items: [top.id, shoes.id]),
                     Wear(day: day(-1), items: [top.id])]
        // The same day twice counts once.
        XCTAssertEqual(Care.wearsSinceWash(top, wears: wears), 2)
        XCTAssertTrue(Care.needsWash(top, wears: wears))
        XCTAssertFalse(Care.needsWash(shoes, wears: wears))
        XCTAssertTrue(Care.needsWash(jeans, wears: wears))
        top.washed = Calendar.current.date(byAdding: .day, value: -2, to: Date())
        XCTAssertEqual(Care.wearsSinceWash(top, wears: wears), 1)
        XCTAssertFalse(Care.needsWash(top, wears: wears))
        XCTAssertEqual(Care.laundry([top, shoes, jeans], wears: wears).map(\.name), ["Jeans"])
    }

    func testSeasonsAndTheSwap() throws {
        let july = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 10)))
        XCTAssertEqual(Season.of(july), .summer)
        XCTAssertEqual(Season.of(july, south: true), .winter)
        var coat = Item(name: "Cappotto", category: .outerwear)
        XCTAssertEqual(coat.effectiveSeasons, [.autumn, .winter])
        var linen = Item(name: "Lino", category: .top)
        linen.warmth = .light
        linen.stored = true
        let tee = Item(name: "Maglietta", category: .top)
        let swap = Care.swap([coat, linen, tee], on: july)
        XCTAssertEqual(swap.putAway.map(\.name), ["Cappotto"])
        XCTAssertEqual(swap.bringOut.map(\.name), ["Lino"])
        // Seasons chosen by hand win over the warmth.
        coat.seasons = [.summer]
        XCTAssertTrue(Care.swap([coat], on: july).putAway.isEmpty)
    }

    func testClearOutFindsWhatIsNotWorn() {
        let old = Calendar.current.date(byAdding: .month, value: -10, to: Date())!
        var never = Item(name: "Mai", category: .top)
        never.created = old
        var worn = Item(name: "Messo", category: .top)
        worn.created = old
        var longAgo = Item(name: "Tanto tempo fa", category: .top)
        longAgo.created = old
        let new = Item(name: "Nuovo", category: .top)
        var kept = Item(name: "Tenuto", category: .top)
        kept.created = old
        kept.keepUntil = Calendar.current.date(byAdding: .month, value: 1, to: Date())
        let wears = [Wear(day: day(-5), items: [worn.id]), Wear(day: day(-250), items: [longAgo.id])]
        let list = Care.clearOut([never, worn, longAgo, new, kept], wears: wears, months: 6)
        XCTAssertEqual(list.map(\.item.name), ["Mai", "Tanto tempo fa"])
        XCTAssertEqual(list.last?.times, 1)
    }

    func testStatsAndAffinity() {
        var top = Item(name: "Maglia", category: .top, colors: ["red"])
        top.price = 30
        let jeans = Item(name: "Jeans", category: .bottom, colors: ["blue"])
        let unused = Item(name: "Gonna", category: .bottom, colors: ["black"])
        let wears = [Wear(day: day(-2), items: [top.id, jeans.id], rating: 1),
                     Wear(day: day(-1), items: [top.id], rating: -1),
                     Wear(day: day(0), items: [top.id, jeans.id], rating: 1)]
        XCTAssertEqual(Care.affinity(wears)[top.id], 1)
        XCTAssertEqual(Care.affinity(wears)[jeans.id], 2)
        let stats = Care.stats(items: [top, jeans, unused], outfits: [], wears: wears)
        XCTAssertEqual(stats.daysWritten, 3)
        XCTAssertEqual(stats.wornPieces, 2)
        XCTAssertEqual(stats.neverWorn.map(\.name), ["Gonna"])
        XCTAssertEqual(stats.byCategory.first?.key, "top")
        XCTAssertEqual(stats.mostWorn.first?.item.name, "Maglia")
        XCTAssertEqual(stats.costPerWear.first?.cost, 10)
        XCTAssertEqual(stats.liked.first?.name, "Jeans")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    func testSpendingByMonthIsThePriceInTheMonthAPieceCameIn() {
        var a = Item(name: "A", category: .top)
        a.price = 30
        a.created = date(2026, 11, 3)
        var b = Item(name: "B", category: .top)
        b.price = 20.5
        b.created = date(2026, 11, 20)
        var c = Item(name: "C", category: .top)
        c.price = 100
        c.created = date(2026, 9, 15)
        var free = Item(name: "Regalo", category: .top)
        free.created = date(2026, 10, 15)
        var old = Item(name: "Vecchio", category: .top)
        old.price = 999
        old.created = date(2020, 10, 15)
        let months = Care.spending([a, b, c, free, old], months: 3, today: date(2026, 11, 21))
        XCTAssertEqual(months.map(\.month), ["2026-09", "2026-10", "2026-11"])
        XCTAssertEqual(months.map(\.total), [100, 0, 50.5])
        XCTAssertEqual(months.map(\.pieces), [1, 0, 2])
        XCTAssertEqual(Care.spending([], today: date(2026, 1, 31)).count, 12)
        XCTAssertEqual(Care.spending([], today: date(2026, 1, 31)).first?.month, "2025-02")
    }

    func testPiecesNeverWornAfterTwoMonthsTheDearestFirst() {
        let today = date(2026, 11, 21)
        var cheap = Item(name: "Economico", category: .top)
        cheap.price = 30
        cheap.created = date(2026, 6, 1)
        var dear = Item(name: "Caro", category: .outerwear)
        dear.price = 180
        dear.created = date(2026, 8, 1)
        var worn = Item(name: "Messo", category: .top)
        worn.created = date(2026, 6, 1)
        var new = Item(name: "Nuovo", category: .top)
        new.created = date(2026, 11, 1)
        let idle = Care.idle([cheap, dear, worn, new], wears: [Wear(day: "2026-07-01", items: [worn.id])], today: today)
        XCTAssertEqual(idle.map(\.name), ["Caro", "Economico"])
    }

    func testTheYearInAFewNumbers() {
        var shirt = Item(name: "Camicia", category: .top, colors: ["white"])
        shirt.price = 40
        shirt.created = date(2026, 3, 1)
        var jeans = Item(name: "Jeans", category: .bottom, colors: ["blue"])
        jeans.price = 90
        jeans.created = date(2025, 3, 1)
        let office = Outfit(name: "Ufficio", items: [shirt.id, jeans.id])
        let wears = [Wear(day: "2026-10-01", outfit: office.id, items: [shirt.id, jeans.id]),
                     Wear(day: "2026-10-02", outfit: office.id, items: [shirt.id, jeans.id]),
                     Wear(day: "2026-11-01", items: [shirt.id]),
                     Wear(day: "2025-11-01", items: [jeans.id])]
        XCTAssertEqual(Care.recapYears(wears), [2026, 2025])
        let year = Care.yearRecap(items: [shirt, jeans], outfits: [office], wears: wears, year: 2026)
        XCTAssertEqual(year.days, 3)
        XCTAssertEqual(year.wornPieces, 2)
        XCTAssertEqual(year.pieces, 2)
        XCTAssertEqual(year.mostWorn.map(\.item.name), ["Camicia", "Jeans"])
        XCTAssertEqual(year.mostWorn.map(\.times), [3, 2])
        XCTAssertEqual(year.colors.map(\.key), ["white", "blue"])
        XCTAssertEqual(year.topOutfit?.outfit.id, office.id)
        XCTAssertEqual(year.topOutfit?.times, 2)
        XCTAssertEqual(year.added, 1)
        XCTAssertEqual(year.spent, 40)
        XCTAssertEqual(year.best?.item.name, "Camicia")
        XCTAssertEqual(year.best?.cost ?? 0, 40.0 / 3, accuracy: 0.0001)
        XCTAssertEqual(Care.yearRecap(items: [shirt, jeans], outfits: [office], wears: wears, year: 2024).days, 0)
    }

    func testTheStylistLeavesDirtyPiecesAside() {
        let clean = Item(name: "Pulita", category: .top)
        let dirty = Item(name: "Sporca", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        let taste = Taste(dirty: [dirty.id], affinity: [:])
        let a = Stylist.score(clean, lastWorn: [:], today: Date(), conditions: nil, taste: taste)
        let b = Stylist.score(dirty, lastWorn: [:], today: Date(), conditions: nil, taste: taste)
        XCTAssertGreaterThan(a, b)
        let pairs = Stylist.pairings(for: jeans, items: [clean, dirty, jeans], lastWorn: [:], conditions: nil, taste: taste)
        XCTAssertFalse(pairs.isEmpty)
        XCTAssertTrue(pairs.allSatisfy { $0.first == jeans.id && $0.count >= 2 })
    }

    func testNewFieldsSurviveAndOldFilesDecode() throws {
        var item = Item(name: "Giacca", category: .outerwear)
        item.material = "Lana"
        item.seasons = [.autumn, .winter]
        item.formality = .smart
        item.price = 120
        item.stored = true
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let back = try Closet.decoder.decode(Item.self, from: encoder.encode(item))
        XCTAssertEqual(back.material, "Lana")
        XCTAssertEqual(back.seasons, [.autumn, .winter])
        XCTAssertEqual(back.formality, .smart)
        XCTAssertEqual(back.price, 120)
        XCTAssertTrue(back.stored)
        // A season or a formality from a newer version is skipped, not the piece.
        let json = #"{"id":"6A9D6F1C-2E1B-4C55-9C4B-6C0F9D1E2A11","name":"X","category":"top","seasons":["summer","monsoon"],"formality":"cosmic"}"#
        let odd = try Closet.decoder.decode(Item.self, from: Data(json.utf8))
        XCTAssertEqual(odd.seasons, [.summer])
        XCTAssertNil(odd.formality)
    }
}

final class PackerTests: XCTestCase {
    private func trip(nights: Int, high: Double, rain: Int = 0, occasions: [Occasion] = [.everyday]) -> TripPlan {
        var trip = TripPlan(place: Place(name: "Lisbona", latitude: 38.7, longitude: -9.1), start: Date(), nights: nights, occasions: occasions)
        trip.days = (0...nights).map { TripPlan.Day(day: "2026-12-0\($0 + 1)", high: high, low: high - 8, rain: rain) }
        return trip
    }

    func testCountsFollowLengthAndWeather() {
        let items = [Item(name: "T", category: .top), Item(name: "B", category: .bottom), Item(name: "C", category: .outerwear),
                     Item(name: "S", category: .shoes)]
        let hot = Packer.counts(days: 4, conditions: trip(nights: 3, high: 32).days.compactMap(\.conditions), occasions: [.everyday], items: items)
        XCTAssertEqual(hot[.top], 4)
        XCTAssertEqual(hot[.bottom], 2)
        XCTAssertNil(hot[.outerwear])
        let cold = Packer.counts(days: 12, conditions: trip(nights: 11, high: 5).days.compactMap(\.conditions), occasions: [.everyday, .sport], items: items)
        XCTAssertEqual(cold[.outerwear], 1)
        XCTAssertEqual(cold[.shoes], 2)
        // More than a week: a wash on the way, not twelve T-shirts.
        XCTAssertLessThanOrEqual(cold[.top] ?? 0, 9)
    }

    func testThePlanPicksPiecesForTheWeather() {
        var light = Item(name: "Lino", category: .top)
        light.warmth = .light
        var warm = Item(name: "Lana", category: .top)
        warm.warmth = .warm
        let jeans = Item(name: "Jeans", category: .bottom)
        let plan = Packer.plan(items: [warm, light, jeans], trip: trip(nights: 0, high: 33))
        XCTAssertEqual(plan.first { $0.category == .top }?.items.first, light.id)
        XCTAssertTrue(Packer.reminders(trip: trip(nights: 2, high: 33, rain: 80)).contains { $0.contains("Ombrello") || $0.contains("Umbrella") })
    }
    func testASuitcasePackedByHandHasOnlyWhatWasChosen() {
        let top = Item(name: "Maglia", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        let other = Item(name: "Ombrello", category: .other)
        let shoes = Item(name: "Scarpe", category: .shoes)
        var made = trip(nights: 3, high: 10)
        made.manual = true
        XCTAssertTrue(Packer.lines(items: [top, jeans, other, shoes], trip: made).isEmpty)
        made.chosen = [jeans.id, other.id]
        let lines = Packer.lines(items: [top, jeans, other, shoes], trip: made)
        XCTAssertEqual(lines.map(\.category), [.bottom, .other])
        XCTAssertEqual(lines.map(\.count), [1, 1])
        XCTAssertFalse(lines.contains(where: \.short))
        // Made by the app: the kinds the trip calls for show even when empty, with what is missing.
        made.manual = false
        let auto = Packer.lines(items: [top, jeans, other, shoes], trip: made)
        XCTAssertEqual(auto.first?.category, .top)
        XCTAssertTrue(auto.first?.short ?? false)
        XCTAssertTrue(auto.contains { $0.category == .other })
    }

    func testATripToTheSnowTakesAllTheSkiGear() {
        let top = Item(name: "Maglia", category: .top)
        let jeans = Item(name: "Jeans", category: .bottom)
        let goggles = Item(name: "Maschera", category: .ski)
        let helmet = Item(name: "Casco", category: .ski)
        let items = [top, jeans, goggles, helmet]
        var made = trip(nights: 3, high: 0)
        // Not to the snow: the ski gear stays home.
        XCTAssertFalse(Packer.plan(items: items, trip: made).contains { $0.category == .ski })
        XCTAssertFalse(Packer.reminders(trip: made).contains { $0.contains("Skipass") || $0.contains("Ski pass") })
        made.ski = true
        let plan = Packer.plan(items: items, trip: made)
        XCTAssertEqual(plan.first?.category, .ski)
        XCTAssertEqual(Set(plan.first?.items ?? []), [goggles.id, helmet.id])
        XCTAssertTrue(Packer.reminders(trip: made).contains { $0.contains("Skipass") || $0.contains("Ski pass") })
        // One piece taken out: the line shows what is left, and nothing is missing.
        made.chosen = plan.flatMap(\.items).filter { $0 != helmet.id }
        let line = Packer.lines(items: items, trip: made).first { $0.category == .ski }
        XCTAssertEqual(line?.items, [goggles.id])
        XCTAssertFalse(line?.short ?? true)
        // It is saved with the suitcase.
        let encoder = JSONEncoder(), decoder = JSONDecoder()
        XCTAssertTrue((try? decoder.decode(TripPlan.self, from: encoder.encode(made)))?.ski ?? false)
        XCTAssertTrue(made.occasionNames.count == 2)
    }

    func testTheSkiGearIsKeptApartFromTheEverydayCloset() {
        let long = Date().addingTimeInterval(-400 * 86_400)
        var suit = Item(name: "Tuta da sci", category: .ski)
        suit.created = long
        var tee = Item(name: "Maglia", category: .top)
        tee.created = long
        var jeans = Item(name: "Jeans", category: .bottom)
        jeans.created = long
        let items = [suit, tee, jeans]
        XCTAssertTrue(Category.ski.apart)
        XCTAssertEqual(Category.guess(from: [("ski_goggles", 0.6)]), .ski)
        // The grids: no kind is the everyday closet, the kind shows the gear.
        XCTAssertEqual(items.filter { Category?.none.shows($0) }.map(\.id), [tee.id, jeans.id])
        XCTAssertEqual(items.filter { Category?.some(.ski).shows($0) }.map(\.id), [suit.id])
        // Never worn for a year, but it is not asked to leave the closet.
        XCTAssertFalse(Care.clearOut(items, wears: [], months: 6).contains { $0.item.id == suit.id })
        XCTAssertFalse(Care.idle(items, wears: []).contains { $0.id == suit.id })
        XCTAssertTrue(Care.idle(items, wears: []).contains { $0.id == tee.id })
        XCTAssertNil(Care.washEvery(suit))
        // Neither the season nor the ideas of the day touch it.
        let july = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 15)) ?? Date()
        suit.seasons = [.winter]
        XCTAssertFalse(Care.swap([suit, tee, jeans], on: july).putAway.contains { $0.id == suit.id })
        let ideas = Stylist.suggestions(items: items, outfits: [], lastWorn: [:], conditions: nil, seed: 7)
        XCTAssertFalse(ideas.contains { $0.items.contains(suit.id) })
    }

    func testAnOlderSuitcaseStillOpensAndTheNewOneKeepsItsOccasions() throws {
        let old = #"{"place":{"name":"Lisbona","latitude":38.7,"longitude":-9.1},"start":"2026-12-01T10:00:00Z","nights":2,"occasions":["everyday","nuova"],"days":[],"packed":[],"chosen":[],"tips":""}"#
        let read = try Closet.decoder.decode(TripPlan.self, from: Data(old.utf8))
        XCTAssertFalse(read.manual)
        XCTAssertEqual(read.occasions, [.everyday])
        XCTAssertEqual(read.otherOccasions, [])
        var trip = read
        trip.manual = true
        trip.otherOccasions = ["Serata romantica"]
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let back = try Closet.decoder.decode(TripPlan.self, from: encoder.encode(trip))
        XCTAssertTrue(back.manual)
        XCTAssertEqual(back.occasionNames.last, "Serata romantica")
        XCTAssertEqual(back.nights, 2)
    }
}

final class LinkPreviewTests: XCTestCase {
    func testOpenGraphAndProductTags() throws {
        let html = """
        <html><head><title>Ignored</title>
        <meta property="og:title" content="Giacca di lana &amp; cashmere">
        <meta property='og:image' content='/img/giacca.jpg'>
        <meta property="product:price:amount" content="1.299,00">
        <meta property="product:price:currency" content="eur">
        </head></html>
        """
        let preview = LinkPreview.parse(html, base: try XCTUnwrap(URL(string: "https://shop.example.org/p/1")))
        XCTAssertEqual(preview.title, "Giacca di lana & cashmere")
        XCTAssertEqual(preview.image, "https://shop.example.org/img/giacca.jpg")
        XCTAssertEqual(preview.price, 1299)
        XCTAssertEqual(preview.currency, "EUR")
    }

    func testJSONLDPriceAndTitleFallback() throws {
        let html = #"<title> Stivaletti </title><script type="application/ld+json">{"offers":{"price":"119.90","priceCurrency":"EUR"}}</script>"#
        let preview = LinkPreview.parse(html, base: try XCTUnwrap(URL(string: "https://example.org")))
        XCTAssertEqual(preview.title, "Stivaletti")
        XCTAssertEqual(preview.price, 119.9)
        XCTAssertEqual(preview.currency, "EUR")
    }

    func testNumbers() {
        XCTAssertEqual(LinkPreview.number("49,90"), 49.9)
        XCTAssertEqual(LinkPreview.number("49.9"), 49.9)
        XCTAssertEqual(LinkPreview.number("1,299.00"), 1299)
        XCTAssertEqual(LinkPreview.number("1.299"), 1299)
        XCTAssertEqual(LinkPreview.number("€ 89"), 89)
        XCTAssertNil(LinkPreview.number("gratis"))
    }
}

final class AITests: XCTestCase {
    func testTheJSONOfTheAIIsReadEvenWhenMessy() {
        XCTAssertEqual(AIJSON.numbers("Ecco: ```json\n{\"pieces\": [2, \"3\", 4.0]}\n```", key: "pieces"), [2, 3, 4])
        XCTAssertNil(AIJSON.object("nessun JSON"))
    }

    func testADescriptionKeepsOnlyWhatTheAppKnows() {
        let json: [String: Any] = ["name": "Felpa grigia", "category": "TOP", "colors": ["grey", "magenta", "Black"],
                                   "warmth": "warm", "material": "Cotone", "pattern": "Tinta unita", "formality": "casual",
                                   "seasons": ["autumn", "Fall", "winter", "monsoon"], "notes": "Con i jeans."]
        let description = AIDescription(json: json)
        XCTAssertEqual(description.category, .top)
        XCTAssertEqual(description.colors, ["grey", "black"])
        XCTAssertEqual(description.warmth, 2)
        XCTAssertEqual(description.seasons, [.autumn, .winter])
        var item = Item(name: "", category: .other)
        item.notes = "Mie note"
        description.apply(to: &item)
        XCTAssertEqual(item.name, "Felpa grigia")
        XCTAssertEqual(item.material, "Cotone")
        XCTAssertEqual(item.formality, .casual)
        XCTAssertEqual(item.warmth, .warm)
        XCTAssertEqual(item.notes, "Mie note")
    }

    func testTheCustomAddressGetsItsVersionPath() {
        XCTAssertEqual(AIService.base("192.168.1.10:11434")?.absoluteString, "http://192.168.1.10:11434/v1")
        XCTAssertEqual(AIService.base("https://api.openai.com/v1")?.absoluteString, "https://api.openai.com/v1")
        XCTAssertNil(AIService.base(""))
    }

    func testTheStylistNamesThePiecesItMentions() {
        let a = Item(name: "Maglia", category: .top)
        let b = Item(name: "Jeans", category: .bottom)
        XCTAssertEqual(StylistChatView.mentioned("Metti [2] con [1], e ancora [2]. [9] no.", in: [a, b]).map(\.name), ["Jeans", "Maglia"])
        XCTAssertEqual(StylistChatView.readable("Metti [2] con la Maglia [1].", pieces: [a, b]), "Metti (Jeans) con la Maglia.")
    }
}

/// The looks of Settings → Look: each one must be readable, whatever its colors.
final class LookTests: XCTestCase {
    /// The contrast of two colors as WCAG counts it, from 1 (the same) to 21 (black on white).
    private func contrast(_ a: Color, _ b: Color) -> Double {
        func luminance(_ color: Color) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &alpha)
            func linear(_ c: CGFloat) -> Double {
                let c = Double(c)
                return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        let (x, y) = (luminance(a), luminance(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }

    func testEveryLookIsReadable() {
        XCTAssertEqual(Set(Palette.all.map(\.id)).count, Palette.all.count)
        for look in Palette.all {
            XCTAssertGreaterThanOrEqual(contrast(look.text, look.panel), 7, look.id)
            XCTAssertGreaterThanOrEqual(contrast(look.text, look.bg), 7, look.id)
            XCTAssertGreaterThanOrEqual(contrast(look.sub, look.panel), 4.5, look.id)
            XCTAssertGreaterThanOrEqual(contrast(look.onAccent, look.accent), 4.5, look.id)
            XCTAssertGreaterThanOrEqual(contrast(look.accent, look.panel), 4.5, look.id)
            for signal in [look.good, look.bad, look.warn] {
                XCTAssertGreaterThanOrEqual(contrast(signal, look.panel), 4.5, look.id)
            }
        }
    }

    func testAnUnknownLookIsTheFirstOne() {
        XCTAssertEqual(Palette.named(nil).id, "power")
        XCTAssertEqual(Palette.named("what").id, "power")
        XCTAssertEqual(Palette.named("carta").id, "carta")
    }
}
