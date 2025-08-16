// NetPulse/Core/Managers/NetworkManager.swift
// Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI
import UserNotifications
import OSLog

@MainActor
final class NetworkManager: ObservableObject {

    enum NetworkError: LocalizedError {
        case invalidHost
        case timeout
        case cancelled
        case processFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidHost:
                return String(localized: "network.error.invalid_host")
            case .timeout:
                return String(localized: "network.error.timeout")
            case .cancelled:
                return String(localized: "network.error.cancelled")
            case .processFailed(let message):
                return message
            }
        }
    }
    
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
    
    func startFastUpdates() {
        setUpdateFrequency(isFast: true)
    }
    
    func stopFastUpdates() {
        setUpdateFrequency(isFast: false)
    }
       
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
                    do {
                        let latency = try await self.ping(host: device.host)
                        return (device.id, DeviceStatus(state: .online, latency: latency))
                    } catch {
                        Logger.network.error("Ping error for \(device.name): \(error.localizedDescription)")
                        return (device.id, DeviceStatus(state: .offline))
                    }
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

        let newInternetStatus: DeviceStatus
        do {
            let latency = try await ping(host: settingsManager.settings.checkHost)
            newInternetStatus = .init(state: .online, latency: latency)
        } catch {
            Logger.network.error("Internet check failed: \(error.localizedDescription)")
            newInternetStatus = .init(state: .offline)
        }
        self.internetStatus = newInternetStatus
        
        if isBackgroundCheck {
            checkAndNotify(device: nil, old: previousInternetStatus, new: newInternetStatus.state)
        }
        previousInternetStatus = newInternetStatus.state
            
        updateMenuBarIconState()
    }
    
    func executeCommand(for device: Device, command: String?) {
        guard let commandToExecute = command, !commandToExecute.isEmpty else { return }

        var targetHost = device.host
        var targetUser = device.user

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
                let successMessage = output.isEmpty ? String(localized: "notification.command.success.body.empty") : output
                sendNotification(title: "✅ \(device.name)", subtitle: successMessage, body: "")
            } catch NetworkError.cancelled {
                Logger.network.error("Команда отменена для '\(device.name)'")
                sendNotification(title: "⚠️ \(device.name)", subtitle: String(localized: "command.cancelled"), body: "")
            } catch {
                Logger.network.error("Ошибка выполнения команды для '\(device.name)': \(error.localizedDescription)")
                sendNotification(title: "❌ \(device.name)", subtitle: "Ошибка выполнения команды", body: error.localizedDescription)
            }
        }
    }
    
    func testSSHConnection(user: String, host: String) async -> (Bool, String) {
        guard !user.isEmpty, !host.isEmpty else { return (false, String(localized: "ssh.error.empty_fields")) }
        guard settingsManager.isSshKeyPathValid else { return (false, String(localized: "ssh.error.invalid_key_path")) }
        
        do {
            let result = try await ssh(user: user, host: host, command: "echo 'SSH OK'")
            let isSuccess = result.trimmingCharacters(in: .whitespacesAndNewlines) == "SSH OK"
            let message = isSuccess ? String(localized: "ssh.success.message") : "\(String(localized: "ssh.error.unexpected_response")) \(result)"
            return (isSuccess, message)
        } catch {
            return (false, "\(String(localized: "ssh.error.connection_failed")) \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func updateMenuBarIconState() {
            // --- НАЧАЛО ДИАГНОСТИЧЕСКОГО БЛОКА ---
            Logger.app.debug("--- Обновление иконки ---")
            
            let isValid = settingsManager.areAllFieldsValid
            Logger.app.debug("Настройки валидны: \(isValid)")
            
            if !isValid {
                menuBarIconState = ("exclamationmark.triangle.fill", .orange)
                Logger.app.debug("Результат: Оранжевая иконка (невалидные настройки)")
            } else {
                let statuses = deviceStatuses.values
                Logger.app.debug("Количество статусов: \(statuses.count)")
                
                if statuses.isEmpty || statuses.allSatisfy({ $0.state == .unknown }) {
                    menuBarIconState = ("questionmark.circle.fill", .secondary)
                    Logger.app.debug("Результат: Серая иконка (статусы неизвестны или отсутствуют)")
                } else {
                    let onlineCount = statuses.filter { $0.state == .online }.count
                    let offlineCount = statuses.filter { $0.state == .offline }.count
                    Logger.app.debug("Статусы: \(onlineCount) онлайн, \(offlineCount) офлайн")
                    
                    if onlineCount == statuses.count {
                        menuBarIconState = ("circle.fill", .green)
                        Logger.app.debug("Результат: Зеленая иконка (все онлайн)")
                    } else if onlineCount > 0 {
                        menuBarIconState = ("circle.fill", .orange)
                        Logger.app.debug("Результат: Оранжевая иконка (частично онлайн)")
                    } else {
                        menuBarIconState = ("circle.fill", .red)
                        Logger.app.debug("Результат: Красная иконка (все офлайн)")
                    }
                }
            }
            // --- КОНЕЦ ДИАГНОСТИЧЕСКОГО БЛОКА ---
            
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
        
        let title: String
        let subtitle: String
        
        if let device = device {
            title = device.name
            subtitle = new == .online ? "✅ \(String(localized: "status.online"))" : "❌ \(String(localized: "status.offline"))"
        } else {
            title = String(localized: "device.internet")
            subtitle = new == .online ? "✅ \(String(localized: "status.online"))" : "❌ \(String(localized: "status.offline"))"
        }

        sendNotification(title: title, subtitle: subtitle, body: "")
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        if granted == true {
            Logger.app.info("Разрешение на уведомления получено.")
        } else {
            Logger.app.warning("Пользователь отклонил запрос на уведомления.")
        }
    }
    
    private func sendNotification(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Process Execution

    private func runProcess(executableURL: URL, arguments: [String], timeout: TimeInterval) async throws -> (output: String, error: String, exitCode: Int32) {
        try Task.checkCancellation()
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executableURL
            process.arguments = arguments

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
                return
            }

            let timeoutTask = Task {
                try? await Task.sleep(for: .seconds(timeout))
                if process.isRunning { process.terminate() }
            }

            let cancelTask = Task {
                while process.isRunning {
                    try await Task.sleep(for: .milliseconds(100))
                    if Task.isCancelled {
                        process.terminate()
                        return
                    }
                }
            }

            process.terminationHandler = { _ in
                timeoutTask.cancel()
                cancelTask.cancel()
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let error = String(data: errorData, encoding: .utf8) ?? ""
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    continuation.resume(returning: (output, error, process.terminationStatus))
                }
            }
        }
    }

    func ping(host: String, timeout: TimeInterval = 2) async throws -> Double {
        try Task.checkCancellation()
        guard !host.isEmpty else { throw NetworkError.invalidHost }
        let ms = Int(timeout * 1000)
        let result = try await runProcess(executableURL: URL(fileURLWithPath: "/sbin/ping"), arguments: ["-c", "1", "-W", "\(ms)", host], timeout: timeout)

        guard result.exitCode == 0,
              let timeRange = result.output.range(of: "time="),
              let msRange = result.output[timeRange.upperBound...].range(of: " ms")
        else {
            throw NetworkError.processFailed(result.error.isEmpty ? "Ping failed" : result.error)
        }

        try Task.checkCancellation()
        let latencyString = result.output[timeRange.upperBound..<msRange.lowerBound]
        guard let latency = Double(latencyString) else {
            throw NetworkError.processFailed("Invalid latency format")
        }
        return latency
    }

    func ssh(user: String, host: String, command: String, timeout: TimeInterval = 5) async throws -> String {
        try Task.checkCancellation()
        let keyPath = (settingsManager.settings.sshKeyPath as NSString).expandingTildeInPath
        let sshOptions = [
            "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null",
            "-o", "ConnectTimeout=\(Int(timeout))"
        ]
        let arguments = ["-i", keyPath] + sshOptions + ["\(user)@\(host)", command]

        do {
            let result = try await runProcess(executableURL: URL(fileURLWithPath: "/usr/bin/ssh"), arguments: arguments, timeout: timeout)
            try Task.checkCancellation()
            if result.exitCode == 0 {
                return result.output
            } else {
                let description = result.error.isEmpty ? "SSH command failed with exit code \(result.exitCode)." : result.error
                throw NetworkError.processFailed(description)
            }
        } catch is CancellationError {
            throw NetworkError.cancelled
        }
    }
}
