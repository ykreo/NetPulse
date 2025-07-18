// NetPulse/Core/Managers/NetworkManager.swift
//  Copyright © 2025 ykreo. All rights reserved.

import Foundation
import SwiftUI
import UserNotifications
import OSLog

@MainActor
class NetworkManager: ObservableObject {
    
    // MARK: - Properties
    
    private let settingsManager: SettingsManager
    private var updateTask: Task<Void, Error>?
      
    @Published var deviceStatuses: [UUID: DeviceStatus] = [:]
    @Published var internetStatus = DeviceStatus()
    @Published var isUpdating = false
    @Published var commandStates: [UUID: Bool] = [:]
    @Published var menuBarIconState: (name: String, color: Color) = ("circle.fill", .secondary)
    
    // --- НОВОЕ СВОЙСТВО ДЛЯ ПРИНУДИТЕЛЬНОГО ОБНОВЛЕНИЯ ---
    @Published var iconUpdateId = UUID()
      
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
    
    // MARK: - Timer Control
       
    func setUpdateFrequency(isFast: Bool) {
        updateTask?.cancel()
        updateTask = Task {
            let interval = isFast ? 5.0 : self.settingsManager.settings.backgroundCheckInterval
            let mode = isFast ? "быстрый" : "фоновый"
            Logger.app.info("Переход на \(mode) режим обновления (\(interval) сек).")
            await self.updateAllStatuses(isBackgroundCheck: !isFast)
            
            while !Task.isCancelled {
                try await Task.sleep(for: .seconds(interval))
                let currentInterval = self.settingsManager.settings.backgroundCheckInterval
                if !isFast && interval != currentInterval {
                    self.setUpdateFrequency(isFast: false); break
                }
                await self.updateAllStatuses(isBackgroundCheck: !isFast)
            }
        }
    }
    
    // MARK: - Status Update Logic
    
    func updateAllStatuses(isBackgroundCheck: Bool = false) async {
        guard !isUpdating else { return }
        guard settingsManager.areAllFieldsValid else {
            initializeStatuses(); updateMenuBarIconState(); return
        }
            
        isUpdating = true
        defer { isUpdating = false }
            
        await withTaskGroup(of: (UUID, DeviceStatus).self) { group in
            for device in self.settingsManager.settings.devices {
                group.addTask {
                    let latency = await self.ping(host: device.host)
                    let status: DeviceStatus = latency != nil ? .init(state: .online, latency: latency) : .init(state: .offline)
                    return (device.id, status)
                }
            }
            for await (id, status) in group {
                deviceStatuses[id] = status
                if isBackgroundCheck { checkAndNotify(device: settingsManager.settings.devices.first { $0.id == id }, old: previousDeviceStatuses[id] ?? .unknown, new: status.state) }
                previousDeviceStatuses[id] = status.state
            }
        }
        
        let internetLatency = await ping(host: settingsManager.settings.checkHost)
        let newInternetStatus: DeviceStatus = internetLatency != nil ? .init(state: .online, latency: internetLatency) : .init(state: .offline)
        self.internetStatus = newInternetStatus
        if isBackgroundCheck { checkAndNotify(device: nil, old: previousInternetStatus, new: newInternetStatus.state) }
        previousInternetStatus = newInternetStatus.state
            
        updateMenuBarIconState()
    }
    
    private func updateMenuBarIconState() {
        if !settingsManager.areAllFieldsValid {
            self.menuBarIconState = ("exclamationmark.triangle.fill", .orange)
        } else {
            let statuses = self.deviceStatuses.values
            if statuses.isEmpty {
                self.menuBarIconState = ("questionmark.circle.fill", .secondary)
            } else {
                let onlineCount = statuses.filter { $0.state == .online }.count
                if onlineCount == statuses.count { self.menuBarIconState = ("circle.fill", .green) }
                else if onlineCount > 0 { self.menuBarIconState = ("circle.fill", .orange) }
                else {
                    let hasOffline = statuses.contains { $0.state == .offline }
                    self.menuBarIconState = ("circle.fill", hasOffline ? .red : .secondary)
                }
            }
        }
        // --- ОБНОВЛЯЕМ ID, ЧТОБЫ ГАРАНТИРОВАННО ПЕРЕРИСОВАТЬ VIEW ---
        self.iconUpdateId = UUID()
    }
    
    // ... Остальной код файла остается без изменений ...
    
