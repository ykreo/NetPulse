// NetPulse/Features/Settings/SettingsView.swift
// Copyright © 2025 ykreo. All rights reserved.

import SwiftUI
import ServiceManagement
import OSLog

struct SettingsView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    @EnvironmentObject private var settingsManager: SettingsManager
    @EnvironmentObject private var updateManager: UpdateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var localSettings: AppSettings
    @State private var showRestartAlert = false
    
    @State private var editingDevice: Device?
    @State private var isCreatingNewDevice = false
    
    @State private var showLaunchCtlError = false
    @State private var launchCtlErrorText = ""
    
    init() {
        _localSettings = State(initialValue: AppSettings.defaultSettings())
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.horizontal, 32)
            TabView {
                GeneralSettingsTab(localSettings: $localSettings)
                    .tabItem { Label("settings.tab.general", systemImage: "gear") }

                ScrollView {
                    DevicesSettingsTab(
                        localSettings: $localSettings,
                        onEdit: { device in self.editingDevice = device },
                        onCreate: { self.isCreatingNewDevice = true }
                    )
                    .padding(32)
                }
                .tabItem { Label("settings.tab.devices", systemImage: "server.rack") }
                NotificationsSettingsTab(localSettings: $localSettings)
                    .tabItem { Label("settings.tab.notifications", systemImage: "bell.badge") }
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
        .alert("alert.restart.title", isPresented: $showRestartAlert) {
            Button("alert.restart.button.restart") { saveChanges(andRestart: true) }
            Button("alert.restart.button.later", role: .cancel) {
                saveChanges()
            }
        } message: {
            Text("alert.restart.message")
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
        .alert("Ошибка автозапуска", isPresented: $showLaunchCtlError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(launchCtlErrorText)
        }
    }
    
    private var header: some View {
        VStack(spacing: 8) {
            Text("settings.header.title").font(.largeTitle).fontWeight(.bold)
            Text("settings.header.subtitle").font(.body).foregroundColor(.secondary)
        }
        .padding(.horizontal, 32).padding(.top, 24).padding(.bottom, 16)
    }
    
    private var footer: some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 32)
            HStack(spacing: 12) {
                Spacer()
                Button("common.cancel", role: .cancel) { dismiss() }.buttonStyle(.bordered).controlSize(.large)
                Button("common.save") {
                    if localSettings.hideDockIcon != settingsManager.settings.hideDockIcon {
                        showRestartAlert = true
                    } else {
                        saveChanges()
                    }
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!settingsManager.areAllFieldsValid)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 32).padding(.vertical, 16)
        }
    }
    
    private func saveChanges(andRestart restart: Bool = false) {
        if localSettings.launchAtLogin != settingsManager.settings.launchAtLogin {
            handleLaunchAtLoginChange(to: localSettings.launchAtLogin)
        }
        settingsManager.applyAndSave(localSettings)
        (NSApp.delegate as? AppDelegate)?.updateActivationPolicy()
        networkManager.setUpdateFrequency(isFast: false)
        if restart { restartApp() } else { dismiss() }
    }
    
    private func handleLaunchAtLoginChange(to newValue: Bool) {
        do {
            if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            Logger.app.info("Статус автозапуска успешно изменен на \(newValue).")
        } catch {
            Logger.app.error("Ошибка изменения статуса автозапуска: \(error.localizedDescription)")
            launchCtlErrorText = "Не удалось изменить статус автозапуска. Пожалуйста, проверьте разрешения или попробуйте снова.\n\nОшибка: \(error.localizedDescription)"
            showLaunchCtlError = true
        }
    }
    
    private func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process(); task.launchPath = "/usr/bin/open"; task.arguments = [path]
        do { try task.run(); NSApp.terminate(nil) } catch { Logger.app.fault("Не удалось перезапустить приложение: \(error.localizedDescription)") }
    }
}

// ... (Остальной код файла остается без изменений, я привожу его для полноты)

// MARK: - Вкладка "Устройства"
private struct DevicesSettingsTab: View {
    @Binding var localSettings: AppSettings
    let onEdit: (Device) -> Void
    let onCreate: () -> Void
    
    @State private var selection: Device.ID?

