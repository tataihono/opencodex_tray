import XCTest
@testable import PauseWorkerCore

final class QuotaCalculatorTests: XCTestCase {
    private let accounts = [
        OpenCodexAccount(id: "main-id", alias: nil, plan: "pro", isMain: true, paused: false, weeklyUsedPercent: 100),
        OpenCodexAccount(id: "friend-id", alias: "workmate", plan: "prolite", isMain: false, paused: false, weeklyUsedPercent: 53),
    ]

    func testTrayFloorsSumOfProEquivalentRemainingAllowances() throws {
        let summary = QuotaCalculator.summarize(accounts: accounts)

        XCTAssertEqual(summary.trayPercentage, 11)
        XCTAssertEqual(summary.rows, [
            AccountAllowance(accountId: "main-id", label: "main", remainingPercent: 0, totalPercent: 100),
            AccountAllowance(accountId: "friend-id", label: "workmate", remainingPercent: 11.75, totalPercent: 25),
        ])
    }

    func testTrayTotalCanExceedOneHundredPercent() throws {
        let summary = QuotaCalculator.summarize(accounts: [
                OpenCodexAccount(id: "target-id", alias: "target", plan: "pro", isMain: false, paused: false, weeklyUsedPercent: 0),
                OpenCodexAccount(id: "other-id", alias: "other", plan: "pro", isMain: false, paused: false, weeklyUsedPercent: 0),
            ])

        XCTAssertEqual(summary.trayPercentage, 200)
    }

    func testMirroredMainAccountIsNotDoubleCounted() {
        let summary = QuotaCalculator.summarize(accounts: [
            OpenCodexAccount(
                id: "__main__",
                email: "t***a@gmail.com",
                alias: nil,
                plan: "pro",
                isMain: true,
                paused: true,
                weeklyUsedPercent: 8
            ),
            OpenCodexAccount(
                id: "personal-id",
                email: "T***A@GMAIL.COM",
                alias: "personal",
                plan: "pro",
                isMain: false,
                paused: false,
                weeklyUsedPercent: 8
            ),
            OpenCodexAccount(
                id: "work-id",
                email: "t***a@example.com",
                alias: "work",
                plan: "pro",
                isMain: false,
                paused: false,
                weeklyUsedPercent: 0
            ),
        ])

        XCTAssertEqual(summary.trayPercentage, 192)
        XCTAssertEqual(summary.rows.map(\.label), ["personal", "work"])
    }

    func testAmbiguousMaskedEmailDoesNotDeduplicateAccounts() {
        let summary = QuotaCalculator.summarize(accounts: [
            OpenCodexAccount(id: "__main__", email: "t***a@gmail.com", alias: nil, plan: "pro", isMain: true, paused: false, weeklyUsedPercent: 8),
            OpenCodexAccount(id: "personal-a", email: "t***a@gmail.com", alias: "personal-a", plan: "pro", isMain: false, paused: false, weeklyUsedPercent: 8),
            OpenCodexAccount(id: "personal-b", email: "t***a@gmail.com", alias: "personal-b", plan: "pro", isMain: false, paused: false, weeklyUsedPercent: 8),
        ])

        XCTAssertEqual(summary.rows.count, 3)
    }

    func testMissingQuotaMakesAggregateUnknownWithoutInventingCapacity() throws {
        let summary = QuotaCalculator.summarize(accounts: [
                OpenCodexAccount(id: "main-id", alias: nil, plan: "pro", isMain: true, paused: false, weeklyUsedPercent: nil),
                accounts[1],
            ])

        XCTAssertNil(summary.trayPercentage)
        XCTAssertNil(summary.rows[0].remainingPercent)
        XCTAssertEqual(summary.rows[0].totalPercent, 100)
    }

