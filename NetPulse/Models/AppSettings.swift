// NetPulse/Models/AppSettings.swift

import Foundation

struct AppSettings: Codable, Equatable {
    var routerIP: String
    var sshUserRouter: String
    var pcIP: String
    var pcMAC: String
    var sshUserPC: String
    var sshKeyPath: String
    var checkHost: String
    var launchAtLogin: Bool
    var hideDockIcon: Bool // <- ИЗМЕНЕНО c showDockIcon
    var backgroundCheckInterval: TimeInterval

    static func defaultSettings() -> AppSettings {
        return AppSettings(
            routerIP: "192.168.1.1",
            sshUserRouter: "root",
            pcIP: "192.168.1.243",
            pcMAC: "74:D0:2B:96:27:AF",
            sshUserPC: "ykreo",
            sshKeyPath: NSHomeDirectory() + "/.ssh/id_ed25519",
            checkHost: "1.1.1.1",
            launchAtLogin: false,
            hideDockIcon: false, // <- ИЗМЕНЕНО. По умолчанию иконка видна.
            backgroundCheckInterval: 60.0
        )
    }
}
