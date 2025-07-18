// NetPulse/NetPulseApp.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI

struct MenuBarIconView: View {
    @ObservedObject var networkManager: NetworkManager

    var body: some View {
        let iconInfo = networkManager.menuBarIconState
        
        Image(systemName: iconInfo.name)
            .font(.title3)
            .foregroundColor(iconInfo.color)
            .symbolEffect(.pulse, options: .repeating, isActive: networkManager.isUpdating)
    }
}

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
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
                .onAppear {
                    appDelegate.settingsManager = settingsManager
                    appDelegate.networkManager = networkManager
                }
        } label: {
            MenuBarIconView(networkManager: networkManager)
                // --- ПРИВЯЗЫВАЕМ ID К VIEW, ЧТОБЫ ЗАСТАВИТЬ ЕЕ ПЕРЕРИСОВЫВАТЬСЯ ---
                .id(networkManager.iconUpdateId)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(networkManager)
                .environmentObject(settingsManager)
        }
        
        Window("О программе NetPulse", id: "about") {
            AboutView()
                .environmentObject(settingsManager)
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
    }
}
