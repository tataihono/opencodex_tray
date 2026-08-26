import XCTest
@testable import PauseWorkerCore

final class ConfigurationTests: XCTestCase {
    func testResolvesExistingWorkerDefaults() throws {
        let config = try WorkerConfiguration.resolve(environment: [
            "HOME": "/Users/user",
        ])

        XCTAssertEqual(config.baseURL, URL(string: "http://127.0.0.1:10100")!)
        XCTAssertEqual(config.adminTokenPath, "/Users/user/.opencodex/admin-api-token")
        XCTAssertEqual(config.pollInterval, 60)
        XCTAssertEqual(config.requestTimeout, 30)
    }

    func testRejectsHTTPHostnameThatOnlyLooksLikeLoopback() {
        for hostname in ["127.attacker.example", "127.0.0.1.attacker.example"] {
            XCTAssertThrowsError(try WorkerConfiguration.resolve(environment: [
                "HOME": "/tmp",
                "OPENCODEX_BASE_URL": "http://\(hostname)",
            ]))
        }
    }

    func testRejectsRemoteHTTPSHost() {
        XCTAssertThrowsError(try WorkerConfiguration.resolve(environment: [
            "HOME": "/tmp",
            "OPENCODEX_BASE_URL": "https://opencodex.example",
        ]))
    }

    func testLoadsFinderSafeJSONConfigWhenEnvironmentHasNoAlias() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("config.json")
        try Data(#"{"pollIntervalMS":15000}"#.utf8).write(to: file)

        let config = try WorkerConfiguration.load(
            environment: ["HOME": "/Users/user"],
            configFileURL: file
        )

        XCTAssertEqual(config.pollInterval, 15)
    }
}