    func executeCommand(for device: Device, command: String?) {
        guard let commandToExecute = command, !commandToExecute.isEmpty else { return }
        let hostForCommand = commandToExecute.contains("etherwake") ? settingsManager.settings.devices.first(where: { $0.icon == "wifi.router" })?.host ?? "" : device.host
        Task {
            self.commandStates[device.id] = true
            defer { self.commandStates[device.id] = false }
            do {
                _ = try await self.ssh(user: device.user, host: hostForCommand, command: commandToExecute)
                sendNotification(title: "✅ Успех: \(device.name)", body: "Команда успешно отправлена.")
            } catch {
                Logger.network.error("Ошибка выполнения команды для '\(device.name)': \(error.localizedDescription)")
                sendNotification(title: "❌ Ошибка: \(device.name)", body: error.localizedDescription)
            }
        }
    }
    
    private func runProcess(executableURL: URL, arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process(); process.executableURL = executableURL; process.arguments = arguments
                let outputPipe = Pipe(); let errorPipe = Pipe(); process.standardOutput = outputPipe; process.standardError = errorPipe
                do {
                    try process.run()
                    let outputData = try outputPipe.fileHandleForReading.readToEnd() ?? Data()
                    let errorData = try errorPipe.fileHandleForReading.readToEnd() ?? Data()
                    process.waitUntilExit()
                    let output = String(data: outputData, encoding: .utf8) ?? ""; let error = String(data: errorData, encoding: .utf8) ?? ""
                    continuation.resume(returning: (output, error, process.terminationStatus))
                } catch { continuation.resume(returning: ("", "Failed to run process: \(error)", 1)) }
            }
        }
    }
    private func ping(host: String) async -> Double? {
        guard !host.isEmpty else { return nil }
        let result = await runProcess(executableURL: URL(fileURLWithPath: "/sbin/ping"), arguments: ["-c", "1", "-W", "2000", host])
        if result.exitCode == 0, let timeRange = result.output.range(of: "time="), let msRange = result.output[timeRange.upperBound...].range(of: " ms") {
            let latencyString = result.output[timeRange.upperBound..<msRange.lowerBound]
            return Double(latencyString)
        } else { return nil }
    }
    private func ssh(user: String, host: String, command: String) async throws -> String {
        let keyPath = (settingsManager.settings.sshKeyPath as NSString).expandingTildeInPath
        let sshOptions = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=5"]
        let result = await runProcess(executableURL: URL(fileURLWithPath: "/usr/bin/ssh"), arguments: ["-i", keyPath] + sshOptions + ["\(user)@\(host)", command])
        if result.exitCode == 0 { return result.output } else {
            let errorDescription = result.error.isEmpty ? "SSH command failed with exit code \(result.exitCode)." : result.error
            throw NSError(domain: "SSH Error", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: errorDescription])
        }
    }
    func testSSHConnection(user: String, host: String) async -> (Bool, String) {
        guard !user.isEmpty, !host.isEmpty else { return (false, "Поля 'Хост' и 'Пользователь' не могут быть пустыми.") }
        guard settingsManager.isSshKeyPathValid else { return (false, "Путь к SSH ключу недействителен.") }
        do {
            let result = try await self.ssh(user: user, host: host, command: "echo 'SSH OK'")
            return result.trimmingCharacters(in: .whitespacesAndNewlines) == "SSH OK" ? (true, "SSH-соединение успешно установлено!") : (false, "Получен неожиданный ответ: \(result)")
        } catch { return (false, "Не удалось подключиться: \(error.localizedDescription)") }
    }
    private func initializeStatuses() {
        var freshStatuses: [UUID: DeviceStatus] = [:]; for device in settingsManager.settings.devices { freshStatuses[device.id] = DeviceStatus(state: .unknown) }
        self.deviceStatuses = freshStatuses; self.internetStatus = DeviceStatus(state: .unknown); self.previousDeviceStatuses.removeAll(); self.previousInternetStatus = .unknown
    }
    private func checkAndNotify(device: Device?, old: DeviceStatus.State, new: DeviceStatus.State) {
        guard old != .unknown, new != .unknown, old != new else { return }
        let deviceName = device?.name ?? "Интернет"; let title = "\(deviceName) изменил статус"; let body = new == .online ? "✅ Снова в сети" : "❌ Ушел в офлайн"
        sendNotification(title: title, body: body)
    }
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do { try await center.requestAuthorization(options: [.alert, .sound, .badge]) } catch { Logger.app.warning("Не удалось получить разрешение на уведомления: \(error.localizedDescription)") }
    }
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}
