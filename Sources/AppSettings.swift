import SwiftUI
import Combine
import ServiceManagement

enum ReminderDateRange: String, CaseIterable, Identifiable {
    case today = "today"
    case todayTomorrow = "2days"
    case threeDays = "3days"
    case oneWeek = "1week"
    case twoWeeks = "2weeks"
    case all = "all"
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .today: return "今日のみ"
        case .todayTomorrow: return "今日と明日"
        case .threeDays: return "3日間"
        case .oneWeek: return "1週間"
        case .twoWeeks: return "2週間"
        case .all: return "すべて"
        }
    }
}

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @AppStorage("windowX") var windowX: Double = 30.0
    @AppStorage("windowY") var windowY: Double = 50.0
    @AppStorage("windowWidth") var windowWidth: Double = 920.0
    @AppStorage("windowHeight") var windowHeight: Double = 540.0
    @AppStorage("leftPanelWidth") var leftPanelWidth: Double = 230.0
    
    @AppStorage("backgroundOpacity") var backgroundOpacity: Double = 0.55
    @AppStorage("blurRadius") var blurRadius: Double = 20.0
    @AppStorage("isDarkTheme") var isDarkTheme: Bool = true
    
    @AppStorage("firstDayOfWeek") var firstDayOfWeek: Int = 1 // 1: Sunday, 2: Monday
    @AppStorage("is24HourFormat") var is24HourFormat: Bool = true
    
    @AppStorage("showMonthCalendar") var showMonthCalendar: Bool = true
    @AppStorage("showAgenda") var showAgenda: Bool = true
    @AppStorage("showReminders") var showReminders: Bool = true
    @AppStorage("showCompletedReminders") var showCompletedReminders: Bool = false
    @AppStorage("showWeather") var showWeather: Bool = true
    @AppStorage("reminderDateRange") var reminderDateRangeRaw: String = ReminderDateRange.all.rawValue
    
    @AppStorage("timelineDaysCount") var timelineDaysCount: Int = 1 // 1, 2, or 3 days
    
    @AppStorage("showMenuBarExtra") var showMenuBarExtra: Bool = true {
        didSet {
            NotificationCenter.default.post(name: Notification.Name("MenuBarVisibilityChanged"), object: nil)
        }
    }
    
    var reminderDateRange: ReminderDateRange {
        get { ReminderDateRange(rawValue: reminderDateRangeRaw) ?? .all }
        set {
            reminderDateRangeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = true
    
    @AppStorage("disabledCalendarIDs") var disabledCalendarIDsJSON: String = "[]"
    @AppStorage("disabledReminderListIDs") var disabledReminderListIDsJSON: String = "[]"
    
    @Published var selectedDate: Date = Date()
    @Published var currentMonthDate: Date = Date()
    
    var disabledCalendarIDs: Set<String> {
        get {
            guard let data = disabledCalendarIDsJSON.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(array)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue)),
               let str = String(data: data, encoding: .utf8) {
                disabledCalendarIDsJSON = str
                objectWillChange.send()
            }
        }
    }
    
    var disabledReminderListIDs: Set<String> {
        get {
            guard let data = disabledReminderListIDsJSON.data(using: .utf8),
                  let array = try? JSONDecoder().decode([String].self, from: data) else {
                return []
            }
            return Set(array)
        }
        set {
            if let data = try? JSONEncoder().encode(Array(newValue)),
               let str = String(data: data, encoding: .utf8) {
                disabledReminderListIDsJSON = str
                objectWillChange.send()
            }
        }
    }
    
    func isCalendarEnabled(_ id: String) -> Bool {
        return !disabledCalendarIDs.contains(id)
    }
    
    func toggleCalendar(_ id: String) {
        var current = disabledCalendarIDs
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        disabledCalendarIDs = current
    }
    
    func isReminderListEnabled(_ id: String) -> Bool {
        return !disabledReminderListIDs.contains(id)
    }
    
    func toggleReminderList(_ id: String) {
        var current = disabledReminderListIDs
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        disabledReminderListIDs = current
    }
    
    func setLaunchAtLogin(_ enabled: Bool) {
        self.launchAtLogin = enabled
        
        let appPath = "/Applications/DesktopCalendar.app"
        if enabled {
            let script = "tell application \"System Events\" to if not (exists (login items whose name is \"DesktopCalendar\")) then make login item at end with properties {path:\"\(appPath)\", hidden:false, name:\"DesktopCalendar\"}"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        } else {
            let script = "tell application \"System Events\" to delete (login items whose name is \"DesktopCalendar\")"
            var error: NSDictionary?
            NSAppleScript(source: script)?.executeAndReturnError(&error)
        }
    }
}
