// NetPulse/Features/Settings/SettingsView.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import ServiceManagement
import OSLog

struct SettingsView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    @EnvironmentObject private var settingsManager: SettingsManager
    // ИЗМЕНЕНО: Получаем updateManager из окружения.
    @EnvironmentObject private var updateManager: UpdateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var localSettings: AppSettings
    @State private var showRestartAlert = false
    
    @State private var editingDevice: Device?
    @State private var isCreatingNewDevice = false
    
    init() {
        _localSettings = State(initialValue: SettingsManager().settings)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 32)
            TabView {
                GeneralSettingsTab(localSettings: $localSettings)
                    .tabItem { Label("Общие", systemImage: "gear") }

                DevicesSettingsTab(
                    localSettings: $localSettings,
                    onEdit: { device in self.editingDevice = device },
                    onCreate: { self.isCreatingNewDevice = true }
                )
                .tabItem { Label("Устройства", systemImage: "server.rack") }
            }
            .frame(minWidth: 700, minHeight: 520)
            footer
        }
        .onAppear {
            localSettings = settingsManager.settings
        }
        .onChange(of: localSettings) { _, newSettings in
            settingsManager.applyForValidation(newSettings)
        }
        .onChange(of: localSettings.hideDockIcon) { _, newHideDockIcon in
            if newHideDockIcon != settingsManager.settings.hideDockIcon {
                showRestartAlert = true
            }
        }
        .alert("Требуется перезапуск", isPresented: $showRestartAlert) {
            Button("Перезапустить") { restartApp() }
            Button("Позже", role: .cancel) {}
        } message: {
            Text("Чтобы изменения для иконки в Dock вступили в силу, необходимо перезапустить NetPulse.")
        }
        .sheet(isPresented: $isCreatingNewDevice) {
            DeviceEditView(device: .new()) { newDevice in
                localSettings.devices.append(newDevice)
            }
        }
        .sheet(item: $editingDevice) { device in
            DeviceEditView(device: device) { updatedDevice in
                if let index = localSettings.devices.firstIndex(where: { $0.id == updatedDevice.id }) {
                    localSettings.devices[index] = updatedDevice
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("Настройки").font(.largeTitle).fontWeight(.bold)
            Text("Настройте устройства для мониторинга и параметры приложения").font(.body).foregroundColor(.secondary)
        }
        .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 16)
    }
    
    private var footer: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 32)
            HStack(spacing: 12) {
                Spacer()
                Button("Отмена", role: .cancel) { dismiss() }.buttonStyle(.bordered).controlSize(.large)
                Button("Сохранить") {
                    saveChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!settingsManager.areAllFieldsValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
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
        if showRestartAlert { restartApp() }
    }
    
    private func handleLaunchAtLoginChange(to newValue: Bool) {
        do {
            if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch { Logger.app.error("Ошибка изменения статуса автозапуска: \(error.localizedDescription)") }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process(); task.launchPath = "/usr/bin/open"; task.arguments = [path]
        do { try task.run(); NSApp.terminate(nil) } catch { Logger.app.fault("Не удалось перезапустить приложение: \(error.localizedDescription)") }
    }
}


// MARK: - Вкладка "Устройства"
private struct DevicesSettingsTab: View {
    @Binding var localSettings: AppSettings
    let onEdit: (Device) -> Void
    let onCreate: () -> Void
    
    @State private var selection: Device.ID?

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                ForEach($localSettings.devices) { $device in
                    DeviceRowView(device: $device, onEdit: { onEdit(device) })
                        .tag(device.id)
                }
                .onMove(perform: moveDevice)
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))

            HStack {
                Button(action: onCreate) { Image(systemName: "plus") }
                    .help("Добавить новое устройство")
                
                Button(action: deleteSelectedDevice) { Image(systemName: "minus") }
                    .disabled(selection == nil)
                    .help("Удалить выбранное устройство")
                
                Spacer()
            }
            .padding(12)
        }
    }
    
    private func moveDevice(from source: IndexSet, to destination: Int) {
        localSettings.devices.move(fromOffsets: source, toOffset: destination)
        updateSortOrder()
    }

    private func deleteSelectedDevice() {
        guard let selection = selection else { return }
        localSettings.devices.removeAll { $0.id == selection }
        updateSortOrder()
    }
    
    private func updateSortOrder() {
        for i in 0..<localSettings.devices.count {
            localSettings.devices[i].sortOrder = i
        }
    }
}


// MARK: - Строка с устройством для списка
private struct DeviceRowView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Binding var device: Device
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: device.icon).font(.title).foregroundColor(.accentColor).frame(width: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name).font(.headline)
                Text("\(device.user)@\(device.host)").font(.body).foregroundColor(.secondary)
            }
            Spacer()
            if let isValid = settingsManager.deviceValidation[device.id] {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isValid ? .green : .red)
            }
            Button("Изменить", action: onEdit).buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
    }
}


