// NetPulse/Core/Managers/NetworkManager.swift

import Foundation
import SwiftUI
import UserNotifications
import OSLog

@MainActor
class NetworkManager: ObservableObject {
    
    // MARK: - Properties
    
    private let settingsManager: SettingsManager
    private var updateTask: Task<Void, Error>?
      
    @Published var routerStatus = DeviceStatus()
    @Published var pcStatus = DeviceStatus()
    @Published var internetStatus = DeviceStatus()
    @Published var isUpdating = false
      
    private var previousRouterStatus: DeviceStatus.State = .unknown
    private var previousPcStatus: DeviceStatus.State = .unknown
    private var previousInternetStatus: DeviceStatus.State = .unknown
    
    // MARK: - Initializer

    init(settingsManager: SettingsManager) {
        self.settingsManager = settingsManager
        Task {
            await self.requestNotificationPermission()
            // Сразу запускаем управляемую задачу
            self.setUpdateFrequency(isFast: false)
        }
    }
    
    // MARK: - Timer Control
       
    func setUpdateFrequency(isFast: Bool) {
        // Отменяем предыдущую задачу, если она была
        updateTask?.cancel()
        
        // Создаем новую задачу
        updateTask = Task {
            // Устанавливаем начальный интервал
            var currentInterval = isFast ? 5.0 : self.settingsManager.settings.backgroundCheckInterval
            let logMessage = isFast ? "Переход на быстрый режим обновления (5 сек)." : "Переход на фоновый режим обновления (\(currentInterval) сек)."
            Logger.app.info("\(logMessage)")
            
            // Сразу выполняем первую проверку
            await self.updateAllStatuses(isBackgroundCheck: !isFast)
            
            // Бесконечный цикл, который будет прерван отменой задачи
            while !Task.isCancelled {
                // Засыпаем на нужный интервал
                try await Task.sleep(for: .seconds(currentInterval))
                
                // Проверяем, не изменился ли интервал в настройках
                // Это делает систему более отзывчивой к изменениям настроек
                let settingsInterval = self.settingsManager.settings.backgroundCheckInterval
                if !isFast && currentInterval != settingsInterval {
                    currentInterval = settingsInterval
                    Logger.app.info("Интервал фонового обновления изменен на \(currentInterval) сек.")
                }
                
                // Выполняем проверку
                await self.updateAllStatuses(isBackgroundCheck: !isFast)
            }
        }
    }
    
    // MARK: - Status Update Logic
    
    func updateAllStatuses(isBackgroundCheck: Bool = false) async {
            // Если уже идет обновление, выходим
            guard !isUpdating else { return }

            // Если все поля невалидны, сбрасываем статусы
            guard self.settingsManager.areAllFieldsValid else {
                (self.routerStatus, self.pcStatus, self.internetStatus) = (.init(), .init(), .init())
                return
            }
            
            // Включаем индикатор загрузки
            self.isUpdating = true
            // Отложенное выключение индикатора в конце функции
            defer { self.isUpdating = false }
            
            Logger.app.info("Начинается обновление статусов (фоновое: \(isBackgroundCheck))...")
            
            // Асинхронно пингуем все цели
            async let directInternetLatency = self.ping(host: self.settingsManager.settings.checkHost)
            async let routerLatency = self.ping(host: self.settingsManager.settings.routerIP)
            async let pcLatency = self.ping(host: self.settingsManager.settings.pcIP)

            let (routerResult, pcResult, directInternetResult) = await (routerLatency, pcLatency, directInternetLatency)

            // Обновляем статус Роутера
            let newRouterStatus: DeviceStatus = routerResult != nil ? .init(state: .online, latency: routerResult) : .init(state: .offline)
            self.routerStatus = newRouterStatus
            
            // Обновляем статус ПК
            let newPcStatus: DeviceStatus = pcResult != nil ? .init(state: .online, latency: pcResult) : .init(state: .offline)
            self.pcStatus = newPcStatus

            // Переработанная логика статуса Интернета
            let newInternetStatus: DeviceStatus
            if let latency = directInternetResult {
                newInternetStatus = .init(state: .online, latency: latency)
            } else if self.routerStatus.state == .online {
                if let latencyViaRouter = await self.checkInternetViaRouter() {
                    newInternetStatus = .init(state: .online, latency: latencyViaRouter)
                } else {
                    newInternetStatus = .init(state: .offline)
                }
            } else {
                newInternetStatus = .init(state: .offline)
            }
            self.internetStatus = newInternetStatus

            // Только для фоновых проверок: сравниваем статусы и отправляем уведомления
            if isBackgroundCheck {
                self.checkAndNotify(device: "Роутер", old: self.previousRouterStatus, new: self.routerStatus.state)
                self.checkAndNotify(device: "Компьютер", old: self.previousPcStatus, new: self.pcStatus.state)
                self.checkAndNotify(device: "Интернет", old: self.previousInternetStatus, new: self.internetStatus.state)
            }
            
            // Обновляем "предыдущие" статусы для следующей проверки
            self.previousRouterStatus = self.routerStatus.state
            self.previousPcStatus = self.pcStatus.state
            self.previousInternetStatus = self.internetStatus.state
            
            Logger.app.info("Обновление статусов завершено.")
        }
    
