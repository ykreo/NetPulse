// NetPulse/Core/Managers/SettingsManager.swift
// Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let SETTINGS_KEY = "appSettingsV4"

@MainActor
final class SettingsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var settings: AppSettings {
        didSet {
            // Перепроверяем валидность при любом изменении настроек.
            validateAllSettings()
        }
    }
    
    // Статусы валидации для UI
    @Published private(set) var deviceValidation: [UUID: Bool] = [:]
    @Published private(set) var isSshKeyPathValid = false
    @Published private(set) var isCheckHostValid = false
    
    // Общая валидность всех настроек для активации/деактивации кнопки "Сохранить".
    var areAllFieldsValid: Bool {
        // Все устройства должны быть валидны.
        let allDevicesValid = !deviceValidation.contains(where: { !$0.value })
        return isSshKeyPathValid && isCheckHostValid && allDevicesValid
    }
    
    let appVersion: String
    let author = "ykreo"

    // MARK: - Initializer
    
    init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        self.appVersion = "\(version) (build \(build))"
        
        // Загружаем настройки или используем дефолтные.
        if let data = UserDefaults.standard.data(forKey: SETTINGS_KEY),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
            Logger.settings.info("Настройки успешно загружены.")
        } else {
            self.settings = AppSettings.defaultSettings()
            Logger.settings.info("Используются настройки по умолчанию.")
        }
        
        // Первичная валидация при запуске.
        validateAllSettings()
    }
    
    // MARK: - Public API for Settings Management
    
    /// Применяет и сохраняет новые настройки в UserDefaults.
    func applyAndSave(_ newSettings: AppSettings) {
        var settingsToSave = newSettings
        // Сортируем устройства по их sortOrder перед сохранением.
        settingsToSave.devices.sort { $0.sortOrder < $1.sortOrder }
        
        self.settings = settingsToSave
        save()
    }
    
    /// Применяет настройки только для валидации (без сохранения), чтобы UI мог реагировать на ввод пользователя.
    func applyForValidation(_ newSettings: AppSettings) {
        self.settings = newSettings
    }
    
    /// Восстанавливает настройки по умолчанию.
    func restoreDefaults() {
        self.settings = AppSettings.defaultSettings()
        save()
    }

    // MARK: - Import/Export
    
    func exportSettings() {
        let savePanel = NSSavePanel()
        savePanel.title = "Экспорт конфигурации NetPulse"
        savePanel.allowedContentTypes = [UTType.json]
        savePanel.nameFieldStringValue = "netpulse_config.json"
        
        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(settings)
            try data.write(to: url)
            Logger.settings.info("Конфигурация экспортирована в \(url.path)")
        } catch {
            Logger.settings.error("Ошибка экспорта: \(error.localizedDescription)")
        }
    }

    func importSettings() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Импорт конфигурации NetPulse"
        openPanel.allowedContentTypes = [UTType.json]
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        
        guard openPanel.runModal() == .OK, let url = openPanel.url else { return }
        
        do {
            let data = try Data(contentsOf: url)
            let decodedSettings = try JSONDecoder().decode(AppSettings.self, from: data)
            applyAndSave(decodedSettings)
            Logger.settings.info("Конфигурация импортирована из \(url.path)")
        } catch {
            Logger.settings.error("Ошибка импорта: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Validation Logic
    
    /// Проверяет валидность всех устройств и общих настроек.
    private func validateAllSettings() {
        var validationResults: [UUID: Bool] = [:]
        for device in settings.devices {
            // Устройство считается валидным, если у него непустое имя, хост и пользователь,
            // а хост является валидным IP или доменным именем.
            let isDeviceValid = !device.name.trimmingCharacters(in: .whitespaces).isEmpty &&
                                !device.host.trimmingCharacters(in: .whitespaces).isEmpty &&
                                !device.user.trimmingCharacters(in: .whitespaces).isEmpty &&
                                (validateIP(device.host) || validateHost(device.host))
            
            validationResults[device.id] = isDeviceValid
        }
        self.deviceValidation = validationResults
        
        // Валидация общих полей.
        self.isSshKeyPathValid = validateSSHKey(settings.sshKeyPath)
        self.isCheckHostValid = validateHost(settings.checkHost)
    }

    private func validateIP(_ address: String) -> Bool {
        let pattern = #"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return address.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateHost(_ host: String) -> Bool {
        if validateIP(host) { return true }
        // Паттерн для доменных имен.
        let pattern = #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$"#
        return host.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func validateSSHKey(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        // Ключ должен существовать и не быть директорией.
        return FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory) && !isDirectory.boolValue
    }
    
    // MARK: - Private Methods
    
    private func save() {
        do {
            let encoded = try JSONEncoder().encode(settings)
            UserDefaults.standard.set(encoded, forKey: SETTINGS_KEY)
            Logger.settings.info("Настройки успешно сохранены.")
        } catch {
            Logger.settings.error("Не удалось сохранить настройки: \(error.localizedDescription)")
        }
    }
}
