// NetPulse/Core/Logger+Extensions.swift
//  Copyright © 2025 ykreo. All rights reserved.

import Foundation
import OSLog

extension Logger {
    // Используем bundleIdentifier, чтобы лог был уникальным для нашего приложения.
    private static let subsystem = Bundle.main.bundleIdentifier ?? "NetPulse"

    /// Логгер для общих событий жизненного цикла приложения.
    static let app = Logger(subsystem: subsystem, category: "Application")

    /// Логгер для всех сетевых операций (ping, ssh).
    static let network = Logger(subsystem: subsystem, category: "Network")

    /// Логгер для операций с настройками (сохранение, загрузка, валидация).
    static let settings = Logger(subsystem: subsystem, category: "Settings")

    /// Логгер для операций с базой данных SwiftData.
    static let database = Logger(subsystem: subsystem, category: "Database")
}
