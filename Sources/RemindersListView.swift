import SwiftUI
import EventKit

struct RemindersListView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var calendarManager: CalendarManager
    
    private var filteredReminders: [EKReminder] {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        
        return calendarManager.reminders.filter { reminder in
            if reminder.isCompleted {
                // Completed reminders filter
                guard settings.showCompletedReminders else { return false }
                
                let compDate = reminder.completionDate ?? reminder.dueDateComponents?.date ?? Date.distantPast
                
                switch settings.reminderDateRange {
                case .today:
                    return compDate >= startOfToday
                case .todayTomorrow:
                    return compDate >= startOfToday && compDate < calendar.date(byAdding: .day, value: 2, to: startOfToday)!
                case .threeDays:
                    guard let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: startOfToday) else { return true }
                    return compDate >= threeDaysAgo
                case .oneWeek:
                    guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) else { return true }
                    return compDate >= weekAgo
                case .twoWeeks:
                    guard let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: startOfToday) else { return true }
                    return compDate >= twoWeeksAgo
                case .all:
                    return true
                }
            } else {
                // Incomplete reminders filter
                let dueDate = reminder.dueDateComponents?.date
                
                switch settings.reminderDateRange {
                case .today:
                    guard let d = dueDate else { return false }
                    return d < calendar.date(byAdding: .day, value: 1, to: startOfToday)!
                case .todayTomorrow:
                    guard let d = dueDate else { return false }
                    return d < calendar.date(byAdding: .day, value: 2, to: startOfToday)!
                case .threeDays:
                    guard let d = dueDate else { return false }
                    return d < calendar.date(byAdding: .day, value: 3, to: startOfToday)!
                case .oneWeek:
                    guard let d = dueDate else { return false }
                    return d < calendar.date(byAdding: .day, value: 7, to: startOfToday)!
                case .twoWeeks:
                    guard let d = dueDate else { return false }
                    return d < calendar.date(byAdding: .day, value: 14, to: startOfToday)!
                case .all:
                    return true
                }
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("リマインダー / ToDo")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                
                Spacer()
                
                // Date Range Menu Picker
                Menu {
                    ForEach(ReminderDateRange.allCases) { range in
                        Button(action: {
                            settings.reminderDateRange = range
                        }) {
                            HStack {
                                Text(range.label)
                                if settings.reminderDateRange == range {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text(settings.reminderDateRange.label)
                            .font(.system(size: 10, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
            
            if filteredReminders.isEmpty {
                HStack {
                    Spacer()
                    Text("該当するタスクはありません")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.vertical, 6)
                    Spacer()
                }
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 4) {
                        ForEach(filteredReminders, id: \.calendarItemIdentifier) { reminder in
                            ReminderRowView(
                                reminder: reminder,
                                calendarManager: calendarManager,
                                eventFontSize: settings.eventFontSize
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct ReminderRowView: View {
    let reminder: EKReminder
    let calendarManager: CalendarManager
    let eventFontSize: Double
    
    struct DueBadgeInfo {
        let text: String
        let textColor: Color
        let bgColor: Color?
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Text(reminder.title ?? "名称未設定")
                .font(.system(size: CGFloat(eventFontSize), weight: .medium))
                .strikethrough(reminder.isCompleted)
                .foregroundColor(reminder.isCompleted ? .secondary.opacity(0.5) : .white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            if reminder.isCompleted {
                if let compDate = reminder.completionDate {
                    Text(formatCompletion(compDate))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1.5)
                        .background(Color.white.opacity(0.04))
                        .cornerRadius(3)
                        .lineLimit(1)
                }
            } else if let dueDate = reminder.dueDateComponents?.date {
                let badge = getDueBadge(for: dueDate)
                Text(badge.text)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundColor(badge.textColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(badge.bgColor ?? Color.clear)
                    .cornerRadius(4)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3.5)
        .background(Color.white.opacity(reminder.isCompleted ? 0.02 : 0.05))
        .cornerRadius(5)
    }
    
    private func getDueBadge(for date: Date) -> DueBadgeInfo {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfDue = calendar.startOfDay(for: date)
        
        let daysDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfDue).day ?? 0
        
        if daysDiff < 0 {
            // 期限超過 (何日経過したか)
            let elapsedDays = abs(daysDiff)
            if elapsedDays == 1 {
                return DueBadgeInfo(
                    text: "昨日",
                    textColor: Color(red: 1.0, green: 0.8, blue: 0.2), // Yellow
                    bgColor: Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.18)
                )
            } else if elapsedDays <= 6 {
                return DueBadgeInfo(
                    text: "\(elapsedDays)日前",
                    textColor: Color(red: 1.0, green: 0.8, blue: 0.2), // Yellow (警告)
                    bgColor: Color(red: 1.0, green: 0.8, blue: 0.2).opacity(0.18)
                )
            } else {
                return DueBadgeInfo(
                    text: "\(elapsedDays)日前",
                    textColor: Color(red: 1.0, green: 0.35, blue: 0.35), // Red (1週間以上放置)
                    bgColor: Color(red: 1.0, green: 0.35, blue: 0.35).opacity(0.2)
                )
            }
        } else if daysDiff == 0 {
            // 今日
            let timeFormatter = DateFormatter()
            timeFormatter.dateFormat = "HH:mm"
            let timeStr = timeFormatter.string(from: date)
            let label = (timeStr == "00:00") ? "今日" : "今日 \(timeStr)"
            return DueBadgeInfo(
                text: label,
                textColor: Color(red: 0.35, green: 0.75, blue: 1.0), // Blue
                bgColor: Color(red: 0.35, green: 0.75, blue: 1.0).opacity(0.18)
            )
        } else if daysDiff == 1 {
            return DueBadgeInfo(
                text: "明日",
                textColor: .white.opacity(0.9),
                bgColor: Color.white.opacity(0.1)
            )
        } else if daysDiff == 2 {
            return DueBadgeInfo(
                text: "明後日",
                textColor: .white.opacity(0.75),
                bgColor: Color.white.opacity(0.06)
            )
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return DueBadgeInfo(
                text: formatter.string(from: date),
                textColor: .secondary,
                bgColor: nil
            )
        }
    }
    
    private func formatCompletion(_ date: Date) -> String {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let startOfComp = calendar.startOfDay(for: date)
        let daysDiff = calendar.dateComponents([.day], from: startOfToday, to: startOfComp).day ?? 0
        
        if daysDiff == 0 {
            return "完了: 今日"
        } else if daysDiff == -1 {
            return "完了: 昨日"
        } else if daysDiff < 0 {
            return "完了: \(abs(daysDiff))日前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d"
            return "完了: " + formatter.string(from: date)
        }
    }
}