    var body: some View {
        SettingsGroup(title: "settings.tab.devices", icon: "server.rack") {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach($localSettings.devices) { $device in
                        DeviceRowView(device: $device, onEdit: { onEdit(device) })
                            .tag(device.id)
                    }
                    .onMove(perform: moveDevice)
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .frame(minHeight: 300)

                HStack {
                    Button(action: onCreate) { Image(systemName: "plus") }
                        .help("help.device.add")
                    
                    Button(action: deleteSelectedDevice) { Image(systemName: "minus") }
                        .disabled(selection == nil)
                        .help("help.device.remove")
                    
                    Spacer()
                }
                .padding([.horizontal, .bottom], 12)
                .padding(.top, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.001))
            }
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
            Button("common.edit", action: onEdit).buttonStyle(.bordered)
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
                SettingsGroup(title: "settings.group.behavior", icon: "macwindow") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "settings.row.launchAtLogin.title", description: "settings.row.launchAtLogin.description") { Toggle("", isOn: $localSettings.launchAtLogin).labelsHidden() }
                        SettingsRow(title: "settings.row.hideDockIcon.title", description: "settings.row.hideDockIcon.description") { Toggle("", isOn: $localSettings.hideDockIcon).labelsHidden() }
                        SettingsRow(title: "settings.row.checkInterval.title", description: "settings.row.checkInterval.description") {
                            HStack(spacing: 8) {
                                Stepper(value: $localSettings.backgroundCheckInterval, in: 10...3600, step: 10) { EmptyView() }.labelsHidden()
                                Text(String(format: NSLocalizedString("common.seconds", comment: "Seconds format"), Int(localSettings.backgroundCheckInterval))).frame(minWidth: 60, alignment: .trailing)
                            }
                        }
                    }
                }
                
                SettingsGroup(title: "settings.group.updates", icon: "arrow.down.circle") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "settings.row.currentVersion.title", description: "settings.row.currentVersion.description") {
                            Text(settingsManager.appVersion).font(.body.monospacedDigit()).foregroundColor(.secondary)
                        }
                        
                        SettingsRow(title: "settings.row.autoCheckUpdates.title", description: "settings.row.autoCheckUpdates.description") {
                            Toggle("", isOn: $localSettings.checkForUpdatesAutomatically).labelsHidden()
                        }
                        
                        SettingsRow(title: "settings.row.manualCheck.title", description: "settings.row.manualCheck.description") {
                            Button(action: {
                                Task {
                                    isCheckingForUpdates = true
                                    await updateManager.checkForUpdates(silently: false)
                                    isCheckingForUpdates = false
                                }
                            }) {
                                HStack {
                                    if isCheckingForUpdates { ProgressView().controlSize(.small) }
                                    Text("settings.button.checkNow")
                                }
                            }
                            .disabled(isCheckingForUpdates)
                        }
                    }
                }
                
                SettingsGroup(title: "settings.group.network", icon: "globe") {
                    VStack(spacing: 16) {
                        SshKeyPicker(keyPath: $localSettings.sshKeyPath, isValid: settingsManager.isSshKeyPathValid)
                        ValidationField(key: "checkHost", title: "settings.field.checkHost.title", text: $localSettings.checkHost, focusedField: $focusedField, isValid: settingsManager.isCheckHostValid, description: "settings.field.checkHost.description")
                    }
                }
                
                SettingsGroup(title: "settings.group.config", icon: "doc.text") {
                    VStack(spacing: 16) {
                        SettingsRow(title: "settings.row.importExport.title", description: "settings.row.importExport.description") {
                            HStack(spacing: 8) {
                                Button("settings.button.import") { settingsManager.importSettings(); localSettings = settingsManager.settings }
                                Button("settings.button.export") { settingsManager.exportSettings() }
                            }.buttonStyle(.bordered).controlSize(.regular)
                        }
                        SettingsRow(title: "settings.row.reset.title", description: "settings.row.reset.description") {
                            Button("settings.button.reset", role: .destructive) { settingsManager.restoreDefaults(); localSettings = settingsManager.settings }.buttonStyle(.bordered).controlSize(.regular)
                        }
                    }
                }
            }
            .padding(.horizontal, 32).padding(.vertical, 24)
        }
    }
}
// MARK: - НОВАЯ ВКЛАДКА "Уведомления"
private struct NotificationsSettingsTab: View {
    @Binding var localSettings: AppSettings
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                SettingsGroup(title: "settings.group.notifications_main", icon: "app.badge") {
                    VStack(spacing: 16) {
                        // Эта настройка пока не добавлена в модель, но как заготовка для будущего
                        // SettingsRow(title: "settings.row.enableNotifications.title", description: "settings.row.enableNotifications.description") {
                        //     Toggle("", isOn: .constant(true)).labelsHidden()
                        // }
                        
                        SettingsRow(title: "settings.row.notification_info.title", description: "settings.row.notification_info.description") {
                            Button("settings.button.open_sys_settings") {
                                // Открываем системные настройки уведомлений для нашего приложения
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                                    NSWorkspace.shared.open(url)
                                }
                            }
                        }
                    }
                }
                
                // Здесь в будущем можно добавить детальные настройки для каждого типа уведомлений
                
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
            Group {
                            if device.name.isEmpty {
                                Text("device.edit.title.new")
                            } else {
                                Text(String(format: NSLocalizedString("device.edit.title.existing", comment: "Title for editing an existing device"), device.name))
                            }
                        }
                        .font(.title2).fontWeight(.bold)
                        .padding()

            Form {
                Section {
                    TextField("device.edit.field.name", text: $device.name)
                    TextField("device.edit.field.host", text: $device.host)
                    TextField("device.edit.field.user", text: $device.user)
                    Picker("device.edit.field.icon", selection: $device.icon) {
                        ForEach(iconList, id: \.self) { iconName in
                            HStack { Image(systemName: iconName); Text(iconName.capitalized) }.tag(iconName)
                        }
                    }
                } header: {
                    Text("device.edit.section.general").font(.headline).padding(.bottom, 4)
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
                                Spacer()
                                Button("common.edit") { editingAction = action }.buttonStyle(.bordered)
                            }
                            .tag(action.id)
                            .contentShape(Rectangle())
                        }
                        .onMove(perform: moveAction)
                        .onDelete(perform: deleteAction)
                    }
                    .listStyle(.inset(alternatesRowBackgrounds: true))
                    .frame(minHeight: 120, maxHeight: 240)
                } header: {
                    Text("device.edit.section.actions").font(.headline).padding(.bottom, 4)
                } footer: {
                    HStack(spacing: 8) {
                        Button(action: addAction) { Image(systemName: "plus") }
                            .help("help.action.add")
                        
                        Button(action: deleteSelectedAction) { Image(systemName: "minus") }
                            .disabled(selectedActionID == nil)
                            .help("help.action.remove")
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)

            HStack {
                Button("common.cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("common.save") { onSave(device); dismiss() }.keyboardShortcut(.defaultAction)
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
            Text("action.edit.title")
                .font(.title2).fontWeight(.bold)
            
            Form {
                Section("action.edit.section.parameters") {
                    TextField("action.edit.field.name", text: $localAction.name)
                    TextField("action.edit.field.command", text: $localAction.command)
                        .font(.monospaced(.body)())
                }
                
                Section("action.edit.section.display") {
                    Picker("action.edit.field.icon", selection: $localAction.icon) {
                        ForEach(iconList, id: \.self) { iconName in
                            HStack { Image(systemName: iconName); Text(iconName) }.tag(iconName)
                        }
                    }
                    Picker("action.edit.field.condition", selection: $localAction.displayCondition) {
                        ForEach(CustomAction.DisplayCondition.allCases) { condition in
                            Text(condition.localizedString).tag(condition)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .controlSize(.regular)
            .textFieldStyle(.roundedBorder)
            
            HStack {
                Button("common.cancel", role: .cancel) { dismiss() }
                Spacer()
                Button("common.save") {
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
    let title: LocalizedStringKey; let icon: String; let content: Content
    init(title: LocalizedStringKey, icon: String, @ViewBuilder content: () -> Content) { self.title = title; self.icon = icon; self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) { Image(systemName: icon).font(.title3).foregroundColor(.accentColor).frame(width: 20); Text(title).font(.headline).fontWeight(.semibold) }.padding(.leading, 4)
            content.padding(16).background(RoundedRectangle(cornerRadius: 12).fill(Color(NSColor.controlBackgroundColor)))
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let title: LocalizedStringKey; let description: LocalizedStringKey; let content: Content
    init(title: LocalizedStringKey, description: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.title = title; self.description = description; self.content = content() }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.body).fontWeight(.medium); Text(description).font(.caption).foregroundColor(.secondary).lineLimit(2) }.frame(maxWidth: .infinity, alignment: .leading)
            content.frame(alignment: .trailing)
        }
    }
}

private struct ValidationField: View {
    let key: String
    let title: LocalizedStringKey
    @Binding var text: String
    @FocusState.Binding var focusedField: String?
    let isValid: Bool
    let description: LocalizedStringKey
    @State private var hasBeenEdited: Bool = false
    
    var body: some View {
        SettingsRow(title: title, description: description) {
            HStack(spacing: 8) {
                TextField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: key)
                    .frame(minWidth: 160)
                    .onChange(of: text) { _, _ in hasBeenEdited = true }
                    .onAppear { if !text.isEmpty { hasBeenEdited = true } }
                
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
    @Binding var keyPath: String; let isValid: Bool; @State private var showEditSheet = false
    var body: some View {
        SettingsRow(title: "settings.row.sshKey.title", description: "settings.row.sshKey.description") {
            HStack(spacing: 8) {
                Text((keyPath as NSString).abbreviatingWithTildeInPath).lineLimit(1).truncationMode(.middle).padding(.horizontal, 8).padding(.vertical, 4).background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                Button("common.edit...") { showEditSheet = true }.controlSize(.regular)
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundColor(isValid ? .green : .red)
            }
        }.sheet(isPresented: $showEditSheet) { SshKeyEditView(keyPath: $keyPath) }
    }
}

extension CustomAction.DisplayCondition {
    var localizedString: LocalizedStringKey {
        switch self {
        case .always: return "condition.always"
        case .ifOnline: return "condition.ifOnline"
        case .ifOffline: return "condition.ifOffline"
        }
    }
}
