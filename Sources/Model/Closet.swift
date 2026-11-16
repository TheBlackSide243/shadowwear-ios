import Observation
import UIKit

/// The closet on this device: Documents/Armadio/items.json, outfits.json, diario.json and the
/// photos in Documents/Armadio/Foto, also visible in the Files app. Written on every change.
@MainActor
@Observable
final class Closet {
    private(set) var items: [Item] = []
    private(set) var outfits: [Outfit] = []
    /// What was worn, a day at a time (several entries on the same day are allowed).
    private(set) var wears: [Wear] = []
    /// The last thing that went wrong while reading or writing, for the error banner.
    var error: String?

    let root: URL
    private var photos: URL { root.appendingPathComponent("Foto", isDirectory: true) }
    private var file: URL { root.appendingPathComponent("items.json") }
    private var outfitsFile: URL { root.appendingPathComponent("outfits.json") }
    private var wearsFile: URL { root.appendingPathComponent("diario.json") }
    private let cache = NSCache<NSString, UIImage>()

    nonisolated static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Armadio", isDirectory: true)
    }

    init(root: URL = Closet.defaultRoot) {
        self.root = root
        try? FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        load()
    }

    // MARK: Items

    func item(_ id: Item.ID) -> Item? { items.first { $0.id == id } }

    func add(_ item: Item) {
        items.append(item)
        save()
    }

    func update(_ item: Item) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return add(item) }
        var changed = item
        changed.updated = Date()
        // Photos the edit dropped leave the disk with it.
        let kept = Set(changed.photos.map(\.id))
        for photo in items[i].photos where !kept.contains(photo.id) { deleteFiles(of: photo) }
        items[i] = changed
        save()
    }

    func delete(_ id: Item.ID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        for photo in items[i].photos { deleteFiles(of: photo) }
        items.remove(at: i)
        save()
        // Outfits lose the piece; the diary keeps its id (the day shows the pieces still there).
        if outfits.contains(where: { $0.items.contains(id) }) {
            for j in outfits.indices { outfits[j].items.removeAll { $0 == id } }
            saveOutfits()
        }
    }

    func toggleFavorite(_ id: Item.ID) {
        guard var item = item(id) else { return }
        item.favorite.toggle()
        update(item)
    }

    // MARK: Outfits

    func outfit(_ id: Outfit.ID) -> Outfit? { outfits.first { $0.id == id } }

    func add(_ outfit: Outfit) {
        outfits.append(outfit)
        saveOutfits()
    }

    func update(_ outfit: Outfit) {
        guard let i = outfits.firstIndex(where: { $0.id == outfit.id }) else { return add(outfit) }
        var changed = outfit
        changed.updated = Date()
        outfits[i] = changed
        saveOutfits()
    }

    func deleteOutfit(_ id: Outfit.ID) {
        outfits.removeAll { $0.id == id }
        saveOutfits()
    }

    func toggleFavoriteOutfit(_ id: Outfit.ID) {
        guard var outfit = outfit(id) else { return }
        outfit.favorite.toggle()
        update(outfit)
    }

    /// The pieces of an outfit that are still in the closet, in its order.
    func pieces(of outfit: Outfit) -> [Item] { outfit.items.compactMap(item) }

    // MARK: Diary

    /// Writes down that these pieces (or this outfit) were worn on that day.
    @discardableResult
    func wear(_ itemIDs: [Item.ID], outfit: Outfit.ID? = nil, on date: Date = Date()) -> Wear {
        let entry = Wear(day: Day.key(date), outfit: outfit, items: itemIDs)
        wears.append(entry)
        saveWears()
        return entry
    }

    func wear(_ outfit: Outfit, on date: Date = Date()) {
        wear(outfit.items, outfit: outfit.id, on: date)
    }

    func removeWear(_ id: Wear.ID) {
        wears.removeAll { $0.id == id }
        saveWears()
    }

    func wears(on day: String) -> [Wear] { wears.filter { $0.day == day } }

    /// Days a piece was worn, newest first, each day once.
    func days(worn id: Item.ID) -> [String] {
        Array(Set(wears.filter { $0.items.contains(id) }.map(\.day))).sorted(by: >)
    }

    func days(wornOutfit id: Outfit.ID) -> [String] {
        Array(Set(wears.filter { $0.outfit == id }.map(\.day))).sorted(by: >)
    }

    /// The last day each piece was worn, for the suggestions.
    var lastWorn: [Item.ID: String] {
        var last: [Item.ID: String] = [:]
        for entry in wears {
            for id in entry.items where (last[id] ?? "") < entry.day { last[id] = entry.day }
        }
        return last
    }

    // MARK: Files

    private func load() {
        items = read([Item].self, from: file, what: String(localized: "L'armadio salvato")) ?? []
        outfits = read([Outfit].self, from: outfitsFile, what: String(localized: "Gli outfit salvati")) ?? []
        wears = read([Wear].self, from: wearsFile, what: String(localized: "Il diario salvato")) ?? []
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL, what: String) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: Data(contentsOf: url))
        } catch {
            // Keep the unreadable file aside instead of writing over it on the next save.
            let base = url.deletingPathExtension().lastPathComponent
            let aside = root.appendingPathComponent("\(base)-illeggibile-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            self.error = String(localized: "\(what) non si leggeva: l'ho messo da parte in \(aside.lastPathComponent).")
            return nil
        }
    }

    private func save() { write(items, to: file) }
    private func saveOutfits() { write(outfits, to: outfitsFile) }
    private func saveWears() { write(wears, to: wearsFile) }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(value).write(to: url, options: .atomic)
        } catch {
            self.error = String(localized: "Non riesco a salvare l'armadio: \(error.localizedDescription)")
        }
    }

    // MARK: Photos

    /// Writes a processed photo to disk and returns it, to put in an item.
    func store(_ processed: ProcessedPhoto) -> Photo? {
        let photo = Photo(hasCutout: processed.cutout != nil)
        do {
            guard let jpeg = processed.original.jpegData(compressionQuality: 0.85) else { return nil }
            try jpeg.write(to: url(of: photo, cutout: false), options: .atomic)
            if let cutout = processed.cutout, let png = cutout.pngData() {
                try png.write(to: url(of: photo, cutout: true), options: .atomic)
            }
            return photo
        } catch {
            self.error = String(localized: "Non riesco a salvare la foto: \(error.localizedDescription)")
            deleteFiles(of: photo)
            return nil
        }
    }

    /// Adds a cut-out to a photo that has none yet (made later with Remove background).
    func storeCutout(_ image: UIImage, for photo: Photo) -> Photo? {
        guard let png = image.pngData() else { return nil }
        do {
            try png.write(to: url(of: photo, cutout: true), options: .atomic)
            invalidate(photo)
            var changed = photo
            changed.hasCutout = true
            changed.showCutout = true
            return changed
        } catch {
            self.error = String(localized: "Non riesco a salvare la foto: \(error.localizedDescription)")
            return nil
        }
    }

    /// The photo as shown: without background when it has one and should show it.
    func image(of photo: Photo, thumbnail: Bool = false) -> UIImage? {
        let cutout = photo.usesCutout
        let key = "\(photo.id.uuidString)-\(cutout)-\(thumbnail)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let full = UIImage(contentsOfFile: url(of: photo, cutout: cutout).path) else { return nil }
        let image = thumbnail ? Self.thumbnail(full, side: 480) : full
        cache.setObject(image, forKey: key)
        return image
    }

    /// The photo as it was taken, for redoing the cut-out.
    func original(of photo: Photo) -> UIImage? {
        UIImage(contentsOfFile: url(of: photo, cutout: false).path)
    }

    /// Files of photos that were stored but never made it into an item (an import that was cancelled).
    func discard(_ photos: [Photo]) {
        for photo in photos { deleteFiles(of: photo) }
    }

    /// Bytes used by the closet's folder.
    func diskUsage() -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey]
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let url as URL in files {
            total += Int64((try? url.resourceValues(forKeys: Set(keys)).fileSize) ?? 0)
        }
        return total
    }

    var photoCount: Int { items.reduce(0) { $0 + $1.photos.count } }

    private func url(of photo: Photo, cutout: Bool) -> URL {
        photos.appendingPathComponent(photo.id.uuidString + (cutout ? ".png" : ".jpg"))
    }

    private func deleteFiles(of photo: Photo) {
        try? FileManager.default.removeItem(at: url(of: photo, cutout: false))
        try? FileManager.default.removeItem(at: url(of: photo, cutout: true))
        invalidate(photo)
    }

    private func invalidate(_ photo: Photo) {
        for cutout in [true, false] {
            for thumb in [true, false] {
                cache.removeObject(forKey: "\(photo.id.uuidString)-\(cutout)-\(thumb)" as NSString)
            }
        }
    }

    static func thumbnail(_ image: UIImage, side: CGFloat) -> UIImage {
        let scale = min(1, side / max(image.size.width, image.size.height, 1))
        guard scale < 1 else { return image }
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
