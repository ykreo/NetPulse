// NetPulse/Core/Managers/UpdateManager.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import OSLog

// Структура для декодирования ответа от GitHub API
private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlUrl: String
    let body: String
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
        case body
    }
}

// --- ИСПРАВЛЕНО: Добавлено 'ObservableObject' ---
@MainActor
class UpdateManager: ObservableObject {
    
    private let repoURL = URL(string: "https://api.github.com/repos/ykreo/NetPulse/releases/latest")!
    
    /// Проверяет наличие новой версии на GitHub.
    func checkForUpdates(silently: Bool = true) async {
        Logger.app.info("--- Начинаю проверку обновлений ---")
        
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            Logger.app.error("!!! Не удалось получить текущую версию приложения из Bundle.")
            return
        }
        Logger.app.info("Текущая версия приложения: \(currentVersion)")
        
        do {
            Logger.app.info("Отправляю запрос на URL: \(self.repoURL.absoluteString)")
            let (data, response) = try await URLSession.shared.data(from: repoURL)
            
            if let httpResponse = response as? HTTPURLResponse {
                Logger.app.info("Получен ответ от сервера. Статус код: \(httpResponse.statusCode)")
                if !(200...299).contains(httpResponse.statusCode) {
                    Logger.app.error("!!! Сервер вернул ошибку. Проверка прекращена.")
                    if !silently { presentErrorAlert(error: NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Сервер вернул код статуса \(httpResponse.statusCode)"])) }
                    return
                }
            }
            
            Logger.app.info("Пытаюсь декодировать JSON...")
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            Logger.app.info("JSON успешно декодирован. Тег релиза: '\(release.tagName)'")
            
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            Logger.app.info("Сравниваю версии: Latest = '\(latestVersion)', Current = '\(currentVersion)'")
            
            
            let comparisonResult = latestVersion.compare(currentVersion, options: .numeric)
            
            if comparisonResult == .orderedDescending {
                Logger.app.info(">>> РЕЗУЛЬТАТ: Найдена новая версия! (\(latestVersion) > \(currentVersion))")
                presentUpdateAlert(for: release)
            } else {
                Logger.app.info(">>> РЕЗУЛЬТАТ: У вас установлена последняя версия.")
                if !silently {
                    presentNoUpdateAlert()
                }
            }
        } catch {
            Logger.app.error("!!! КРИТИЧЕСКАЯ ОШИБКА в блоке do-catch: \(error.localizedDescription)")
            if !silently {
                presentErrorAlert(error: error)
            }
        }
        Logger.app.info("--- Проверка обновлений завершена ---")
    }
    
    /// Показывает диалоговое окно с предложением обновиться.
    private func presentUpdateAlert(for release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Доступна новая версия!"
        alert.informativeText = "Найдена версия \(release.tagName). Хотите загрузить ее сейчас?\n\nЧто нового:\n\(release.body)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Загрузить")
        alert.addButton(withTitle: "Позже")
        
        if let url = URL(string: release.htmlUrl), alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }
    
    /// Показывает диалоговое окно, что обновлений нет.
    private func presentNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = "Обновлений не найдено"
        alert.informativeText = "У вас установлена самая свежая версия NetPulse."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    /// Показывает диалоговое окно с ошибкой.
    private func presentErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = "Ошибка проверки обновлений"
        alert.informativeText = "Не удалось связаться с сервером GitHub или обработать ответ. Пожалуйста, проверьте ваше интернет-соединение и попробуйте позже.\n\nДетали: \(error.localizedDescription)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
