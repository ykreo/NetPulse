// NetPulse/Features/About/AboutView.swift
// Код отличный, оставляем как есть.
import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 15) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 80, height: 80).padding(.bottom, 5)
            VStack {
                Text("NetPulse").font(.largeTitle).fontWeight(.bold)
                Text("Версия \(settingsManager.appVersion)").foregroundColor(.secondary)
            }
            Text("Простая утилита для строки меню macOS для мониторинга и управления домашней сетью.")
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).padding(.horizontal)
            Divider()
            HStack {
                Text("Автор: \(settingsManager.author)")
                Spacer()
                Button("GitHub") {
                    if let url = URL(string: "https://github.com/ykreo") { openURL(url) }
                }
            }
        }
        .padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30))
        .frame(minWidth: 400)
    }
}