    func testUnknownPlanMakesItsRowAndAggregateUnknown() throws {
        let summary = QuotaCalculator.summarize(accounts: [OpenCodexAccount(
                id: "unknown-id",
                alias: "workmate",
                plan: "future-plan",
                isMain: false,
                paused: false,
                weeklyUsedPercent: 20
            )])

        XCTAssertNil(summary.trayPercentage)
        XCTAssertNil(summary.rows[0].remainingPercent)
        XCTAssertNil(summary.rows[0].totalPercent)
    }

    func testFloatingPointNoiseDoesNotFloorExactPercentageOnePointLow() throws {
        let summary = QuotaCalculator.summarize(accounts: [
                OpenCodexAccount(id: "main-id", alias: nil, plan: "pro", isMain: true, paused: false, weeklyUsedPercent: 17.525),
                OpenCodexAccount(id: "friend-id", alias: "workmate", plan: "prolite", isMain: false, paused: false, weeklyUsedPercent: 3.9),
            ])

        XCTAssertEqual(summary.trayPercentage, 106)
    }

    func testClaudeSummaryConvertsUsedPercentagesToRemainingAllowances() {
        let summary = ClaudeQuotaCalculator.summarize(accounts: [
            ClaudeAccount(
                id: "claude-a",
                alias: "work",
                email: "w***@example.com",
                fiveHourUsedPercent: 3,
                weeklyUsedPercent: 12
            ),
        ])

        XCTAssertEqual(summary.fiveHourRemainingPercentage, 97)
        XCTAssertEqual(summary.weeklyRemainingPercentage, 88)
        XCTAssertEqual(summary.rows, [
            ClaudeAccountAllowance(
                accountId: "claude-a",
                label: "work",
                fiveHourRemainingPercent: 97,
                weeklyRemainingPercent: 88
            ),
        ])
    }

    func testEmptyClaudeSummaryDoesNotInventZeroPercentages() {
        let summary = ClaudeQuotaCalculator.summarize(accounts: [])

        XCTAssertNil(summary.fiveHourRemainingPercentage)
        XCTAssertNil(summary.weeklyRemainingPercentage)
        XCTAssertTrue(summary.rows.isEmpty)
    }

    func testClaudeSummarySumsFiveHourAndWeeklyRemainingAllowancesInDisplayOrder() {
        let summary = ClaudeQuotaCalculator.summarize(accounts: [
            ClaudeAccount(
                id: "claude-a",
                alias: "work",
                email: "w***@example.com",
                fiveHourUsedPercent: 50,
                weeklyUsedPercent: 20
            ),
            ClaudeAccount(
                id: "claude-b",
                alias: nil,
                email: "p***@example.com",
                fiveHourUsedPercent: 10,
                weeklyUsedPercent: 60
            ),
        ])

        XCTAssertEqual(summary.fiveHourRemainingPercentage, 140)
        XCTAssertEqual(summary.weeklyRemainingPercentage, 120)
        XCTAssertEqual(summary.rows, [
            ClaudeAccountAllowance(
                accountId: "claude-a",
                label: "work",
                fiveHourRemainingPercent: 50,
                weeklyRemainingPercent: 80
            ),
            ClaudeAccountAllowance(
                accountId: "claude-b",
                label: "p***@example.com",
                fiveHourRemainingPercent: 90,
                weeklyRemainingPercent: 40
            ),
        ])
    }

    func testClaudeSummaryMarksOnlyMissingAggregateWindowUnknown() {
        let summary = ClaudeQuotaCalculator.summarize(accounts: [
            ClaudeAccount(
                id: "claude-a",
                alias: "work",
                email: nil,
                fiveHourUsedPercent: nil,
                weeklyUsedPercent: 20
            ),
            ClaudeAccount(
                id: "claude-b",
                alias: "personal",
                email: nil,
                fiveHourUsedPercent: 10,
                weeklyUsedPercent: 30
            ),
        ])

        XCTAssertNil(summary.fiveHourRemainingPercentage)
        XCTAssertEqual(summary.weeklyRemainingPercentage, 150)
    }
}
