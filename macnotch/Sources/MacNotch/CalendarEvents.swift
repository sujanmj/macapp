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
            guard updatedStatus == .fullAccess || updatedStatus == .authorized else {
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
