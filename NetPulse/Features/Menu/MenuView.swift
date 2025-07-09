// NetPulse/Features/Menu/MenuView.swift

import SwiftUI

struct MenuView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    // Для открытия окон
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    
    // Для закрытия поповера
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            if settings.areAllFieldsValid {
                // --- Основной интерфейс ---
                VStack(spacing: 0) {
                    // Заголовок
                    HeaderView()
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 12)
                    
                    // Статусы устройств
                    VStack(spacing: 12) {
                        StatusCard(
                            title: "Роутер",
                            status: manager.routerStatus,
                            icon: "wifi.router"
                        )
                        
                        StatusCard(
                            title: "Компьютер",
                            status: manager.pcStatus,
                            icon: "desktopcomputer"
                        )
                        
                        StatusCard(
                            title: "Интернет",
                            status: manager.internetStatus,
                            icon: "globe"
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    
                    // Действия
                    if settings.isSshKeyPathValid {
                        Divider()
                            .padding(.horizontal, 12)
                        
                        ActionsView()
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                }
            } else {
                // --- Состояние без настроек ---
                UnconfiguredView {
                    openSettings()
                    dismiss()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            
            // --- Футер ---
            Divider()
                .padding(.horizontal, 12)
            
            FooterView(
                onAbout: {
                    openWindow(id: "about")
                    dismiss()
                },
                onSettings: {
                    openSettings()
                    dismiss()
                }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 320)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear { manager.setUpdateFrequency(isFast: true) }
        .onDisappear { manager.setUpdateFrequency(isFast: false) }
    }
}

// MARK: - Subviews

private struct HeaderView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("NetPulse")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text("by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(settings.author)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("• v\(settings.appVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            
            Spacer()
            
            Button(action: {
                Task { await manager.updateAllStatuses() }
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .disabled(manager.isUpdating)
            .opacity(manager.isUpdating ? 0.5 : 1.0)
        }
    }
}

private struct StatusCard: View {
    let title: String
    let status: DeviceStatus
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Иконка устройства
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(0.1))
                )
            
            // Информация об устройстве
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    // Индикатор статуса
                    Circle()
                        .fill(status.displayColor)
                        .frame(width: 8, height: 8)
                    
                    Text(status.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Задержка
            if let latency = status.latency, status.state == .online {
                Text("\(Int(latency)) ms")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

private struct ActionsView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Действия")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.leading, 4)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                ActionButton(
                    title: "Включить ПК",
                    icon: "power",
                    action: manager.wolPC,
                    isEnabled: manager.pcStatus.state != .online && manager.routerStatus.state == .online
                )
                
                ActionButton(
                    title: "Перезагрузить ПК",
                    icon: "restart",
                    action: manager.rebootPC,
                    isEnabled: manager.pcStatus.state == .online
                )
                
                ActionButton(
                    title: "Выключить ПК",
                    icon: "power.dotted",
                    action: manager.shutdownPC,
                    isEnabled: manager.pcStatus.state == .online
                )
                
                ActionButton(
                    title: "Перезагрузить Роутер",
                    icon: "wifi.router",
                    action: manager.rebootRouter,
                    isEnabled: manager.routerStatus.state == .online
                )
            }
        }
    }
}

private struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    let isEnabled: Bool
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isEnabled ? .accentColor : .secondary)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isEnabled ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isEnabled ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct FooterView: View {
    let onAbout: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Кнопка "О программе"
            Button(action: onAbout) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("О программе")
            
            Spacer()
            
            // Кнопка "Выход"
            Button("Выход") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            // Кнопка "Настройки"
            Button(action: onSettings) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape.fill")
                        .font(.caption)
                    Text("Настройки")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(height: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
    }
}

// MARK: - Unconfigured State View

private struct UnconfiguredView: View {
    let onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "gear.badge.questionmark")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                    .frame(height: 60)
                
                Text("Требуется настройка")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("Пожалуйста, укажите IP-адреса устройств и настройте SSH-ключи для начала мониторинга сети.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
            }
            
            Button(action: onSettings) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.body)
                    Text("Открыть настройки")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
    }
}