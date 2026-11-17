import Foundation
import UserNotifications

/// The morning reminder: a notification at the chosen time with the idea of the day and the
/// weather, made on this iPhone (no server, no push). It is written again each time the app opens,
/// so it carries the idea for the next morning.
enum Reminders {
    static let enabledKey = "morningReminder"
    static let hourKey = "morningReminderHour"
    static let minuteKey = "morningReminderMinute"
    private static let id = "shadowwear.morning"

    /// Asks the permission once; false when the user said no.
    static func allow() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    /// Writes the next morning's notification (or removes it when the reminder is off).
    static func schedule(enabled: Bool, hour: Int, minute: Int, idea: String?, laundry: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Cosa mettere oggi")
        var body = idea.map { String(localized: "Idea: \($0).") } ?? String(localized: "Apri ShadowWear: c'è un'idea per oggi, con il meteo.")
        if laundry > 0 { body += " " + String(localized: "Da lavare: \(laundry).") }
        content.body = body
        content.sound = .default
        var when = DateComponents()
        when.hour = hour
        when.minute = minute
        // Repeats every day; the words are refreshed whenever the app is opened.
        let trigger = UNCalendarNotificationTrigger(dateMatching: when, repeats: true)
        try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
