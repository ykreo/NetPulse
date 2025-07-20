// NetPulse/NetPulseApp.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

// --- НАЧАЛО НОВОГО КОДА ---

/// Создает цветную иконку SF Symbol с помощью AppKit, чтобы обойти принудительный "шаблонный" рендеринг в MenuBarExtra.
/// - Parameters:
///   - systemName: Имя SF Symbol.
///   - color: Цвет иконки.
/// - Returns: Готовое изображение для SwiftUI.
private func createColoredIcon(systemName: String, color: Color) -> Image {
    // 1. Получаем системное изображение (NSImage) из имени SF Symbol.
    guard let nsImage = NSImage(systemSymbolName: systemName, accessibilityDescription: nil) else {
        return Image(systemName: systemName) // Возвращаем обычную иконку, если что-то пошло не так
    }

    // 2. Создаем конфигурацию, которая применяет наш цвет.
    let configuration = NSImage.SymbolConfiguration(paletteColors: [NSColor(color)])
    
    // 3. Применяем конфигурацию к изображению.
    let coloredImage = nsImage.withSymbolConfiguration(configuration)
    
    // 4. ЭТО КЛЮЧЕВОЙ ШАГ: Явно говорим системе, что это НЕ шаблон.
    coloredImage?.isTemplate = false
    
    // 5. Возвращаем сконфигурированное изображение обратно в SwiftUI.
    return Image(nsImage: coloredImage ?? nsImage)
}

// --- КОНЕЦ НОВОГО КОДА ---


/// Корневая структура приложения, определяющая основную сцену.
@main
struct NetPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    @StateObject private var settingsManager: SettingsManager
    @StateObject private var networkManager: NetworkManager
    @StateObject private var updateManager: UpdateManager
    
    init() {
        let settings = SettingsManager()
        let network = NetworkManager(settingsManager: settings)
        let updater = UpdateManager()

        _settingsManager = StateObject(wrappedValue: settings)
        _networkManager = StateObject(wrappedValue: network)
        _updateManager = StateObject(wrappedValue: updater)
        
        appDelegate.setup(
            settingsManager: settings,
            networkManager: network,
            updateManager: updater
        )
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
        } label: {
            MenuBarIconView(networkManager: networkManager)
                .id(networkManager.iconUpdateId)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
                .environmentObject(updateManager)
        }
        
        Window("window.title.about", id: "about") {
            AboutView()
                .environmentObject(settingsManager)
                .environmentObject(updateManager)
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
        
        // ИЗМЕНЕНИЕ: Теперь мы не создаем Image напрямую, а вызываем нашу новую функцию.
        // Она возвращает уже готовую, правильно сконфигурированную цветную иконку.
        createColoredIcon(systemName: iconInfo.name, color: iconInfo.color)
    }
}
