// NetPulse/Features/About/AboutView.swift
//  Copyright © 2025 ykreo. All rights reserved.
import SwiftUI

struct AboutView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @Environment(\.openURL) private var openURL
    
    private let githubURL = URL(string: "https://github.com/ykreo/NetPulse")
    
    var body: some View {
        VStack(spacing: 0) {
            // Основной контент
            VStack(spacing: 24) {
                // Иконка приложения
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // Название и версия
                VStack(spacing: 8) {
                    Text("NetPulse")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Версия \(settingsManager.appVersion)")
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
                Text("Простая утилита для строки меню macOS для мониторинга и управления домашней сетью.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .lineLimit(nil)
                    .padding(.horizontal, 16)
                
                // Возможности
                VStack(alignment: .leading, spacing: 8) {
                    FeatureRow(icon: "wifi", title: "Мониторинг сети", description: "Отслеживание статуса роутера, компьютера и интернета")
                    FeatureRow(icon: "terminal", title: "SSH управление", description: "Удаленное управление устройствами через SSH")
                    FeatureRow(icon: "power", title: "Wake-on-LAN", description: "Удаленное включение компьютера")
                    FeatureRow(icon: "bell", title: "Уведомления", description: "Автоматические уведомления об изменениях")
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
                            
                            // --- ИСПРАВЛЕНО: Добавлена информация о лицензии и авторстве ---
                            HStack(alignment: .center, spacing: 16) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Copyright © 2025 \(settingsManager.author). Все права защищены.")
                                    Text("Распространяется по лицензии MIT.")
                                }
                                .font(.caption)
                                .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                if let url = githubURL {
                                    Button("GitHub") { openURL(url) }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                        .help("Открыть репозиторий проекта")
                                }
                            }
                            .padding(.horizontal, 32).padding(.vertical, 16)
                        }
                        .background(Color(NSColor.windowBackgroundColor))
                    }
                    .frame(minWidth: 480, minHeight: 480) // Сделаем окно чуть компактнее
                    .background(Color(NSColor.windowBackgroundColor))
                }
            }

// MARK: - Subviews

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
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
