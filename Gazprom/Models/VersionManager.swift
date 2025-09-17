//
//  VersionManager.swift
//  Gazprom
//
//  Created by AI Assistant on 17.09.2025.
//

import Foundation

class VersionManager {
    static let shared = VersionManager()
    
    private let versionKey = "AppVersion"
    private let buildNumberKey = "BuildNumber"
    
    private init() {}
    
    // MARK: - Version Properties
    
    var version: String {
        get {
            return UserDefaults.standard.string(forKey: versionKey) ?? "1.0.0"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: versionKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var buildNumber: Int {
        get {
            return UserDefaults.standard.integer(forKey: buildNumberKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: buildNumberKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    var fullVersionString: String {
        return "v\(version) (\(buildNumber))"
    }
    
    var shortVersionString: String {
        return "v\(version)"
    }
    
    // MARK: - Version Management
    
    /// Увеличивает build number на 1
    func incrementBuild() {
        buildNumber += 1
    }
    
    /// Устанавливает новую версию
    func setVersion(_ newVersion: String) {
        version = newVersion
    }
    
    /// Устанавливает новую версию и build number
    func setVersion(_ newVersion: String, build: Int) {
        version = newVersion
        buildNumber = build
    }
    
    /// Автоматически увеличивает build number при каждом запуске
    func autoIncrementBuild() {
        incrementBuild()
    }
    
    /// Получает версию из Info.plist (если есть)
    func getInfoPlistVersion() -> String? {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let version = infoDictionary["CFBundleShortVersionString"] as? String else {
            return nil
        }
        return version
    }
    
    /// Получает build number из Info.plist (если есть)
    func getInfoPlistBuildNumber() -> String? {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let buildNumber = infoDictionary["CFBundleVersion"] as? String else {
            return nil
        }
        return buildNumber
    }
    
    /// Синхронизирует версию с Info.plist
    func syncWithInfoPlist() {
        if let plistVersion = getInfoPlistVersion() {
            version = plistVersion
        }
        
        if let plistBuildNumber = getInfoPlistBuildNumber(),
           let buildInt = Int(plistBuildNumber) {
            buildNumber = buildInt
        }
    }
    
    /// Создает строку версии для отображения в UI
    func getDisplayVersion() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy"
        let buildDate = dateFormatter.string(from: Date())
        
        return "Версия \(fullVersionString)\nСборка: \(buildDate)"
    }
    
    /// Создает краткую строку версии для отображения в UI
    func getShortDisplayVersion() -> String {
        return shortVersionString
    }
    
    // MARK: - Version History
    
    private let versionHistoryKey = "VersionHistory"
    
    func addVersionToHistory() {
        var history = getVersionHistory()
        let versionEntry = VersionEntry(
            version: version,
            buildNumber: buildNumber,
            date: Date(),
            description: "Автоматическое обновление версии"
        )
        history.append(versionEntry)
        
        // Ограничиваем историю 50 записями
        if history.count > 50 {
            history = Array(history.suffix(50))
        }
        
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: versionHistoryKey)
            UserDefaults.standard.synchronize()
        }
    }
    
    func getVersionHistory() -> [VersionEntry] {
        guard let data = UserDefaults.standard.data(forKey: versionHistoryKey),
              let history = try? JSONDecoder().decode([VersionEntry].self, from: data) else {
            return []
        }
        return history
    }
}

// MARK: - Version Entry Model

struct VersionEntry: Codable {
    let version: String
    let buildNumber: Int
    let date: Date
    let description: String
    
    var displayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "v\(version) (\(buildNumber)) - \(formatter.string(from: date))"
    }
}