// MARK: - Вкладка "Общие"
private struct GeneralSettingsTab: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var updateManager: UpdateManager
    @FocusState private var focusedField: String?
    @Binding var localSettings: AppSettings
    
    @State private var isCheckingForUpdates = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsGroup(title: "Поведение приложения", icon: "macwindow") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "Запускать при входе", description: "Автоматически запускать NetPulse при входе в macOS.") { Toggle("", isOn: $localSettings.launchAtLogin).labelsHidden() }
                        SettingsRow(title: "Скрывать иконку в Dock", description: "Показывать приложение только в строке меню.") { Toggle("", isOn: $localSettings.hideDockIcon).labelsHidden() }
                        SettingsRow(title: "Интервал фоновой проверки", description: "Как часто проверять статус устройств в фоне.") {
                            HStack(spacing: 8) {
                                Stepper(value: $localSettings.backgroundCheckInterval, in: 10...3600, step: 10) { EmptyView() }.labelsHidden()
                                Text("\(Int(localSettings.backgroundCheckInterval)) сек").frame(minWidth: 60, alignment: .trailing)
                            }
                        }
                    }
                }
                
                SettingsGroup(title: "Обновления", icon: "arrow.down.circle") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "Текущая версия", description: "Установленная в данный момент версия NetPulse.") {
                            Text(settingsManager.appVersion).font(.body.monospacedDigit()).foregroundColor(.secondary)
                        }
                        
                        SettingsRow(title: "Проверять автоматически", description: "Проверять наличие обновлений при запуске приложения.") {
                            Toggle("", isOn: $localSettings.checkForUpdatesAutomatically).labelsHidden()
                        }
                        
                        SettingsRow(title: "Ручная проверка", description: "Проверить наличие новой версии на GitHub прямо сейчас.") {
                            Button(action: {
                                Task {
                                    isCheckingForUpdates = true
                                    // Теперь мы вызываем updateManager напрямую из Environment
                                    await updateManager.checkForUpdates(silently: false)
                                    isCheckingForUpdates = false
                                }
                            }) {
                                HStack {
                                    if isCheckingForUpdates { ProgressView().controlSize(.small) }
                                    Text("Проверить сейчас")
                                }
                            }
                            .disabled(isCheckingForUpdates)
                        }
                    }
                }
                
                SettingsGroup(title: "Общие параметры сети", icon: "globe") {
                    VStack(spacing: 16) {
                        SshKeyPicker(keyPath: $localSettings.sshKeyPath, isValid: settingsManager.isSshKeyPathValid)
                        ValidationField(title: "Хост для проверки интернета", text: $localSettings.checkHost, focusedField: $focusedField, isValid: settingsManager.isCheckHostValid, description: "IP/домен для проверки доступности интернета.")
                    }
                }
                
                SettingsGroup(title: "Управление конфигурацией", icon: "doc.text") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "Импорт и экспорт", description: "Сохранение и загрузка всех настроек приложения.") {
                            HStack(spacing: 8) {
                                Button("Импорт...") { settingsManager.importSettings(); localSettings = settingsManager.settings }
                                Button("Экспорт...") { settingsManager.exportSettings() }
                            }.buttonStyle(.bordered).controlSize(.regular)
                        }
                        SettingsRow(title: "Сброс настроек", description: "Восстановить все настройки до исходных значений.") {
                            Button("Сбросить", role: .destructive) { settingsManager.restoreDefaults(); localSettings = settingsManager.settings }.buttonStyle(.bordered).controlSize(.regular)
                        }
                    }
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 24)
        }
    }
}


// MARK: - Модальное окно редактирования УСТРОЙСТВА
private struct DeviceEditView: View {
    @State var device: Device
    let onSave: (Device) -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var editingAction: CustomAction?
    @State private var selectedActionID: CustomAction.ID?

    private let iconList = ["desktopcomputer", "server.rack", "laptopcomputer", "tv", "gamecontroller", "printer", "camera", "wifi.router"]

