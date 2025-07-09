// NetPulse/Features/Settings/SettingsView.swift

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
            Text("Настройки")
                .font(.largeTitle).fontWeight(.bold)
                .padding()

            TabView {
                GeneralSettingsTab(localSettings: $localSettings)
                    .tabItem { Label("Основные", systemImage: "gear") }
                
                NetworkSettingsTab(localSettings: $localSettings,
                                   onTestRouter: testRouterConnection,
                                   onTestPC: testPcConnection)
                    .tabItem { Label("Сеть", systemImage: "network") }
            }
            .frame(minWidth: 580, minHeight: 450)
            
            HStack {
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }
                Button("Сохранить") {
                    saveChanges()
                    dismiss()
                }
                .disabled(!settingsManager.areAllFieldsValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.bar)
        }
        .onAppear { self.localSettings = settingsManager.settings }
        .onChange(of: localSettings) { _, newSettings in settingsManager.applyForValidation(newSettings) }
        .onChange(of: localSettings.hideDockIcon) { _, newHideDockIcon in
            if newHideDockIcon != settingsManager.settings.hideDockIcon {
                showRestartAlert = true
            }
        }
        .alert(isPresented: $showTestResultAlert) {
            Alert(title: Text(testResultTitle), message: Text(testResultMessage), dismissButton: .default(Text("OK")))
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
            let (success, message) = await networkManager.testSSHConnection(user: localSettings.sshUserRouter, host: localSettings.routerIP)
            testResultTitle = success ? "Успех!" : "Ошибка!"
            testResultMessage = message
            showTestResultAlert = true
        }
    }
    
    private func testPcConnection() {
        Task {
            let (success, message) = await networkManager.testSSHConnection(user: localSettings.sshUserPC, host: localSettings.pcIP)
            testResultTitle = success ? "Успех!" : "Ошибка!"
            testResultMessage = message
            showTestResultAlert = true
        }
    }
    
    private func handleLaunchAtLoginChange(to newValue: Bool) {
        do {
            if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
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
        Form {
            Section("Поведение приложения") {
                Toggle(isOn: $localSettings.launchAtLogin) {
                    Label("Запускать при входе в систему", systemImage: "macwindow.on.rectangle")
                }
                Toggle(isOn: $localSettings.hideDockIcon) {
                    Label("Скрывать иконку в Dock", systemImage: "dock.rectangle")
                }
                
                LabeledContent {
                    Stepper(value: $localSettings.backgroundCheckInterval, in: 10...3600, step: 10) {
                        TextField("", value: $localSettings.backgroundCheckInterval, formatter: NumberFormatter())
                            .multilineTextAlignment(.trailing)
                            .frame(minWidth: 50)
                    }
                } label: {
                    Label("Интервал проверки (сек)", systemImage: "timer")
                }
            }
            
            Section {
                // Кнопки импорта и экспорта теперь внутри LabeledContent
                LabeledContent {
                    HStack {
                        Button("Импорт...") { settingsManager.importSettings() }
                        Button("Экспорт...") { settingsManager.exportSettings() }
                    }
                } label: {
                    Label("Конфигурация", systemImage: "doc.text.magnifyingglass")
                }
            } footer: {
                // Сброс вынесен отдельно для наглядности
                HStack {
                    Spacer()
                    Button("Сбросить все настройки", role: .destructive) {
                        settingsManager.restoreDefaults()
                        localSettings = settingsManager.settings
                    }
                }
                .padding(.top, 8)
            }
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
        Form {
            Section("Роутер") {
                ValidationField(title: "IP адрес", text: $localSettings.routerIP, focusedField: $focusedField, isValid: settingsManager.isRouterIPValid, prompt: "Например, 192.168.1.1")
                ValidationField(title: "Пользователь SSH", text: $localSettings.sshUserRouter, focusedField: $focusedField, isValid: !localSettings.sshUserRouter.isEmpty, prompt: "Обычно 'root' или 'admin'")
                HStack { Spacer(); Button("Проверить SSH", action: onTestRouter) }
            }
            
            Section("Компьютер") {
                ValidationField(title: "IP адрес", text: $localSettings.pcIP, focusedField: $focusedField, isValid: settingsManager.isPcIPValid, prompt: "Например, 192.168.1.100")
                ValidationField(title: "MAC адрес", text: $localSettings.pcMAC, focusedField: $focusedField, isValid: settingsManager.isPcMACValid, prompt: "Например, 00:1A:2B:3C:4D:5E", helpText: "Используется для Wake-on-LAN.")
                ValidationField(title: "Пользователь SSH", text: $localSettings.sshUserPC, focusedField: $focusedField, isValid: !localSettings.sshUserPC.isEmpty, prompt: "Имя вашего пользователя на ПК")
                HStack { Spacer(); Button("Проверить SSH", action: onTestPC) }
            }
            
            Section("Общие") {
                SshKeyPicker(keyPath: $localSettings.sshKeyPath, isValid: settingsManager.isSshKeyPathValid, helpText: "Приватный ключ для доступа к устройствам без пароля.")
                ValidationField(title: "Хост для проверки", text: $localSettings.checkHost, focusedField: $focusedField, isValid: settingsManager.isCheckHostValid, prompt: "Например, 1.1.1.1 или ya.ru", helpText: "Адрес для определения статуса интернета.")
            }
        }
        .padding()
    }
}

// MARK: - Переиспользуемые компоненты
private struct ValidationField: View {
    let title: String // Мы будем использовать title как стабильный ID
    @Binding var text: String
    @FocusState.Binding var focusedField: String?
    let isValid: Bool
    let prompt: String
    var helpText: String? = nil

    @State private var hasBeenEdited: Bool = false

    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    TextField("", text: $text, prompt: Text(prompt).foregroundColor(.secondary.opacity(0.5)))
                        // ИСПОЛЬЗУЕМ `title` КАК СТАБИЛЬНЫЙ ИДЕНТИФИКАТОР
                        .focused($focusedField, equals: title)
                        .onChange(of: text) { _, _ in hasBeenEdited = true }
                        // При появлении проверяем, не было ли поле уже отредактировано
                        .onAppear {
                            if !text.isEmpty { hasBeenEdited = true }
                        }

                    // Показываем иконку, если поле было отредактировано или оно не пустое при открытии
                    if hasBeenEdited {
                        Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(isValid ? .green : .red)
                            .transition(.scale.animation(.spring()))
                    }
                }
                if let helpText = helpText {
                    Text(helpText).font(.caption2).foregroundColor(.secondary)
                }
            }
        } label: { Text(title) }
    }
}

// ИСПРАВЛЕННАЯ ВЕРСИЯ SshKeyPicker
private struct SshKeyPicker: View {
    @Binding var keyPath: String
    let isValid: Bool
    let helpText: String
    
    var body: some View {
        LabeledContent {
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    // Текст с путем к файлу
                    Text((keyPath as NSString).abbreviatingWithTildeInPath)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(isValid ? .primary : .secondary)
                    
                    // Кнопка выбора файла
                    Button("Выбрать...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.urls.first {
                            keyPath = url.path
                        }
                    }
                    
                    // Иконка валидации
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundColor(isValid ? .green : .red)
                }
                // Текст подсказки
                Text(helpText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        } label: {
            Text("Путь к SSH ключу")
        }
    }
}
