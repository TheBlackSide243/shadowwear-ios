import Observation
import UIKit

/// The closet on this device: Documents/Armadio/items.json and the photos in Documents/Armadio/Foto,
/// also visible in the Files app. Written on every change.
@MainActor
@Observable
final class Closet {
    private(set) var items: [Item] = []
    /// The last thing that went wrong while reading or writing, for the error banner.
    var error: String?

    let root: URL
    private var photos: URL { root.appendingPathComponent("Foto", isDirectory: true) }
    private var file: URL { root.appendingPathComponent("items.json") }
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
    }

    func toggleFavorite(_ id: Item.ID) {
        guard var item = item(id) else { return }
        item.favorite.toggle()
        update(item)
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([Item].self, from: Data(contentsOf: file))
        } catch {
            // Keep the unreadable file aside instead of writing over it on the next save.
            let aside = root.appendingPathComponent("items-illeggibile-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: file, to: aside)
            self.error = String(localized: "L'armadio salvato non si leggeva: l'ho messo da parte in \(aside.lastPathComponent).")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(items).write(to: file, options: .atomic)
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
