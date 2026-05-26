import Foundation

enum ReminderTimeFormatters {
    /// Builds RFC3339 string in UTC (`...Z`) for a given calendar day and HH:mm time in the supplied IANA timezone.
    /// UTC формат используем чтобы избежать проблемы с `+` в URL-параметрах.
    static func makeRFC3339(date: Date, time: String, timezoneID: String?) -> String {
        let tz = TimeZone(identifier: timezoneID ?? "") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        let parts = time.split(separator: ":")
        let hour = Int(parts.first ?? "") ?? 0
        let minute = parts.count > 1 ? (Int(parts[1]) ?? 0) : 0

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = tz

        let composed = calendar.date(from: components) ?? date

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: composed)
    }

    static func parseRFC3339(_ string: String) -> Date? {
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFractional.date(from: string) { return date }

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }

    static func slotDateString(_ date: Date, timezoneID: String?) -> String {
        let tz = TimeZone(identifier: timezoneID ?? "") ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func slotTimeString(_ date: Date, timezoneID: String?) -> String {
        let tz = TimeZone(identifier: timezoneID ?? "") ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
