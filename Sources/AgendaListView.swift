import SwiftUI
import EventKit
import Combine

struct AgendaListView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var weatherManager: WeatherManager = WeatherManager.shared
    
    @State private var currentTime: Date = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private let hourHeight: CGFloat = 40.0
    private let totalHours: Int = 24
    
    private var displayedDates: [Date] {
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: settings.selectedDate)
        let count = max(1, min(settings.timelineDaysCount, 3))
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: baseDate) }
    }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: currentTime)
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = settings.is24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: currentTime)
    }
    
    // Earliest event hour across displayed dates for smart initial scroll
    private var initialScrollHour: Int {
        var earliest = currentHour - 1
        for date in displayedDates {
            let timed = calendarManager.events(for: date).filter { !$0.isAllDay }
            for e in timed {
                let hour = Calendar.current.component(.hour, from: e.startDate)
                if hour < earliest {
                    earliest = hour
                }
            }
        }
        return max(0, min(earliest, 20))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 0. Location & Live Current Time Header Bar
            HStack(spacing: 4) {
                // Location & Timezone Indicator
                HStack(spacing: 3) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(.accentColor)
                    
                    Text(weatherManager.fullLocationLabel.isEmpty ? "現在地 (JST)" : weatherManager.fullLocationLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.primary.opacity(0.9))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Live Current Clock Badge
                HStack(spacing: 3) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text("現在: " + currentTimeString)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.12))
                .cornerRadius(5)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
            
            // 1. Day Headers Row (Apple Calendar Style with Weather & Sat/Sun colors)
            HStack(spacing: 0) {
                // Left spacer matching hour label width
                Color.clear.frame(width: 44)
                
                ForEach(displayedDates, id: \.self) { date in
                    AppleCalendarDayHeader(
                        date: date,
                        weather: settings.showWeather ? weatherManager.forecast(for: date) : nil
                    )
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 42)
            .padding(.bottom, 2)
            
            // 2. All-Day Events Section (Between Date Headers & 24h Timeline)
            let hasAnyAllDay = displayedDates.contains { !calendarManager.events(for: $0).filter { $0.isAllDay }.isEmpty }
            if hasAnyAllDay {
                VStack(spacing: 0) {
                    Divider()
                        .background(Color.white.opacity(0.12))
                    
                    HStack(alignment: .top, spacing: 0) {
                        Text("終日")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary.opacity(0.9))
                            .frame(width: 44, alignment: .trailing)
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                        
                        ForEach(displayedDates, id: \.self) { date in
                            let allDayList = calendarManager.events(for: date).filter { $0.isAllDay }
                            VStack(spacing: 3) {
                                if allDayList.isEmpty {
                                    Color.clear.frame(height: 4)
                                } else {
                                    ForEach(allDayList, id: \.eventIdentifier) { event in
                                        let calColor = Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue)
                                        Text(event.title ?? "終日予定")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2.5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                                    .fill(calColor.opacity(0.9))
                                            )
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 2)
                            .padding(.vertical, 3)
                        }
                    }
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.03))
                    
                    Divider()
                        .background(Color.white.opacity(0.12))
                }
            } else {
                Divider()
                    .background(Color.white.opacity(0.12))
            }
            
            // 3. 24-Hour Scrollable Grid (0:00 to 23:00)
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        // Left Hour Labels Column (0:00 - 23:00) + Live Now Badge
                        ZStack(alignment: .topTrailing) {
                            VStack(spacing: 0) {
                                ForEach(0..<totalHours, id: \.self) { hour in
                                    Text(formatHour(hour))
                                        .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 40, height: hourHeight, alignment: .topTrailing)
                                        .offset(y: -6)
                                        .id("hour_\(hour)")
                                }
                            }
                            
                            // Red Current Time Badge on Hour Axis (if displayed dates contains today)
                            if displayedDates.contains(where: { Calendar.current.isDateInToday($0) }) {
                                let minutesSinceMidnight = getMinutesSinceMidnight(currentTime)
                                let yOffset = CGFloat(minutesSinceMidnight) / 60.0 * hourHeight
                                
                                Text(currentTimeString)
                                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3.5)
                                    .padding(.vertical, 1)
                                    .background(Color.red)
                                    .cornerRadius(3)
                                    .offset(y: yOffset - 7)
                                    .zIndex(30)
                            }
                        }
                        .frame(width: 44)
                        
                        // Multi-Day Columns Area
                        ZStack(alignment: .topLeading) {
                            // Horizontal Gridlines
                            VStack(spacing: 0) {
                                ForEach(0..<totalHours, id: \.self) { _ in
                                    VStack(spacing: 0) {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.18))
                                            .frame(height: 1)
                                        
                                        Spacer()
                                        
                                        Rectangle()
                                            .fill(Color.white.opacity(0.06))
                                            .frame(height: 1)
                                        
                                        Spacer()
                                    }
                                    .frame(height: hourHeight)
                                }
                            }
                            
                            // Day Columns with Vertical Dividers
                            HStack(spacing: 0) {
                                ForEach(displayedDates.indices, id: \.self) { idx in
                                    let date = displayedDates[idx]
                                    DayTimelineColumn(
                                        date: date,
                                        hourHeight: hourHeight,
                                        totalHours: totalHours,
                                        currentTime: currentTime,
                                        events: calendarManager.events(for: date),
                                        is24HourFormat: settings.is24HourFormat,
                                        showWeather: settings.showWeather,
                                        weatherManager: weatherManager
                                    )
                                    .frame(maxWidth: .infinity)
                                    
                                    if idx < displayedDates.count - 1 {
                                        Rectangle()
                                            .fill(Color.white.opacity(0.18))
                                            .frame(width: 1)
                                    }
                                }
                            }
                        }
                        .frame(height: CGFloat(totalHours) * hourHeight)
                    }
                    .padding(.top, 4)
                }
                .onAppear {
                    proxy.scrollTo("hour_\(initialScrollHour)", anchor: .top)
                }
                .onReceive(timer) { newTime in
                    self.currentTime = newTime
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    private func getMinutesSinceMidnight(_ d: Date) -> Int {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (comp.hour ?? 0) * 60 + (comp.minute ?? 0)
    }
    
    private func formatHour(_ hour: Int) -> String {
        if settings.is24HourFormat {
            return String(format: "%d:00", hour)
        } else {
            let h = hour % 12 == 0 ? 12 : hour % 12
            let ampm = hour < 12 ? "AM" : "PM"
            return "\(h) \(ampm)"
        }
    }
}

