// NetPulse/Application/AppDelegate.swift

import SwiftUI
import OSLog

// Помечаем весь класс для работы в основном потоке
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsManager: SettingsManager?
    var networkManager: NetworkManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Начальная установка политики при запуске
        updateActivationPolicy()
        
        // Подписываемся на уведомления об изменении видимости окон
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.willCloseNotification, object: nil)
    }
    
    @objc private func windowVisibilityChanged() {
        // Даем SwiftUI время обновить список окон
        DispatchQueue.main.async {
            self.updateActivationPolicy()
        }
    }
    
    /// Обновляет политику активации приложения (видимость иконки в Dock)
    func updateActivationPolicy() {
        guard let settings = settingsManager?.settings else { return }

        // Безопасно получаем приватный класс, если он существует
        let menuBarWindowClass: AnyClass? = NSClassFromString("SwiftUI._SwiftUI_MenuBarExtraWindow")

        // Проверяем наличие видимых стандартных окон
        let hasVisibleWindows = NSApp.windows.contains { window in
            // Основные условия: окно видимо и может стать главным
            var isStandardWindow = window.isVisible && window.canBecomeMain

            // Если мы смогли найти приватный класс поповера,
            // то дополнительно исключаем его из проверки.
            if let menuBarWindowClass = menuBarWindowClass {
                isStandardWindow = isStandardWindow && !window.isKind(of: menuBarWindowClass)
            }
            
            return isStandardWindow
        }

        if settings.hideDockIcon {
            if hasVisibleWindows {
                NSApp.setActivationPolicy(.regular)
                Logger.app.info("Политика активации: .regular (окна открыты)")
            } else {
                NSApp.setActivationPolicy(.accessory)
                Logger.app.info("Политика активации: .accessory (окна закрыты)")
            }
        } else {
            NSApp.setActivationPolicy(.regular)
            Logger.app.info("Политика активации: .regular (настройка)")
        }

        if hasVisibleWindows {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
