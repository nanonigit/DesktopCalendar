import Foundation
import SwiftUI
import Combine
import CoreLocation

struct GeocodingCityResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let admin1: String? // Prefecture / State
    let country: String
    let latitude: Double
    let longitude: Double
    let timezone: String
    
    var displayName: String {
        var parts: [String] = [name]
        if let admin = admin1, !admin.isEmpty, admin != name {
            parts.append(admin)
        }
        parts.append(country)
        return parts.joined(separator: ", ")
    }
}

struct DayWeather: Identifiable {
    let id = UUID()
    let dateString: String // "yyyy-MM-dd"
    let weatherCode: Int
    let maxTemp: Int
    let minTemp: Int
    
    var iconName: String {
        switch weatherCode {
        case 0:
            return "sun.max.fill"
        case 1, 2:
            return "cloud.sun.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55, 56, 57:
            return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67:
            return "cloud.rain.fill"
        case 71, 73, 75, 77:
            return "snowflake"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "sun.max.fill"
        }
    }
    
    var iconColor: Color {
        switch weatherCode {
        case 0:
            return Color(red: 1.0, green: 0.75, blue: 0.1)
        case 1, 2:
            return Color(red: 1.0, green: 0.8, blue: 0.2)
        case 3, 45, 48:
            return Color(white: 0.75)
        case 51...67, 80...82:
            return Color(red: 0.35, green: 0.7, blue: 1.0)
        case 71...77, 85, 86:
            return Color(red: 0.5, green: 0.85, blue: 1.0)
        case 95...99:
            return Color(red: 1.0, green: 0.85, blue: 0.2)
        default:
            return Color.yellow
        }
    }
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var dailyForecasts: [String: DayWeather] = [:]
    @Published var locationName: String = "検出中..."
    @Published var timezoneInfo: String = ""
    @Published var fullLocationLabel: String = ""
    @Published var isRefreshing: Bool = false
    
    @Published var searchResults: [GeocodingCityResult] = []
    @Published var isSearching: Bool = false
    
    private var locationManager: CLLocationManager?
    private let geocoder = CLGeocoder()
    
    override init() {
        super.init()
        setupLocationManager()
        fetchWeather()
    }
    
    private func setupLocationManager() {
        let lm = CLLocationManager()
        lm.delegate = self
        lm.desiredAccuracy = kCLLocationAccuracyKilometer
        self.locationManager = lm
    }
    
    func fetchWeather() {
        let settings = AppSettings.shared
        
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
        // Mode 1: Manual City Specified
        if settings.locationMode == "manual" && !settings.manualCityName.isEmpty && settings.manualLatitude != 0 {
            let tz = settings.manualTimezone.isEmpty ? TimeZone.current.identifier : settings.manualTimezone
            let currentTz = TimeZone(identifier: tz) ?? TimeZone.current
            let gmtOffsetHours = currentTz.secondsFromGMT() / 3600
            let gmtString = gmtOffsetHours >= 0 ? "GMT+\(gmtOffsetHours)" : "GMT\(gmtOffsetHours)"
            
            let label = "\(settings.manualCityName) (\(gmtString))"
            
            DispatchQueue.main.async {
                self.locationName = settings.manualCityName
                self.timezoneInfo = gmtString
                self.fullLocationLabel = label
            }
            
            fetchForecast(lat: settings.manualLatitude, lon: settings.manualLongitude, timezone: tz)
            return
        }
        
        // Mode 2: Auto Detect (CoreLocation -> IP Fallback)
        if let lm = locationManager {
            let status = lm.authorizationStatus
            if status == .notDetermined {
                lm.requestAlwaysAuthorization()
                lm.requestLocation()
            } else if status == .authorizedAlways {
                lm.requestLocation()
                return
            }
        }
        
        // Fallback to IP Geolocation
        fetchViaIP()
    }
    
