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
    
    init() {
        // Создаем экземпляры менеджеров при инициализации приложения.
        let settings = SettingsManager()
        let network = NetworkManager(settingsManager: settings)
        
        // Инициализируем StateObject с созданными экземплярами.
        _settingsManager = StateObject(wrappedValue: settings)
        _networkManager = StateObject(wrappedValue: network)
    }

    var body: some Scene {
        // Основной элемент в строке меню.
        MenuBarExtra {
            MenuView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
                .onAppear {
                    // Передаем ссылки на менеджеры в AppDelegate после того, как View появится.
                    appDelegate.settingsManager = settingsManager
                    appDelegate.networkManager = networkManager
                }
        } label: {
            MenuBarIconView(networkManager: networkManager)
                // Привязка уникального ID заставляет View перерисовываться при его изменении.
                // Это ключевой механизм для динамического обновления иконки.
                .id(networkManager.iconUpdateId)
        }
        .menuBarExtraStyle(.window)

        // Окно настроек, стандартное для macOS.
        Settings {
            SettingsView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
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
