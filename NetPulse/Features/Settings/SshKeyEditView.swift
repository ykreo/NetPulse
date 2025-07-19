// NetPulse/Features/Settings/SshKeyEditView.swift
// Copyright © 2025 ykreo. All rights reserved.
import SwiftUI

struct SshKeyEditView: View {
    @Binding var keyPath: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("ssh.edit.title")
                .font(.title2)
                .fontWeight(.bold)

            TextField("ssh.edit.placeholder", text: $keyPath)
                .textFieldStyle(.roundedBorder)

            HStack {
                Text("ssh.edit.quick_access")
                    .foregroundColor(.secondary)
                Button("~/.ssh/id_rsa") { keyPath = "~/.ssh/id_rsa" }
                Button("~/.ssh/id_ed25519") { keyPath = "~/.ssh/id_ed25519" }
            }

            HStack {
                Button("ssh.edit.button.select") { selectFile() }
                Spacer()
                Button("ssh.edit.button.done") { dismiss() }.keyboardShortcut(.defaultAction)
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
