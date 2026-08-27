import Foundation

public enum DisplayFormatter {
    public static func trayTitle(_ summary: QuotaSummary, now: Date = Date()) -> String {
        let percentage = summary.trayPercentage.map { "\($0)%" } ?? "—"
        guard let days = daysRemaining(until: summary.nearestResetAt, now: now) else {
            return percentage
        }
        return "\(percentage) \(days)d"
    }

    public static func row(_ allowance: AccountAllowance, now: Date = Date()) -> String {
        let remaining = allowance.remainingPercent.map(format) ?? "—"
        guard let days = daysRemaining(until: allowance.resetAt, now: now) else {
            return "\(allowance.label): \(remaining)%"
        }
        return "\(allowance.label): \(remaining)% \(days)d"
    }

    public static func claudeTrayTitle(_ summary: ClaudeQuotaSummary) -> String {
        "\(percentage(summary.fiveHourRemainingPercentage))/\(percentage(summary.weeklyRemainingPercentage))"
    }

    public static func claudeRow(_ allowance: ClaudeAccountAllowance) -> String {
        "\(allowance.label): \(percentage(allowance.fiveHourRemainingPercent))/\(percentage(allowance.weeklyRemainingPercent))"
    }

    private static func percentage(_ value: Int?) -> String {
        value.map { "\($0)%" } ?? "—"
    }

    private static func percentage(_ value: Double?) -> String {
        value.map { "\(format($0))%" } ?? "—"
    }

    private static func format(_ value: Double) -> String {
        var result = String(format: "%.2f", value)
        while result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result
    }

    private static func daysRemaining(until resetAt: Date?, now: Date) -> Int? {
        guard let resetAt else { return nil }
        let interval = max(resetAt.timeIntervalSince(now), 0)
        return Int(ceil(interval / 86_400))
    }
}
