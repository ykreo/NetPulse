import XCTest
@testable import NetPulse

final class SettingsManagerTests: XCTestCase {
    func testValidateIP() {
        let manager = SettingsManager()
        XCTAssertTrue(manager.validateIP("192.168.1.1"))
        XCTAssertFalse(manager.validateIP("256.256.256.256"))
    }

    func testValidateHost() {
        let manager = SettingsManager()
        XCTAssertTrue(manager.validateHost("example.com"))
        XCTAssertTrue(manager.validateHost("10.0.0.1"))
        XCTAssertFalse(manager.validateHost(""))
    }

    func testValidateSSHKey() throws {
        let manager = SettingsManager()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: tempURL.path, contents: Data())
        XCTAssertTrue(manager.validateSSHKey(tempURL.path))
        try FileManager.default.removeItem(at: tempURL)
        XCTAssertFalse(manager.validateSSHKey(tempURL.path))
    }
}
