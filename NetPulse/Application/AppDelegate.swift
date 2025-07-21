// NetPulse/Application/AppDelegate.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsManager: SettingsManager?
    var networkManager: NetworkManager?
    
    // ИЗМЕНЕНО: Больше не создаем UpdateManager здесь.
    // public let updateManager = UpdateManager()
    // Он будет передан нам извне.
    var updater: SparkleUpdaterController?
    
    // НОВЫЙ МЕТОД: для получения ссылок на менеджеры.
    func setup(settingsManager: SettingsManager, networkManager: NetworkManager, updater: SparkleUpdaterController) {
        self.settingsManager = settingsManager
        self.networkManager = networkManager
        self.updater = updater
        Logger.app.info("AppDelegate успешно настроен с менеджерами.")
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateActivationPolicy()
        
        // Наблюдатели за состоянием окон для корректной работы иконки в Dock.
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.willCloseNotification, object: nil)
        if let settings = settingsManager?.settings {
               updater?.toggleAutomaticChecks(enabled: settings.checkForUpdatesAutomatically)
           }
    }
    
    @objc private func windowVisibilityChanged() {
        // Обновляем политику активации асинхронно, чтобы избежать гонки состояний.
        DispatchQueue.main.async {
            self.updateActivationPolicy()
        }
    }
    
    /// Управляет видимостью иконки в Dock и поведением приложения.
    func updateActivationPolicy() {
        guard let settings = settingsManager?.settings else { return }
        
        let menuBarWindowClass: AnyClass? = NSClassFromString("SwiftUI._SwiftUI_MenuBarExtraWindow")
        
        // Проверяем, есть ли у приложения видимые стандартные окна (кроме окна меню-бара).
        let hasVisibleWindows = NSApp.windows.contains { window in
            var isStandardWindow = window.isVisible && window.canBecomeMain
            if let menuBarWindowClass = menuBarWindowClass {
                isStandardWindow = isStandardWindow && !window.isKind(of: menuBarWindowClass)
            }
            return isStandardWindow
        }
        
        // Если иконка в Dock скрыта, переключаем приложение в режим "аксессуара" без видимых окон.
        if settings.hideDockIcon {
            NSApp.setActivationPolicy(hasVisibleWindows ? .regular : .accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
        
        // Принудительно активируем приложение, если есть видимые окна, чтобы оно вышло на передний план.
        if hasVisibleWindows {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