    var body: some View {
        VStack(spacing: 0) {
            Text(device.name.isEmpty ? "Новое устройство" : "Редактирование: \(device.name)")
                .font(.title2).fontWeight(.bold)
                .padding()

            Form {
                Section {
                    TextField("Имя устройства:", text: $device.name)
                    TextField("Хост (IP или домен):", text: $device.host)
                    TextField("Пользователь SSH:", text: $device.user)
                    Picker("Иконка устройства:", selection: $device.icon) {
                        ForEach(iconList, id: \.self) { iconName in
                            HStack { Image(systemName: iconName); Text(iconName.capitalized) }.tag(iconName)
                        }
                    }
                } header: {
                    Text("Основные параметры").font(.headline).padding(.bottom, 4)
                }

                Section {
                    List(selection: $selectedActionID) {
                        ForEach($device.actions) { $action in
                            HStack {
                                Image(systemName: action.icon).frame(width: 24, alignment: .center)
                                VStack(alignment: .leading) {
                                    Text(action.name).fontWeight(.medium)
                                    Text(action.command).font(.monospaced(.caption)()).foregroundColor(.secondary).lineLimit(1)
                                }
                            }
                            .tag(action.id)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                editingAction = action
                            }
                        }
                        .onMove(perform: moveAction)
                        .onDelete(perform: deleteAction)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minHeight: 120, maxHeight: 240)
                } header: {
                    Text("Действия (SSH Команды)").font(.headline).padding(.bottom, 4)
                } footer: {
                    HStack(spacing: 8) {
                        Button(action: addAction) { Image(systemName: "plus") }
                            .help("Добавить новое действие")
                        
                        Button(action: deleteSelectedAction) { Image(systemName: "minus") }
                            .disabled(selectedActionID == nil)
                            .help("Удалить выбранное действие")
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("Отмена", role: .cancel) { dismiss() }
                Spacer()
                Button("Сохранить") { onSave(device); dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(.bar)
        }
        .sheet(item: $editingAction) { action in
            ActionEditView(action: action) { updatedAction in
                if let index = device.actions.firstIndex(where: { $0.id == action.id }) {
                    device.actions[index] = updatedAction
                }
            }
        }
        .frame(width: 500)
    }
    
    private func addAction() {
        let newAction = CustomAction()
        device.actions.append(newAction)
        editingAction = newAction
    }
    
    private func deleteAction(at offsets: IndexSet) {
        device.actions.remove(atOffsets: offsets)
    }
    
    private func deleteSelectedAction() {
        guard let selectedID = selectedActionID else { return }
        device.actions.removeAll { $0.id == selectedID }
    }
    
    private func moveAction(from source: IndexSet, to destination: Int) {
        device.actions.move(fromOffsets: source, toOffset: destination)
    }
}


// MARK: - Модальное окно редактирования ДЕЙСТВИЯ
private struct ActionEditView: View {
    @State private var localAction: CustomAction
    private let onSave: (CustomAction) -> Void
    @Environment(\.dismiss) private var dismiss
    
    private let iconList = ["power", "power.dotted", "restart", "terminal", "arrow.up.arrow.down", "play", "pause", "stop", "bell", "eject", "moon.stars"]
    
    init(action: CustomAction, onSave: @escaping (CustomAction) -> Void) {
        self._localAction = State(initialValue: action)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Редактирование действия")
                .font(.title2).fontWeight(.bold)
            
            Form {
                Section("Параметры") {
                    TextField("Название кнопки:", text: $localAction.name)
                    TextField("SSH Команда:", text: $localAction.command)
                        .font(.monospaced(.body)())
                }
                
                Section("Отображение") {
                    Picker("Иконка:", selection: $localAction.icon) {
                        ForEach(iconList, id: \.self) { iconName in
                            HStack { Image(systemName: iconName); Text(iconName) }.tag(iconName)
                        }
                    }
                    Picker("Показывать кнопку:", selection: $localAction.displayCondition) {
                        ForEach(CustomAction.DisplayCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("Отмена", role: .cancel) { dismiss() }
                Spacer()
                Button("Сохранить") {
                    onSave(localAction)
                    dismiss()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450)
    }
}


// MARK: - Переиспользуемые компоненты
private struct SettingsGroup<Content: View>: View {
    let title: String; let icon: String; let content: Content
    init(title: String, icon: String, @ViewBuilder content: () -> Content) { self.title = title; self.icon = icon; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) { Image(systemName: icon).font(.title3).foregroundColor(.accentColor).frame(width: 20); Text(title).font(.headline).fontWeight(.semibold) }.padding(.leading, 4)
            content.padding(16).background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: String; let description: String; let content: Content
    init(title: String, description: String, @ViewBuilder content: () -> Content) { self.title = title; self.description = description; self.content = content() }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.body).fontWeight(.medium); Text(description).font(.caption).foregroundColor(.secondary).lineLimit(2) }.frame(maxWidth: .infinity, alignment: .leading)
            content.frame(alignment: .trailing)
        }
    }
}

private struct ValidationField: View {
    let title: String; @Binding var text: String; @FocusState.Binding var focusedField: String?
    let isValid: Bool; let description: String; @State private var hasBeenEdited: Bool = false
    var body: some View {
        SettingsRow(title: title, description: description) {
            HStack(spacing: 8) {
                TextField("", text: $text).textFieldStyle(.roundedBorder).focused($focusedField, equals: title).frame(minWidth: 160).onChange(of: text) { _, _ in hasBeenEdited = true }.onAppear { if !text.isEmpty { hasBeenEdited = true } }
                if hasBeenEdited { Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill").font(.caption).foregroundColor(isValid ? .green : .red).transition(.scale.animation(.spring())) }
            }
        }
    }
}

private struct SshKeyPicker: View {
    @Binding var keyPath: String; let isValid: Bool; @State private var showEditSheet = false
    var body: some View {
        SettingsRow(title: "Путь к SSH ключу", description: "Приватный ключ для авторизации на устройствах") {
            HStack(spacing: 8) {
                Text((keyPath as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle).padding(.horizontal, 8).padding(.vertical, 4).background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                Button("Изменить...") { showEditSheet = true }.controlSize(.regular)
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundColor(isValid ? .green : .red)
            }
        }.sheet(isPresented: $showEditSheet) { SshKeyEditView(keyPath: $keyPath) }
    }
}
