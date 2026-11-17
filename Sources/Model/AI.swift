import Foundation
import Observation
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Where the AI runs. Stored in UserDefaults: never rename the raw values.
enum AIProvider: String, Codable, CaseIterable, Identifiable {
    /// No AI: the app works the same, without the AI buttons.
    case off
    /// The model chosen on the ShadowWear server (Ollama on the NAS).
    case server
    /// Apple Intelligence on this iPhone: text only, nothing leaves the phone.
    case device
    /// A service of the user's own: Ollama, LM Studio, OpenAI or anything with the same API.
    case custom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: String(localized: "Nessuna")
        case .server: String(localized: "Server ShadowWear")
        case .device: String(localized: "Apple Intelligence")
        case .custom: String(localized: "Un tuo servizio IA")
        }
    }

    var symbol: String {
        switch self {
        case .off: "slash.circle"
        case .server: "server.rack"
        case .device: "sparkles"
        case .custom: "network"
        }
    }
}

/// The AI settings of this device. The key of the user's service is in the Keychain.
struct AIConfig: Codable, Equatable {
    var provider: AIProvider = .off
    /// The address of the user's own service, e.g. http://192.168.1.10:11434 (Ollama).
    var customURL = ""
    /// The model that sees photos, and the one that writes (empty: the same one).
    var visionModel = ""
    var textModel = ""
    /// The model of the server's Ollama this iPhone uses (empty: the one chosen on the site).
    var serverModel = ""
    /// New pieces are named and tagged by the AI as they are added.
    var autoTag = true
    /// The provider was chosen once (at the first launch or in Settings): not asked again.
    var chosen = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        provider = (try? c.decodeIfPresent(AIProvider.self, forKey: .provider)) ?? .off
        customURL = try c.decodeIfPresent(String.self, forKey: .customURL) ?? ""
        visionModel = try c.decodeIfPresent(String.self, forKey: .visionModel) ?? ""
        textModel = try c.decodeIfPresent(String.self, forKey: .textModel) ?? ""
        serverModel = try c.decodeIfPresent(String.self, forKey: .serverModel) ?? ""
        autoTag = try c.decodeIfPresent(Bool.self, forKey: .autoTag) ?? true
        chosen = try c.decodeIfPresent(Bool.self, forKey: .chosen) ?? false
    }
}

enum AIError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self { case .message(let text): text }
    }
}

/// The AI of the app, whichever it is. The questions (prompts) are written here, the same for every
/// provider; each provider only carries them.
@MainActor
@Observable
final class AIService {
    private(set) var config: AIConfig
    private let sync: SyncService
    private let defaults: UserDefaults
    /// The README pictures: the AI shows as ready, nothing is asked.
    private let demo: Bool
    private static let key = "aiConfig"
    static let keychain = "win.shadowbyte.shadowwear.ai"

