import Foundation
import Observation
import Security
import UIKit

/// Something deleted on this device, still to tell the server.
struct Tombstone: Codable, Hashable {
    /// "items", "outfits" or "wears", as the server calls them.
    var kind: String
    var id: UUID
    var at: Date
}

/// What the server's AI says about a photo.
struct AIDescription: Codable, Equatable {
    var name: String
    var category: Category
    var colors: [String]
    var warmth: Int?
    var material: String?
    var style: String?
    var notes: String?

    /// The words for the notes: material, style and the advice.
    var noteText: String {
        let first = [material, style].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: ", ")
        return [first, notes ?? ""].filter { !$0.isEmpty }.joined(separator: ". ")
    }

    /// The suggestion put into a piece: name and notes only where they are empty.
    func apply(to item: inout Item) {
        if !name.isEmpty { item.name = name }
        item.category = category
        if !colors.isEmpty { item.colors = colors }
        if let warmth, let value = Warmth(rawValue: warmth) { item.warmth = value }
        if item.notes.isEmpty { item.notes = noteText }
    }
}

/// The token for the server, in the Keychain (this device only).
enum Keychain {
    static let defaultService = "win.shadowbyte.shadowwear.server"

    static func read(service: String = defaultService) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ token: String?, service: String = defaultService) {
        let base: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service]
        SecItemDelete(base as CFDictionary)
        guard let token, let data = token.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Keeps the closet the same as on the ShadowWear server on the NAS: what changed here goes up,
/// what changed elsewhere (another iPhone, the iPad, the web site) comes down, photos included.
@MainActor
@Observable
final class SyncService {
    private(set) var server: URL?
    private(set) var lastSync: Date?
    private(set) var syncing = false
    private(set) var progress: String?
    /// Whether the server has an AI model to describe pieces.
    private(set) var aiReady = false
    var error: String?

    private let closet: Closet
    private let enabled: Bool
    private let defaults: UserDefaults
    private let keychain: String
    private var token: String?
    private var again = false
    private var soon: Task<Void, Never>?

    private static let serverKey = "syncServer"
    private static let userKey = "syncUser"

    /// The user name of the last connection, to fill in the form again.
    var lastUser: String { defaults.string(forKey: Self.userKey) ?? "" }
    private static let lastKey = "syncLast"

    init(closet: Closet, enabled: Bool = true, defaults: UserDefaults = .standard, keychain: String = Keychain.defaultService) {
        self.closet = closet
        self.enabled = enabled
        self.defaults = defaults
        self.keychain = keychain
        guard enabled else { return }
        server = defaults.string(forKey: Self.serverKey).flatMap(URL.init(string:))
        token = Keychain.read(service: keychain)
        lastSync = defaults.object(forKey: Self.lastKey) as? Date
        closet.onLocalChange = { [weak self] in self?.syncSoon() }
    }

    var isOn: Bool { server != nil && token != nil }

    // MARK: Connecting

    /// The address as typed: "192.168.1.10:30320" or a full URL; http when no scheme is given.
    static func address(_ text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("/") { t.removeLast() }
        guard !t.isEmpty else { return nil }
        if !t.contains("://") { t = "http://" + t }
        guard let url = URL(string: t), url.host != nil, ["http", "https"].contains(url.scheme ?? "") else { return nil }
        return url
    }

    /// Signs in to the server. A new server (no account yet) throws `needsAccount`, unless `create`:
    /// then the account is made with this user name and password (the server allows it only from home).
    func connect(address text: String, user: String, password: String, create: Bool = false) async throws {
        guard let url = Self.address(text) else { throw SyncError.message(String(localized: "Indirizzo non valido.")) }
        struct Status: Decodable { let app: String; let configured: Bool }
        let status: Status
        do {
            status = try JSONDecoder().decode(Status.self, from: try await request(url, "status", token: nil))
        } catch {
            throw SyncError.message(String(localized: "Nessun server ShadowWear a questo indirizzo."))
        }
        guard status.app == "shadowwear" else { throw SyncError.message(String(localized: "Nessun server ShadowWear a questo indirizzo.")) }
        if !status.configured && !create { throw SyncError.needsAccount }
        struct Login: Decodable { let token: String }
        let name = user.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = try JSONSerialization.data(withJSONObject: ["user": name, "password": password, "device": UIDevice.current.name])
        // Already set up (from the site or another device): a normal sign-in.
        let path = status.configured ? "login" : "setup"
        let login = try JSONDecoder().decode(Login.self, from: try await request(url, path, method: "POST", body: body, token: nil))
        defaults.set(name, forKey: Self.userKey)
        await signedIn(url, login.token)
    }

