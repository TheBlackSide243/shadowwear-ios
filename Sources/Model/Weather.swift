import CoreLocation
import Foundation
import Observation

/// Where the weather is for: a town picked by name, or the phone's position rounded to about a
/// kilometre (that is all Open-Meteo is sent).
struct Place: Codable, Hashable {
    var name: String
    var latitude: Double
    var longitude: Double

    var rounded: Place {
        Place(name: name, latitude: (latitude * 100).rounded() / 100, longitude: (longitude * 100).rounded() / 100)
    }
}

/// Today's weather from Open-Meteo (free, no account, no key).
struct Forecast: Codable, Equatable {
    var place: String
    var fetched: Date
    /// The day it is for, yyyy-MM-dd.
    var day: String
    var now: Double?
    var high: Double
    var low: Double
    var rain: Int
    var code: Int

    var conditions: Conditions { Conditions(high: high, low: low, rain: rain) }

    /// The WMO weather code as a symbol and a few words.
    var symbol: String { WeatherCode.symbol(code) }
    var summary: String { WeatherCode.summary(code) }
}

enum WeatherCode {
    static func symbol(_ code: Int) -> String {
        switch code {
        case 0: "sun.max.fill"
        case 1, 2: "cloud.sun.fill"
        case 3: "cloud.fill"
        case 45, 48: "cloud.fog.fill"
        case 51...57: "cloud.drizzle.fill"
        case 61...67, 80...82: "cloud.rain.fill"
        case 71...77, 85, 86: "cloud.snow.fill"
        case 95...99: "cloud.bolt.rain.fill"
        default: "cloud.fill"
        }
    }

    static func summary(_ code: Int) -> String {
        switch code {
        case 0: String(localized: "Sereno")
        case 1, 2: String(localized: "Poco nuvoloso")
        case 3: String(localized: "Nuvoloso")
        case 45, 48: String(localized: "Nebbia")
        case 51...57: String(localized: "Pioviggine")
        case 61...67, 80...82: String(localized: "Pioggia")
        case 71...77, 85, 86: String(localized: "Neve")
        case 95...99: String(localized: "Temporale")
        default: String(localized: "Variabile")
        }
    }
}

/// Keeps the place and today's forecast, fetched at most every half hour.
@MainActor
@Observable
final class WeatherService {
    private(set) var place: Place?
    private(set) var forecast: Forecast?
    private(set) var loading = false
    var error: String?

    private let defaults: UserDefaults
    private static let placeKey = "weatherPlace"
    private static let forecastKey = "weatherForecast"

    init(defaults: UserDefaults = .standard, demo: Forecast? = nil) {
        self.defaults = defaults
        if let demo {
            place = Place(name: demo.place, latitude: 0, longitude: 0)
            forecast = demo
            return
        }
        place = Self.decode(Place.self, defaults.data(forKey: Self.placeKey))
        forecast = Self.decode(Forecast.self, defaults.data(forKey: Self.forecastKey))
    }

    /// Today's conditions, when the forecast is today's.
    var today: Conditions? {
        guard let forecast, forecast.day == Day.key(Date()) else { return nil }
        return forecast.conditions
    }

    func setPlace(_ place: Place?) async {
        self.place = place?.rounded
        defaults.set(place.flatMap { try? JSONEncoder().encode($0.rounded) }, forKey: Self.placeKey)
        forecast = nil
        defaults.removeObject(forKey: Self.forecastKey)
        await refresh(force: true)
    }

    /// Asks for the phone's position (once) and uses it.
    func useCurrentLocation() async {
        loading = true
        defer { loading = false }
        do {
            let location = try await LocationOnce.fetch()
            let name = await Self.townName(of: location) ?? String(localized: "La mia posizione")
            await setPlace(Place(name: name, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
        } catch {
            self.error = String(localized: "Non riesco a sapere dove sei: permetti la posizione a ShadowWear in Impostazioni, oppure cerca la tua città.")
        }
    }

    func refresh(force: Bool = false) async {
        guard let place, !loading || force else { return }
        if !force, let forecast, forecast.day == Day.key(Date()), Date().timeIntervalSince(forecast.fetched) < 1800 { return }
        loading = true
        defer { loading = false }
        do {
            let fresh = try await Self.fetch(place)
            forecast = fresh
            error = nil
            defaults.set(try? JSONEncoder().encode(fresh), forKey: Self.forecastKey)
        } catch {
            self.error = String(localized: "Meteo non disponibile: \(error.localizedDescription)")
        }
    }

    /// Towns matching a name, for the search.
    static func search(_ name: String) async throws -> [Place] {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        var url = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        url.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "it"),
            URLQueryItem(name: "format", value: "json"),
        ]
        struct Response: Decodable {
            struct Result: Decodable {
                let name: String
                let latitude: Double
                let longitude: Double
                let admin1: String?
                let country: String?
            }
            let results: [Result]?
        }
        let (data, _) = try await URLSession.shared.data(from: url.url!)
        let results = try JSONDecoder().decode(Response.self, from: data).results ?? []
        return results.map { r in
            let detail = [r.admin1, r.country].compactMap { $0 }.filter { !$0.isEmpty && $0 != r.name }
            let name = ([r.name] + detail.prefix(1)).joined(separator: ", ")
            return Place(name: name, latitude: r.latitude, longitude: r.longitude)
        }
    }