    // MARK: - Core Network Operations
    
    // ИСПРАВЛЕНО: Гарантированное выполнение в фоне, чтобы не замораживать UI
    private func runProcess(executableURL: URL, arguments: [String]) async -> (output: String, error: String, exitCode: Int32) {
        return await withCheckedContinuation { continuation in
            // Запускаем всю работу в фоновом потоке
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

    /// Пингует хост с помощью нативной утилиты `/sbin/ping`.
    private func ping(host: String) async -> Double? {
        guard !host.isEmpty else { return nil }
        
        let result = await self.runProcess(
            executableURL: URL(fileURLWithPath: "/sbin/ping"),
            arguments: ["-c", "1", "-W", "2000", host] // 1 пакет, таймаут 2000 мс
        )
        
        // Парсим вывод
        if result.exitCode == 0,
           let timeRange = result.output.range(of: "time="),
           let msRange = result.output[timeRange.upperBound...].range(of: " ms") {
            let latencyString = result.output[timeRange.upperBound..<msRange.lowerBound]
            Logger.network.info("Ping to \(host) successful: \(latencyString)ms")
            return Double(latencyString)
        } else {
            Logger.network.warning("Ping to \(host) failed. Error: \(result.error)")
            return nil
        }
    }

    /// Выполняет команду по SSH с помощью нативной утилиты `/usr/bin/ssh`.
    private func ssh(user: String, host: String, command: String) async throws -> String {
        let keyPath = (self.settingsManager.settings.sshKeyPath as NSString).expandingTildeInPath
        
        // Эти опции КРИТИЧЕСКИ ВАЖНЫ. Без них ssh будет в интерактивном режиме
        // запрашивать подтверждение ключа хоста и выполнение зависнет.
        let sshOptions = [
            "-o", "StrictHostKeyChecking=no",    // Не проверять ключ хоста
            "-o", "UserKnownHostsFile=/dev/null", // Не использовать и не сохранять ключи хостов
            "-o", "ConnectTimeout=5"             // Таймаут на подключение 5 секунд
        ]
        
        let result = await self.runProcess(
            executableURL: URL(fileURLWithPath: "/usr/bin/ssh"),
            arguments: ["-i", keyPath] + sshOptions + ["\(user)@\(host)", command]
        )
        
        if result.exitCode == 0 {
            Logger.network.info("SSH command '\(command)' to \(user)@\(host) successful.")
            return result.output
        } else {
            Logger.network.error("SSH command '\(command)' to \(user)@\(host) failed. Error: \(result.error)")
            throw NSError(domain: "SSH Error", code: Int(result.exitCode), userInfo: [NSLocalizedDescriptionKey: result.error])
        }
    }

    /// Проверяет интернет через роутер (пинг с самого роутера).
    private func checkInternetViaRouter() async -> Double? {
        let command = "ping -c 1 -W 2 \(self.settingsManager.settings.checkHost)"
        do {
            let output = try await self.ssh(
                user: self.settingsManager.settings.sshUserRouter,
                host: self.settingsManager.settings.routerIP,
                command: command
            )
            // Парсим вывод пинга от роутера
            if let timeRange = output.range(of: "time="),
               let msRange = output[timeRange.upperBound...].range(of: " ms") {
                let latencyString = output[timeRange.upperBound..<msRange.lowerBound]
                return Double(latencyString)
            }
            return nil
        } catch {
            Logger.network.warning("Internet check via router failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Actions (Действия из меню)
    
    func rebootRouter() {
        self.executeAndNotify(title: "Роутер", successMessage: "Команда перезагрузки отправлена.") {
            _ = try await self.ssh(user: self.settingsManager.settings.sshUserRouter, host: self.settingsManager.settings.routerIP, command: "sleep 2 && reboot")
        }
    }

    func wolPC() {
        self.executeAndNotify(title: "Компьютер (WOL)", successMessage: "WOL-пакет для ПК отправлен.") {
            let command = "/usr/bin/etherwake -i br-lan \(self.settingsManager.settings.pcMAC)" // Команда может отличаться для разных прошивок роутеров
            _ = try await self.ssh(user: self.settingsManager.settings.sshUserRouter, host: self.settingsManager.settings.routerIP, command: command)
        }
    }

    func rebootPC() {
        self.executeAndNotify(title: "Компьютер", successMessage: "Команда перезагрузки ПК отправлена.") {
            _ = try await self.ssh(user: self.settingsManager.settings.sshUserPC, host: self.settingsManager.settings.pcIP, command: "sudo reboot")
        }
    }

    func shutdownPC() {
        self.executeAndNotify(title: "Компьютер", successMessage: "Команда выключения ПК отправлена.") {
            _ = try await self.ssh(user: self.settingsManager.settings.sshUserPC, host: self.settingsManager.settings.pcIP, command: "sudo shutdown now")
        }
    }
    
    func testSSHConnection(user: String, host: String) async -> (Bool, String) {
        guard !user.isEmpty, !host.isEmpty else {
            return (false, "Поля 'IP-адрес' и 'Пользователь' не могут быть пустыми.")
        }
        guard self.settingsManager.isSshKeyPathValid else {
            return (false, "Путь к SSH ключу недействителен или файл ключа некорректен.")
        }
        
        do {
            let result = try await self.ssh(user: user, host: host, command: "echo 'SSH OK'")
            if result.trimmingCharacters(in: .whitespacesAndNewlines) == "SSH OK" {
                return (true, "SSH-соединение успешно установлено!")
            } else {
                return (false, "Получен неожиданный ответ: \(result)")
            }
        } catch {
            return (false, "Не удалось подключиться: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helpers
    
    private func checkAndNotify(device: String, old: DeviceStatus.State, new: DeviceStatus.State) {
           // Уведомляем только если статус реально изменился и он не "неизвестен"
           guard old != .unknown, new != .unknown, old != new else { return }
           
           let title = "\(device) изменил статус"
           let body = new == .online ? "✅ Снова в сети" : "❌ Ушел в офлайн"
           
           Logger.app.info("Отправка уведомления: \(title) - \(body)")
           self.sendNotification(title: title, body: body)
    }

    private func executeAndNotify(title: String, successMessage: String, task: @escaping () async throws -> Void) {
        Task {
            do {
                try await task()
                self.sendNotification(title: title, body: successMessage)
            } catch {
                Logger.network.error("Ошибка выполнения действия '\(title)': \(error.localizedDescription)")
                self.sendNotification(title: "Ошибка: \(title)", body: error.localizedDescription)
            }
        }
    }
    
    private func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            // Запрашиваем разрешение на показ уведомлений
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
}