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
        let pixels = Array(repeating: (red: 20.0, green: 20.0, blue: 22.0), count: 70)
            + Array(repeating: (red: 245.0, green: 245.0, blue: 240.0), count: 25)
            + Array(repeating: (red: 204.0, green: 38.0, blue: 44.0), count: 5)
        XCTAssertEqual(PaletteColor.dominant(pixels: pixels), ["black", "white"])
    }

    func testDominantColorAlwaysReturnsTheBiggest() {
        let pixels = (0..<20).map { i in (red: Double(i * 12), green: Double(255 - i * 12), blue: Double(i * 6)) }
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
