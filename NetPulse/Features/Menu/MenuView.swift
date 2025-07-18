// NetPulse/Features/Menu/MenuView.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

struct MenuView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    
    // --- НОВАЯ ЛОГИКА ДЛЯ ВЫЧИСЛЕНИЯ ВЫСОТЫ ---
    private var idealHeight: CGFloat {
        let headerHeight: CGFloat = 60
        let footerHeight: CGFloat = 50
        let internetCardHeight: CGFloat = 70 // Приблизительная высота карточек
        let deviceCardHeight: CGFloat = 110
        let verticalPadding: CGFloat = 32
        
        // Считаем общую высоту контента
        let contentHeight = headerHeight + footerHeight + internetCardHeight + (CGFloat(settings.settings.devices.count) * deviceCardHeight) + verticalPadding
        return contentHeight
    }
    
    private var maxHeight: CGFloat {
        (NSScreen.main?.visibleFrame.height ?? 800) * 0.75
    }

    var body: some View {
        // --- ИСПРАВЛЕНИЕ: Условное добавление ScrollView ---
        let content = VStack(spacing: 0) {
            if !settings.settings.devices.isEmpty && settings.areAllFieldsValid {
                mainInterface
            } else {
                UnconfiguredView {
                    openSettings(); dismiss()
                }
                .padding(.horizontal, 20).padding(.vertical, 24)
            }
            footer
        }

        // Если идеальная высота больше максимальной, используем ScrollView
        if idealHeight > maxHeight {
            ScrollView {
                content
            }
            .frame(width: 340, height: maxHeight)
        } else {
            // Иначе, просто показываем контент с его идеальной высотой
            content
                .frame(width: 340, height: idealHeight)
        }
        
        // Общие модификаторы
        // .background(Color(NSColor.windowBackgroundColor))
        // .onAppear { manager.setUpdateFrequency(isFast: true) }
        // .onDisappear { manager.setUpdateFrequency(isFast: false) }
    }
    
    // ... Остальной код файла остается без изменений ...
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

private struct HeaderView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NetPulse").font(.title2).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text("by").font(.caption).foregroundColor(.secondary); Text(settings.author).font(.caption).fontWeight(.medium).foregroundColor(.secondary)
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
    let device: Device?; let status: DeviceStatus; let isLoading: Bool
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: device?.icon ?? "globe").font(.title2).foregroundColor(.secondary).frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(device?.name ?? "Интернет").font(.body).fontWeight(.medium)
                    HStack(spacing: 6) { Circle().fill(status.displayColor).frame(width: 8, height: 8); Text(status.state.displayName).font(.caption).foregroundColor(.secondary) }
                }
                Spacer()
                if isLoading { ProgressView().controlSize(.small) }
                else if let latency = status.latency, status.state == .online {
                    Text("\(Int(latency)) ms").font(.caption).fontWeight(.medium).foregroundColor(.secondary).padding(.horizontal, 8).padding(.vertical, 4).background(RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.1)))
                }
            }
            if let device = device { actionButtons(for: device) }
        }.padding(12).background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
    }
    @ViewBuilder private func actionButtons(for device: Device) -> some View {
        let isOnline = status.state == .online; let commandInProgress = manager.commandStates[device.id] ?? false
        if device.commands.wake != nil || device.commands.reboot != nil || device.commands.shutdown != nil {
            Divider()
            HStack(spacing: 8) {
                if let wakeCmd = device.commands.wake { ActionButton(title: "Включить", icon: "power", isEnabled: !isOnline, command: wakeCmd, device: device) }
                if let rebootCmd = device.commands.reboot { ActionButton(title: "Ребут", icon: "restart", isEnabled: isOnline, command: rebootCmd, device: device) }
                if let shutdownCmd = device.commands.shutdown { ActionButton(title: "Выключить", icon: "power.dotted", isEnabled: isOnline, command: shutdownCmd, device: device) }
            }.disabled(commandInProgress)
        }
    }
}
private struct ActionButton: View {
    @EnvironmentObject var manager: NetworkManager
    let title: String; let icon: String; let isEnabled: Bool; let command: String; let device: Device
    var body: some View {
        Button(action: { manager.executeCommand(for: device, command: command) }) {
            HStack(spacing: 4) { Image(systemName: icon); Text(title) }
            .font(.caption).padding(.horizontal, 8).padding(.vertical, 5).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 6).fill(isEnabled ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1)))
        }.buttonStyle(.plain).disabled(!isEnabled)
    }
}
private struct FooterView: View {
    let onAbout: () -> Void; let onSettings: () -> Void
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
