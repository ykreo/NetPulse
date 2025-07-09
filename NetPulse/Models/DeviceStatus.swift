// NetPulse/Models/DeviceStatus.swift
//  Copyright © 2025 ykreo. All rights reserved.
import SwiftUI

struct DeviceStatus {
    enum State {
        case online, offline, unknown
    }

    var state: State = .unknown
    var latency: Double? // Задержка в мс

    // Цвет для отображения статуса
    var displayColor: Color {
        switch state {
        case .online: return .green
        case .offline: return .red
        case .unknown: return .gray
        }
    }

    // Форматированное имя для отображения в меню
    func displayName(for device: String) -> String {
        let icon: String
        switch state {
        case .online: icon = "🟢"
        case .offline: icon = "🔴"
        case .unknown: icon = "⚫️"
        }

        if let latency = latency, state == .online {
            return "\(icon) \(device): Онлайн (\(String(format: "%.0f", latency))ms)"
        } else {
            let statusText: String
            switch state {
            case .online: statusText = "Онлайн"
            case .offline: statusText = "Офлайн"
            case .unknown: statusText = "Проверка..."
            }
            return "\(icon) \(device): \(statusText)"
        }
    }
}
extension DeviceStatus.State {
    var iconName: String {
        switch self {
        case .online: return "wifi"
        case .offline: return "wifi.slash"
        case .unknown: return "wifi.exclamationmark"
        }
    }
    
    var displayName: String {
        switch self {
        case .online: return "Онлайн"
        case .offline: return "Офлайн"
        case .unknown: return "Проверка..."
        }
    }
}
