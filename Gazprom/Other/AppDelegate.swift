//
//  AppDelegate.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import Foundation

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Настраиваем обработку ошибок
        setupErrorHandling()
        
        // Устанавливаем русскую локализацию через UserDefaults
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
        
        // Инициализируем русские контекстные меню
        setupRussianMenus()
        
        // Инициализируем систему нарушений
        setupViolationsSystem()
        
        return true
    }
    
    private func setupErrorHandling() {
        // Настраиваем обработку необработанных исключений
        NSSetUncaughtExceptionHandler { exception in
            print("❌ Необработанное исключение: \(exception)")
            print("❌ Стек вызовов: \(exception.callStackSymbols)")
        }
        
        // Настраиваем обработку сигналов
        signal(SIGABRT) { _ in
            print("❌ Получен сигнал SIGABRT")
        }
        
        signal(SIGILL) { _ in
            print("❌ Получен сигнал SIGILL")
        }
        
        signal(SIGSEGV) { _ in
            print("❌ Получен сигнал SIGSEGV")
        }
        
        signal(SIGFPE) { _ in
            print("❌ Получен сигнал SIGFPE")
        }
        
        signal(SIGBUS) { _ in
            print("❌ Получен сигнал SIGBUS")
        }
        
        signal(SIGPIPE) { _ in
            print("❌ Получен сигнал SIGPIPE")
        }
        
        // Настраиваем системный обработчик ошибок
        SystemErrorHandler.shared.setupErrorHandling()
    }
    
    
    private func setupViolationsSystem() {
        // Инициализируем систему нарушений
        // Это вызовет проверку первого запуска и очистку данных при необходимости
        _ = ViolationsModel.returnAvialableViolation()
        
        print("✅ Система нарушений инициализирована")
    }
    
    private func setupRussianMenus() {
        // Настройка русской локализации для системных меню
        setupRussianLocalization()
    }
    
    private func setupRussianLocalization() {
        // Перехватываем системные строки локализации
        DispatchQueue.main.async {
            // Устанавливаем русскую локализацию для системных строк
            UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
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

