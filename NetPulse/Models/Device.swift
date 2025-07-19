// NetPulse/Models/Device.swift
// Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI

/// Определяет кастомное SSH-действие, которое может выполнить пользователь.
struct CustomAction: Codable, Equatable, Hashable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Новое действие"
    var command: String = "echo 'Hello'"
    var icon: String = "terminal" // Иконка из SF Symbols
    
    // Условие для отображения кнопки (всегда, только онлайн, только офлайн)
    enum DisplayCondition: String, Codable, CaseIterable, Identifiable {
        case always = "Всегда"
        case ifOnline = "Если онлайн"
        case ifOffline = "Если офлайн"
        
        var id: String { self.rawValue }
    }
    
    var displayCondition: DisplayCondition = .ifOnline
}


/// Основная модель устройства в сети.
struct Device: Codable, Identifiable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var host: String
    var user: String
    var icon: String = "desktopcomputer" // Иконка по умолчанию для устройства
    
    // Заменяем старую структуру на массив кастомных действий.
    var actions: [CustomAction]
    
    var sortOrder: Int = 0

    /// Статический метод для создания пустого устройства для редактора.
    static func new() -> Device {
        return Device(
            name: "",
            host: "",
            user: "user",
            icon: "desktopcomputer",
            actions: [
                CustomAction(name: "Перезагрузка", command: "sudo reboot", icon: "restart", displayCondition: .ifOnline),
                CustomAction(name: "Выключение", command: "sudo shutdown -h now", icon: "power.dotted", displayCondition: .ifOnline)
            ]
        )
    }
}
