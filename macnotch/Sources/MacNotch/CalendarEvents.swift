import EventKit
import Foundation
import Combine

struct CalendarEventItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let calendarTitle: String
    let isAllDay: Bool
}

@MainActor
final class CalendarEventsController: ObservableObject {
    @Published private(set) var events: [CalendarEventItem] = []
    @Published private(set) var busy = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var message = "Calendar access is requested only when you choose Load Events."

    private let eventStore = EKEventStore()

    func loadUpcomingEvents() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .notDetermined {
                guard try await eventStore.requestFullAccessToEvents() else {
                    message = "Calendar access was not granted. You can enable it in System Settings → Privacy & Security → Calendars."
                    return
                }
            }
            let updatedStatus = EKEventStore.authorizationStatus(for: .event)
            guard updatedStatus == .fullAccess else {
                message = "Allow full calendar access in System Settings → Privacy & Security → Calendars to read upcoming events."
                return
            }

            let start = Date()
            let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 24 * 60 * 60)
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            events = eventStore.events(matching: predicate)
                .sorted { $0.startDate < $1.startDate }
                .prefix(40)
                .map { event in
                    CalendarEventItem(id: event.eventIdentifier ?? UUID().uuidString,
                                      title: event.title ?? "Untitled event",
                                      start: event.startDate,
                                      end: event.endDate,
                                      calendarTitle: event.calendar.title,
                                      isAllDay: event.isAllDay)
                }
            hasLoaded = true
            message = events.isEmpty ? "No upcoming events in the next seven days." : "Showing your next \(events.count) events. Calendar data stays on this Mac."
        } catch {
            message = "Could not load calendar events: \(error.localizedDescription)"
        }
    }
}

struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let dueDate: Date?
    let listTitle: String
}

@MainActor
final class CalendarTasksController: ObservableObject {
    @Published private(set) var reminders: [ReminderItem] = []
    @Published private(set) var busy = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var message = "Reminder access is requested only when you choose Load Reminders."

    private let eventStore = EKEventStore()

    func loadUpcomingReminders() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let status = EKEventStore.authorizationStatus(for: .reminder)
            if status == .notDetermined {
                guard try await eventStore.requestFullAccessToReminders() else {
                    message = "Reminder access was not granted. You can enable it in System Settings → Privacy & Security → Reminders."
                    return
                }
            }
            let updatedStatus = EKEventStore.authorizationStatus(for: .reminder)
            guard updatedStatus == .fullAccess else {
                message = "Allow full reminder access in System Settings → Privacy & Security → Reminders to load tasks."
                return
            }
            let end = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
            let predicate = eventStore.predicateForIncompleteReminders(withDueDateStarting: nil, ending: end, calendars: nil)
            let items: [ReminderItem] = await withCheckedContinuation { continuation in
                eventStore.fetchReminders(matching: predicate) { fetched in
                    let mapped = (fetched ?? []).map { reminder in
                        let dueDate = reminder.dueDateComponents.flatMap { Calendar.current.date(from: $0) }
                        return ReminderItem(id: reminder.calendarItemIdentifier,
                                            title: reminder.title,
                                            dueDate: dueDate,
                                            listTitle: reminder.calendar.title)
                    }.sorted {
                        switch ($0.dueDate, $1.dueDate) {
                        case let (left?, right?): left < right
                        case (_?, nil): true
                        case (nil, _?): false
                        case (nil, nil): $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                        }
                    }
                    continuation.resume(returning: mapped)
                }
            }
            reminders = Array(items.prefix(40))
            hasLoaded = true
            message = reminders.isEmpty ? "No incomplete reminders due in the next 30 days." : "Showing \(reminders.count) incomplete reminders."
        } catch {
            message = "Could not load reminders: \(error.localizedDescription)"
        }
    }

    func complete(_ item: ReminderItem) {
        guard let reminder = eventStore.calendarItem(withIdentifier: item.id) as? EKReminder else {
            message = "This reminder is no longer available. Refresh the list and try again."
            return
        }
        reminder.isCompleted = true
        reminder.completionDate = Date()
        do {
            try eventStore.save(reminder, commit: true)
            reminders.removeAll { $0.id == item.id }
            message = "Marked “\(item.title)” complete."
        } catch {
            message = "Could not complete reminder: \(error.localizedDescription)"
        }
    }
}
