// NetPulse/Features/Menu/MenuView.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

struct MenuView: View {
    @EnvironmentObject private var manager: NetworkManager
    @EnvironmentObject private var settings: SettingsManager
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    
    // ИСПРАВЛЕНИЕ: Логика расчета высоты теперь учитывает реальный статус устройств.
    private var idealHeight: CGFloat {
        let headerHeight: CGFloat = 60
        let footerHeight: CGFloat = 50
        let internetCardHeight: CGFloat = 60
        let baseDeviceCardHeight: CGFloat = 60
        let actionRowHeight: CGFloat = 45 // Высота ряда с кнопками
        let verticalPadding: CGFloat = 32
        let spacing: CGFloat = 8 * CGFloat(settings.settings.devices.count + 1) // Пространство между карточками

        let devicesHeight = settings.settings.devices.reduce(0) { total, device in
            // Получаем актуальный статус устройства
            let status = manager.deviceStatuses[device.id] ?? DeviceStatus(state: .unknown)
            let isOnline = status.state == .online

            // Проверяем, есть ли видимые действия для ТЕКУЩЕГО статуса
            let hasVisibleActions = device.actions.contains { action in
                switch action.displayCondition {
                case .always: return true
                case .ifOnline: return isOnline
                case .ifOffline: return !isOnline
                }
            }

            let actionHeight = hasVisibleActions ? actionRowHeight : 0
            return total + baseDeviceCardHeight + actionHeight
        }
        
        // Считаем итоговую высоту
        if settings.settings.devices.isEmpty {
            return 300 // Фиксированная высота для окна с предложением настроить
        }
        
        return headerHeight + footerHeight + internetCardHeight + devicesHeight + verticalPadding + spacing
    }
    
    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.8
    }

    var body: some View {
        let content = VStack(spacing: 0) {
            if !settings.settings.devices.isEmpty && settings.areAllFieldsValid {
                mainInterface
            } else {
                UnconfiguredView {
                    openSettings()
                    dismiss()
                }
                .padding(.horizontal, 20).padding(.vertical, 24)
            }
            footer
        }

        if idealHeight > maxHeight {
            ScrollView { content }.frame(width: 340, height: maxHeight)
        } else {
            content.frame(width: 340, height: idealHeight)
        }
    }
    
    // MARK: - Subviews
    
    private var mainInterface: some View {
        VStack(spacing: 0) {
            HeaderView().padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
            Divider().padding(.horizontal, 12)
            VStack(spacing: 8) {
                StatusCard(device: nil, status: manager.internetStatus, isLoading: manager.isUpdating)
                ForEach(settings.settings.devices) { device in
                    StatusCard(
                        device: device,
                        status: manager.deviceStatuses[device.id] ?? DeviceStatus(state: .unknown),
                        isLoading: manager.isUpdating || (manager.commandStates[device.id] ?? false)
                    )
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
    }
    
    private var footer: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 12)
            FooterView(
                onAbout: { openWindow(id: "about"); dismiss() },
                onSettings: { openSettings(); dismiss() }
            )
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }
}


// MARK: - UI Components (без изменений в этой секции)

private struct HeaderView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NetPulse").font(.title2).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text("by").font(.caption).foregroundColor(.secondary)
                    Text(settings.author).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                    Text("• v\(settings.appVersion)").font(.caption).foregroundColor(.secondary.opacity(0.7))
                }
            }
            Spacer()
            Button(action: { Task { await manager.updateAllStatuses() } }) {
                Image(systemName: "arrow.clockwise").font(.title3).foregroundColor(.secondary).frame(width: 24, height: 24)
            }.buttonStyle(.plain).disabled(manager.isUpdating).opacity(manager.isUpdating ? 0.5 : 1.0)
        }
    }
}

private struct StatusCard: View {
    @EnvironmentObject var manager: NetworkManager
    let device: Device?
    let status: DeviceStatus
    let isLoading: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: device?.icon ?? "globe").font(.title2).foregroundColor(.secondary).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device?.name ?? "Интернет").font(.body).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Circle().fill(status.displayColor).frame(width: 8, height: 8)
                        Text(status.state.displayName).font(.caption).foregroundColor(.secondary)
                    }
                }
                Spacer()
                if isLoading {
                    ProgressView().controlSize(.small)
                } else if let latency = status.latency, status.state == .online {
                    Text("\(Int(latency)) ms").font(.caption).fontWeight(.medium).foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                }
            }
            
            if let device = device, !device.actions.isEmpty {
                actionButtons(for: device)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
    }
    
    @ViewBuilder private func actionButtons(for device: Device) -> some View {
        let isOnline = status.state == .online
        let commandInProgress = manager.commandStates[device.id] ?? false
        
        let visibleActions = device.actions.filter { action in
            switch action.displayCondition {
            case .always: return true
            case .ifOnline: return isOnline
            case .ifOffline: return !isOnline
            }
        }
        
        if !visibleActions.isEmpty {
            Divider()
            HStack(spacing: 8) {
                ForEach(visibleActions) { action in
                    ActionButton(action: action, device: device)
                }
            }
            .disabled(commandInProgress)
        }
    }
}

private struct ActionButton: View {
    @EnvironmentObject var manager: NetworkManager
    let action: CustomAction
    let device: Device
    
    var body: some View {
        Button(action: {
            manager.executeCommand(for: device, command: action.command)
        }) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                Text(action.name)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.accentColor.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }
}

private struct FooterView: View {
    let onAbout: () -> Void
    let onSettings: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Button(action: onAbout) { Image(systemName: "info.circle") }.buttonStyle(.plain).help("О программе")
            Spacer()
            HStack(spacing: 8) {
                Button("Выход") { NSApplication.shared.terminate(nil) }
                Button(action: onSettings) { HStack(spacing: 4) { Image(systemName: "gearshape.fill"); Text("Настройки") } }.buttonStyle(.borderedProminent)
            }.controlSize(.regular)
        }
    }
}

private struct UnconfiguredView: View {
    let onSettings: () -> Void
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "gear.badge.questionmark").font(.system(size: 48)).foregroundColor(.secondary)
            Text("Требуется настройка").font(.headline).fontWeight(.semibold)
            Text("Пожалуйста, добавьте устройства и настройте SSH-ключи для начала мониторинга.").multilineTextAlignment(.center).foregroundColor(.secondary)
            Button(action: onSettings) {
                HStack(spacing: 8) { Image(systemName: "gearshape.fill"); Text("Открыть настройки") }.frame(maxWidth: .infinity).frame(height: 36)
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }
}
