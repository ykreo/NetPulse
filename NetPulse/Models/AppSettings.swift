// NetPulse/Models/AppSettings.swift
// Copyright © 2025 ykreo. All rights reserved.

import Foundation

/// Главная структура, хранящая все настройки приложения.
struct AppSettings: Codable, Equatable {
    var devices: [Device]
    
    // MARK: - Общие настройки
    var sshKeyPath: String
    var checkHost: String
    var launchAtLogin: Bool
    var hideDockIcon: Bool
    var backgroundCheckInterval: TimeInterval
    
    // НОВОЕ: Настройка для управления автообновлениями
    var checkForUpdatesAutomatically: Bool

    /// Создает настройки по умолчанию для первого запуска.
    static func defaultSettings() -> AppSettings {
        let exampleRouter = Device(
            name: "Роутер",
            host: "192.168.1.1",
            user: "root",
            icon: "wifi.router",
            actions: [
                CustomAction(name: "Перезагрузить", command: "reboot", icon: "restart", displayCondition: .ifOnline)
            ],
            sortOrder: 0
        )
        
        let examplePC = Device(
            name: "Мой ПК",
            host: "192.168.1.243",
            user: "ykreo",
            icon: "desktopcomputer",
            actions: [
                CustomAction(name: "Включить", command: "/usr/bin/etherwake -i br-lan 74:D0:2B:96:27:AF", icon: "power", displayCondition: .ifOffline),
                CustomAction(name: "Перезагрузка", command: "sudo reboot", icon: "restart", displayCondition: .ifOnline),
                CustomAction(name: "Выключение", command: "sudo shutdown -h now", icon: "power.dotted", displayCondition: .ifOnline)
            ],
            sortOrder: 1
        )
        
        return AppSettings(
            devices: [exampleRouter, examplePC],
            sshKeyPath: NSHomeDirectory() + "/.ssh/id_ed25519",
            checkHost: "1.1.1.1",
            launchAtLogin: false,
            hideDockIcon: false,
            backgroundCheckInterval: 60.0,
            checkForUpdatesAutomatically: true // Включаем по умолчанию
        )
    }
}
