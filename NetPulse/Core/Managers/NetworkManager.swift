// NetPulse/Core/Managers/NetworkManager.swift
// Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI
import UserNotifications
import OSLog

@MainActor
final class NetworkManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var deviceStatuses: [UUID: DeviceStatus] = [:]
    @Published private(set) var internetStatus = DeviceStatus()
    @Published private(set) var isUpdating = false
    @Published private(set) var commandStates: [UUID: Bool] = [:]
    @Published private(set) var menuBarIconState: (name: String, color: Color) = ("circle.fill", .secondary)
    
    @Published private(set) var iconUpdateId = UUID()
      
    // MARK: - Private Properties
    
    private let settingsManager: SettingsManager
    private var updateTask: Task<Void, Error>?
    private var previousDeviceStatuses: [UUID: DeviceStatus.State] = [:]
    private var previousInternetStatus: DeviceStatus.State = .unknown
    
    // MARK: - Initializer

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        Task {
            await self.requestNotificationPermission()
            self.initializeStatuses()
            self.setUpdateFrequency(isFast: false)
        }
    }
    
    // MARK: - Public API
       
    func setUpdateFrequency(isFast: Bool) {
        updateTask?.cancel()
        updateTask = Task {
            let interval = isFast ? 5.0 : settingsManager.settings.backgroundCheckInterval
            let mode = isFast ? "быстрый" : "фоновый"
            Logger.network.info("Переход на \(mode) режим обновления (каждые \(String(format: "%.0f", interval)) сек).")
            
            await updateAllStatuses(isBackgroundCheck: !isFast)
            
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(interval))
                let currentInterval = settingsManager.settings.backgroundCheckInterval
                if !isFast && interval != currentInterval {
                    setUpdateFrequency(isFast: false); break
                }
                await updateAllStatuses(isBackgroundCheck: !isFast)
            }
        }
    }
    
    func updateAllStatuses(isBackgroundCheck: Bool = false) async {
        guard !isUpdating else { return }
        guard settingsManager.areAllFieldsValid else {
            initializeStatuses()
            return
        }
            
        isUpdating = true
        defer { isUpdating = false }
            
        await withTaskGroup(of: (UUID, DeviceStatus).self) { group in
            for device in settingsManager.settings.devices {
                group.addTask {
                    let latency = await self.ping(host: device.host)
                    let status: DeviceStatus = latency != nil ? .init(state: .online, latency: latency) : .init(state: .offline)
                    return (device.id, status)
                }
            }
            
            for await (id, status) in group {
                deviceStatuses[id] = status
                if isBackgroundCheck {
                    checkAndNotify(
                        device: settingsManager.settings.devices.first { $0.id == id },
                        old: previousDeviceStatuses[id] ?? .unknown,
                        new: status.state
                    )
                }
                previousDeviceStatuses[id] = status.state
            }
        }
        
        let internetLatency = await ping(host: settingsManager.settings.checkHost)
        let newInternetStatus: DeviceStatus = internetLatency != nil ? .init(state: .online, latency: internetLatency) : .init(state: .offline)
        self.internetStatus = newInternetStatus
        
        if isBackgroundCheck {
            checkAndNotify(device: nil, old: previousInternetStatus, new: newInternetStatus.state)
        }
        previousInternetStatus = newInternetStatus.state
            
        updateMenuBarIconState()
    }
    
    // ИСПРАВЛЕНО: Логика выполнения команды
    func executeCommand(for device: Device, command: String?) {
        guard let commandToExecute = command, !commandToExecute.isEmpty else { return }

        // По умолчанию используем данные текущего устройства
        var targetHost = device.host
        var targetUser = device.user

        // Специальная логика для Wake-on-LAN: команда должна выполняться на роутере
        if commandToExecute.contains("etherwake") {
            if let router = settingsManager.settings.devices.first(where: { $0.icon == "wifi.router" }) {
                targetHost = router.host
                targetUser = router.user
                Logger.network.info("Команда Wake-on-LAN. Цель изменена на роутер: \(targetUser)@\(targetHost)")
            } else {
                Logger.network.warning("Команда Wake-on-LAN, но роутер не найден в настройках. Используется хост устройства.")
            }
        }
        
        Task {
            commandStates[device.id] = true
            defer { commandStates[device.id] = false }
            
            do {
                let output = try await ssh(user: targetUser, host: targetHost, command: commandToExecute)
                let successMessage = output.isEmpty ? "Команда успешно отправлена." : output
                sendNotification(title: "✅ \(device.name)", body: successMessage)
            } catch {
                Logger.network.error("Ошибка выполнения команды для '\(device.name)': \(error.localizedDescription)")
                sendNotification(title: "❌ \(device.name)", body: error.localizedDescription)
            }
        }
    }
    
    func testSSHConnection(user: String, host: String) async -> (Bool, String) {
        guard !user.isEmpty, !host.isEmpty else { return (false, String(localized: "Host and User fields cannot be empty.")) }
        guard settingsManager.isSshKeyPathValid else { return (false, String(localized: "SSH key path is invalid.")) }
        
        do {
            let result = try await ssh(user: user, host: host, command: "echo 'SSH OK'")
            let isSuccess = result.trimmingCharacters(in: .whitespacesAndNewlines) == "SSH OK"
            let message = isSuccess ? String(localized: "SSH connection successful!") : "\(String(localized: "Unexpected response received:")) \(result)"
            return (isSuccess, message)
        } catch {
            return (false, "\(String(localized: "Failed to connect:")) \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateMenuBarIconState() {
        if !settingsManager.areAllFieldsValid {
            menuBarIconState = ("exclamationmark.triangle.fill", .orange)
        } else {
            let statuses = deviceStatuses.values
            if statuses.isEmpty {
                menuBarIconState = ("questionmark.circle.fill", .secondary)
            } else {
                let onlineCount = statuses.filter { $0.state == .online }.count
                if onlineCount == statuses.count {
                    menuBarIconState = ("circle.fill", .green)
                } else if onlineCount > 0 {
                    menuBarIconState = ("circle.fill", .orange)
                } else {
                    menuBarIconState = ("circle.fill", .red)
                }
            }
        }
        iconUpdateId = UUID()
    }
    
    private func initializeStatuses() {
        var freshStatuses: [UUID: DeviceStatus] = [:]
        for device in settingsManager.settings.devices {
            freshStatuses[device.id] = DeviceStatus(state: .unknown)
        }
        deviceStatuses = freshStatuses
        internetStatus = DeviceStatus(state: .unknown)
        previousDeviceStatuses.removeAll()
        previousInternetStatus = .unknown
        updateMenuBarIconState()
    }
    
    private func checkAndNotify(device: Device?, old: DeviceStatus.State, new: DeviceStatus.State) {
        guard old != .unknown, new != .unknown, old != new else { return }
        
        let deviceName = device?.name ?? String(localized: "Internet")
        let title = "\(deviceName) \(String(localized: "Status changed"))"
        let body = new == .online ? String(localized: "Back online") : String(localized: "Went offline")
        sendNotification(title: title, body: body)
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            Logger.app.warning("Не удалось получить разрешение на уведомления: \(error.localizedDescription)")
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Process Execution
    
    private func runProcess(executableURL: URL, arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = executableURL
                process.arguments = arguments
                
                let outputPipe = Pipe()
                let errorPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = errorPipe
                
                do {
                    try process.run()
                    let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
                    let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
                    process.waitUntilExit()
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    let error = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (output, error, process.terminationStatus))
                } catch {
                    continuation.resume(returning: ("", "Failed to run process: \(error)", 1))
                }
            }
        }
    }
    
    private func ping(host: String) async -> Double? {
        guard !host.isEmpty else { return nil }
        // -c 1: одна попытка, -W 2000: таймаут 2000 мс
        let result = await runProcess(executableURL: URL(fileURLWithPath: "/sbin/ping"), arguments: ["-c", "1", "-W", "2000", host])
        
        guard result.exitCode == 0,
              let timeRange = result.output.range(of: "time="),
              let msRange = result.output[timeRange.upperBound...].range(of: " ms")
        else {
            return nil
        }
        
        let latencyString = result.output[timeRange.upperBound..<msRange.lowerBound]
        return Double(latencyString)
    }

    private func ssh(user: String, host: String, command: String) async throws -> String {
        let keyPath = (settingsManager.settings.sshKeyPath as NSString).expandingTildeInPath
        let sshOptions = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=5"
        ]
        let arguments = ["-i", keyPath] + sshOptions + ["\(user)@\(host)", command]
        
        let result = await runProcess(executableURL: URL(fileURLWithPath: "/usr/bin/ssh"), arguments: arguments)
        
        if result.exitCode == 0 {
            return result.output
        } else {
            let errorDescription = result.error.isEmpty ? "SSH command failed with exit code \(result.exitCode)." : result.error
            throw NSError(domain: "SSH Error", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: errorDescription])
        }
    }
}
