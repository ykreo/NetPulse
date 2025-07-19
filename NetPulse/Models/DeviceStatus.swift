// NetPulse/Models/DeviceStatus.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

struct DeviceStatus: Equatable {
    enum State: Equatable {
        case online
        case offline
        case unknown
        case loading
    }

    var state: State = .unknown
    var latency: Double?

    var displayColor: Color {
        switch state {
        case .online: return .green
        case .offline: return .red
        case .unknown: return .gray
        case .loading: return .orange
        }
    }
}

extension DeviceStatus.State {
    var displayName: LocalizedStringKey {
        switch self {
        case .online: return "status.online"
        case .offline: return "status.offline"
        case .unknown: return "status.checking"
        case .loading: return "status.executing"
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
