import SwiftUI
import EventKit
import Combine

struct LayoutEvent: Identifiable {
    let id: String
    let event: EKEvent
    let startMinutes: Int
    let durationMinutes: Int
    let column: Int
    let totalColumns: Int
}

struct AgendaListView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var weatherManager: WeatherManager = WeatherManager.shared
    
    @State private var currentTime: Date = Date()
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    
    private var displayedDates: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: currentTime)
        let count = max(1, min(settings.timelineDaysCount, 3))
        
        let baseDate: Date
        if count > 1 {
            // When displaying multiple days (2 or 3 days), the leftmost column is ALWAYS Today
            // (or a future selected date if explicitly browsing upcoming future days)
            if calendar.startOfDay(for: settings.selectedDate) > today {
                baseDate = calendar.startOfDay(for: settings.selectedDate)
            } else {
                baseDate = today
            }
        } else {
            // 1-day mode: show selected date
            baseDate = calendar.startOfDay(for: settings.selectedDate)
        }
        
        return (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: baseDate) }
    }
    
    private var startHour: Int {
        switch settings.timelineDisplayMode {
        case .fitDaytime: return 7
        case .fit24, .scroll: return 0
        }
    }
    
    private var endHour: Int { 24 }
    private var totalDisplayHours: Int { endHour - startHour }
    
    private var currentHour: Int {
        Calendar.current.component(.hour, from: currentTime)
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = settings.is24HourFormat ? "HH:mm" : "h:mm a"
        return formatter.string(from: currentTime)
    }
    
    // Smart Auto-Scroll for scroll mode
    private var smartScrollHour: Int {
        let nowHour = currentHour
        var bestHour = max(0, nowHour - 1)
        
        for date in displayedDates {
            let timed = calendarManager.events(for: date).filter { !$0.isAllDay }
            for e in timed {
                let sHour = Calendar.current.component(.hour, from: e.startDate)
                let eHour = Calendar.current.component(.hour, from: e.endDate)
                
                if Calendar.current.isDateInToday(date) {
                    if eHour >= nowHour && sHour < bestHour {
                        bestHour = sHour
                    }
                } else if date > Date() && sHour < bestHour {
                    bestHour = sHour
                }
            }
        }
        return max(0, min(bestHour, 20))
    }
    
    private func getMinutesSinceMidnight(_ d: Date) -> Int {
        let comp = Calendar.current.dateComponents([.hour, .minute], from: d)
        return (comp.hour ?? 0) * 60 + (comp.minute ?? 0)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 0. Location & Live Current Time Header Bar
            HStack(spacing: 4) {
                // Location & Timezone Indicator with Country Flag
                HStack(spacing: 4) {
                    if !weatherManager.countryFlag.isEmpty {
                        Text(weatherManager.countryFlag)
                            .font(.system(size: 13))
                    } else {
                        Image(systemName: "location.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.accentColor)
                    }
                    
                    Text(weatherManager.locationName.isEmpty ? "現在地 (JST)" : "\(weatherManager.locationName) (\(weatherManager.timezoneInfo))")
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
                                            .font(.system(size: CGFloat(settings.eventFontSize), weight: .bold))
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
            
            // 3. Grid Area (Fit to Window or Scrollable)
            GeometryReader { geometry in
                let availableHeight = max(120, geometry.size.height)
                
                if settings.timelineDisplayMode == .scroll {
                    // Scroll Mode (Fixed 40px/hour)
                    let hourHeight: CGFloat = 40.0
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            renderTimelineGrid(
                                hourHeight: hourHeight,
                                startHour: 0,
                                totalHours: 24,
                                containerHeight: CGFloat(24) * hourHeight,
                                proxy: proxy
                            )
                        }
                        .onAppear {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                proxy.scrollTo("hour_\(smartScrollHour)", anchor: .top)
                            }
                        }
                    }
                } else {
                    // Fit Mode (No Scrolling - Scale to window height perfectly)
                    let hourHeight = availableHeight / CGFloat(totalDisplayHours)
                    renderTimelineGrid(
                        hourHeight: hourHeight,
                        startHour: startHour,
                        totalHours: totalDisplayHours,
                        containerHeight: availableHeight,
                        proxy: nil
                    )
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .onAppear {
            if settings.timelineDaysCount > 1 && !Calendar.current.isDateInToday(settings.selectedDate) {
                settings.selectedDate = Date()
                settings.currentMonthDate = Date()
            }
        }
        .onReceive(timer) { newTime in
            self.currentTime = newTime
            let cal = Calendar.current
            if settings.timelineDaysCount > 1 && !cal.isDate(settings.selectedDate, inSameDayAs: newTime) {
                settings.selectedDate = newTime
                settings.currentMonthDate = newTime
            }
        }
    }
    
    @ViewBuilder
    private func renderTimelineGrid(
        hourHeight: CGFloat,
        startHour: Int,
        totalHours: Int,
        containerHeight: CGFloat,
        proxy: ScrollViewProxy?
    ) -> some View {
        HStack(alignment: .top, spacing: 0) {
            // Left Hour Labels Column + Live Now Badge
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    ForEach(0..<totalHours, id: \.self) { offset in
                        let hour = startHour + offset
                        let shouldShow = shouldShowHourLabel(hour: hour, hourHeight: hourHeight)
                        
                        Text(shouldShow ? formatHour(hour) : "")
                            .font(.system(size: hourHeight < 24 ? 8.5 : 9.5, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 40, height: hourHeight, alignment: .topTrailing)
                            .offset(y: -6)
                            .id("hour_\(hour)")
                    }
                }
                
                // Red Current Time Badge on Hour Axis (if in visible range)
                if displayedDates.contains(where: { Calendar.current.isDateInToday($0) }) {
                    let minutesSinceMidnight = getMinutesSinceMidnight(currentTime)
                    let startMinutes = startHour * 60
                    let endMinutes = (startHour + totalHours) * 60
                    
                    if minutesSinceMidnight >= startMinutes && minutesSinceMidnight <= endMinutes {
                        let relMinutes = minutesSinceMidnight - startMinutes
                        let yOffset = CGFloat(relMinutes) / 60.0 * hourHeight
                        
                        Text(currentTimeString)
                            .font(.system(size: hourHeight < 24 ? 7.5 : 8.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.red)
                            .cornerRadius(3)
                            .offset(y: yOffset - 7)
                            .zIndex(30)
                    }
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
                            
                            if hourHeight >= 28 {
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                                
                                Spacer()
                            }
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
                            startHour: startHour,
                            hourHeight: hourHeight,
                            totalHours: totalHours,
                            currentTime: currentTime,
                            eventFontSize: settings.eventFontSize,
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
            .frame(height: containerHeight)
        }
        .padding(.top, 4)
    }
    
    private func shouldShowHourLabel(hour: Int, hourHeight: CGFloat) -> Bool {
        if hourHeight < 22 {
            // 3-hour interval (0, 3, 6, 9, 12, 15, 18, 21)
            return hour % 3 == 0
        } else if hourHeight < 32 {
            // 2-hour interval (0, 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22)
            return hour % 2 == 0
        } else {
            return true
        }
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
            
            HStack(spacing: 3) {
                ZStack {
                    if isToday {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 21, height: 21)
                        Text(dayNumberString)
                            .font(.system(size: 11.5, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(dayNumberString)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(numberColor)
                    }
                }
                
                // Day Weather Forecast Badge (Icon + High/Low Temps: e.g. ⛅️ 28°/19° + Rain chance if >= 20%)
                if let w = weather {
                    HStack(spacing: 2) {
                        Image(systemName: w.iconName)
                            .font(.system(size: 9.5))
                            .foregroundColor(w.iconColor)
                        
                        HStack(spacing: 1.5) {
                            Text("\(w.maxTemp)°")
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.95))
                            
                            Text("/")
                                .font(.system(size: 8, weight: .regular))
                                .foregroundColor(.white.opacity(0.35))
                            
                            Text("\(w.minTemp)°")
                                .font(.system(size: 8.5, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                            
                            if w.precipProbMax >= 20 || w.isRainyOrSnow {
                                Text("\(w.precipProbMax)%")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(red: 0.35, green: 0.8, blue: 1.0))
                                    .padding(.leading, 1)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct DayTimelineColumn: View {
    let date: Date
    let startHour: Int
    let hourHeight: CGFloat
    let totalHours: Int
    let currentTime: Date
    let eventFontSize: Double
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
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let layoutEvents = computeEventLayout(timedEvents)
            
            ZStack(alignment: .topLeading) {
                Color.clear
                    .frame(height: CGFloat(totalHours) * hourHeight)
                
                // Hourly Weather Layer (Subtle badges at 3-hour intervals)
                if showWeather {
                    ForEach(0..<totalHours, id: \.self) { offset in
                        let hour = startHour + offset
                        if (hour % 3 == 0),
                           let hw = weatherManager.hourlyForecast(for: date, hour: hour) {
                            let yOffset = CGFloat(offset) * hourHeight
                            HStack(spacing: 2) {
                                Spacer()
                                
                                HStack(spacing: 2.5) {
                                    Image(systemName: hw.iconName)
                                        .font(.system(size: hourHeight < 24 ? 7.5 : 8))
                                        .foregroundColor(hw.iconColor.opacity(0.9))
                                    
                                    Text("\(hw.temp)°")
                                        .font(.system(size: hourHeight < 24 ? 7.5 : 8.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white.opacity(0.55))
                                    
                                    if hw.precipProb >= 20 || hw.isRainyOrSnow {
                                        Text("\(hw.precipProb)%")
                                            .font(.system(size: hourHeight < 24 ? 7.0 : 7.5, weight: .bold, design: .rounded))
                                            .foregroundColor(Color(red: 0.35, green: 0.8, blue: 1.0))
                                    }
                                }
                                .padding(.horizontal, 3.5)
                                .padding(.vertical, 1)
                                .background(Color.black.opacity(0.25))
                                .cornerRadius(3.5)
                                .padding(.trailing, 3)
                            }
                            .frame(height: 14)
                            .offset(y: yOffset + 2)
                        }
                    }
                }
                
                // Current Time Line (Red Now Line with Glowing indicator)
                if isToday {
                    let minutesSinceMidnight = getMinutesSinceMidnight(currentTime)
                    let startMinutes = startHour * 60
                    let endMinutes = (startHour + totalHours) * 60
                    
                    if minutesSinceMidnight >= startMinutes && minutesSinceMidnight <= endMinutes {
                        let relMinutes = minutesSinceMidnight - startMinutes
                        let yOffset = CGFloat(relMinutes) / 60.0 * hourHeight
                        
                        HStack(spacing: 0) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                                .shadow(color: .red.opacity(0.8), radius: 3)
                            Rectangle()
                                .fill(Color.red)
                                .frame(height: 1.5)
                        }
                        .offset(y: yOffset - 3)
                        .zIndex(20)
                    }
                }
                
                // Overlap-Aware Side-by-Side Event Blocks
                ForEach(layoutEvents) { item in
                    let startMinutes = item.startMinutes
                    let endMinutes = item.startMinutes + item.durationMinutes
                    let windowStartMinutes = startHour * 60
                    let windowEndMinutes = (startHour + totalHours) * 60
                    
                    // Check if event is within visible hour window
                    if endMinutes > windowStartMinutes && startMinutes < windowEndMinutes {
                        let visibleStart = max(startMinutes, windowStartMinutes) - windowStartMinutes
                        let visibleEnd = min(endMinutes, windowEndMinutes) - windowStartMinutes
                        let visibleDuration = max(15, visibleEnd - visibleStart)
                        
                        let totalCols = CGFloat(item.totalColumns)
                        let hSpacing: CGFloat = 2.0
                        let totalHSpacing = hSpacing * (totalCols - 1)
                        let itemWidth = max(24.0, (availableWidth - 4 - totalHSpacing) / totalCols)
                        let xOffset = 2.0 + CGFloat(item.column) * (itemWidth + hSpacing)
                        let yOffset = CGFloat(visibleStart) / 60.0 * hourHeight
                        let blockHeight = max(18.0, CGFloat(visibleDuration) / 60.0 * hourHeight - 1.5)
                        let calColor = Color(nsColor: NSColor(cgColor: item.event.calendar.cgColor) ?? .systemBlue)
                        
                        let baseFontSize = CGFloat(eventFontSize)
                        let titleSize = hourHeight < 24 ? max(7.5, baseFontSize - 1.5) : (item.totalColumns > 1 ? max(8.0, baseFontSize - 1.0) : baseFontSize)
                        let subSize = max(7.0, titleSize - 2.0)
                        
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text(item.event.title ?? "名称未設定")
                                .font(.system(size: titleSize, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                            
                            if blockHeight > 22 && hourHeight >= 22 {
                                Text(formatTimeRange(start: item.event.startDate, end: item.event.endDate))
                                    .font(.system(size: subSize, weight: .medium))
                                    .foregroundColor(.white.opacity(0.9))
                                    .lineLimit(1)
                            }
                        }
                        .padding(.horizontal, 3.5)
                        .padding(.vertical, 1.5)
                        .frame(width: itemWidth, height: blockHeight, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                .fill(calColor.opacity(0.92))
                                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
                        )
                        .offset(x: xOffset, y: yOffset)
                        .zIndex(10)
                    }
                }
            }
        }
        .frame(height: CGFloat(totalHours) * hourHeight)
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
    
    // Apple Calendar Overlap Layout Algorithm
    private func computeEventLayout(_ events: [EKEvent]) -> [LayoutEvent] {
        let sorted = events.sorted { e1, e2 in
            if e1.startDate == e2.startDate {
                return e1.endDate > e2.endDate
            }
            return e1.startDate < e2.startDate
        }
        
        guard !sorted.isEmpty else { return [] }
        
        var clusters: [[EKEvent]] = []
        var currentCluster: [EKEvent] = []
        var clusterEnd: Date? = nil
        
        for event in sorted {
            if let end = clusterEnd, event.startDate < end {
                currentCluster.append(event)
                if event.endDate > end {
                    clusterEnd = event.endDate
                }
            } else {
                if !currentCluster.isEmpty {
                    clusters.append(currentCluster)
                }
                currentCluster = [event]
                clusterEnd = event.endDate
            }
        }
        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }
        
        var result: [LayoutEvent] = []
        
        for cluster in clusters {
            var columnEndTimes: [Date] = []
            var clusterAssignments: [(event: EKEvent, col: Int)] = []
            
            for event in cluster {
                var placed = false
                for (colIdx, end) in columnEndTimes.enumerated() {
                    if event.startDate >= end {
                        columnEndTimes[colIdx] = event.endDate
                        clusterAssignments.append((event, colIdx))
                        placed = true
                        break
                    }
                }
                if !placed {
                    let newCol = columnEndTimes.count
                    columnEndTimes.append(event.endDate)
                    clusterAssignments.append((event, newCol))
                }
            }
            
            let totalCols = max(1, columnEndTimes.count)
            for item in clusterAssignments {
                let startMinutes = getMinutesSinceMidnight(item.event.startDate)
                let durationMinutes = max(15, Calendar.current.dateComponents([.minute], from: item.event.startDate, to: item.event.endDate).minute ?? 30)
                
                result.append(LayoutEvent(
                    id: item.event.eventIdentifier ?? UUID().uuidString,
                    event: item.event,
                    startMinutes: startMinutes,
                    durationMinutes: durationMinutes,
                    column: item.col,
                    totalColumns: totalCols
                ))
            }
        }
        
        return result
    }
}
