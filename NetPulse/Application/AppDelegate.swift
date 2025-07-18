// NetPulse/Application/AppDelegate.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import OSLog

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var settingsManager: SettingsManager?
    var networkManager: NetworkManager?
    
    // --- ИЗМЕНЕНО: делаем свойство публичным ---
    public let updateManager = UpdateManager()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        updateActivationPolicy()
        
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.didBecomeMainNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowVisibilityChanged), name: NSWindow.willCloseNotification, object: nil)
        
        Task {
            try? await Task.sleep(for: .seconds(1))
            await updateManager.checkForUpdates()
        }
    }
    
    @objc private func windowVisibilityChanged() {
        DispatchQueue.main.async {
            self.updateActivationPolicy()
        }
    }
    
    func updateActivationPolicy() {
        guard let settings = settingsManager?.settings else { return }
        let menuBarWindowClass: AnyClass? = NSClassFromString("SwiftUI._SwiftUI_MenuBarExtraWindow")
        let hasVisibleWindows = NSApp.windows.contains { window in
            var isStandardWindow = window.isVisible && window.canBecomeMain
            if let menuBarWindowClass = menuBarWindowClass {
                isStandardWindow = isStandardWindow && !window.isKind(of: menuBarWindowClass)
            }
            return isStandardWindow
        }
        if settings.hideDockIcon {
            NSApp.setActivationPolicy(hasVisibleWindows ? .regular : .accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
        if hasVisibleWindows {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
