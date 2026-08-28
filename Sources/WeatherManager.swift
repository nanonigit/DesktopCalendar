import Foundation
import SwiftUI
import Combine

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

class WeatherManager: ObservableObject {
    static let shared = WeatherManager()
    
    @Published var dailyForecasts: [String: DayWeather] = [:]
    @Published var locationName: String = "検出中..."
    @Published var timezoneInfo: String = ""
    @Published var fullLocationLabel: String = ""
    @Published var isRefreshing: Bool = false
    
    init() {
        fetchWeather()
    }
    
    func fetchWeather() {
        DispatchQueue.main.async {
            self.isRefreshing = true
        }
        
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
    
    func forecast(for date: Date) -> DayWeather? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: date)
        return dailyForecasts[key]
    }
}
