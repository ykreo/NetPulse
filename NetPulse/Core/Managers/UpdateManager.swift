// NetPulse/Core/Managers/UpdateManager.swift
//  Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import OSLog

private struct GitHubRelease: Decodable {
    let tagName: String, htmlUrl: String, body: String
    enum CodingKeys: String, CodingKey { case tagName = "tag_name", htmlUrl = "html_url", body }
}

@MainActor
class UpdateManager: ObservableObject {
    private let repoURL = URL(string: "https://api.github.com/repos/ykreo/NetPulse/releases/latest")!

    func checkForUpdates(silently: Bool = true) async {
        Logger.app.info("--- Начинаю проверку обновлений ---")
        guard let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            Logger.app.error("!!! Не удалось получить текущую версию приложения из Bundle.")
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: repoURL)

            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                if !silently { presentErrorAlert(error: NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Сервер вернул код статуса \(httpResponse.statusCode)"])) }
                return
            }

            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let latestVersion = release.tagName.replacingOccurrences(of: "v", with: "")

            if latestVersion.compare(currentVersion, options: .numeric) == .orderedDescending {
                presentUpdateAlert(for: release)
            } else if !silently {
                presentNoUpdateAlert()
            }
        } catch {
            if !silently { presentErrorAlert(error: error) }
        }
    }

    private func presentUpdateAlert(for release: GitHubRelease) {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.update.title")
        alert.informativeText = String(format: NSLocalizedString("alert.update.message", comment: "Update message"), release.tagName, release.body)
        alert.alertStyle = .informational
        alert.addButton(withTitle: String(localized: "alert.update.button.download"))
        alert.addButton(withTitle: String(localized: "alert.update.button.later"))

        if let url = URL(string: release.htmlUrl), alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(url)
        }
    }

    private func presentNoUpdateAlert() {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.no_update.title")
        alert.informativeText = String(localized: "alert.no_update.message")
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentErrorAlert(error: Error) {
        let alert = NSAlert()
        alert.messageText = String(localized: "alert.update_error.title")
        alert.informativeText = String(format: NSLocalizedString("alert.update_error.message", comment: "Update error message"), error.localizedDescription)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
