// NetPulse/NetPulseApp.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

/// Корневая структура приложения, определяющая основную сцену.
@main
struct NetPulseApp: App {
    // Адаптер для подключения AppDelegate к жизненному циклу SwiftUI.
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    // Менеджеры состояния, инициализируются один раз и передаются в дочерние View.
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var networkManager: NetworkManager
    // ИЗМЕНЕНО: Добавляем UpdateManager как StateObject, чтобы он тоже был доступен.
    @StateObject private var updateManager: UpdateManager
    
    init() {
        // Создаем экземпляры менеджеров в правильном порядке.
        let settings = SettingsManager()
        let network = NetworkManager(settingsManager: settings)
        // Инициализируем UpdateManager здесь, он становится частью графа зависимостей.
        let updater = UpdateManager()

        // Инициализируем StateObject с созданными экземплярами.
        _settingsManager = StateObject(wrappedValue: settings)
        _networkManager = StateObject(wrappedValue: network)
        _updateManager = StateObject(wrappedValue: updater)
        
        // ИЗМЕНЕНО: Сразу после создания передаем ссылки в AppDelegate.
        // Это устраняет гонку состояний.
        appDelegate.setup(
            settingsManager: settings,
            networkManager: network,
            updateManager: updater
        )
    }

    var body: some Scene {
        // Основной элемент в строке меню.
        MenuBarExtra {
            MenuView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
                // Передавать менеджеры через .onAppear больше не нужно,
                // так как мы сделали это в init(), но оставим для совместимости
                // с вашим текущим кодом, если где-то это еще используется.
                .onAppear {
                    appDelegate.settingsManager = settingsManager
                    appDelegate.networkManager = networkManager
                    appDelegate.updateManager = updateManager
                }
        } label: {
            MenuBarIconView(networkManager: networkManager)
                .id(networkManager.iconUpdateId)
        }
        .menuBarExtraStyle(.window)

        // Окно настроек, стандартное для macOS.
        Settings {
            SettingsView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
                // ИЗМЕНЕНО: Передаем updateManager и в настройки.
                .environmentObject(updateManager)
        }
        
        // Кастомное окно "О программе".
        Window("О программе NetPulse", id: "about") {
            AboutView()
                .environmentObject(settingsManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}

/// View для иконки в строке меню.
private struct MenuBarIconView: View {
    @ObservedObject var networkManager: NetworkManager

    var body: some View {
        let iconInfo = networkManager.menuBarIconState
        
        Image(systemName: iconInfo.name)
            .font(.title3)
            .foregroundColor(iconInfo.color)
            // Добавляем эффект пульсации во время обновления.
            .symbolEffect(.pulse, options: .repeating, isActive: networkManager.isUpdating)
    }
}
