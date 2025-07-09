// NetPulse/Core/Managers/SettingsManager.swift

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let SETTINGS_KEY = "appSettingsV3" // Меняем ключ, чтобы избежать конфликтов со старой структурой

@MainActor
class SettingsManager: ObservableObject {
    
    @Published private(set) var settings: AppSettings {
        didSet {
            validateAllFields()
        }
    }
    
    let appVersion: String
    let author = "ykreo"

    @Published private(set) var isRouterIPValid = false
    @Published private(set) var isPcIPValid = false
    @Published private(set) var isPcMACValid = false
    @Published private(set) var isSshKeyPathValid = false
    @Published private(set) var isCheckHostValid = false
    
    var areAllFieldsValid: Bool {
        isRouterIPValid && isPcIPValid && isPcMACValid && isSshKeyPathValid &&
        isCheckHostValid && !settings.sshUserRouter.isEmpty && !settings.sshUserPC.isEmpty
    }
    
    init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        self.appVersion = "\(version) (build \(build))"
        
        if let data = UserDefaults.standard.data(forKey: SETTINGS_KEY),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
            Logger.settings.info("Настройки успешно загружены.")
        } else {
            self.settings = AppSettings.defaultSettings()
            Logger.settings.info("Используются настройки по умолчанию.")
        }
        
        validateAllFields()
    }
    
    private func save() {
        do {
            let encoded = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(encoded, forKey: SETTINGS_KEY)
            Logger.settings.info("Настройки успешно сохранены.")
        } catch {
            Logger.settings.error("Не удалось сохранить настройки: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API
    
    func applyAndSave(_ newSettings: AppSettings) {
        self.settings = newSettings
        save()
    }
    
    func applyForValidation(_ newSettings: AppSettings) {
        self.settings = newSettings
    }
    
    func restoreDefaults() {
        self.settings = AppSettings.defaultSettings()
        save()
    }
    
    // Функции export/import остаются без изменений, они теперь будут работать с новой структурой
    func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт конфигурации NetPulse"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "netpulse_config.json"
        
        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let encoder = JSONEncoder(); encoder.outputFormatting = .prettyPrinted
                let data = try encoder.encode(settings)
                try data.write(to: url)
                Logger.settings.info("Конфигурация экспортирована в \(url.path)")
            } catch {
                Logger.settings.error("Ошибка экспорта: \(error.localizedDescription)")
            }
        }
    }

    func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Импорт конфигурации NetPulse"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.canChooseFiles = true; openPanel.canChooseDirectories = false; openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let decodedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
                applyAndSave(decodedSettings)
                Logger.settings.info("Конфигурация импортирована из \(url.path)")
            } catch {
                Logger.settings.error("Ошибка импорта: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Validation Logic (остается без изменений)
    // ... весь ваш код валидации ...
    private func validateAllFields() {
        isRouterIPValid = validateIP(settings.routerIP)
        isPcIPValid = validateIP(settings.pcIP)
        isPcMACValid = validateMAC(settings.pcMAC)
        isSshKeyPathValid = validateSSHKey(settings.sshKeyPath)
        isCheckHostValid = validateHost(settings.checkHost)
    }

    private func validateIP(_ address: String) -> Bool {
        let pattern = #"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return address.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateHost(_ host: String) -> Bool {
        if validateIP(host) { return true }
        let pattern = #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$"#
        return host.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateMAC(_ address: String) -> Bool {
        let pattern = #"^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"#
        return address.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateSSHKey(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        return true
    }
}