    private static func fetch(_ place: Place) async throws -> Forecast {
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,weather_code"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1"),
        ]
        struct Response: Decodable {
            struct Current: Decodable {
                let temperature_2m: Double?
            }
            struct Daily: Decodable {
                let time: [String]
                let temperature_2m_max: [Double?]
                let temperature_2m_min: [Double?]
                let precipitation_probability_max: [Int?]?
                let weather_code: [Int?]
            }
            let current: Current?
            let daily: Daily
        }
        let (data, response) = try await URLSession.shared.data(from: url.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        let r = try JSONDecoder().decode(Response.self, from: data)
        guard let high = r.daily.temperature_2m_max.first ?? nil, let low = r.daily.temperature_2m_min.first ?? nil else {
            throw URLError(.cannotParseResponse)
        }
        return Forecast(place: place.name, fetched: Date(), day: r.daily.time.first ?? Day.key(Date()),
                        now: r.current?.temperature_2m, high: high, low: low,
                        rain: (r.daily.precipitation_probability_max?.first ?? nil) ?? 0,
                        code: (r.daily.weather_code.first ?? nil) ?? 3)
    }

    /// The forecast of each day of a trip, as far as Open-Meteo knows it (16 days from today).
    /// Days further away come back without temperatures.
    static func trip(_ place: Place, start: Date, days: Int) async throws -> [TripPlan.Day] {
        let calendar = Calendar.current
        let keys = (0..<max(1, days)).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }.map { Day.key($0) }
        guard let first = keys.first, let last = keys.last else { return [] }
        let horizon = Day.key(calendar.date(byAdding: .day, value: 15, to: Date()) ?? Date())
        let today = Day.key(Date())
        guard first <= horizon, last >= today else { return keys.map { TripPlan.Day(day: $0) } }
        var url = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        url.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.2f", place.latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.2f", place.longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,precipitation_probability_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "start_date", value: max(first, today)),
            URLQueryItem(name: "end_date", value: min(last, horizon)),
        ]
        struct Response: Decodable {
            struct Daily: Decodable {
                let time: [String]
                let temperature_2m_max: [Double?]
                let temperature_2m_min: [Double?]
                let precipitation_probability_max: [Int?]?
            }
            let daily: Daily
        }
        let (data, response) = try await URLSession.shared.data(from: url.url!)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 { throw URLError(.badServerResponse) }
        let daily = try JSONDecoder().decode(Response.self, from: data).daily
        var known: [String: TripPlan.Day] = [:]
        for (i, day) in daily.time.enumerated() {
            known[day] = TripPlan.Day(day: day,
                                      high: daily.temperature_2m_max[safe: i] ?? nil,
                                      low: daily.temperature_2m_min[safe: i] ?? nil,
                                      rain: daily.precipitation_probability_max?[safe: i] ?? nil)
        }
        return keys.map { known[$0] ?? TripPlan.Day(day: $0) }
    }

    private static func townName(of location: CLLocation) async -> String? {
        let marks = try? await CLGeocoder().reverseGeocodeLocation(location)
        return marks?.first.flatMap { $0.locality ?? $0.subAdministrativeArea ?? $0.name }
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

/// One position, asked for when needed (never in the background).
@MainActor
final class LocationOnce: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private static var current: LocationOnce?

    static func fetch() async throws -> CLLocation {
        let once = LocationOnce()
        current = once
        defer { current = nil }
        return try await withCheckedThrowingContinuation { continuation in
            once.continuation = continuation
            once.manager.delegate = once
            once.manager.desiredAccuracy = kCLLocationAccuracyKilometer
            switch once.manager.authorizationStatus {
            case .notDetermined: once.manager.requestWhenInUseAuthorization()
            case .denied, .restricted: once.finish(.failure(CLError(.denied)))
            default: once.manager.requestLocation()
            }
        }
    }

    private func finish(_ result: Result<CLLocation, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: self.manager.requestLocation()
            case .denied, .restricted: self.finish(.failure(CLError(.denied)))
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in self.finish(.success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(.failure(error)) }
    }
}

extension Array {
    /// The element at `index`, or nil past the end.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
