//
//  AppDelegate.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Устанавливаем русскую локализацию через UserDefaults
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Инициализируем русские контекстные меню
        setupRussianMenus()
        
        // Инициализируем систему версий
        setupVersionManager()
        
        return true
    }
    
    private func setupVersionManager() {
        // Синхронизируем версию с Info.plist
        VersionManager.shared.syncWithInfoPlist()
        
        // Автоматически увеличиваем build number при каждом запуске
        VersionManager.shared.autoIncrementBuild()
        
        // Добавляем версию в историю
        VersionManager.shared.addVersionToHistory()
    }
    
    private func setupRussianMenus() {
        // Настройка русской локализации для системных меню
        setupRussianLocalization()
    }
    
    private func setupRussianLocalization() {
        // Перехватываем системные строки локализации
        DispatchQueue.main.async {
            // Устанавливаем русскую локализацию для системных строк
            UserDefaults.standard.set("ru", forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
            
            // Принудительно обновляем локализацию через swizzling
            self.setupRussianSwizzling()
        }
    }
    
    private func setupRussianSwizzling() {
        // Простая настройка русской локализации
        // Устанавливаем русский язык как приоритетный
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Принудительно обновляем локализацию
        NotificationCenter.default.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
    }
    
    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}

extension UIWindow {
    var firstResponder: UIResponder? {
        return firstResponder(in: self)
    }
    
    private func firstResponder(in view: UIView) -> UIResponder? {
        if view.isFirstResponder {
            return view
        }
        
        for subview in view.subviews {
            if let responder = firstResponder(in: subview) {
                return responder
            }
        }
        
        return nil
    }
}

