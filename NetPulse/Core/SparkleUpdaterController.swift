// NetPulse/Core/SparkleUpdaterController.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import Sparkle

/// Этот класс-обертка отвечает за управление Sparkle.
@MainActor
final class SparkleUpdaterController: ObservableObject {
    // Контроллер Sparkle, который делает всю работу
    private let updaterController: SPUStandardUpdaterController

    init() {
        // Инициализируем стандартный контроллер Sparkle
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    }

    /// Запускает проверку обновлений.
    /// Sparkle сам покажет UI, если найдет что-то новое или если ошибок не будет.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    /// Включает или выключает автоматическую проверку обновлений.
       /// - Parameter enabled: Значение, которое нужно установить.
       func toggleAutomaticChecks(enabled: Bool) {
           // Это официальный способ управлять автоматическими проверками в Sparkle.
           // Мы напрямую говорим фреймворку, разрешено ли ему это делать.
           updaterController.updater.automaticallyChecksForUpdates = enabled
       }
}
