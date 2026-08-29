import Foundation
import SwiftUI
import Combine
import CoreLocation

struct WeatherAlert: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
    let detail: String
    
    static func == (lhs: WeatherAlert, rhs: WeatherAlert) -> Bool {
        lhs.title == rhs.title && lhs.detail == rhs.detail
    }
}

struct GeocodingCityResult: Identifiable, Hashable {
    let id: Int
    let name: String
    let admin1: String? // Prefecture / State
    let country: String
    let countryCode: String?
    let latitude: Double
    let longitude: Double
    let timezone: String
    
    var flag: String {
        WeatherManager.flagEmoji(for: country, code: countryCode)
    }
    
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
    let precipProbMax: Int
    let alert: WeatherAlert?
    
    var iconName: String {
        WeatherManager.weatherIcon(for: weatherCode)
    }
    
    var iconColor: Color {
        WeatherManager.weatherColor(for: weatherCode)
    }
    
    var isRainyOrSnow: Bool {
        return (51...67).contains(weatherCode) || (80...82).contains(weatherCode) || (71...77).contains(weatherCode) || (85...86).contains(weatherCode) || (95...99).contains(weatherCode)
    }
}

struct HourlyWeather: Identifiable {
    let id = UUID()
    let dateString: String // "yyyy-MM-dd"
    let hour: Int          // 0...23
    let weatherCode: Int
    let temp: Int
    let precipProb: Int
    
    var iconName: String {
        WeatherManager.weatherIcon(for: weatherCode, hour: hour)
    }
    
    var iconColor: Color {
        WeatherManager.weatherColor(for: weatherCode)
    }
    
    var isRainyOrSnow: Bool {
        return (51...67).contains(weatherCode) || (80...82).contains(weatherCode) || (71...77).contains(weatherCode) || (85...86).contains(weatherCode) || (95...99).contains(weatherCode)
    }
}

class WeatherManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = WeatherManager()
    
    @Published var dailyForecasts: [String: DayWeather] = [:]
    @Published var hourlyForecasts: [String: [Int: HourlyWeather]] = [:]
    @Published var locationName: String = "検出中..."
    @Published var countryFlag: String = ""
    @Published var timezoneInfo: String = ""
    @Published var fullLocationLabel: String = ""
    @Published var activeAlert: WeatherAlert? = nil
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
    
    // Country flag emoji converter (ISO 3166-1 alpha-2 or country name)
    static func flagEmoji(for country: String? = nil, code: String? = nil) -> String {
        if let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased(), code.count == 2 {
            let base: UInt32 = 127397
            var s = ""
            var valid = true
            for scalar in code.unicodeScalars {
                guard scalar.value >= 65 && scalar.value <= 90 else { valid = false; break }
                if let flagScalar = UnicodeScalar(base + scalar.value) {
                    s.unicodeScalars.append(flagScalar)
                }
            }
            if valid && !s.isEmpty { return s }
        }
        
        guard let country = country?.trimmingCharacters(in: .whitespacesAndNewlines), !country.isEmpty else {
            return "🇯🇵"
        }
        
        let lower = country.lowercased()
        if lower.contains("日本") || lower.contains("japan") { return "🇯🇵" }
        if lower.contains("アメリカ") || lower.contains("米国") || lower.contains("united states") || lower.contains("usa") { return "🇺🇸" }
        if lower.contains("イギリス") || lower.contains("英国") || lower.contains("united kingdom") || lower.contains("uk") { return "🇬🇧" }
        if lower.contains("タイ") || lower.contains("thailand") { return "🇹🇭" }
        if lower.contains("シンガポール") || lower.contains("singapore") { return "🇸🇬" }
        if lower.contains("ベトナム") || lower.contains("vietnam") { return "🇻🇳" }
        if lower.contains("韓国") || lower.contains("korea") { return "🇰🇷" }
        if lower.contains("台湾") || lower.contains("taiwan") { return "🇹🇼" }
        if lower.contains("中国") || lower.contains("china") { return "🇨🇳" }
        if lower.contains("ミャンマー") || lower.contains("myanmar") || lower.contains("ヤンゴン") || lower.contains("yangon") { return "🇲🇲" }
        if lower.contains("フランス") || lower.contains("france") { return "🇫🇷" }
        if lower.contains("ドイツ") || lower.contains("germany") { return "🇩🇪" }
        if lower.contains("イタリア") || lower.contains("italy") { return "🇮🇹" }
        if lower.contains("スペイン") || lower.contains("spain") { return "🇪🇸" }
        if lower.contains("オーストラリア") || lower.contains("australia") { return "🇦🇺" }
        if lower.contains("カナダ") || lower.contains("canada") { return "🇨🇦" }
        if lower.contains("インドネシア") || lower.contains("indonesia") { return "🇮🇩" }
        if lower.contains("マレーシア") || lower.contains("malaysia") { return "🇲🇾" }
        if lower.contains("フィリピン") || lower.contains("philippines") { return "🇵🇭" }
        if lower.contains("カンボジア") || lower.contains("cambodia") { return "🇰🇭" }
        if lower.contains("ラオス") || lower.contains("laos") { return "🇱🇦" }
        if lower.contains("オランダ") || lower.contains("netherlands") { return "🇳🇱" }
        if lower.contains("スイス") || lower.contains("switzerland") { return "🇨🇭" }
        if lower.contains("スウェーデン") || lower.contains("sweden") { return "🇸🇪" }
        if lower.contains("ニュージーランド") || lower.contains("new zealand") { return "🇳🇿" }
        if lower.contains("ハワイ") || lower.contains("hawaii") { return "🇺🇸" }
        
        return "🌐"
    }
    
    static func weatherIcon(for code: Int, hour: Int? = nil) -> String {
        let isNight = (hour != nil) ? (hour! < 6 || hour! >= 19) : false
        
        switch code {
        case 0:
            return isNight ? "moon.stars.fill" : "sun.max.fill"
        case 1, 2:
            return isNight ? "cloud.moon.fill" : "cloud.sun.fill"
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
            return isNight ? "moon.fill" : "sun.max.fill"
        }
    }
    
    static func weatherColor(for code: Int) -> Color {
        switch code {
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
    
    // Worldwide Severe Weather & Alert Detection (WMO / JMA / NOAA Standards)
    static func computeAlert(weatherCode: Int, maxTemp: Int, minTemp: Int, precipSum: Double, windGustsMax: Double) -> WeatherAlert? {
        // 1. Typhoon / Gale / Storm Warning (windGusts in km/h: 65 km/h ≈ 18 m/s, 85 km/h ≈ 24 m/s)
        if windGustsMax >= 85.0 {
            return WeatherAlert(title: "暴風・台風警報", icon: "wind", color: Color(red: 1.0, green: 0.3, blue: 0.3), detail: String(format: "最大突風 %.0f km/h", windGustsMax))
        } else if windGustsMax >= 65.0 {
            return WeatherAlert(title: "強風・突風注意", icon: "wind", color: Color(red: 1.0, green: 0.6, blue: 0.2), detail: String(format: "最大突風 %.0f km/h", windGustsMax))
        }
        
        // 2. Heavy Rain / Torrential Rain / Flood Warning
        if precipSum >= 70.0 || weatherCode == 82 {
            return WeatherAlert(title: "大雨・豪雨警報", icon: "exclamationmark.triangle.fill", color: Color(red: 1.0, green: 0.3, blue: 0.3), detail: String(format: "予測降水量 %.0f mm", precipSum))
        } else if precipSum >= 40.0 || weatherCode == 65 {
            return WeatherAlert(title: "大雨警戒", icon: "exclamationmark.triangle.fill", color: Color(red: 1.0, green: 0.6, blue: 0.2), detail: String(format: "予測降水量 %.0f mm", precipSum))
        }
        
        // 3. Thunderstorm / Severe Squall (95, 96, 99)
        if weatherCode == 96 || weatherCode == 99 {
            return WeatherAlert(title: "激しい雷雨・雹警報", icon: "bolt.fill", color: Color(red: 1.0, green: 0.35, blue: 0.35), detail: "落雷・突風・降雹に警戒")
        } else if weatherCode == 95 {
            return WeatherAlert(title: "雷雨・スコール警戒", icon: "bolt.fill", color: Color(red: 1.0, green: 0.65, blue: 0.2), detail: "落雷・急な強雨に警戒")
        }
        
        // 4. Extreme Heat Warning
        if maxTemp >= 38 {
            return WeatherAlert(title: "極度猛暑警戒", icon: "sun.max.fill", color: Color(red: 1.0, green: 0.25, blue: 0.25), detail: "熱中症に厳重警戒")
        } else if maxTemp >= 35 {
            return WeatherAlert(title: "猛暑警戒", icon: "sun.max.fill", color: Color(red: 1.0, green: 0.55, blue: 0.2), detail: "熱中症に警戒")
        }
        
        // 5. Heavy Snow / Blizzard
        if weatherCode == 86 || weatherCode == 75 {
            return WeatherAlert(title: "大雪・吹雪警報", icon: "snowflake", color: Color(red: 0.4, green: 0.8, blue: 1.0), detail: "積雪・吹雪に警戒")
        }
        
        return nil
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
            let flag = WeatherManager.flagEmoji(for: settings.manualCountryName, code: settings.manualCountryCode)
            
            let label = "\(flag) \(settings.manualCityName) (\(gmtString))"
            
            DispatchQueue.main.async {
                self.locationName = settings.manualCityName
                self.countryFlag = flag
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
            var country = ""
            var countryCode = ""
            
            if let place = placemarks?.first {
                country = place.country ?? ""
                countryCode = place.isoCountryCode ?? ""
                
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
            
            let flag = WeatherManager.flagEmoji(for: country, code: countryCode)
            let label = "\(flag) \(name) (\(gmtString))"
            
            DispatchQueue.main.async {
                self?.locationName = name
                self?.countryFlag = flag
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
            var countryCodeStr = ""
            
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
                if let code = json["countryCode"] as? String {
                    countryCodeStr = code
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
            
            let flag = WeatherManager.flagEmoji(for: countryStr, code: countryCodeStr)
            let label = "\(flag) \(locDisplay) (\(gmtString))"
            
            DispatchQueue.main.async {
                self?.locationName = locDisplay
                self?.countryFlag = flag
                self?.timezoneInfo = gmtString
                self?.fullLocationLabel = label
            }
            
            self?.fetchForecast(lat: lat, lon: lon, timezone: tz)
        }.resume()
    }
    
    private func fetchForecast(lat: Double, lon: Double, timezone: String) {
        let tzEncoded = timezone.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Asia/Tokyo"
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=weathercode,temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum,windgusts_10m_max,windspeed_10m_max&hourly=weathercode,temperature_2m,precipitation_probability,windgusts_10m&timezone=\(tzEncoded)"
        
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
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return
            }
            
            // 1. Initial Parse Daily Forecast
            var dailyDict: [String: DayWeather] = [:]
            if let daily = json["daily"] as? [String: Any],
               let times = daily["time"] as? [String],
               let codes = daily["weathercode"] as? [Int],
               let maxTemps = daily["temperature_2m_max"] as? [Double],
               let minTemps = daily["temperature_2m_min"] as? [Double] {
                
                let precipMaxList = daily["precipitation_probability_max"] as? [Int] ?? []
                let precipSumList = daily["precipitation_sum"] as? [Double] ?? []
                let windGustsList = daily["windgusts_10m_max"] as? [Double] ?? []
                
                for i in 0..<times.count {
                    guard i < codes.count, i < maxTemps.count, i < minTemps.count else { break }
                    let pMax = i < precipMaxList.count ? precipMaxList[i] : 0
                    let pSum = i < precipSumList.count ? precipSumList[i] : 0.0
                    let wGust = i < windGustsList.count ? windGustsList[i] : 0.0
                    let mxT = Int(round(maxTemps[i]))
                    let mnT = Int(round(minTemps[i]))
                    
                    let alert = WeatherManager.computeAlert(
                        weatherCode: codes[i],
                        maxTemp: mxT,
                        minTemp: mnT,
                        precipSum: pSum,
                        windGustsMax: wGust
                    )
                    
                    let item = DayWeather(
                        dateString: times[i],
                        weatherCode: codes[i],
                        maxTemp: mxT,
                        minTemp: mnT,
                        precipProbMax: pMax,
                        alert: alert
                    )
                    dailyDict[times[i]] = item
                }
            }
            
            // 2. Parse Hourly Forecast & Strictly Harmonize Daily Max/Min from Hourly Values
            if let hourly = json["hourly"] as? [String: Any],
               let hTimes = hourly["time"] as? [String],
               let hCodes = hourly["weathercode"] as? [Int],
               let hTemps = hourly["temperature_2m"] as? [Double] {
                
                let hPrecipList = hourly["precipitation_probability"] as? [Int] ?? []
                
                var hDict: [String: [Int: HourlyWeather]] = [:]
                for i in 0..<hTimes.count {
                    guard i < hCodes.count, i < hTemps.count else { break }
                    let rawTime = hTimes[i] // e.g. "2026-08-28T14:00"
                    let parts = rawTime.split(separator: "T")
                    guard parts.count == 2 else { continue }
                    let datePart = String(parts[0])
                    let hourPart = parts[1].split(separator: ":").first.flatMap { Int($0) } ?? 0
                    let precip = i < hPrecipList.count ? hPrecipList[i] : 0
                    
                    let item = HourlyWeather(
                        dateString: datePart,
                        hour: hourPart,
                        weatherCode: hCodes[i],
                        temp: Int(round(hTemps[i])),
                        precipProb: precip
                    )
                    
                    if hDict[datePart] == nil {
                        hDict[datePart] = [:]
                    }
                    hDict[datePart]?[hourPart] = item
                }
                
                // Guarantee 100% consistency: Header Max/Min must strictly equal the actual 24-hour extremes
                for (dateStr, hourMap) in hDict {
                    let temps = hourMap.values.map { $0.temp }
                    let precips = hourMap.values.map { $0.precipProb }
                    
                    if !temps.isEmpty {
                        let actualMax = temps.max() ?? 0
                        let actualMin = temps.min() ?? 0
                        let maxPrecip = precips.max() ?? (dailyDict[dateStr]?.precipProbMax ?? 0)
                        let existingCode = dailyDict[dateStr]?.weatherCode ?? hourMap[12]?.weatherCode ?? 0
                        let existingAlert = dailyDict[dateStr]?.alert
                        
                        dailyDict[dateStr] = DayWeather(
                            dateString: dateStr,
                            weatherCode: existingCode,
                            maxTemp: actualMax,
                            minTemp: actualMin,
                            precipProbMax: maxPrecip,
                            alert: existingAlert
                        )
                    }
                }
                
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let keyToday = formatter.string(from: Date())
                let todayAlert = dailyDict[keyToday]?.alert
                
                DispatchQueue.main.async {
                    self?.hourlyForecasts = hDict
                    self?.dailyForecasts = dailyDict
                    self?.activeAlert = todayAlert
                }
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let keyToday = formatter.string(from: Date())
                let todayAlert = dailyDict[keyToday]?.alert
                
                DispatchQueue.main.async {
                    self?.dailyForecasts = dailyDict
                    self?.activeAlert = todayAlert
                }
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
                let countryCode = item["country_code"] as? String
                
                list.append(GeocodingCityResult(
                    id: id,
                    name: name,
                    admin1: admin1,
                    country: country,
                    countryCode: countryCode,
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
        settings.manualCountryCode = city.countryCode ?? ""
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
    
    func hourlyForecast(for date: Date, hour: Int) -> HourlyWeather? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return hourlyForecasts[key]?[hour]
    }
}
