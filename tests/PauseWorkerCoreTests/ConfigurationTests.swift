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

    func testRejectsURLsWithCredentialsOrExtraComponents() {
        for url in [
            "http://user:password@127.0.0.1:10100",
            "http://127.0.0.1:10100/api",
            "http://127.0.0.1:10100?token=test",
            "http://127.0.0.1:10100#fragment",
            "file://localhost/tmp",
        ] {
            XCTAssertThrowsError(try WorkerConfiguration.resolve(environment: [
                "HOME": "/tmp",
                "OPENCODEX_BASE_URL": url,
            ]), url)
        }
    }

    func testEnvironmentOverridesFinderConfiguration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("config.json")
        try Data(#"{"pollIntervalMS":15000,"requestTimeoutMS":5000,"openCodexBaseURL":"http://127.0.0.1:10101","openCodexHome":"/tmp/file-config"}"#.utf8).write(to: file)

        let config = try WorkerConfiguration.load(environment: [
            "HOME": "/tmp",
            "POLL_INTERVAL_MS": "30000",
            "REQUEST_TIMEOUT_MS": "10000",
            "OPENCODEX_BASE_URL": "http://localhost:10102",
            "OPENCODEX_HOME": "/tmp/environment-config",
        ], configFileURL: file)

        XCTAssertEqual(config.pollInterval, 30)
        XCTAssertEqual(config.requestTimeout, 10)
        XCTAssertEqual(config.baseURL, URL(string: "http://localhost:10102"))
        XCTAssertEqual(config.adminTokenPath, "/tmp/environment-config/admin-api-token")
    }

    func testTokenReaderTrimsWhitespaceAtMaximumFileSize() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: file) }
        let token = String(repeating: "t", count: 510)
        try Data((" " + token + "\n").utf8).write(to: file)

        XCTAssertEqual(try AdminTokenReader.read(path: file.path), token)
    }

    func testTokenReaderRejectsDirectoryOversizedAndEmptyFiles() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertThrowsError(try AdminTokenReader.read(path: directory.path))

        let file = directory.appendingPathComponent("synthetic-token")
        for invalid in [String(repeating: "t", count: 513), "", " \n"] {
            try Data(invalid.utf8).write(to: file)
            XCTAssertThrowsError(try AdminTokenReader.read(path: file.path))
        }
    }
}
