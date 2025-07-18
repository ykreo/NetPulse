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

@MainActor
class UpdateManager {
    
    private let repoURL = URL(string: "https://api.github.com/repos/ykreo/NetPulse/releases/latest")!
    
    /// Проверяет наличие новой версии на GitHub.
    func checkForUpdates(silently: Bool = true) async {
        Logger.app.info("Проверка обновлений...")
        
        do {
            let (data, _) = try await URLSession.shared.data(from: repoURL)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")
            guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
                Logger.app.error("Не удалось получить текущую версию приложения.")
                return
            }
            
            // Сравниваем версии. compare() вернет .orderedAscending, если latestVersion > currentVersion
            if latestVersion.compare(currentVersion, options: .numeric) == .orderedAscending {
                Logger.app.info("Найдена новая версия: \(latestVersion). Текущая: \(currentVersion).")
                presentUpdateAlert(for: release)
            } else {
                Logger.app.info("У вас установлена последняя версия.")
                if !silently {
                    presentNoUpdateAlert()
                }
            }
        } catch {
            Logger.app.error("Ошибка при проверке обновлений: \(error.localizedDescription)")
            if !silently {
                presentErrorAlert(error: error)
            }
        }
    }
    
    /// Показывает диалоговое окно с предложением обновиться.
    private func presentUpdateAlert(for release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = "Доступна новая версия!"
        alert.informativeText = "Найдена версия \(release.tagName). Хотите загрузить ее сейчас?\n\nЧто нового:\n\(release.body)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Загрузить")
        alert.addButton(withTitle: "Позже")
        
        // Открываем URL на загрузку в браузере по умолчанию
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
        alert.informativeText = "Не удалось связаться с сервером GitHub. Пожалуйста, проверьте ваше интернет-соединение.\n\n(\(error.localizedDescription))"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