    // CoreLocation Delegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            fetchViaIP()
            return
        }
        
        let lat = location.coordinate.latitude
        let lon = location.coordinate.longitude
        let currentTz = TimeZone.current
        let gmtOffsetHours = currentTz.secondsFromGMT() / 3600
        let gmtString = gmtOffsetHours >= 0 ? "GMT+\(gmtOffsetHours)" : "GMT\(gmtOffsetHours)"
        
        geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP")) { [weak self] placemarks, _ in
            var name = ""
            if let place = placemarks?.first {
                if let locality = place.locality {
                    name = locality
                    if let admin = place.administrativeArea, admin != locality {
                        name = "\(locality), \(admin)"
                    }
                } else if let nameStr = place.name {
                    name = nameStr
                }
            }
            
            if name.isEmpty {
                name = "現在地"
            }
            
            let label = "\(name) (\(gmtString))"
            DispatchQueue.main.async {
                self?.locationName = name
                self?.timezoneInfo = gmtString
                self?.fullLocationLabel = label
            }
            
            self?.fetchForecast(lat: lat, lon: lon, timezone: currentTz.identifier)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("CoreLocation failed: \(error), falling back to IP")
        fetchViaIP()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
    
    private func fetchViaIP() {
        guard let url = URL(string: "http://ip-api.com/json/") else {
            DispatchQueue.main.async { self.isRefreshing = false }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            var lat = 35.6895
            var lon = 139.6917
            var tz = TimeZone.current.identifier
            var cityStr = ""
            var countryStr = ""
            
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let latitude = json["lat"] as? Double,
                   let longitude = json["lon"] as? Double {
                    lat = latitude
                    lon = longitude
                }
                if let timezone = json["timezone"] as? String {
                    tz = timezone
                }
                if let cityName = json["city"] as? String {
                    cityStr = cityName
                }
                if let countryName = json["country"] as? String {
                    countryStr = countryName
                }
            }
            
            let currentTz = TimeZone(identifier: tz) ?? TimeZone.current
            let gmtOffsetHours = currentTz.secondsFromGMT() / 3600
            let gmtString = gmtOffsetHours >= 0 ? "GMT+\(gmtOffsetHours)" : "GMT\(gmtOffsetHours)"
            
            let locDisplay: String
            if !cityStr.isEmpty && !countryStr.isEmpty {
                locDisplay = "\(cityStr), \(countryStr)"
            } else if !countryStr.isEmpty {
                locDisplay = countryStr
            } else {
                locDisplay = currentTz.identifier.replacingOccurrences(of: "_", with: " ")
            }
            
            let label = "\(locDisplay) (\(gmtString))"
            
            DispatchQueue.main.async {
                self?.locationName = locDisplay
                self?.timezoneInfo = gmtString
                self?.fullLocationLabel = label
            }
            
            self?.fetchForecast(lat: lat, lon: lon, timezone: tz)
        }.resume()
    }
    
    private func fetchForecast(lat: Double, lon: Double, timezone: String) {
        let tzEncoded = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Asia/Tokyo"
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=\(tzEncoded)"
        
        guard let url = URL(string: urlStr) else {
            DispatchQueue.main.async { self.isRefreshing = false }
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            defer {
                DispatchQueue.main.async {
                    self?.isRefreshing = false
                }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let daily = json["daily"] as? [String: Any],
                  let times = daily["time"] as? [String],
                  let codes = daily["weathercode"] as? [Int],
                  let maxTemps = daily["temperature_2m_max"] as? [Double],
                  let minTemps = daily["temperature_2m_min"] as? [Double] else {
                return
            }
            
            var dict: [String: DayWeather] = [:]
            for i in 0..<times.count {
                guard i < codes.count, i < maxTemps.count, i < minTemps.count else { break }
                let item = DayWeather(
                    dateString: times[i],
                    weatherCode: codes[i],
                    maxTemp: Int(round(maxTemps[i])),
                    minTemp: Int(round(minTemps[i]))
                )
                dict[times[i]] = item
            }
            
            DispatchQueue.main.async {
                self?.dailyForecasts = dict
            }
        }.resume()
    }
    
    // City Search (Open-Meteo Geocoding)
    func searchCities(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async { self.searchResults = [] }
            return
        }
        
        guard let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=6&language=ja") else {
            return
        }
        
        DispatchQueue.main.async { self.isSearching = true }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            defer {
                DispatchQueue.main.async { self?.isSearching = false }
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]] else {
                DispatchQueue.main.async { self?.searchResults = [] }
                return
            }
            
            var list: [GeocodingCityResult] = []
            for item in results {
                guard let id = item["id"] as? Int,
                      let name = item["name"] as? String,
                      let lat = item["latitude"] as? Double,
                      let lon = item["longitude"] as? Double,
                      let country = item["country"] as? String,
                      let tz = item["timezone"] as? String else { continue }
                
                let admin1 = item["admin1"] as? String
                list.append(GeocodingCityResult(
                    id: id,
                    name: name,
                    admin1: admin1,
                    country: country,
                    latitude: lat,
                    longitude: lon,
                    timezone: tz
                ))
            }
            
            DispatchQueue.main.async {
                self?.searchResults = list
            }
        }.resume()
    }
    
    func selectCity(_ city: GeocodingCityResult) {
        let settings = AppSettings.shared
        settings.locationMode = "manual"
        settings.manualCityName = city.displayName
        settings.manualCountryName = city.country
        settings.manualLatitude = city.latitude
        settings.manualLongitude = city.longitude
        settings.manualTimezone = city.timezone
        
        self.searchResults = []
        fetchWeather()
    }
    
    func forecast(for date: Date) -> DayWeather? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyForecasts[key]
    }
}
