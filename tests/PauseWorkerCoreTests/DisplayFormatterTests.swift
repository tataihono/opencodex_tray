import XCTest
@testable import PauseWorkerCore

final class DisplayFormatterTests: XCTestCase {
    func testFormatsTrayAndAccountRows() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let resetAt = now.addingTimeInterval((2 * 86_400) + 1)
        let row = AccountAllowance(
            accountId: "friend-id",
            label: "workmate",
            remainingPercent: 4.25,
            totalPercent: 17.5,
            resetAt: resetAt
        )
        let summary = QuotaSummary(trayPercentage: 27, rows: [row])

        XCTAssertEqual(DisplayFormatter.trayTitle(summary, now: now), "27% 3d")
        XCTAssertEqual(DisplayFormatter.row(row, now: now), "workmate: 4.25% 3d")
    }

    func testOmitsResetDaysWhenResetIsUnavailable() {
        let summary = QuotaSummary(trayPercentage: nil, rows: [])

        XCTAssertEqual(DisplayFormatter.trayTitle(summary), "—")
        XCTAssertEqual(DisplayFormatter.row(AccountAllowance(
            accountId: "friend-id",
            label: "workmate",
            remainingPercent: 4.25,
            totalPercent: 17.5
        )), "workmate: 4.25%")
    }

    func testFormatsClaudeFiveHourThenWeeklyRemainingForTrayAndDropdown() {
        let summary = ClaudeQuotaSummary(
            fiveHourRemainingPercentage: 50,
            weeklyRemainingPercentage: 20,
            rows: []
        )
        let row = ClaudeAccountAllowance(
            accountId: "claude-a",
            label: "work",
            fiveHourRemainingPercent: 50.25,
            weeklyRemainingPercent: 20
        )
        let partialRow = ClaudeAccountAllowance(
            accountId: "claude-b",
            label: "personal",
            fiveHourRemainingPercent: nil,
            weeklyRemainingPercent: 20
        )

        XCTAssertEqual(DisplayFormatter.claudeTrayTitle(summary), "50%/20%")
        XCTAssertEqual(DisplayFormatter.claudeRow(row), "work: 50.25%/20%")
        XCTAssertEqual(DisplayFormatter.claudeRow(partialRow), "personal: —/20%")
    }
}
