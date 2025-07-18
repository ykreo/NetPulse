// NetPulse/Models/Device.swift
//  Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI

// Определяем структуру для кастомных SSH-команд
struct SSHCommands: Codable, Equatable, Hashable {
    var wake: String?           // Команда для включения (может быть не SSH, а, например, WOL)
    var reboot: String?         // Команда для перезагрузки
    var shutdown: String?       // Команда для выключения
    
    // Команда для проверки статуса (может быть простой 'echo' или что-то сложнее)
    var statusCheck: String = "echo 'OK'"
}

// Основная модель устройства
struct Device: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var host: String
    var user: String
    var icon: String = "desktopcomputer" // Иконка по умолчанию
    var commands: SSHCommands
    var sortOrder: Int = 0 // Для будущей сортировки
    
    // Статический метод для создания пустого или дефолтного устройства
    static func new() -> Device {
        return Device(
            name: "Новое устройство",
            host: "192.168.1.10",
            user: "user",
            commands: SSHCommands(
                wake: "/usr/bin/etherwake -i br-lan AA:BB:CC:DD:EE:FF",
                reboot: "sudo reboot",
                shutdown: "sudo shutdown -h now"
            )
        )
    }
}
