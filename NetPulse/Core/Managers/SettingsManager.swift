// NetPulse/Core/Managers/SettingsManager.swift
//  Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import OSLog

private let SETTINGS_KEY = "appSettingsV4" // Снова меняем ключ из-за новой структуры

@MainActor
class SettingsManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var settings: AppSettings {
        didSet {
            validateAllDevices()
        }
    }
    
    // Словарь для хранения статусов валидации для каждого устройства
    @Published private(set) var deviceValidation: [UUID: Bool] = [:]
    
    // Валидация для общих полей
    @Published private(set) var isSshKeyPathValid = false
    @Published private(set) var isCheckHostValid = false
    
    // Общая валидность всех настроек
    var areAllFieldsValid: Bool {
        // Проверяем, что все устройства валидны
        let allDevicesValid = !deviceValidation.contains(where: { !$0.value })
        // Проверяем общие настройки
        return isSshKeyPathValid && isCheckHostValid && allDevicesValid
    }
    
    let appVersion: String
    let author = "ykreo"

    // MARK: - Initializer
    
    init() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "N/A"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "N/A"
        self.appVersion = "\(version) (build \(build))"
        
        // Загружаем настройки или используем дефолтные
        if let data = UserDefaults.standard.data(forKey: SETTINGS_KEY),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decodedSettings
            Logger.settings.info("Настройки успешно загружены.")
        } else {
            self.settings = AppSettings.defaultSettings()
            Logger.settings.info("Используются настройки по умолчанию.")
        }
        
        // Первичная валидация при запуске
        validateAllDevices()
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
    
    // MARK: - Public API for Settings Management
    
    func applyAndSave(_ newSettings: AppSettings) {
        // Сортируем устройства перед сохранением
        var settingsToSave = newSettings
        settingsToSave.devices.sort { $0.sortOrder < $1.sortOrder }
        
        self.settings = settingsToSave
        save()
    }
    
    func applyForValidation(_ newSettings: AppSettings) {
        self.settings = newSettings
    }
    
    func restoreDefaults() {
        self.settings = AppSettings.defaultSettings()
        save()
    }

    // MARK: - Import/Export (без изменений, но теперь работают с новой структурой)
    
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
                applyAndSave(decodedSettings) // Применяем и сохраняем импортированные настройки
                Logger.settings.info("Конфигурация импортирована из \(url.path)")
            } catch {
                Logger.settings.error("Ошибка импорта: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - New Validation Logic
    
    /// Проверяет валидность всех устройств и общих настроек.
    private func validateAllDevices() {
        var validationResults: [UUID: Bool] = [:]
        for device in settings.devices {
            // Устройство считается валидным, если у него непустое имя, хост и пользователь
            let isDeviceValid = !device.name.isEmpty &&
                                !device.host.isEmpty &&
                                !device.user.isEmpty &&
                                (validateIP(device.host) || validateHost(device.host))
            
            validationResults[device.id] = isDeviceValid
        }
        self.deviceValidation = validationResults
        
        // Валидация общих полей
        self.isSshKeyPathValid = validateSSHKey(settings.sshKeyPath)
        self.isCheckHostValid = validateHost(settings.checkHost)
    }

    // Функции валидации IP, хоста и SSH-ключа остаются без изменений
    private func validateIP(_ address: String) -> Bool {
        let pattern = #"^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"#
        return address.range(of: pattern, options: .regularExpression) != nil
    }

    private func validateHost(_ host: String) -> Bool {
        if validateIP(host) { return true }
        let pattern = #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6}$"#
        return host.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func validateSSHKey(_ path: String) -> Bool {
        guard !path.isEmpty else { return false }
        let expandedPath = (path as NSString).expandingTildeInPath
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: expandedPath, isDirectory: &isDirectory), !isDirectory.boolValue else { return false }
        return true
    }
}
