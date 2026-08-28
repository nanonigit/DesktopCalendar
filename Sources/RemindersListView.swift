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
                    // Completed today
                    return compDate >= startOfToday
                case .todayTomorrow:
                    // Completed today or tomorrow
                    return compDate >= startOfToday && compDate < calendar.date(byAdding: .day, value: 2, to: startOfToday)!
                case .threeDays:
                    // Completed within last 3 days
                    guard let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: startOfToday) else { return true }
                    return compDate >= threeDaysAgo
                case .oneWeek:
                    // Completed within last 7 days
                    guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: startOfToday) else { return true }
                    return compDate >= weekAgo
                case .twoWeeks:
                    // Completed within last 14 days
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
                            ReminderRowView(reminder: reminder, calendarManager: calendarManager)
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
    
    var body: some View {
        HStack(spacing: 6) {
            Text(reminder.title ?? "名称未設定")
                .font(.system(size: 11.5, weight: .medium))
                .strikethrough(reminder.isCompleted)
                .foregroundColor(reminder.isCompleted ? .secondary.opacity(0.5) : .white)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            if reminder.isCompleted {
                if let compDate = reminder.completionDate {
                    Text("完了: " + formatCompletionDate(compDate))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.6))
                        .lineLimit(1)
                }
            } else if let dueDate = reminder.dueDateComponents?.date {
                Text(formatDueDate(dueDate))
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundColor(isOverdue(dueDate) ? Color(red: 1.0, green: 0.4, blue: 0.4) : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white.opacity(reminder.isCompleted ? 0.02 : 0.05))
        .cornerRadius(5)
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if Calendar.current.isDateInToday(date) {
            formatter.dateFormat = "今日 HH:mm"
        } else {
            formatter.dateFormat = "M/d"
        }
        return formatter.string(from: date)
    }
    
    private func formatCompletionDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        if Calendar.current.isDateInToday(date) {
            return "今日"
        } else {
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        }
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !Calendar.current.isDateInToday(date)
    }
}
