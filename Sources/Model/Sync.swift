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
    var pattern: String?
    var formality: Formality?
    var seasons: [Season]?
    var brand: String?
    var size: String?

    init(name: String, category: Category, colors: [String], warmth: Int? = nil, material: String? = nil, style: String? = nil,
         notes: String? = nil, pattern: String? = nil, formality: Formality? = nil, seasons: [Season]? = nil,
         brand: String? = nil, size: String? = nil) {
        self.name = name
        self.category = category
        self.colors = colors
        self.warmth = warmth
        self.material = material
        self.style = style
        self.notes = notes
        self.pattern = pattern
        self.formality = formality
        self.seasons = seasons
        self.brand = brand
        self.size = size
    }

    /// From the AI's JSON, kept to what the app knows.
    init(json: [String: Any]) {
        var colors: [String] = []
        // Some models name the colors in Italian ("bianca") even when asked for the keys.
        for word in AIJSON.strings(json["colors"]) {
            if let color = PaletteColor.key(forWord: word), !colors.contains(color) { colors.append(color) }
        }
        let warmth: Int? = switch AIJSON.string(json["warmth"]).lowercased() {
        case "light": 0
        case "medium": 1
        case "warm": 2
        default: nil
        }
        let seasons = AIJSON.strings(json["seasons"]).compactMap { word -> Season? in
            if word == "fall" { return .autumn }
            return Season(rawValue: word)
        }
        func text(_ key: String, _ limit: Int) -> String? {
            let value = String(AIJSON.string(json[key]).prefix(limit))
            // Some models write "unknown" or "N/A" instead of leaving it empty.
            let blank = ["unknown", "n/a", "none", "-", "—", "sconosciuto", "sconosciuta", "non visibile", "non leggibile"]
            return value.isEmpty || blank.contains(value.lowercased()) ? nil : value
        }
        self.init(name: text("name", 60) ?? "",
                  category: Category(rawValue: AIJSON.string(json["category"]).lowercased()) ?? .other,
                  colors: Array(colors.prefix(3)), warmth: warmth,
                  material: text("material", 60), style: text("style", 60), notes: text("notes", 300),
                  pattern: text("pattern", 60),
                  formality: Formality(rawValue: AIJSON.string(json["formality"]).lowercased()),
                  seasons: seasons.isEmpty ? nil : Array(Set(seasons)).sorted { $0.order < $1.order },
                  brand: text("brand", 60), size: text("size", 30))
    }

    /// The suggestion put into a piece: the notes only when they are empty.
    func apply(to item: inout Item) {
        if !name.isEmpty { item.name = name }
        item.category = category
        if !colors.isEmpty { item.colors = colors }
        if let warmth, let value = Warmth(rawValue: warmth) { item.warmth = value }
        if let material, !material.isEmpty { item.material = material }
        if let pattern, !pattern.isEmpty { item.pattern = pattern }
        if let style, !style.isEmpty { item.style = style }
        if let formality { item.formality = formality }
        if let seasons, !seasons.isEmpty { item.seasons = seasons }
        if item.notes.isEmpty, let notes { item.notes = notes }
        // Brand and size only when the AI read them, and never over what the user wrote.
        if item.brand.isEmpty, let brand, !brand.isEmpty { item.brand = brand }
        if item.size.isEmpty, let size, !size.isEmpty { item.size = size }
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
    /// Whether the server reaches an Ollama (with a model chosen or not).
    private(set) var aiAvailable = false
    var error: String?

    private let closet: Closet
    private let enabled: Bool
    private let defaults: UserDefaults
    private let keychain: String
    private var token: String?
    /// The sync under way. Another call waits for it and then syncs again, so what changed in the
    /// meantime has gone up when the call returns.
    private var running: Task<Void, Never>?
    private var runningID = UUID()
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
    nonisolated static func address(_ text: String) -> URL? {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        while t.hasSuffix("/") { t.removeLast() }
        guard !t.isEmpty else { return nil }
        if !t.contains("://") { t = "http://" + t }
        guard let url = URL(string: t), url.host != nil, ["http", "https"].contains(url.scheme ?? "") else { return nil }
        return url
    }

    /// The new server met by the last `connect` wants the setup code (it is reached from the internet).
    private(set) var newServerNeedsCode = false

    /// Signs in to the server. A new server (no account yet) throws `needsAccount`, unless `create`:
    /// then the account is made with this user name and password. The server allows it from home, or
    /// from the internet with the setup code it wrote in its log.
    func connect(address text: String, user: String, password: String, create: Bool = false, setupCode: String = "") async throws {
        guard let url = Self.address(text) else { throw SyncError.message(String(localized: "Indirizzo non valido.")) }
        struct Status: Decodable { let app: String; let configured: Bool; let needsSetupCode: Bool? }
        let status: Status
        do {
            status = try JSONDecoder().decode(Status.self, from: try await request(url, "status", token: nil))
        } catch {
            throw SyncError.message(String(localized: "Nessun server ShadowWear a questo indirizzo."))
        }
        guard status.app == "shadowwear" else { throw SyncError.message(String(localized: "Nessun server ShadowWear a questo indirizzo.")) }
        newServerNeedsCode = !status.configured && status.needsSetupCode == true
        if !status.configured && !create { throw SyncError.needsAccount }
        struct Login: Decodable { let token: String }
        let name = user.trimmingCharacters(in: .whitespacesAndNewlines)
        var fields = ["user": name, "password": password, "device": UIDevice.current.name]
        if !status.configured && !setupCode.isEmpty { fields["setupCode"] = setupCode }
        let body = try JSONSerialization.data(withJSONObject: fields)
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

    /// A code that connects another device to this server (made by this iPhone, already signed in).
    struct LinkCode: Equatable {
        let code: String
        let expires: Date
        let server: String

        /// What the QR code carries, the same as on the site.
        var url: URL? {
            var parts = URLComponents()
            parts.scheme = "shadowwear"
            parts.host = "link"
            parts.queryItems = [URLQueryItem(name: "server", value: server), URLQueryItem(name: "code", value: code)]
            return parts.url
        }
    }

    /// A new code for another device (the one before stops working): ten minutes, once.
    func makeLink() async throws -> LinkCode {
        guard let server, let token else { throw SyncError.message(String(localized: "Collega prima il server.")) }
        let data = try await request(server, "link", method: "POST", body: Data("{}".utf8), token: token)
        struct Answer: Decodable { let code: String; let expires: String }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let expires = iso.date(from: answer.expires) ?? Date().addingTimeInterval(600)
        return LinkCode(code: answer.code, expires: expires, server: server.absoluteString)
    }

    /// The code in waiting stops working.
    func cancelLink() async {
        guard let server, let token else { return }
        _ = try? await request(server, "link", method: "DELETE", token: token)
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
        aiAvailable = false
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
        guard enabled, server != nil, token != nil else { return }
        while let current = running { await current.value }
        let id = UUID()
        runningID = id
        let task = Task {
            await self.syncOnce()
            if self.runningID == id { self.running = nil }
        }
        running = task
        await task.value
    }

    private func syncOnce() async {
        guard enabled, let server, let token else { return }
        syncing = true
        defer {
            syncing = false
            progress = nil
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
            /// Servers before 0.5 have no list of things to buy.
            var wishes: [Wish]?
        }
        struct IDs: Decodable {
            var items: [String]
            var outfits: [String]
            var wears: [String]
            var wishes: [String]?
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
            aiAvailable = ai["available"] as? Bool ?? false
            aiReady = aiAvailable && (ai["model"] as? String) != nil
        }

        progress = String(localized: "Confronto con il server…")
        let sentDeletes = closet.pendingDeletes
        var manifest: [String: Any] = [:]
        manifest["items"] = closet.items.map { ["id": $0.id.uuidString, "updated": Self.iso($0.updated)] }
        manifest["outfits"] = closet.outfits.map { ["id": $0.id.uuidString, "updated": Self.iso($0.updated)] }
        manifest["wears"] = closet.wears.map(\.id.uuidString)
        manifest["wishes"] = closet.wishes.map { ["id": $0.id.uuidString, "updated": Self.iso($0.updated)] }
        manifest["deleted"] = sentDeletes.map { ["kind": $0.kind, "id": $0.id.uuidString, "at": Self.iso($0.at)] }
        let answerData = try await request(server, "sync/compare", method: "POST",
                                           body: try JSONSerialization.data(withJSONObject: manifest), token: token)
        let answer = try Closet.decoder.decode(Answer.self, from: answerData)

        // What changed elsewhere comes in first, then what the server asked for goes up.
        closet.applyRemote(items: answer.send.items, outfits: answer.send.outfits, wears: answer.send.wears,
                           wishes: answer.send.wishes ?? [], deleted: answer.deleted)
        closet.clearPendingDeletes(sentDeletes)

        let needItems = Set(answer.need.items.map { $0.uppercased() })
        let needOutfits = Set(answer.need.outfits.map { $0.uppercased() })
        let needWears = Set(answer.need.wears.map { $0.uppercased() })
        let needWishes = Set((answer.need.wishes ?? []).map { $0.uppercased() })
        if !needItems.isEmpty || !needOutfits.isEmpty || !needWears.isEmpty || !needWishes.isEmpty {
            progress = String(localized: "Invio le modifiche…")
            struct Push: Encodable { var items: [Item]; var outfits: [Outfit]; var wears: [Wear]; var wishes: [Wish] }
            let push = Push(items: closet.items.filter { needItems.contains($0.id.uuidString) },
                            outfits: closet.outfits.filter { needOutfits.contains($0.id.uuidString) },
                            wears: closet.wears.filter { needWears.contains($0.id.uuidString) },
                            wishes: closet.wishes.filter { needWishes.contains($0.id.uuidString) })
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

    /// What the server's AI sees in the photo. `model`: this iPhone's choice, empty for the server's.
    func describe(_ image: UIImage, model: String = "") async throws -> AIDescription {
        guard let server, let token else { throw SyncError.message(String(localized: "Collega prima il server.")) }
        let small = Closet.thumbnail(image, side: 1024)
        guard let jpeg = small.jpegData(compressionQuality: 0.85) else { throw SyncError.message(String(localized: "Foto non leggibile.")) }
        var query = URLComponents()
        query.queryItems = [URLQueryItem(name: "lang", value: Locale.current.language.languageCode?.identifier == "it" ? "it" : "en")]
        if !model.isEmpty { query.queryItems?.append(URLQueryItem(name: "model", value: model)) }
        let data = try await request(server, "ai/describe?\(query.percentEncodedQuery ?? "")", method: "POST", body: jpeg, token: token,
                                     type: "image/jpeg", timeout: 180)
        return try JSONDecoder().decode(AIDescription.self, from: data)
    }

    /// A model of the server's Ollama.
    struct ServerModel: Decodable, Hashable {
        let name: String
        let vision: Bool?
    }

    /// The models of the server's Ollama, and the one chosen on the site.
    func aiModels() async throws -> (models: [ServerModel], chosen: String?) {
        guard let server, let token else { throw SyncError.message(String(localized: "Collega prima il server.")) }
        let data = try await request(server, "ai/models", token: token, timeout: 30)
        struct Answer: Decodable { let models: [ServerModel]; let model: String? }
        let answer = try JSONDecoder().decode(Answer.self, from: data)
        return (answer.models, answer.model)
    }

    /// A question of the app to the server's model, with a photo or not. `model`: this iPhone's
    /// choice, empty for the one chosen on the site.
    func askAI(system: String, prompt: String, image: Data?, json: Bool, model: String = "") async throws -> String {
        guard let server, let token else { throw SyncError.message(String(localized: "Collega prima il server.")) }
        var body: [String: Any] = ["system": system, "prompt": prompt, "json": json]
        if let image { body["image"] = image.base64EncodedString() }
        if !model.isEmpty { body["model"] = model }
        let data = try await request(server, "ai/chat", method: "POST", body: try JSONSerialization.data(withJSONObject: body),
                                     token: token, timeout: 300)
        struct Answer: Decodable { let text: String }
        return try JSONDecoder().decode(Answer.self, from: data).text
    }

    // MARK: HTTP

    enum SyncError: LocalizedError {
        case message(String)
        case signedOut
        /// The server is new: its account is still to be created.
        case needsAccount
        /// The server is older than this app and does not know the question.
        case oldServer

        var errorDescription: String? {
            switch self {
            case .message(let text): text
            case .signedOut: String(localized: "Accesso scaduto.")
            case .needsAccount: String(localized: "Questo server non ha ancora un account.")
            case .oldServer: String(localized: "Il server è di una versione vecchia: aggiornalo alla 0.5.0.")
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
        if status == 404, path.hasPrefix("ai/") { throw SyncError.oldServer }
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
