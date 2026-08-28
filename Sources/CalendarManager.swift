import Foundation
import EventKit
import Combine
import SwiftUI

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()
    let store = EKEventStore()
    
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var availableCalendars: [EKCalendar] = []
    @Published var availableReminderLists: [EKCalendar] = []
    @Published var isAuthorized: Bool = false
    @Published var authorizationError: String? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreChanged),
            name: .EKEventStoreChanged,
            object: nil
        )
        requestAccess()
    }
    
    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] grantedEvents, error in
                self?.store.requestFullAccessToReminders { grantedReminders, rError in
                    DispatchQueue.main.async {
                        self?.isAuthorized = grantedEvents || grantedReminders
                        if let error = error ?? rError {
                            self?.authorizationError = error.localizedDescription
                        }
                        self?.fetchCalendarsList()
                        self?.fetchData()
                    }
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    self?.fetchCalendarsList()
                    self?.fetchData()
                }
            }
        }
    }
    
    func fetchCalendarsList() {
        guard isAuthorized else { return }
        self.availableCalendars = store.calendars(for: .event).sorted { c1, c2 in
            if c1.source.title == c2.source.title {
                return c1.title < c2.title
            }
            return c1.source.title < c2.source.title
        }
        self.availableReminderLists = store.calendars(for: .reminder).sorted { c1, c2 in
            if c1.source.title == c2.source.title {
                return c1.title < c2.title
            }
            return c1.source.title < c2.source.title
        }
    }
    
    @objc private func eventStoreChanged() {
        DispatchQueue.main.async {
            self.fetchCalendarsList()
            self.fetchData()
        }
    }
    
    func fetchData(for month: Date = Date()) {
        guard isAuthorized else { return }
        
        let settings = AppSettings.shared
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return }
        
        // Ensure calendar list is populated
        if availableCalendars.isEmpty {
            self.availableCalendars = store.calendars(for: .event)
        }
        if availableReminderLists.isEmpty {
            self.availableReminderLists = store.calendars(for: .reminder)
        }
        
        // Filter event calendars
        let enabledCalendars = availableCalendars.filter { settings.isCalendarEnabled($0.calendarIdentifier) }
        
        if enabledCalendars.isEmpty {
            self.events = []
        } else {
            let startDate = calendar.date(byAdding: .day, value: -30, to: monthInterval.start) ?? monthInterval.start
            let endDate = calendar.date(byAdding: .day, value: 60, to: monthInterval.end) ?? monthInterval.end
            
            let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: enabledCalendars)
            let fetchedEvents = store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
            self.events = fetchedEvents
        }
        
        // Filter reminder lists
        let enabledReminderLists = availableReminderLists.filter { settings.isReminderListEnabled($0.calendarIdentifier) }
        
        if enabledReminderLists.isEmpty {
            self.reminders = []
        } else {
            let reminderPredicate = store.predicateForReminders(in: enabledReminderLists)
            store.fetchReminders(matching: reminderPredicate) { [weak self] fetchedReminders in
                DispatchQueue.main.async {
                    self?.reminders = (fetchedReminders ?? []).sorted { r1, r2 in
                        guard let d1 = r1.dueDateComponents?.date else { return false }
                        guard let d2 = r2.dueDateComponents?.date else { return true }
                        return d1 < d2
                    }
                }
            }
        }
    }
    
    func toggleReminderCompletion(_ reminder: EKReminder) {
        reminder.isCompleted.toggle()
        if reminder.isCompleted {
            reminder.completionDate = Date()
        } else {
            reminder.completionDate = nil
        }
        do {
            try store.save(reminder, commit: true)
            fetchData()
        } catch {
            print("Failed to save reminder completion: \(error)")
        }
    }
    
    func events(for date: Date) -> [EKEvent] {
        let calendar = Calendar.current
        guard let dayInterval = calendar.dateInterval(of: .day, for: date) else { return [] }
        
        return events.filter { event in
            if event.isAllDay {
                return (event.startDate < dayInterval.end) && (event.endDate > dayInterval.start)
            } else {
                return (event.startDate < dayInterval.end) && (event.endDate > dayInterval.start)
            }
        }
    }
}