    /// Signs in with the code shown by a device already connected (on the site: Impostazioni →
    /// Collega un dispositivo): no password typed on this iPhone. The code works once, for ten minutes.
    func connect(address text: String, code: String) async throws {
        guard let url = Self.address(text) else { throw SyncError.message(String(localized: "Indirizzo non valido.")) }
        try await checkServer(url)
        struct Login: Decodable { let token: String }
        let body = try JSONSerialization.data(withJSONObject: ["code": code, "device": UIDevice.current.name])
        let login = try JSONDecoder().decode(Login.self, from: try await request(url, "link/redeem", method: "POST", body: body, token: nil))
        await signedIn(url, login.token)
    }

    private func checkServer(_ url: URL) async throws {
        struct Status: Decodable { let app: String }
        let status = try? JSONDecoder().decode(Status.self, from: try await request(url, "status", token: nil))
        guard status?.app == "shadowwear" else { throw SyncError.message(String(localized: "Nessun server ShadowWear a questo indirizzo.")) }
    }

    private func signedIn(_ url: URL, _ newToken: String) async {
        server = url
        token = newToken
        Keychain.write(newToken, service: keychain)
        defaults.set(url.absoluteString, forKey: Self.serverKey)
        error = nil
        await sync()
    }

    /// What a QR code of the site carries: shadowwear://link?server=<address>&code=<code>.
    struct LinkRequest: Identifiable, Equatable {
        let server: String
        let code: String
        var id: String { server + code }

        init?(_ url: URL) {
            guard url.scheme?.lowercased() == "shadowwear", url.host?.lowercased() == "link",
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  let server = items.first(where: { $0.name == "server" })?.value, SyncService.address(server) != nil,
                  let code = items.first(where: { $0.name == "code" })?.value,
                  code.filter({ $0.isLetter || $0.isNumber }).count == 12 else { return nil }
            self.server = server
            self.code = code.uppercased()
        }

        init(server: String, code: String) {
            self.server = server
            self.code = code
        }
    }

    func disconnect() async {
        if let server, let token {
            _ = try? await request(server, "logout", method: "POST", body: Data("{}".utf8), token: token)
        }
        server = nil
        token = nil
        lastSync = nil
        aiReady = false
        Keychain.write(nil, service: keychain)
        defaults.removeObject(forKey: Self.serverKey)
        defaults.removeObject(forKey: Self.lastKey)
    }

    // MARK: Syncing

