import XCTest
@testable import PauseWorkerCore

private actor FakeOpenCodexClient: OpenCodexServing {
    enum FakeError: Error { case claudeUnavailable }

    var accounts: [OpenCodexAccount]
    var claudeAccounts: [ClaudeAccount]
    var fetchCount = 0
    var fetchDelay: Duration?
    var failClaudeFetch: Bool

    init(
        accounts: [OpenCodexAccount],
        claudeAccounts: [ClaudeAccount] = [],
        fetchDelay: Duration? = nil,
        failClaudeFetch: Bool = false
    ) {
        self.accounts = accounts
        self.claudeAccounts = claudeAccounts
        self.fetchDelay = fetchDelay
        self.failClaudeFetch = failClaudeFetch
    }
    func fetchAccounts() async throws -> [OpenCodexAccount] {
        fetchCount += 1
        if let fetchDelay { try await Task.sleep(for: fetchDelay) }
        return accounts
    }
    func fetchClaudeAccounts() async throws -> [ClaudeAccount] {
        if failClaudeFetch { throw FakeError.claudeUnavailable }
        return claudeAccounts
    }
    func accountFetchCount() -> Int { fetchCount }
}

final class WorkerTests: XCTestCase {
    func testClaudeFailureDoesNotBlockCodexSummary() async throws {
        let client = FakeOpenCodexClient(
            accounts: [
                OpenCodexAccount(id: "friend-id", alias: "workmate", plan: "prolite", isMain: false, paused: false, weeklyUsedPercent: 70),
            ],
            failClaudeFetch: true
        )
        let worker = PauseWorker(client: client)

        let result = try await worker.refresh()

        XCTAssertEqual(result.codexSummary.trayPercentage, 7)
        XCTAssertNil(result.claudeSummary)
        XCTAssertNotNil(result.claudeErrorMessage)
    }

    func testRefreshReturnsCodexAndClaudeRemainingPoolSummaries() async throws {
        let client = FakeOpenCodexClient(
            accounts: [
                OpenCodexAccount(id: "friend-id", alias: "workmate", plan: "prolite", isMain: false, paused: false, weeklyUsedPercent: 53),
            ],
            claudeAccounts: [
                ClaudeAccount(
                    id: "claude-a",
                    alias: "work",
                    email: "w***@example.com",
                    fiveHourUsedPercent: 50,
                    weeklyUsedPercent: 20
                ),
                ClaudeAccount(
                    id: "claude-b",
                    alias: "personal",
                    email: "p***@example.com",
                    fiveHourUsedPercent: 10,
                    weeklyUsedPercent: 60
                ),
            ]
        )
        let worker = PauseWorker(client: client)

        let result = try await worker.refresh()

        XCTAssertEqual(result.codexSummary.trayPercentage, 11)
        XCTAssertEqual(result.claudeSummary?.fiveHourRemainingPercentage, 140)
        XCTAssertEqual(result.claudeSummary?.weeklyRemainingPercentage, 120)
        XCTAssertEqual(result.claudeSummary?.rows.map(\.label), ["work", "personal"])
        XCTAssertNil(result.claudeErrorMessage)
    }

    func testConcurrentRefreshesCoalesceIntoOneAccountRequest() async throws {
        let client = FakeOpenCodexClient(accounts: [
            OpenCodexAccount(id: "friend-id", alias: "workmate", plan: "prolite", isMain: false, paused: false, weeklyUsedPercent: 70),
        ], fetchDelay: .milliseconds(50))
        let worker = PauseWorker(client: client)

        async let first = worker.refresh()
        async let second = worker.refresh()
        _ = try await (first, second)

        let fetchCount = await client.accountFetchCount()
        XCTAssertEqual(fetchCount, 1)
    }
}
