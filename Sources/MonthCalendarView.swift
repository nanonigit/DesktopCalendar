import SwiftUI
import EventKit

struct MonthCalendarView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var weatherManager: WeatherManager = WeatherManager.shared
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = settings.firstDayOfWeek
        return cal
    }
    
    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Header
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(monthYearFormatter.string(from: settings.currentMonthDate))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Spacer(minLength: 2)
                    
                    Button(action: {
                        withAnimation {
                            settings.currentMonthDate = Date()
                            settings.selectedDate = Date()
                            calendarManager.fetchData(for: settings.currentMonthDate)
                        }
                    }) {
                        Text("今日")
                            .font(.system(size: 10, weight: .semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    
                    HStack(spacing: 2) {
                        Button(action: { changeMonth(by: -1) }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 10, weight: .bold))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { changeMonth(by: 1) }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .padding(5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // Recognized Location & Timezone Indicator
                if !weatherManager.fullLocationLabel.isEmpty {
                    HStack(spacing: 3) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 7.5))
                            .foregroundColor(.accentColor)
                        
                        Text(weatherManager.fullLocationLabel)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.85))
                            .lineLimit(1)
                    }
                    .padding(.top, 1)
                }
            }
            .padding(.horizontal, 2)
            
            // Weekday Headers (Sunday: Red, Saturday: Blue)
            let weekdayInfos = getWeekdayInfos()
            HStack(spacing: 0) {
                ForEach(weekdayInfos, id: \.symbol) { info in
                    Text(info.symbol)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(
                            info.weekday == 1 ? Color(red: 1.0, green: 0.35, blue: 0.35) :
                            info.weekday == 7 ? Color(red: 0.35, green: 0.65, blue: 1.0) :
                            .white.opacity(0.85)
                        )
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Days Grid
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        DayCellView(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: settings.selectedDate),
                            isToday: calendar.isDateInToday(date),
                            isCurrentMonth: calendar.isDate(date, equalTo: settings.currentMonthDate, toGranularity: .month),
                            events: calendarManager.events(for: date)
                        )
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                settings.selectedDate = date
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 32)
                    }
                }
            }
        }
    }
    
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: settings.currentMonthDate) {
            withAnimation {
                settings.currentMonthDate = newDate
                calendarManager.fetchData(for: newDate)
            }
        }
    }
    
    struct WeekdayInfo {
        let symbol: String
        let weekday: Int // 1: Sun, 7: Sat
    }
    
    private func getWeekdayInfos() -> [WeekdayInfo] {
        let rawSymbols = ["日", "月", "火", "水", "木", "金", "土"]
        let rawWeekdays = [1, 2, 3, 4, 5, 6, 7]
        let shift = settings.firstDayOfWeek - 1
        
        let shiftedSymbols = Array(rawSymbols[shift...] + rawSymbols[..<shift])
        let shiftedWeekdays = Array(rawWeekdays[shift...] + rawWeekdays[..<shift])
        
        return zip(shiftedSymbols, shiftedWeekdays).map { WeekdayInfo(symbol: $0.0, weekday: $0.1) }
    }
    
    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: settings.currentMonthDate),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }
        
        var days: [Date?] = []
        var currentDate = monthFirstWeek.start
        
        while currentDate < monthInterval.end || days.count % 7 != 0 {
            days.append(currentDate)
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
            if days.count >= 42 { break }
        }
        return days
    }
}

struct DayCellView: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let events: [EKEvent]
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var weekday: Int {
        Calendar.current.component(.weekday, from: date)
    }
    
    private var textColor: Color {
        if isSelected {
            return .white
        }
        if isToday {
            return .white
        }
        
        if weekday == 1 { // Sunday -> Red
            return isCurrentMonth ? Color(red: 1.0, green: 0.35, blue: 0.35) : Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.35)
        } else if weekday == 7 { // Saturday -> Blue
            return isCurrentMonth ? Color(red: 0.35, green: 0.65, blue: 1.0) : Color(red: 0.35, green: 0.65, blue: 1.0).opacity(0.35)
        } else {
            return isCurrentMonth ? .white : .white.opacity(0.3)
        }
    }
    
    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 24, height: 24)
                } else if isToday {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 24, height: 24)
                }
                
                Text(dayNumber)
                    .font(.system(size: 12, weight: isToday || isSelected ? .bold : .medium))
                    .foregroundColor(textColor)
            }
            
            // Event Dots
            HStack(spacing: 2) {
                ForEach(events.prefix(3), id: \.eventIdentifier) { event in
                    Circle()
                        .fill(Color(nsColor: NSColor(cgColor: event.calendar.cgColor) ?? .systemBlue))
                        .frame(width: 3.5, height: 3.5)
                }
            }
            .frame(height: 3.5)
        }
        .frame(height: 32)
        .contentShape(Rectangle())
    }
}
