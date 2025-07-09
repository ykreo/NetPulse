// NetPulse/Features/Settings/SettingsView.swift
//  Copyright © 2025 ykreo. All rights reserved.
import SwiftUI
import ServiceManagement
import OSLog

struct SettingsView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var localSettings: AppSettings
    @State private var showTestResultAlert = false
    @State private var testResultTitle = ""
    @State private var testResultMessage = ""
    @State private var showRestartAlert = false
    
    init() {
        _localSettings = State(initialValue: AppSettings.defaultSettings())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            VStack(spacing: 8) {
                Text("Настройки")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Настройте параметры мониторинга сети")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
            .padding(.top, 24)
            .padding(.bottom, 16)
            
            Divider()
                .padding(.horizontal, 32)
            
            // Основной контент
            TabView {
                GeneralSettingsTab(localSettings: $localSettings)
                    .tabItem {
                        Label("Основные", systemImage: "gear")
                    }
                
                NetworkSettingsTab(
                    localSettings: $localSettings,
                    onTestRouter: testRouterConnection,
                    onTestPC: testPcConnection
                )
                .tabItem {
                    Label("Сеть", systemImage: "network")
                }
            }
            .frame(minWidth: 600, minHeight: 480)
            .padding(.horizontal, 8)
            
            // Футер с кнопками
            VStack(spacing: 0) {
                Divider()
                    .padding(.horizontal, 32)
                
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button("Сохранить") {
                        saveChanges()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!settingsManager.areAllFieldsValid)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)
            }
            .background(Color(NSColor.windowBackgroundColor))
        }
        .onAppear { self.localSettings = settingsManager.settings }
        .onChange(of: localSettings) { _, newSettings in
            settingsManager.applyForValidation(newSettings)
        }
        .onChange(of: localSettings.hideDockIcon) { _, newHideDockIcon in
            if newHideDockIcon != settingsManager.settings.hideDockIcon {
                showRestartAlert = true
            }
        }
        .alert(isPresented: $showTestResultAlert) {
            Alert(
                title: Text(testResultTitle),
                message: Text(testResultMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert("Требуется перезапуск", isPresented: $showRestartAlert) {
            Button("Перезапустить") { restartApp() }
            Button("Позже", role: .cancel) {}
        } message: {
            Text("Чтобы изменения для иконки в Dock вступили в силу, необходимо перезапустить NetPulse.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func saveChanges() {
        if localSettings.launchAtLogin != settingsManager.settings.launchAtLogin {
            handleLaunchAtLoginChange(to: localSettings.launchAtLogin)
        }
        
        settingsManager.applyAndSave(localSettings)
        (NSApp.delegate as? AppDelegate)?.updateActivationPolicy()
        networkManager.setUpdateFrequency(isFast: false)
        
        if showRestartAlert {
            restartApp()
        }
    }
    
    private func testRouterConnection() {
        Task {
            let (success, message) = await networkManager.testSSHConnection(
                user: localSettings.sshUserRouter,
                host: localSettings.routerIP
            )
            testResultTitle = success ? "Успех!" : "Ошибка!"
            testResultMessage = message
            showTestResultAlert = true
        }
    }
    
    private func testPcConnection() {
        Task {
            let (success, message) = await networkManager.testSSHConnection(
                user: localSettings.sshUserPC,
                host: localSettings.pcIP
            )
            testResultTitle = success ? "Успех!" : "Ошибка!"
            testResultMessage = message
            showTestResultAlert = true
        }
    }
    
    private func handleLaunchAtLoginChange(to newValue: Bool) {
        do {
            if newValue {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            Logger.app.info("Статус автозапуска изменен на \(newValue).")
        } catch {
            Logger.app.error("Ошибка изменения статуса автозапуска: \(error.localizedDescription)")
        }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        do {
            try task.run()
            NSApp.terminate(nil)
        } catch {
            Logger.app.fault("Не удалось перезапустить приложение: \(error.localizedDescription)")
        }
    }
}

// MARK: - Вкладка "Основные"

private struct GeneralSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var localSettings: AppSettings
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Поведение приложения
                SettingsGroup(title: "Поведение приложения", icon: "macwindow") {
                    VStack(spacing: 16) {
                        SettingsRow(
                            title: "Запускать при входе в систему",
                            description: "Автоматически запускать NetPulse при входе в macOS"
                        ) {
                            Toggle("", isOn: $localSettings.launchAtLogin)
                                .labelsHidden()
                        }
                        
                        SettingsRow(
                            title: "Скрывать иконку в Dock",
                            description: "Показывать приложение только в строке меню"
                        ) {
                            Toggle("", isOn: $localSettings.hideDockIcon)
                                .labelsHidden()
                        }
                        
                        SettingsRow(
                            title: "Интервал проверки",
                            description: "Как часто проверять статус устройств в фоновом режиме"
                        ) {
                            HStack(spacing: 8) {
                                Stepper(
                                    value: $localSettings.backgroundCheckInterval,
                                    in: 10...3600,
                                    step: 10
                                ) {
                                    EmptyView()
                                }
                                .labelsHidden()
                                
                                Text("\(Int(localSettings.backgroundCheckInterval)) сек")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .frame(minWidth: 60, alignment: .trailing)
                            }
                        }
                    }
                }
                
                // Управление конфигурацией
                SettingsGroup(title: "Конфигурация", icon: "doc.text") {
                    VStack(spacing: 16) {
                        SettingsRow(
                            title: "Импорт и экспорт",
                            description: "Сохранение и загрузка настроек приложения"
                        ) {
                            HStack(spacing: 8) {
                                Button("Импорт...") {
                                    settingsManager.importSettings()
                                    localSettings = settingsManager.settings
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                                
                                Button("Экспорт...") {
                                    settingsManager.exportSettings()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                            }
                        }
                        
                        SettingsRow(
                            title: "Сброс настроек",
                            description: "Восстановить все настройки по умолчанию"
                        ) {
                            Button("Сбросить", role: .destructive) {
                                settingsManager.restoreDefaults()
                                localSettings = settingsManager.settings
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                        }
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Вкладка "Сеть"

private struct NetworkSettingsTab: View {
    @FocusState private var focusedField: String?
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var localSettings: AppSettings
    let onTestRouter: () -> Void
    let onTestPC: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Настройки роутера
                SettingsGroup(title: "Роутер", icon: "wifi.router") {
                    VStack(spacing: 16) {
                        ValidationField(
                            title: "IP адрес",
                            text: $localSettings.routerIP,
                            focusedField: $focusedField,
                            isValid: settingsManager.isRouterIPValid,
                            prompt: "192.168.1.1",
                            description: "IP адрес вашего домашнего роутера"
                        )
                        
                        ValidationField(
                            title: "Пользователь SSH",
                            text: $localSettings.sshUserRouter,
                            focusedField: $focusedField,
                            isValid: !localSettings.sshUserRouter.isEmpty,
                            prompt: "root",
                            description: "Имя пользователя для SSH подключения к роутеру"
                        )
                        
                        SettingsRow(
                            title: "Тестирование подключения",
                            description: "Проверить SSH соединение с роутером"
                        ) {
                            Button("Проверить SSH", action: onTestRouter)
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                        }
                    }
                }
                
                // Настройки компьютера
                SettingsGroup(title: "Компьютер", icon: "desktopcomputer") {
                    VStack(spacing: 16) {
                        ValidationField(
                            title: "IP адрес",
                            text: $localSettings.pcIP,
                            focusedField: $focusedField,
                            isValid: settingsManager.isPcIPValid,
                            prompt: "192.168.1.100",
                            description: "IP адрес вашего компьютера в сети"
                        )
                        
                        ValidationField(
                            title: "MAC адрес",
                            text: $localSettings.pcMAC,
                            focusedField: $focusedField,
                            isValid: settingsManager.isPcMACValid,
                            prompt: "00:1A:2B:3C:4D:5E",
                            description: "MAC адрес сетевой карты для Wake-on-LAN"
                        )
                        ValidationField(
                            title: "Команда WOL",
                            text: $localSettings.wolCommand,
                            focusedField: $focusedField,
                            isValid: !localSettings.wolCommand.isEmpty, // Простая проверка на непустое значение
                            prompt: "/usr/bin/etherwake -i br-lan",
                            description: "Команда для отправки WOL-пакета через роутер"
                        )
                        
                        ValidationField(
                            title: "Пользователь SSH",
                            text: $localSettings.sshUserPC,
                            focusedField: $focusedField,
                            isValid: !localSettings.sshUserPC.isEmpty,
                            prompt: "username",
                            description: "Имя пользователя для SSH подключения к компьютеру"
                        )
                        
                        SettingsRow(
                            title: "Тестирование подключения",
                            description: "Проверить SSH соединение с компьютером"
                        ) {
                            Button("Проверить SSH", action: onTestPC)
                                .buttonStyle(.bordered)
                                .controlSize(.regular)
                        }
                    }
                }
                
                // Общие настройки
                SettingsGroup(title: "Общие параметры", icon: "globe") {
                    VStack(spacing: 16) {
                        SshKeyPicker(
                            keyPath: $localSettings.sshKeyPath,
                            isValid: settingsManager.isSshKeyPathValid
                        )
                        
                        ValidationField(
                            title: "Хост для проверки интернета",
                            text: $localSettings.checkHost,
                            focusedField: $focusedField,
                            isValid: settingsManager.isCheckHostValid,
                            prompt: "1.1.1.1",
                            description: "IP адрес или домен для проверки подключения к интернету"
                        )
                    }
                }
                
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Переиспользуемые компоненты

private struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.accentColor)
                    .frame(width: 20)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            .padding(.leading, 4)
            
            content
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String
    let description: String
    let content: Content
    
    init(title: String, description: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.description = description
        self.content = content()
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            content
                .frame(alignment: .trailing)
        }
    }
}

private struct ValidationField: View {
    let title: String
    @Binding var text: String
    @FocusState.Binding var focusedField: String?
    let isValid: Bool
    let prompt: String
    let description: String
    
    @State private var hasBeenEdited: Bool = false
    
    var body: some View {
        SettingsRow(title: title, description: description) {
            HStack(spacing: 8) {
                TextField("", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: title)
                    .frame(minWidth: 160)
                    .onChange(of: text) { _, _ in
                        hasBeenEdited = true
                    }
                    .onAppear {
                        if !text.isEmpty {
                            hasBeenEdited = true
                        }
                    }
                
                if hasBeenEdited {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(isValid ? .green : .red)
                        .transition(.scale.animation(.spring()))
                }
            }
        }
    }
}

private struct SshKeyPicker: View {
    @Binding var keyPath: String
    let isValid: Bool
    @State private var showEditSheet = false

    var body: some View {
        SettingsRow(
            title: "Путь к SSH ключу",
            description: "Приватный ключ для авторизации на устройствах"
        ) {
            HStack(spacing: 8) {
                Text((keyPath as NSString).abbreviatingWithTildeInPath)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

                Button("Изменить...") { showEditSheet = true }
                    .controlSize(.regular) // Используем новый размер

                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isValid ? .green : .red)
            }
        }
        .sheet(isPresented: $showEditSheet) {
            SshKeyEditView(keyPath: $keyPath)
        }
    }
}