struct AppleCalendarDayHeader: View {
    let date: Date
    let weather: DayWeather?
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var weekday: Int {
        Calendar.current.component(.weekday, from: date)
    }
    
    private var weekdayString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private var dayNumberString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var headerColor: Color {
        if isToday {
            return Color.red
        }
        if weekday == 1 { // Sunday
            return Color(red: 1.0, green: 0.35, blue: 0.35)
        } else if weekday == 7 { // Saturday
            return Color(red: 0.35, green: 0.65, blue: 1.0)
        } else {
            return Color.secondary
        }
    }
    
    private var numberColor: Color {
        if isToday {
            return .white
        }
        if weekday == 1 { // Sunday
            return Color(red: 1.0, green: 0.35, blue: 0.35)
        } else if weekday == 7 { // Saturday
            return Color(red: 0.35, green: 0.65, blue: 1.0)
        } else {
            return .white
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(weekdayString)
                .font(.system(size: 10.5, weight: .bold))
                .foregroundColor(headerColor)
            
            HStack(spacing: 4) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 22, height: 22)
                        Text(dayNumberString)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(dayNumberString)
                            .font(.system(size: 12.5, weight: .bold))
                            .foregroundColor(numberColor)
                    }
                }
                
                // Day Weather Forecast Badge (Icon + Max/Min)
                if let w = weather {
                    HStack(spacing: 2) {
                        Image(systemName: w.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(w.iconColor)
                        
                        Text("\(w.maxTemp)°")
                            .font(.system(size: 9.5, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
            }
        }
    }
}

struct DayTimelineColumn: View {
    let date: Date
    let hourHeight: CGFloat
    let totalHours: Int
    let currentTime: Date
    let events: [EKEvent]
    let is24HourFormat: Bool
    let showWeather: Bool
    let weatherManager: WeatherManager
    
    private var timedEvents: [EKEvent] {
        events.filter { !$0.isAllDay }
    }
    
    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear
                .frame(height: CGFloat(totalHours) * hourHeight)
            
            // Hourly Weather Layer (Subtle badges at every 3-hour intervals: 0, 3, 6, 9, 12, 15, 18, 21)
            if showWeather {
                ForEach(0..<totalHours, id: \.self) { hour in
                    if (hour % 3 == 0),
                       let hw = weatherManager.hourlyForecast(for: date, hour: hour) {
                        let yOffset = CGFloat(hour) * hourHeight
                        HStack(spacing: 2) {
                            Spacer()
                            
                            HStack(spacing: 2.5) {
                                Image(systemName: hw.iconName)
                                    .font(.system(size: 8))
                                    .foregroundColor(hw.iconColor.opacity(0.9))
                                
                                Text("\(hw.temp)°")
                                    .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.55))
                            }
                            .padding(.horizontal, 3.5)
                            .padding(.vertical, 1.5)
                            .background(Color.black.opacity(0.25))
                            .cornerRadius(3.5)
                            .padding(.trailing, 3)
                        }
                        .frame(height: 16)
                        .offset(y: yOffset + 2)
                    }
                }
            }
            
            // Current Time Line (Red Now Line with Glowing indicator)
            if isToday {
                let minutesSinceMidnight = getMinutesSinceMidnight(currentTime)
                let yOffset = CGFloat(minutesSinceMidnight) / 60.0 * hourHeight
                
                HStack(spacing: 0) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .shadow(color: .red.opacity(0.8), radius: 3)
                    Rectangle()
                        .fill(Color.red)
                        .frame(height: 1.5)
                }
                .offset(y: yOffset - 3.5)
                .zIndex(20)
            }
            
            // Timed Event Blocks
            ForEach(timedEvents, id: \.eventIdentifier) { event in
                let startMinutes = getMinutesSinceMidnight(event.startDate)
                let durationMinutes = max(20, Calendar.current.dateComponents([.minute], from: event.startDate, to: event.endDate).minute ?? 30)
                
                let yOffset = CGFloat(startMinutes) / 60.0 * hourHeight
                let blockHeight = max(22.0, CGFloat(durationMinutes) / 60.0 * hourHeight - 2)
                let calColor = Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title ?? "名称未設定")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if blockHeight > 26 {
                        Text(formatTimeRange(start: event.startDate, end: event.endDate))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: blockHeight, alignment: .topLeading)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(calColor.opacity(0.9))
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                )
                .padding(.horizontal, 2)
                .offset(y: yOffset)
                .zIndex(10)
            }
        }
    }
    
    private func getMinutesSinceMidnight(_ d: Date) -> Int {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (comp.hour ?? 0) * 60 + (comp.minute ?? 0)
    }
    
    private func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = is24HourFormat ? "H:mm" : "h:mm a"
        return "\(formatter.string(from: start))-\(formatter.string(from: end))"
    }
}
