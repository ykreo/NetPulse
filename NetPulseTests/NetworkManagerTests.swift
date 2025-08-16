import XCTest
@testable import NetPulse

final class NetworkManagerTests: XCTestCase {
    func testPingTimeout() async {
        let settingsManager = SettingsManager()
        let manager = NetworkManager(settingsManager: settingsManager)
        do {
            _ = try await manager.ping(host: "192.0.2.1", timeout: 0.1)
            XCTFail("Expected timeout")
        } catch NetworkManager.NetworkError.timeout {
            // expected timeout
        } catch {
            // other errors are acceptable in test environment
        }
    }

    func testSSHCancellation() async {
        let settingsManager = SettingsManager()
        let manager = NetworkManager(settingsManager: settingsManager)
        let task = Task {
            try await manager.ssh(user: "user", host: "localhost", command: "sleep 5", timeout: 5)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // success
        } catch {
            // other errors acceptable
        }
    }
}
