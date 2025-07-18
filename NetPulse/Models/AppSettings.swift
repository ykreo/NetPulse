// NetPulse/Models/AppSettings.swift
//  Copyright © 2025 ykreo. All rights reserved.

import Foundation

struct AppSettings: Codable, Equatable {
    // Старые поля заменены на массив кастомных устройств
    var devices: [Device]
    
    // Общие настройки приложения остаются
    var sshKeyPath: String
    var checkHost: String
    var launchAtLogin: Bool
    var hideDockIcon: Bool
    var backgroundCheckInterval: TimeInterval

    // Метод для создания настроек по умолчанию
    static func defaultSettings() -> AppSettings {
        // Создадим примеры "Роутер" и "Компьютер" для наглядности
        let exampleRouter = Device(
            name: "Роутер",
            host: "192.168.1.1",
            user: "root",
            icon: "wifi.router",
            commands: SSHCommands(wake: nil, reboot: "reboot", shutdown: nil),
            sortOrder: 0
        )
        
        let examplePC = Device(
            name: "Мой ПК",
            host: "192.168.1.243",
            user: "ykreo",
            icon: "desktopcomputer",
            commands: SSHCommands(
                wake: "/usr/bin/etherwake -i br-lan 74:D0:2B:96:27:AF",
                reboot: "sudo reboot",
                shutdown: "sudo shutdown -h now"
            ),
            sortOrder: 1
        )
        
        return AppSettings(
            devices: [exampleRouter, examplePC], // Массив с примерами
            sshKeyPath: NSHomeDirectory() + "/.ssh/id_ed25519",
            checkHost: "1.1.1.1", // Глобальный хост для проверки интернета
            launchAtLogin: false,
            hideDockIcon: false,
            backgroundCheckInterval: 60.0
        )
    }
}
