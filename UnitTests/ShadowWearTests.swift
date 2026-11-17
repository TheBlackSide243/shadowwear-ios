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
        guard let address = env["SW_TEST_SERVER"], let code = env["SW_TEST_LINK_CODE"] else {
            throw XCTSkip("No code from the test server")
        }
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

        try await syncA.connect(address: address, user: "ci", password: password)
        XCTAssertNil(syncA.error)
        try await syncB.connect(address: address, user: "CI", password: password)
        XCTAssertNil(syncB.error)
        XCTAssertEqual(Set(b.items.map(\.name)), ["Maglia", "Jeans"])
        XCTAssertEqual(b.outfit(outfit.id)?.name, "Weekend")
        XCTAssertEqual(b.wears.count, 1)
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
    }
}
