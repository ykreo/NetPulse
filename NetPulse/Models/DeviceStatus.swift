// NetPulse/Models/DeviceStatus.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

struct DeviceStatus: Equatable {
    enum State: Equatable {
        case online
        case offline
        case unknown
        case loading // Новый статус для отображения процесса выполнения команды
    }

    var state: State = .unknown
    var latency: Double? // Задержка в мс

    // Цвет для отображения статуса
    var displayColor: Color {
        switch state {
        case .online: return .green
        case .offline: return .red
        case .unknown: return .gray
        case .loading: return .orange
        }
    }
}

// Расширение для удобного доступа к текстовому представлению и иконкам
extension DeviceStatus.State {
    var displayName: String {
        switch self {
        case .online: return "Онлайн"
        case .offline: return "Офлайн"
        case .unknown: return "Проверка..."
        case .loading: return "Выполняется..."
        }
    }
    
    var iconName: String {
        switch self {
        case .online: return "wifi"
        case .offline: return "wifi.slash"
        case .unknown: return "wifi.exclamationmark"
        case .loading: return "hourglass"
        }
    }
}
