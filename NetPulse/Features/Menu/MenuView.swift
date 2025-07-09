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
                // --- Основной интерфейс, когда все настроено ---
                VStack(spacing: 0) {
                    HeaderView()
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    Divider()
                    VStack(spacing: 8) {
                        StatusCard(title: "Роутер", status: manager.routerStatus)
                        StatusCard(title: "Компьютер", status: manager.pcStatus)
                        StatusCard(title: "Интернет", status: manager.internetStatus)
                    }
                    .padding(12)
                    ActionsView()
                        .padding(.horizontal)
                    Spacer(minLength: 0)
                }
            } else {
                // --- "Пустое состояние", когда настройки невалидны ---
                UnconfiguredView {
                    openSettings()
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            
            // --- Общий футер ---
            FooterView(onAbout: {
                openWindow(id: "about")
                dismiss()
            }, onSettings: {
                openSettings()
                dismiss()
            })
            .padding()
            .background(.bar)
        }
        .frame(width: 300)
        .onAppear { manager.setUpdateFrequency(isFast: true) }
        .onDisappear { manager.setUpdateFrequency(isFast: false) }
    }
}

// MARK: - Subviews for MenuView (Полный рефакторинг)

private struct HeaderView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text("NetPulse").font(.title2).fontWeight(.bold)
                // ИНФОРМАЦИЯ ОБ АВТОРЕ И ВЕРСИИ
                Text("by \(settings.author) · v\(settings.appVersion)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: { Task { await manager.updateAllStatuses() } }) {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(manager.isUpdating)
        }
    }
}

private struct StatusCard: View {
    let title: String
    let status: DeviceStatus

    var body: some View {
        // ИСПОЛЬЗУЕМ LabeledContent ДЛЯ ИДЕАЛЬНОГО ВЫРАВНИВАНИЯ
        LabeledContent {
            // Контент (правая часть)
            if let latency = status.latency {
                Text("\(String(format: "%.0f", latency)) ms")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            } else {
                // Пустой текст, чтобы сохранить выравнивание, если нет задержки
                Text("")
            }
        } label: {
            // Метка (левая часть)
            HStack(spacing: 12) {
                Image(systemName: status.state.iconName)
                    .font(.headline)
                    .foregroundColor(status.displayColor)
                    .frame(width: 20, alignment: .center) // Фиксированная ширина для иконки

                VStack(alignment: .leading) {
                    Text(title)
                    Text(status.state.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ActionsView: View {
    @EnvironmentObject var manager: NetworkManager
    @EnvironmentObject var settings: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Действия").font(.caption).foregroundColor(.secondary).padding(.leading, 4)
            
            // СЕТКА ДЛЯ КНОПОК
            Grid(horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    ActionButton(title: "Перезагрузить ПК", systemImage: "power", action: manager.rebootPC)
                        .disabled(manager.pcStatus.state != .online)
                    ActionButton(title: "Выключить ПК", systemImage: "bolt.slash.circle", action: manager.shutdownPC)
                        .disabled(manager.pcStatus.state != .online)
                }
                GridRow {
                    ActionButton(title: "Включить ПК (WOL)", systemImage: "sun.max", action: manager.wolPC)
                        .disabled(manager.pcStatus.state == .online || manager.routerStatus.state != .online)
                    ActionButton(title: "Перезагрузить Роутер", systemImage: "antenna.radiowaves.left.and.right", action: manager.rebootRouter)
                        .disabled(manager.routerStatus.state != .online)
                }
            }
            .disabled(!settings.isSshKeyPathValid)
        }
    }
}

// Переиспользуемая кнопка для красивого стиля
private struct ActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.callout)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity, minHeight: 24)
        }
        .buttonStyle(.bordered) // СТАНДАРТНЫЙ СТИЛЬ macOS
    }
}

private struct FooterView: View {
    let onAbout: () -> Void
    let onSettings: () -> Void
    
    var body: some View {
        HStack {
            // Кнопка "О программе" слева
            Button(action: onAbout) {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // Кнопки управления справа
            Button("Выход") { NSApplication.shared.terminate(nil) }
            Button(action: onSettings) {
                Label("Настройки", systemImage: "gearshape.fill")
            }
            .buttonStyle(.borderedProminent) // Делаем главную кнопку заметнее
        }
    }
}
// MARK: - Unconfigured State View
private struct UnconfiguredView: View {
    let onSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "gear.badge.questionmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Требуется настройка")
                .font(.headline)
            
            Text("Пожалуйста, укажите IP-адреса и другие параметры, чтобы начать мониторинг.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            Button {
                onSettings()
            } label: {
                Label("Открыть настройки", systemImage: "gearshape.fill")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}
