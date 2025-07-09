// NetPulse/NetPulseApp.swift

import SwiftUI

@main
struct NetPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var networkManager: NetworkManager
    
    init() {
        let settings = SettingsManager()
        let network = NetworkManager(settingsManager: settings)
        
        _settingsManager = StateObject(wrappedValue: settings)
        _networkManager = StateObject(wrappedValue: network)
        
        // Передаем менеджеры в AppDelegate для управления окнами
        appDelegate.settingsManager = settings
        appDelegate.networkManager = network
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
        } label: {
            // ИСПРАВЛЕНО: Новый, элегантный способ анимации
            Image(systemName: "globe.americas.fill") // Используем одну иконку
                // Условный модификатор для анимации
                .symbolEffect(.pulse, options: .repeating, isActive: networkManager.isUpdating)
                .font(.title3) // Немного увеличим размер для наглядности
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
        }
        
        // ВОЗВРАЩАЕМ ОКНО "О ПРОГРАММЕ"
        Window("О программе NetPulse", id: "about") {
            AboutView()
                .environmentObject(settingsManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar) // Делаем окно более минималистичным
    }
}
