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
    /// Things to buy (Cosa comprare).
    private(set) var wishes: [Wish] = []
    /// The last thing that went wrong while reading or writing, for the error banner.
    var error: String?
    /// Deleted here and not yet told to the server.
    private(set) var pendingDeletes: [Tombstone] = []
    /// Photo files changed here (a new cut-out) that must go up again even if the server has them.
    private(set) var pendingPhotos: Set<String> = []
    /// Called after every change made on this device (not for changes that came from the server).
    @ObservationIgnored var onLocalChange: (() -> Void)?
    @ObservationIgnored private var applyingRemote = false

    let root: URL
    private var photos: URL { root.appendingPathComponent("Foto", isDirectory: true) }
    private var file: URL { root.appendingPathComponent("items.json") }
    private var outfitsFile: URL { root.appendingPathComponent("outfits.json") }
    private var wearsFile: URL { root.appendingPathComponent("diario.json") }
    private var wishesFile: URL { root.appendingPathComponent("desideri.json") }
    /// Hidden from the Files app (dot file): what is still to send to the server.
    private var syncFile: URL { root.appendingPathComponent(".sync.json") }
    private let cache = NSCache<NSString, UIImage>()

    nonisolated static var defaultRoot: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Armadio", isDirectory: true)
    }

    init(root: URL = Closet.defaultRoot) {
        self.root = root
        try? FileManager.default.createDirectory(at: photos, withIntermediateDirectories: true)
        load()
        loadSync()
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
        remember(.init(kind: "items", id: id, at: Date()))
        save()
        // Outfits lose the piece; the diary keeps its id (the day shows the pieces still there).
        if outfits.contains(where: { $0.items.contains(id) }) {
            for j in outfits.indices where outfits[j].items.contains(id) {
                outfits[j].items.removeAll { $0 == id }
                outfits[j].updated = Date()
            }
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
        remember(.init(kind: "outfits", id: id, at: Date()))
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
        remember(.init(kind: "wears", id: id, at: Date()))
        saveWears()
    }

    func wears(on day: String) -> [Wear] { wears.filter { $0.day == day } }

    /// Liked or not liked. Diary entries never change on the server, so the entry is replaced by a
    /// new one with the same day and pieces.
    func rate(_ id: Wear.ID, _ rating: Int?) {
        guard let i = wears.firstIndex(where: { $0.id == id }), wears[i].rating != rating else { return }
        let old = wears[i]
        wears[i] = Wear(day: old.day, outfit: old.outfit, items: old.items, rating: rating)
        remember(.init(kind: "wears", id: old.id, at: Date()))
        saveWears()
    }

    // MARK: Care

    /// Washed today: the count of wears starts again.
    func markWashed(_ ids: [Item.ID], on date: Date = Date()) {
        var touched = false
        for id in ids {
            guard let i = items.firstIndex(where: { $0.id == id }) else { continue }
            items[i].washed = date
            items[i].updated = Date()
            touched = true
        }
        if touched { save() }
    }

    /// Put away for the season, or brought out again.
    func setStored(_ ids: [Item.ID], _ stored: Bool) {
        var touched = false
        for id in ids {
            guard let i = items.firstIndex(where: { $0.id == id }), items[i].stored != stored else { continue }
            items[i].stored = stored
            items[i].updated = Date()
            touched = true
        }
        if touched { save() }
    }

    /// Kept in the clear-out: not proposed again for a while.
    func keep(_ id: Item.ID, until date: Date) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].keepUntil = date
        items[i].updated = Date()
        save()
    }

    /// The days each piece was worn after its last wash.
    func wearsSinceWash(_ item: Item) -> Int { Care.wearsSinceWash(item, wears: wears) }

    /// The pieces to wash now.
    var laundry: [Item] { Care.laundry(items, wears: wears) }

    // MARK: Wishes

    func wish(_ id: Wish.ID) -> Wish? { wishes.first { $0.id == id } }

    func add(_ wish: Wish) {
        wishes.append(wish)
        saveWishes()
    }

    func update(_ wish: Wish) {
        guard let i = wishes.firstIndex(where: { $0.id == wish.id }) else { return add(wish) }
        var changed = wish
        changed.updated = Date()
        wishes[i] = changed
        saveWishes()
    }

    func deleteWish(_ id: Wish.ID) {
        wishes.removeAll { $0.id == id }
        remember(.init(kind: "wishes", id: id, at: Date()))
        saveWishes()
    }

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
        wishes = read([Wish].self, from: wishesFile, what: String(localized: "La lista di cose da comprare")) ?? []
    }

    private func read<T: Decodable>(_ type: T.Type, from url: URL, what: String) -> T? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            return try Self.decoder.decode(type, from: Data(contentsOf: url))
        } catch {
            // Keep the unreadable file aside instead of writing over it on the next save.
            let base = url.deletingPathExtension().lastPathComponent
            let aside = root.appendingPathComponent("\(base)-illeggibile-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            self.error = String(localized: "\(what) non si leggeva: l'ho messo da parte in \(aside.lastPathComponent).")
            return nil
        }
    }

    /// Dates as ISO 8601, with or without fractional seconds (the web site and the server may add them).
    nonisolated static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { from in
            let container = try from.singleValueContainer()
            let text = try container.decode(String.self)
            if let date = isoDate(text) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not an ISO 8601 date: \(text)")
        }
        return decoder
    }

    nonisolated static func isoDate(_ text: String) -> Date? {
        let plain = ISO8601DateFormatter()
        if let date = plain.date(from: text) { return date }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text)
    }

    private func save() {
        write(items, to: file)
        changed()
    }

    private func saveOutfits() {
        write(outfits, to: outfitsFile)
        changed()
    }

    private func saveWears() {
        write(wears, to: wearsFile)
        changed()
    }

    private func saveWishes() {
        write(wishes, to: wishesFile)
        changed()
    }

    private func changed() {
        if !applyingRemote { onLocalChange?() }
    }

    // MARK: Sync

    private struct SyncState: Codable {
        var deletes: [Tombstone] = []
        var photos: [String] = []
    }

    private func remember(_ tombstone: Tombstone) {
        guard !applyingRemote else { return }
        pendingDeletes.append(tombstone)
        // Old ones the server never got (no server, for months) are dropped.
        if pendingDeletes.count > 2000 { pendingDeletes.removeFirst(pendingDeletes.count - 2000) }
        saveSync()
    }

    func clearPendingDeletes(_ sent: [Tombstone]) {
        let gone = Set(sent)
        pendingDeletes.removeAll { gone.contains($0) }
        saveSync()
    }

    private func loadSync() {
        guard let data = try? Data(contentsOf: syncFile), let state = try? Self.decoder.decode(SyncState.self, from: data) else { return }
        pendingDeletes = state.deletes
        pendingPhotos = Set(state.photos)
    }

    private func saveSync() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try? encoder.encode(SyncState(deletes: pendingDeletes, photos: Array(pendingPhotos))).write(to: syncFile, options: .atomic)
    }

    /// Records from the server: newer ones replace these, deletions are carried out. No tombstones
    /// and no new sync come out of this.
    func applyRemote(items remoteItems: [Item], outfits remoteOutfits: [Outfit], wears remoteWears: [Wear],
                     wishes remoteWishes: [Wish] = [], deleted: [Tombstone]) {
        applyingRemote = true
        defer { applyingRemote = false }
        var touchedItems = false, touchedOutfits = false, touchedWears = false, touchedWishes = false
        for gone in deleted {
            switch gone.kind {
            case "items":
                if let i = items.firstIndex(where: { $0.id == gone.id }), items[i].updated <= gone.at {
                    for photo in items[i].photos { deleteFiles(of: photo) }
                    items.remove(at: i)
                    touchedItems = true
                }
            case "outfits":
                if let i = outfits.firstIndex(where: { $0.id == gone.id }), outfits[i].updated <= gone.at {
                    outfits.remove(at: i)
                    touchedOutfits = true
                }
            case "wears":
                if let i = wears.firstIndex(where: { $0.id == gone.id }) {
                    wears.remove(at: i)
                    touchedWears = true
                }
            case "wishes":
                if let i = wishes.firstIndex(where: { $0.id == gone.id }), wishes[i].updated <= gone.at {
                    wishes.remove(at: i)
                    touchedWishes = true
                }
            default: break
            }
        }
        for item in remoteItems {
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                guard item.updated > items[i].updated else { continue }
                let kept = Set(item.photos.map(\.id))
                for photo in items[i].photos where !kept.contains(photo.id) { deleteFiles(of: photo) }
                for photo in item.photos { invalidate(photo) }
                items[i] = item
            } else {
                items.append(item)
            }
            touchedItems = true
        }
        for outfit in remoteOutfits {
            if let i = outfits.firstIndex(where: { $0.id == outfit.id }) {
                guard outfit.updated > outfits[i].updated else { continue }
                outfits[i] = outfit
            } else {
                outfits.append(outfit)
            }
            touchedOutfits = true
        }
        for wear in remoteWears where !wears.contains(where: { $0.id == wear.id }) {
            wears.append(wear)
            touchedWears = true
        }
        for wish in remoteWishes {
            if let i = wishes.firstIndex(where: { $0.id == wish.id }) {
                guard wish.updated > wishes[i].updated else { continue }
                wishes[i] = wish
            } else {
                wishes.append(wish)
            }
            touchedWishes = true
        }
        if touchedItems { save() }
        if touchedOutfits { saveOutfits() }
        if touchedWears { saveWears() }
        if touchedWishes { saveWishes() }
    }

    /// The photo files the pieces use: <id>.jpg always, <id>.png when cut out.
    func photoFileNames() -> [String] {
        items.flatMap(\.photos).flatMap { photo -> [String] in
            let base = photo.id.uuidString
            return photo.hasCutout ? [base + ".jpg", base + ".png"] : [base + ".jpg"]
        }
    }

    private func photoFile(_ name: String) -> URL { photos.appendingPathComponent(name) }

    func hasPhotoFile(_ name: String) -> Bool { FileManager.default.fileExists(atPath: photoFile(name).path) }

    func photoData(_ name: String) -> Data? { try? Data(contentsOf: photoFile(name)) }

    func storePhotoFile(_ name: String, _ data: Data) {
        try? data.write(to: photoFile(name), options: .atomic)
        cache.removeAllObjects()
    }

    func photoUploaded(_ name: String) {
        guard pendingPhotos.remove(name) != nil else { return }
        saveSync()
    }


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
            pendingPhotos.insert(photo.id.uuidString + ".png")
            saveSync()
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