    init(sync: SyncService, defaults: UserDefaults = .standard, demo: Bool = false) {
        self.sync = sync
        self.defaults = defaults
        self.demo = demo
        if demo {
            var config = AIConfig()
            config.provider = .server
            config.chosen = true
            self.config = config
            return
        }
        config = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(AIConfig.self, from: $0) } ?? AIConfig()
    }

    func update(_ change: (inout AIConfig) -> Void) {
        var next = config
        change(&next)
        guard next != config else { return }
        config = next
        defaults.set(try? JSONEncoder().encode(next), forKey: Self.key)
    }

    var apiKey: String {
        get { Keychain.read(service: Self.keychain) ?? "" }
        set { Keychain.write(newValue.isEmpty ? nil : newValue, service: Self.keychain) }
    }

    // MARK: What can be done

    /// Whether Apple Intelligence can answer on this iPhone (iOS 26 or later, turned on, model ready).
    static var deviceAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Why Apple Intelligence cannot answer, in words for the settings.
    static var deviceProblem: String? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(.deviceNotEligible): return String(localized: "Questo iPhone non ha Apple Intelligence.")
            case .unavailable(.appleIntelligenceNotEnabled): return String(localized: "Attiva Apple Intelligence in Impostazioni → Apple Intelligence e Siri.")
            case .unavailable(.modelNotReady): return String(localized: "Il modello di Apple Intelligence si sta ancora scaricando: riprova più tardi.")
            default: return String(localized: "Apple Intelligence non è disponibile adesso.")
            }
        }
        #endif
        return String(localized: "Serve iOS 26 o successivo.")
    }

    /// The AI can look at photos (tags, selfie).
    var canSee: Bool {
        if demo { return true }
        return switch config.provider {
        case .off, .device: false
        case .server: serverReady
        case .custom: customBase != nil && !(config.visionModel.isEmpty && config.textModel.isEmpty)
        }
    }

    /// The server answers with a model: the one of the site, or the one this iPhone chose.
    private var serverReady: Bool {
        sync.isOn && (sync.aiReady || (sync.aiAvailable && !config.serverModel.isEmpty))
    }

    /// The AI can write (stylist, ideas around a piece, packing tips).
    var canTalk: Bool {
        if demo { return true }
        return switch config.provider {
        case .off: false
        case .device: Self.deviceAvailable
        case .server: serverReady
        case .custom: customBase != nil && !(config.visionModel.isEmpty && config.textModel.isEmpty)
        }
    }

    var isOn: Bool { canSee || canTalk }

    /// One line on what the AI is now, for the settings and the tools.
    var summary: String {
        if demo { return String(localized: "IA del server ShadowWear") }
        switch config.provider {
        case .off: return String(localized: "IA spenta")
        case .server:
            if !sync.isOn { return String(localized: "Server non collegato") }
            if !config.serverModel.isEmpty, sync.aiAvailable { return String(localized: "\(config.serverModel) · server ShadowWear") }
            return sync.aiReady ? String(localized: "IA del server ShadowWear") : String(localized: "Il server non ha ancora un modello IA")
        case .device:
            return Self.deviceAvailable ? String(localized: "Apple Intelligence sull'iPhone") : (Self.deviceProblem ?? "")
        case .custom:
            guard let base = customBase else { return String(localized: "Indirizzo del servizio IA mancante") }
            let model = config.visionModel.isEmpty ? config.textModel : config.visionModel
            return model.isEmpty ? String(localized: "Scegli un modello") : "\(model) · \(base.host ?? "")"
        }
    }

    /// The user's service with its /v1 path: "http://nas:11434" → "http://nas:11434/v1".
    var customBase: URL? {
        Self.base(config.customURL)
    }

    nonisolated static func base(_ text: String) -> URL? {
        guard var url = SyncService.address(text) else { return nil }
        if !url.path.hasSuffix("/v1") && !url.path.contains("/v1/") {
            url = url.appendingPathComponent("v1")
        }
        return url
    }

    // MARK: Asking

    /// Asks the AI; `json` asks for a JSON object as the answer. A photo needs a provider that sees.
    func ask(system: String, prompt: String, image: UIImage? = nil, json: Bool = false) async throws -> String {
        switch config.provider {
        case .off:
            throw AIError.message(String(localized: "L'IA è spenta: accendila in Impostazioni → Intelligenza artificiale."))
        case .server:
            return try await sync.askAI(system: system, prompt: prompt, image: image.flatMap(Self.jpeg), json: json,
                                        model: config.serverModel)
        case .device:
            guard image == nil else {
                throw AIError.message(String(localized: "Apple Intelligence non guarda le foto: per questo serve l'IA del server o un tuo servizio IA."))
            }
            return try await Self.askDevice(system: system, prompt: prompt, json: json)
        case .custom:
            return try await askCustom(system: system, prompt: prompt, image: image, json: json)
        }
    }

    private static func jpeg(_ image: UIImage) -> Data? {
        Closet.thumbnail(image, side: 1024).jpegData(compressionQuality: 0.85)
    }

    private static func askDevice(system: String, prompt: String, json: Bool) async throws -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw AIError.message(deviceProblem ?? String(localized: "Apple Intelligence non è disponibile adesso."))
            }
            let instructions = json ? system + "\n" + String(localized: "Rispondi solo con un oggetto JSON valido, senza altro testo.") : system
            let session = LanguageModelSession(instructions: instructions)
            do {
                return try await session.respond(to: prompt).content
            } catch {
                throw AIError.message(String(localized: "Apple Intelligence non ha risposto: \(error.localizedDescription)"))
            }
        }
        #endif
        throw AIError.message(String(localized: "Serve iOS 26 o successivo."))
    }

    private func askCustom(system: String, prompt: String, image: UIImage?, json: Bool) async throws -> String {
        guard let base = customBase else { throw AIError.message(String(localized: "Scrivi l'indirizzo del tuo servizio IA.")) }
        let model = image != nil
            ? (config.visionModel.isEmpty ? config.textModel : config.visionModel)
            : (config.textModel.isEmpty ? config.visionModel : config.textModel)
        guard !model.isEmpty else { throw AIError.message(String(localized: "Scegli il modello del tuo servizio IA.")) }
        var content: [[String: Any]] = [["type": "text", "text": prompt]]
        if let image, let data = Self.jpeg(image) {
            content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64," + data.base64EncodedString()]])
        }
        var body: [String: Any] = [
            "model": model,
            "messages": [["role": "system", "content": system], ["role": "user", "content": content]],
            "temperature": json ? 0.2 : 0.6,
            "stream": false,
        ]
        if json { body["response_format"] = ["type": "json_object"] }
        do {
            return try await chatCompletion(base, body)
        } catch let AIError.message(text) where json && text.contains("400") {
            // Some servers do not know response_format: once more without it.
            body.removeValue(forKey: "response_format")
            return try await chatCompletion(base, body)
        }
    }

    private func chatCompletion(_ base: URL, _ body: [String: Any]) async throws -> String {
        var request = URLRequest(url: base.appendingPathComponent("chat/completions"), timeoutInterval: 240)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let key = apiKey
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.message(String(localized: "Il servizio IA non risponde: \(error.localizedDescription)"))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard (200..<300).contains(status) else {
            let detail = (object?["error"] as? [String: Any])?["message"] as? String ?? (object?["error"] as? String) ?? ""
            throw AIError.message(String(localized: "Il servizio IA ha risposto \(status). \(detail)"))
        }
        guard let choices = object?["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String, !text.isEmpty else {
            throw AIError.message(String(localized: "Il servizio IA ha dato una risposta vuota."))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The models of the user's service, to choose from.
    func customModels(url: String, key: String) async throws -> [String] {
        guard let base = Self.base(url) else { throw AIError.message(String(localized: "Indirizzo non valido.")) }
        var request = URLRequest(url: base.appendingPathComponent("models"), timeoutInterval: 15)
        if !key.isEmpty { request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization") }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.message(String(localized: "Il servizio IA non risponde: \(error.localizedDescription)"))
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw AIError.message(String(localized: "Il servizio IA ha risposto \(status).")) }
        let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        let list = (object?["data"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }
        return list.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    // MARK: The questions

    private var italian: Bool { Locale.current.language.languageCode?.identifier != "en" }

    private var languageRule: String {
        italian ? "Rispondi sempre in italiano." : "Always answer in English."
    }

    /// What the piece in the photo is, for a new piece or "Descrivi con l'IA".
    func describe(_ image: UIImage) async throws -> AIDescription {
        let system = """
        You tag clothes for a digital closet. You look at one photo with one piece of clothing (or shoes, a bag, an accessory) and describe it. \(languageRule)
        """
        let prompt = """
        Describe the piece in the photo. Answer only with a JSON object with these keys:
        "name": a short name, 2-4 words, in \(italian ? "Italian" : "English") (e.g. \(italian ? "\"Felpa grigia con cappuccio\"" : "\"Grey hooded sweatshirt\"")),
        "category": one of \(Category.allCases.map(\.rawValue).joined(separator: ", ")),
        "colors": 1-3 of \(PaletteColor.all.map(\.key).joined(separator: ", ")), the main one first,
        "warmth": light, medium or warm,
        "material": the fabric, a word or two,
        "pattern": solid, striped, checked, floral, printed… in a word or two,
        "style": casual, smart, sporty, elegant… in a word or two,
        "formality": one of casual, smart, formal, sporty,
        "seasons": the seasons it is for, from spring, summer, autumn, winter,
        "notes": one sentence on what it goes with or how to care for it.
        The words of name, material, pattern, style and notes in \(italian ? "Italian" : "English").
        """
        let text: String
        do {
            text = try await ask(system: system, prompt: prompt, image: image, json: true)
        } catch SyncService.SyncError.oldServer {
            // A server before 0.5 knows only its own question.
            return try await sync.describe(image, model: config.serverModel)
        }
        guard let object = AIJSON.object(text) else { throw AIError.message(String(localized: "L'IA ha risposto in un modo che non capisco: riprova.")) }
        return AIDescription(json: object)
    }

    /// The pieces of the closet as a numbered list, one line each, for the questions that need it.
    static func catalogue(_ items: [Item], limit: Int = 400) -> String {
        items.prefix(limit).enumerated().map { index, item in
            let colors = item.colors.compactMap { PaletteColor.named($0)?.name }.joined(separator: "/")
            let extra = [item.category.label, colors, item.effectiveWarmth.label, item.material, item.pattern, item.style, item.brand]
                .filter { !$0.isEmpty }.joined(separator: ", ")
            return "\(index + 1). \(item.displayName) (\(extra))"
        }.joined(separator: "\n")
    }

    /// Which pieces of the closet are in a photo of the user wearing them.
    func whichPieces(in photo: UIImage, items: [Item]) async throws -> [Item.ID] {
        let list = Array(items.prefix(300))
        let system = "You recognise clothes. You compare a photo of a person with the numbered list of the clothes they own. \(languageRule)"
        let prompt = """
        These are the clothes the person owns:
        \(Self.catalogue(list))

        Which of them is the person wearing in the photo? Only the ones you are fairly sure of, at most one per kind of piece.
        Answer only with a JSON object: {"pieces": [the numbers]}.
        """
        let text = try await ask(system: system, prompt: prompt, image: photo, json: true)
        let numbers = AIJSON.numbers(text, key: "pieces")
        var seen = Set<Item.ID>()
        return numbers.compactMap { n in
            guard n >= 1, n <= list.count else { return nil }
            let id = list[n - 1].id
            return seen.insert(id).inserted ? id : nil
        }
    }

    /// Outfits built around one piece, with a sentence on each.
    func pairings(for item: Item, items: [Item], conditions: Conditions?) async throws -> [AIOutfit] {
        let others = items.filter { $0.id != item.id && !$0.stored }
        let list = Array(others.prefix(250))
        let weather = conditions.map { "The weather today: \(Int($0.low))-\(Int($0.high)) °C, rain \($0.rain)%." } ?? ""
        let system = "You are a personal stylist. You build outfits only from the clothes the person owns. \(languageRule)"
        let prompt = """
        The piece to wear: \(item.displayName) (\(item.category.label), \(item.colors.compactMap { PaletteColor.named($0)?.name }.joined(separator: "/"))).
        The other clothes, numbered:
        \(Self.catalogue(list))
        \(weather)

        Make 3 different outfits with this piece and some of the numbered clothes: something for the body and the legs (or a dress), shoes, and a coat or accessories when they help.
        Answer only with a JSON object: {"outfits": [{"pieces": [numbers], "why": "one short sentence"}]}.
        """
        let text = try await ask(system: system, prompt: prompt, json: true)
        guard let object = AIJSON.object(text), let outfits = object["outfits"] as? [[String: Any]] else {
            throw AIError.message(String(localized: "L'IA ha risposto in un modo che non capisco: riprova."))
        }
        return outfits.compactMap { entry in
            let numbers = AIJSON.ints(entry["pieces"])
            var ids = [item.id]
            for n in numbers where n >= 1 && n <= list.count && !ids.contains(list[n - 1].id) { ids.append(list[n - 1].id) }
            guard ids.count > 1 else { return nil }
            return AIOutfit(items: ids, why: (entry["why"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    /// One answer of the stylist chat: the closet, the weather and what was said so far.
    func stylist(_ history: [ChatMessage], items: [Item], wears: [Wear], conditions: Conditions?) async throws -> String {
        // Apple's model reads about 4000 words in all: a shorter list there.
        let limit = config.provider == .device ? 60 : 300
        let list = Array(items.filter { !$0.stored }.prefix(limit))
        let lastWorn = Dictionary(wears.flatMap { w in w.items.map { ($0, w.day) } }, uniquingKeysWith: { max($0, $1) })
        let recent = list.enumerated().compactMap { index, item in lastWorn[item.id].map { "\(index + 1): \($0)" } }.prefix(40)
        let weather = conditions.map { "Today: \(Int($0.low))-\(Int($0.high)) °C, rain \($0.rain)%." } ?? "The weather is not known."
        let system = """
        You are the personal stylist inside the ShadowWear app. You know the person's closet (the numbered list) and suggest what to wear, what goes with what, what is missing, how to care for the clothes. When you mention a piece of the closet, write its number in square brackets, e.g. [3]. Be concise and practical, no more than about 120 words. \(languageRule)
        The closet:
        \(Self.catalogue(list, limit: limit))
        \(weather)
        Last worn (number: day): \(recent.joined(separator: ", "))
        Today is \(Day.key(Date())).
        """
        let talk = history.suffix(10).map { ($0.fromUser ? "Person: " : "Stylist: ") + $0.text }.joined(separator: "\n")
        return try await ask(system: system, prompt: talk + "\nStylist:")
    }

    /// A few tips for the suitcase, on top of the list the app makes.
    func packingTips(trip: TripPlan, list: [PackingLine]) async throws -> String {
        let system = "You are a practical travel stylist. \(languageRule)"
        let lines = list.map { "\($0.count) × \($0.category.label)" }.joined(separator: ", ")
        let weather = trip.days.compactMap(\.conditions).map { "\(Int($0.low))-\(Int($0.high)) °C rain \($0.rain)%" }.joined(separator: "; ")
        let prompt = """
        A trip to \(trip.place.name), \(trip.nights) nights, for: \(trip.occasions.map(\.label).joined(separator: ", ")).
        Weather by day: \(weather.isEmpty ? "not known" : weather).
        The suitcase so far: \(lines).
        Give 3-5 short tips (one line each, starting with "• ") on what to add, leave home or watch out for.
        """
        return try await ask(system: system, prompt: prompt)
    }
}

/// An outfit the AI put together, with its reason.
struct AIOutfit: Identifiable, Equatable {
    let id = UUID()
    var items: [Item.ID]
    var why: String
}

/// One message of the stylist chat.
struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var fromUser: Bool
    var text: String
}

/// Reading the AI's JSON, which is not always clean: code fences, words around it, numbers as text.
enum AIJSON {
    static func object(_ text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return object
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func ints(_ value: Any?) -> [Int] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { element in
            if let n = element as? Int { return n }
            if let n = element as? Double { return Int(n) }
            if let s = element as? String { return Int(s.trimmingCharacters(in: CharacterSet(charactersIn: "[]# "))) }
            return nil
        }
    }

    static func numbers(_ text: String, key: String) -> [Int] {
        ints(object(text)?[key])
    }

    static func string(_ value: Any?) -> String {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func strings(_ value: Any?) -> [String] {
        if let array = value as? [Any] { return array.compactMap { ($0 as? String)?.lowercased() } }
        if let text = value as? String { return text.lowercased().split(whereSeparator: { ",; ".contains($0) }).map(String.init) }
        return []
    }
}
