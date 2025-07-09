// NetPulse/Features/Settings/SshKeyEditView.swift
//  Copyright © 2025 ykreo. All rights reserved.
import SwiftUI

struct SshKeyEditView: View {
    @Binding var keyPath: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Редактирование SSH-ключа")
                .font(.title2)
                .fontWeight(.bold)

            TextField("Введите или выберите путь к ключу", text: $keyPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("Быстрый доступ:")
                    .foregroundColor(.secondary)
                Button("~/.ssh/id_rsa") { keyPath = "~/.ssh/id_rsa" }
                Button("~/.ssh/id_ed25519") { keyPath = "~/.ssh/id_ed25519" }
            }

            HStack {
                Button("Выбрать файл...") { selectFile() }
                Spacer()
                Button("Готово") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(30)
        .frame(width: 500)
    }

    private func selectFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.urls.first {
            keyPath = url.path
        }
    }
}
