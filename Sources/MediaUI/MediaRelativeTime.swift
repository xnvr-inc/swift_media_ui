import Foundation

public enum MediaRelativeTime {
    /// Format the largest elapsed unit without switching to a calendar date.
    public static func korean(since date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let elapsed = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        if let years = elapsed.year, years > 0 { return "\(years)년 전" }
        if let months = elapsed.month, months > 0 { return "\(months)개월 전" }
        if let days = elapsed.day, days >= 7 { return "\(days / 7)주 전" }
        if let days = elapsed.day, days > 0 { return "\(days)일 전" }
        if let hours = elapsed.hour, hours > 0 { return "\(hours)시간 전" }
        if let minutes = elapsed.minute, minutes > 0 { return "\(minutes)분 전" }
        return "방금 전"
    }
}