    /// A sync a few seconds after the last change, so a burst of edits goes up once.
    func syncSoon() {
        guard isOn else { return }
        soon?.cancel()
        soon = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.sync()
        }
    }

    func sync() async {
        guard enabled, let server, let token else { return }
        if syncing {
            again = true
            return
        }
        syncing = true
        defer {
            syncing = false
            progress = nil
            if again {
                again = false
                Task { await self.sync() }
            }
        }
        do {
            try await run(server, token)
            lastSync = Date()
            defaults.set(lastSync, forKey: Self.lastKey)
            error = nil
        } catch SyncError.signedOut {
            self.token = nil
            Keychain.write(nil, service: keychain)
            error = String(localized: "Il server ha chiuso l'accesso di questo iPhone: ricollegalo con nome utente e password o con un codice.")
        } catch {
            self.error = String(localized: "Sincronizzazione non riuscita: \(error.localizedDescription)")
        }
    }

    private struct Answer: Decodable {
        struct Lists: Decodable {
            var items: [Item]
            var outfits: [Outfit]
            var wears: [Wear]
        }
        struct IDs: Decodable {
            var items: [String]
            var outfits: [String]
            var wears: [String]
        }
        var need: IDs
        var send: Lists
        var deleted: [Tombstone]
        var photos: [String]
    }

    private func run(_ server: URL, _ token: String) async throws {
        // What happens to aiReady: ask the server, cheap.
        if let data = try? await request(server, "status", token: token),
           let status = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ai = status["ai"] as? [String: Any] {
            aiReady = (ai["available"] as? Bool ?? false) && (ai["model"] as? String) != nil
        }

        progress = String(localized: "Confronto con il server…")
        let sentDeletes = closet.pendingDeletes
        var manifest: [String: Any] = [:]
        manifest["items"] = closet.items.map { ["id": $0.id.uuidString, "updated": Self.iso($0.updated)] }
        manifest["outfits"] = closet.outfits.map { ["id": $0.id.uuidString, "updated": Self.iso($0.updated)] }
        manifest["wears"] = closet.wears.map(\.id.uuidString)
        manifest["deleted"] = sentDeletes.map { ["kind": $0.kind, "id": $0.id.uuidString, "at": Self.iso($0.at)] }
        let answerData = try await request(server, "sync/compare", method: "POST",
                                           body: try JSONSerialization.data(withJSONObject: manifest), token: token)
        let answer = try Closet.decoder.decode(Answer.self, from: answerData)

        // What changed elsewhere comes in first, then what the server asked for goes up.
        closet.applyRemote(items: answer.send.items, outfits: answer.send.outfits, wears: answer.send.wears, deleted: answer.deleted)
        closet.clearPendingDeletes(sentDeletes)

        let needItems = Set(answer.need.items.map { $0.uppercased() })
        let needOutfits = Set(answer.need.outfits.map { $0.uppercased() })
        let needWears = Set(answer.need.wears.map { $0.uppercased() })
        if !needItems.isEmpty || !needOutfits.isEmpty || !needWears.isEmpty {
            progress = String(localized: "Invio le modifiche…")
            struct Push: Encodable { var items: [Item]; var outfits: [Outfit]; var wears: [Wear] }
            let push = Push(items: closet.items.filter { needItems.contains($0.id.uuidString) },
                            outfits: closet.outfits.filter { needOutfits.contains($0.id.uuidString) },
                            wears: closet.wears.filter { needWears.contains($0.id.uuidString) })
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            _ = try await request(server, "sync/push", method: "POST", body: try encoder.encode(push), token: token)
        }

        // Photos: up what the server lacks (or what was cut out again here), down what this device lacks.
        let onServer = Set(answer.photos.map { $0.uppercased() })
        let wanted = closet.photoFileNames()
        let upload = wanted.filter { (!onServer.contains($0.uppercased()) || closet.pendingPhotos.contains($0)) && closet.hasPhotoFile($0) }
        for (n, name) in upload.enumerated() {
            progress = String(localized: "Invio le foto: \(n + 1) di \(upload.count)")
            guard let data = closet.photoData(name) else { continue }
            _ = try await request(server, "photos/\(name)", method: "PUT", body: data, token: token,
                                  type: name.hasSuffix(".png") ? "image/png" : "image/jpeg")
            closet.photoUploaded(name)
        }
        let download = wanted.filter { !closet.hasPhotoFile($0) && onServer.contains($0.uppercased()) }
        for (n, name) in download.enumerated() {
            progress = String(localized: "Scarico le foto: \(n + 1) di \(download.count)")
            if let data = try? await request(server, "photos/\(name)", token: token) {
                closet.storePhotoFile(name, data)
            }
        }
    }

    // MARK: AI

    /// What the server's AI sees in the photo.
    func describe(_ image: UIImage) async throws -> AIDescription {
        guard let server, let token else { throw SyncError.message(String(localized: "Collega prima il server.")) }
        let small = Closet.thumbnail(image, side: 1024)
        guard let jpeg = small.jpegData(compressionQuality: 0.85) else { throw SyncError.message(String(localized: "Foto non leggibile.")) }
        let lang = Locale.current.language.languageCode?.identifier == "it" ? "it" : "en"
        let data = try await request(server, "ai/describe?lang=\(lang)", method: "POST", body: jpeg, token: token,
                                     type: "image/jpeg", timeout: 180)
        return try JSONDecoder().decode(AIDescription.self, from: data)
    }

    // MARK: HTTP

    enum SyncError: LocalizedError {
        case message(String)
        case signedOut
        /// The server is new: its account is still to be created.
        case needsAccount

        var errorDescription: String? {
            switch self {
            case .message(let text): text
            case .signedOut: String(localized: "Accesso scaduto.")
            case .needsAccount: String(localized: "Questo server non ha ancora un account.")
            }
        }
    }

    private func request(_ server: URL, _ path: String, method: String = "GET", body: Data? = nil, token: String?,
                         type: String = "application/json", timeout: TimeInterval = 30) async throws -> Data {
        guard let url = URL(string: "api/" + path, relativeTo: server.appendingPathComponent("/")) else {
            throw SyncError.message(String(localized: "Indirizzo non valido."))
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body {
            request.httpBody = body
            request.setValue(type, forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401, token != nil { throw SyncError.signedOut }
        guard (200..<300).contains(status) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
            // The server answers in Italian: the same texts are in Localizable.strings.
            if let message { throw SyncError.message(Bundle.main.localizedString(forKey: message, value: message, table: nil)) }
            throw SyncError.message(String(localized: "Il server ha risposto \(status)."))
        }
        return data
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}
