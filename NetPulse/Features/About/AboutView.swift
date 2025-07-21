// NetPulse/Features/About/AboutView.swift
//  Copyright © 2025 ykreo. All rights reserved.
import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var sparkleUpdater: SparkleUpdaterController
    @Environment(\.openURL) private var openURL
    @State private var isCheckingForUpdates = false
    
    // Этот URL не нужно локализовать.
    private let githubURL = URL(string: "https://github.com/ykreo/NetPulse")
    
    var body: some View {
        VStack(spacing: 0) {
            // Основной контент
            VStack(spacing: 24) {
                // Иконка приложения
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Название и версия
                VStack(spacing: 8) {
                    Text("NetPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Используем String(format:) для подстановки версии в локализованную строку
                    Text(String(format: NSLocalizedString("about.version", comment: "Version label"), settingsManager.appVersion))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
                
                // Описание
                Text("about.description")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .padding(.horizontal, 16)
                
                // Возможности
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "wifi", title: "feature.monitoring.title", description: "feature.monitoring.description")
                    FeatureRow(icon: "terminal", title: "feature.ssh.title", description: "feature.ssh.description")
                    FeatureRow(icon: "power", title: "feature.wol.title", description: "feature.wol.description")
                    FeatureRow(icon: "bell", title: "feature.notifications.title", description: "feature.notifications.description")
                }
                .padding(.horizontal, 16)
                
                Spacer(minLength: 16)
            }
            .padding(.horizontal, 32)
            .padding(.top, 32)
            .padding(.bottom, 24)
            
            // Футер
            VStack(spacing: 0) {
                           Divider().padding(.horizontal, 32)
                           
                           HStack(alignment: .center, spacing: 16) {
                               VStack(alignment: .leading, spacing: 4) {
                                   Text(String(format: NSLocalizedString("about.copyright", comment: "Copyright notice"), settingsManager.author))
                                   Text("about.license")
                               }
                               .font(.caption)
                               .foregroundColor(.secondary)
                               
                               Spacer()
                               
                               // ИЗМЕНЕНИЕ: Добавляем кнопку проверки обновлений
                               HStack {
                                   Button(action: {
                                       sparkleUpdater.checkForUpdates()
                                   }) {
                                       HStack {
                                           if isCheckingForUpdates { ProgressView().controlSize(.small) }
                                           Text("about.button.checkUpdates")
                                       }
                                   }
                                   .disabled(isCheckingForUpdates)
                                   
                                   if let url = githubURL {
                                       Button("GitHub") { openURL(url) }
                                           .help("help.open.repository")
                                   }
                               }
                               .buttonStyle(.bordered) // Общий стиль для кнопок
                               .controlSize(.small)
                           }
                           .padding(.horizontal, 32).padding(.vertical, 16)
                       }
                       .background(Color(NSColor.windowBackgroundColor))
                   }
                   .frame(minWidth: 480, minHeight: 480)
                   .background(Color(NSColor.windowBackgroundColor))
               }
           }

// MARK: - Subviews

private struct FeatureRow: View {
    let icon: String
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
