//
//  AppDelegate.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import Foundation
import QuickLook
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // MARK: - Properties
    private var notificationObservers: [NSObjectProtocol] = []
    private var cacheCleanupTimer: Timer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // ПРИМЕЧАНИЕ: Системные предупреждения о конфликтах constraints клавиатуры (UIKeyboardImpl, TUIKeyboardContentView)
        // являются нормальным поведением iOS и не влияют на функциональность приложения.
        // iOS автоматически разрешает эти конфликты, ломая наименее приоритетные constraints.
        
        // Настраиваем обработку ошибок (критично, должно быть первым)
        setupErrorHandling()
        
        // Резервные копии: iCloud Drive при доступности + перенос из старой папки Documents/Backups
        BackupManager.prepareBackupStorage()
        
        // Устанавливаем русскую локализацию через UserDefaults
        UserDefaults.standard.set(["ru"], forKey: "AppleLanguages")
        
        // Настраиваем уведомления (быстрая операция)
        setupNotifications()
        
        // Тяжелые операции выполняем асинхронно в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Инициализируем систему нарушений (только очистка данных, без автоматической загрузки)
            self.setupViolationsSystemForFirstLaunch()
            
            // Настраиваем оптимизацию производительности
            self.setupPerformanceOptimization()
            
            // Синхронизируем объекты из актов в общую базу (идемпотентно)
            ObjectsSyncManager.syncMissingObjectsFromAllAkts()
            
            // ВАЖНО: Удаляем дубликаты записей устранения при запуске приложения
            print("🔄 [APP_DELEGATE] Очистка дубликатов записей устранения при запуске")
            ViolationEliminationManager.removeDuplicateEliminations()
            
            // Восстанавливаем акт 19 из корзины (если он там есть)
            self.restoreAkt19IfNeeded()
            
            // Ищем и восстанавливаем акт 25 (если он удален)
            self.searchAndRestoreAkt25()
            
            // Восстанавливаем формулировки из правил для существующих нарушений
            self.restoreFormulaFromRulesForExistingViolations()
            
            // ВАЖНО: Создаем резервную копию ПОСЛЕ всех операций инициализации
            // Добавляем небольшую задержку, чтобы убедиться, что все данные сохранены
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2.0) {
                if BackupManager.getLastBackupInfo() == nil {
                    print("🔄 [AUTO_BACKUP] Создаем первую резервную копию...")
                    _ = BackupManager.createBackup()
                } else {
                    // Проверяем, нужно ли создать автоматическую резервную копию
                    print("🔄 [AUTO_BACKUP] Проверяем необходимость автоматической резервной копии...")
                    BackupManager.autoBackupIfNeeded()
                }
                
            }
        }
        
        return true
    }
    
    /// Восстанавливает акт 19 из корзины, если он там находится
    private func restoreAkt19IfNeeded() {
        print("🔄 [APP_DELEGATE] Начинаем поиск акта 19...")
        
        // Сначала ищем акт 19 во всех возможных местах
        let searchResult = TrashManager.findAktByNumber("19")
        
        print("🔍 [APP_DELEGATE] Результат поиска: \(searchResult.location)")
        
        switch searchResult.location {
        case "история":
            print("ℹ️ [APP_DELEGATE] Акт 19 уже присутствует в истории")
            
        case "редактируемый":
            print("ℹ️ [APP_DELEGATE] Акт 19 найден как редактируемый")
            // Если акт редактируемый, но не в истории, добавляем его
            if let akt = searchResult.akt {
                var currentAkts = DataFlowAKT.loadArr()
                if !currentAkts.contains(where: { $0.number == "19" }) {
                    currentAkts.append(akt)
                    DataFlowAKT.saveArr(arr: currentAkts)
                    DataFlowAKT.clearCache()
                    print("✅ [APP_DELEGATE] Акт 19 добавлен в историю из редактируемого")
                }
            }
            
        case "корзина":
            print("🔄 [APP_DELEGATE] Акт 19 найден в корзине, восстанавливаем...")
            let restored = TrashManager.restoreAktByNumber("19")
            if restored {
                print("✅ [APP_DELEGATE] Акт 19 успешно восстановлен из корзины")
            } else {
                print("❌ [APP_DELEGATE] Не удалось восстановить акт 19 из корзины")
            }
            
        default:
            print("❌ [APP_DELEGATE] Акт 19 не найден в стандартных местах")
            print("   📊 Детальная диагностика:")
            
            // Детальная диагностика
            let currentAkts = DataFlowAKT.loadArr()
            print("   📋 Акты в истории (\(currentAkts.count)): \(currentAkts.map { $0.number }.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 }))")
            
            let trash = TrashManager.loadTrash()
            print("   🗑️ Акты в корзине (\(trash.count)): \(trash.map { $0.number })")
            
            if let editable = DataFlowAKT.getEditableAKT() {
                print("   ✏️ Редактируемый акт: №\(editable.akt.number)")
            } else {
                print("   ✏️ Редактируемый акт: нет")
            }
            
            print("   💡 Рекомендации:")
            print("      1. Проверьте резервные копии данных")
            print("      2. Если есть резервная копия, используйте функцию импорта")
            print("      3. Акт мог быть удален до внедрения системы корзины")
            
            // Пытаемся найти акт 19 в файле напрямую (на случай ошибки декодирования)
            attemptToRecoverAkt19FromFile()
        }
    }
    
    /// Ищет и восстанавливает акт 25 во всех возможных местах
    private func searchAndRestoreAkt25() {
        print("🔍 [APP_DELEGATE] Начинаем поиск акта 25...")
        
        // Используем новую утилиту для поиска
        let searchResult = AktSearchUtility.findAkt25()
        
        if searchResult.found {
            print("✅ [APP_DELEGATE] Акт 25 найден в \(searchResult.locations.count) месте(ах):")
            for location in searchResult.locations {
                print("   - \(location.location)")
            }
            
            // Пытаемся восстановить акт, если он не в истории
            if !searchResult.locations.contains(where: { $0.location == "История актов" }) {
                print("🔄 [APP_DELEGATE] Акт 25 не в истории, пытаемся восстановить...")
                let restored = AktSearchUtility.restoreAkt25()
                if restored {
                    print("✅ [APP_DELEGATE] Акт 25 успешно восстановлен!")
                } else {
                    print("⚠️ [APP_DELEGATE] Не удалось автоматически восстановить акт 25")
                    print("   💡 Акт найден, но требуется ручное восстановление")
                }
            } else {
                print("ℹ️ [APP_DELEGATE] Акт 25 уже присутствует в истории")
            }
        } else {
            print("❌ [APP_DELEGATE] Акт 25 не найден ни в одном месте")
            print("   💡 Проверьте резервные копии вручную")
        }
    }
    
    /// Пытается восстановить акт 19 напрямую из файла (на случай ошибки декодирования)
    private func attemptToRecoverAkt19FromFile() {
        print("🔍 [RECOVERY] Попытка восстановить акт 19 из файла напрямую...")
        
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [RECOVERY] Не удалось получить директорию документов")
            return
        }
        
        let filePath = documentDirectory.appendingPathComponent("AKT.plist")
        
        guard fileManager.fileExists(atPath: filePath.path) else {
            print("❌ [RECOVERY] Файл AKT.plist не найден")
            return
        }
        
        print("📁 [RECOVERY] Файл найден: \(filePath.path)")
        
        do {
            let data = try Data(contentsOf: filePath)
            print("📊 [RECOVERY] Размер файла: \(data.count) байт")
            
            // Пытаемся декодировать как массив актов
            if let akts = try? JSONDecoder().decode([AKT].self, from: data) {
                print("📊 [RECOVERY] Загружено \(akts.count) актов из файла")
                let numbers = akts.map { $0.number }.sorted(by: { Int($0) ?? 0 < Int($1) ?? 0 })
                print("   Номера актов в файле: \(numbers)")
                
                if let akt19 = akts.first(where: { $0.number == "19" }) {
                    print("✅ [RECOVERY] Акт 19 найден в файле!")
                    print("   ID: \(akt19.id)")
                    print("   Дата: \(akt19.date)")
                    print("   Организация: \(akt19.organization.title)")
                    print("   Нарушений: \(akt19.violations.count)")
                    
                    // Добавляем акт 19 в историю
                    var currentAkts = DataFlowAKT.loadArr()
                    if !currentAkts.contains(where: { $0.number == "19" }) {
                        currentAkts.append(akt19)
                        DataFlowAKT.saveArr(arr: currentAkts)
                        DataFlowAKT.clearCache()
                        print("✅ [RECOVERY] Акт 19 успешно восстановлен из файла!")
                        print("   📊 Теперь в истории: \(currentAkts.count) актов")
                    } else {
                        print("ℹ️ [RECOVERY] Акт 19 уже есть в истории")
                    }
                } else {
                    print("❌ [RECOVERY] Акт 19 не найден в файле")
                    print("   📋 Проверяем, какие акты есть в файле: \(numbers)")
                    
                    // Проверяем, может быть акт 19 есть, но с другим форматом номера
                    let allNumbers = akts.map { $0.number }
                    if allNumbers.contains(where: { $0.contains("19") || $0 == "19" }) {
                        print("   ⚠️ Найден акт, содержащий '19' в номере")
                        if let similarAkt = akts.first(where: { $0.number.contains("19") || $0.number == "19" }) {
                            print("   📋 Найден акт с номером: '\(similarAkt.number)'")
                        }
                    }
                }
            } else {
                print("❌ [RECOVERY] Не удалось декодировать файл AKT.plist")
                print("   💡 Возможно, файл поврежден или имеет неверный формат")
                
                // Пытаемся прочитать как строку для диагностики
                if let stringData = String(data: data, encoding: .utf8) {
                    let preview = String(stringData.prefix(500))
                    print("   📄 Начало файла (первые 500 символов):")
                    print("   \(preview)")
                    
                    // Ищем упоминание акта 19 в сырых данных
                    if stringData.contains("\"number\":\"19\"") || stringData.contains("\"number\": \"19\"") {
                        print("   ⚠️ В файле найдено упоминание акта 19, но декодирование не удалось")
                        print("   💡 Файл может быть поврежден или иметь неверный формат")
                    }
                }
            }
        } catch {
            print("❌ [RECOVERY] Ошибка чтения файла: \(error)")
        }
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
        
        // Инициализируем обработчик NaN ошибок
        _ = NaNErrorHandler.shared
        
        // Настраиваем обработку ошибок плагинов
        setupPluginErrorHandling()
    }
    
    private func setupPluginErrorHandling() {
        // Обработка ошибок плагинов
        let observer1 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("PluginQueryMethodCalled"),
            object: nil,
            queue: .main
        ) { _ in
            print("⚠️ Plugin query method called - обрабатываем ошибку")
            SystemErrorHandler.shared.recoverFromPluginError()
        }
        notificationObservers.append(observer1)
        
        // Обработка ошибок системных сервисов
        let observer2 = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SystemServiceError"),
            object: nil,
            queue: .main
        ) { notification in
            if let error = notification.object as? NSError {
                print("⚠️ System Service Error: \(error.localizedDescription)")
                SystemErrorHandler.shared.handleSystemErrorPublic(error)
            }
        }
        notificationObservers.append(observer2)
        
        print("✅ Обработка ошибок плагинов настроена")
    }
    
    
    private func setupViolationsSystemForFirstLaunch() {
        // Инициализируем систему нарушений только для первого запуска
        // ВАЖНО: НЕ очищаем данные автоматически - это удаляет путь к файлу Excel!
        if ViolationsModel.isFirstLaunch() {
            print("🆕 Первый запуск приложения обнаружен")
            // НЕ вызываем clearViolationsData() - это удаляет путь к файлу!
            // Вместо этого просто отмечаем, что первый запуск завершен
            ViolationsModel.markFirstLaunchCompleted()
            
            // Автоматически ищем файл Excel при первом запуске
            print("   🔄 Автоматический поиск файла Excel...")
            if ViolationsModel.autoFindAndSetExcelPath() {
                print("   ✅ Файл Excel найден и установлен автоматически")
            } else {
                print("   ℹ️ Файл Excel не найден - потребуется импорт")
            }
        }
        
        // Очищаем большие данные из UserDefaults с улучшенной обработкой ошибок
        UserDefaultsCleanupManager.shared.performCleanup()
        
        // Валидируем и ВОССТАНАВЛИВАЕМ невалидные пути к файлам
        self.validateAndCleanupFilePaths()
        
        // Очищаем временные файлы
        FileHandler.shared.cleanupTemporaryFiles()
        
        // Дополнительная очистка для предотвращения ошибок sandbox
        self.performAdditionalCleanup()
        
        // Очищаем несуществующие файлы черновиков
        self.cleanupInvalidDraftFiles()
        
        print("✅ Система нарушений инициализирована")
    }
    
    private func performAdditionalCleanup() {
        print("🔄 Выполняем дополнительную очистку...")
        
        // Очищаем кэш приложения
        URLCache.shared.removeAllCachedResponses()
        
        // Очищаем только временные файлы приложения
        DispatchQueue.global(qos: .utility).async {
            let tempURL = FileManager.default.temporaryDirectory
            do {
                let tempContents = try FileManager.default.contentsOfDirectory(at: tempURL, includingPropertiesForKeys: nil)
                for fileURL in tempContents {
                    if fileURL.lastPathComponent.contains("k.test.Gazprom") {
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
                print("✅ Дополнительные временные файлы очищены")
            } catch {
                print("❌ Ошибка дополнительной очистки: \(error)")
            }
        }
        
        // Синхронизируем UserDefaults
        
        print("✅ Дополнительная очистка завершена")
    }
    
    private func cleanupInvalidDraftFiles() {
        print("🔄 Очистка несуществующих файлов черновиков...")
        
        let userDefaults = UserDefaults.standard
        let draftKey = "DraftAKT"
        
        // Проверяем, есть ли флаг о том, что черновик в файле
        if userDefaults.bool(forKey: "\(draftKey)_in_file") {
            if let filePath = userDefaults.string(forKey: "\(draftKey)_file_path") {
                // Проверяем существование файла
                if !FileManager.default.fileExists(atPath: filePath) {
                    print("🧹 Файл черновика не существует, очищаем флаги")
                    userDefaults.removeObject(forKey: "\(draftKey)_in_file")
                    userDefaults.removeObject(forKey: "\(draftKey)_file_path")
                } else {
                    print("✅ Файл черновика существует: \(filePath)")
                }
            } else {
                // Очищаем флаг, если путь не найден
                userDefaults.removeObject(forKey: "\(draftKey)_in_file")
            }
        }
        
        print("✅ Очистка файлов черновиков завершена")
    }
    
    /// Валидирует и очищает невалидные пути к файлам из UserDefaults
    private func validateAndCleanupFilePaths() {
        print("🔄 [FILE_VALIDATION] Валидация путей к файлам...")
        
        let userDefaults = UserDefaults.standard
        let filePathKeys = [
            "ImportedExcelFilePath",
            "ShabPath",
            "DraftAKT_file_path"
        ]
        
        var fixedCount = 0
        
        for key in filePathKeys {
            if let filePath = userDefaults.string(forKey: key), !filePath.isEmpty {
                // Проверяем существование файла
                if !FileManager.default.fileExists(atPath: filePath) {
                    print("⚠️ [FILE_VALIDATION] Файл не существует по старому пути: \(key)")
                    print("   📁 Старый путь: \(filePath)")
                    
                    // ВАЖНО: НЕ удаляем путь! Вместо этого пытаемся найти файл автоматически
                    if key == "ImportedExcelFilePath" {
                        print("   🔄 Пытаемся найти Excel файл автоматически...")
                        
                        // Пытаемся найти файл автоматически
                        if ViolationsModel.autoFindAndSetExcelPath() {
                            if let newPath = userDefaults.string(forKey: "ImportedExcelFilePath") {
                                print("   ✅ Файл найден автоматически!")
                                print("   📁 Новый путь: \(newPath)")
                                fixedCount += 1
                            }
                        } else {
                            print("   ⚠️ НЕ удаляем путь - он может понадобиться для ручного восстановления")
                            print("   💡 Пользователь может импортировать файл вручную")
                        }
                    } else {
                        // Для других ключей просто логируем предупреждение, но НЕ удаляем
                        print("   ⚠️ Путь сохранен для возможного ручного восстановления")
                    }
                } else {
                    print("✅ [FILE_VALIDATION] Файл существует: \(key)")
                }
            }
        }
        
        if fixedCount > 0 {
            print("✅ [FILE_VALIDATION] Восстановлено путей: \(fixedCount)")
        } else {
            print("✅ [FILE_VALIDATION] Все пути к файлам валидны")
        }
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
    
    // MARK: - Application Lifecycle
    func applicationWillEnterForeground(_ application: UIApplication) {
        // Перепроверяем разрешения и перепланируем уведомления при возврате в приложение
        print("🔄 Приложение возвращается на передний план, проверяем уведомления...")
        checkAndRescheduleNotifications()
        // Обновляем бейдж на иконке приложения
        NotificationManager.shared.updateApplicationIconBadge()
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Перепроверяем разрешения при активации приложения
        print("🔄 Приложение стало активным, проверяем уведомления...")
        checkAndRescheduleNotifications()
        // Обновляем бейдж на иконке приложения
        NotificationManager.shared.updateApplicationIconBadge()
    }
    
    // MARK: - Notifications Setup
    private func setupNotifications() {
        // Устанавливаем делегат для обработки уведомлений
        UNUserNotificationCenter.current().delegate = self
        
        // Запрашиваем разрешение на уведомления
        NotificationManager.shared.requestNotificationPermission { granted in
            if granted {
                print("✅ Разрешение на уведомления получено")
                // Планируем уведомления для всех актов
                NotificationManager.shared.scheduleNotificationsForAllAkts()
            } else {
                print("⚠️ Разрешение на уведомления не предоставлено")
                // Показываем подсказку с переходом в настройки
                self.showNotificationsDeniedAlert()
            }
        }
    }
    
    // Перепроверка разрешений и перепланирование уведомлений
    func checkAndRescheduleNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    print("✅ Уведомления разрешены, перепланируем...")
                    NotificationManager.shared.scheduleNotificationsForAllAkts()
                } else {
                    print("⚠️ Уведомления не разрешены (статус: \(settings.authorizationStatus.rawValue))")
                }
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    // Вызывается, когда пользователь нажимает на уведомление, когда приложение в foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Показываем уведомление даже когда приложение открыто
        if #available(iOS 14.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
        
        // Сохраняем информацию из уведомления для отображения на главном экране
        print("📢 [APP_DELEGATE] Получено уведомление в foreground: \(notification.request.content.title)")
        NotificationInfoManager.shared.saveNotification(notification)
        print("✅ [APP_DELEGATE] Уведомление сохранено")
        
        // Обрабатываем нажатие на уведомление
        NotificationManager.shared.handleNotificationTap(userInfo: notification.request.content.userInfo)
    }
    
    // Вызывается, когда пользователь нажимает на уведомление, когда приложение в background или закрыто
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Сохраняем информацию из уведомления для отображения на главном экране
        print("📢 [APP_DELEGATE] Получено уведомление в background: \(response.notification.request.content.title)")
        NotificationInfoManager.shared.saveNotification(response.notification)
        print("✅ [APP_DELEGATE] Уведомление сохранено")
        
        // Обрабатываем нажатие на уведомление
        NotificationManager.shared.handleNotificationTap(userInfo: response.notification.request.content.userInfo)
        completionHandler()
    }
    
    // MARK: - Cleanup
    
    deinit {
        // Останавливаем таймер очистки кэша
        cacheCleanupTimer?.invalidate()
        cacheCleanupTimer = nil
        
        // Удаляем всех observers
        notificationObservers.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        notificationObservers.removeAll()
        
        print("✅ AppDelegate deallocated")
    }
}

// MARK: - Alerts
extension AppDelegate {
    private func showNotificationsDeniedAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Уведомления выключены",
                message: "Чтобы получать напоминания, включите уведомления в настройках приложения.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            alert.addAction(UIAlertAction(title: "Открыть настройки", style: .default, handler: { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }))
            self.presentTop(alert)
        }
    }
    
    private func presentTop(_ vc: UIViewController) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        top.present(vc, animated: true)
    }
}

// NotificationManager объявлен в Other/NotificationManager.swift

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


// MARK: - Performance Optimization

extension AppDelegate {
    
    // MARK: - Restore Formula From Rules
    /// Восстанавливает формулировки из правил для существующих нарушений в АКТ
    private func restoreFormulaFromRulesForExistingViolations() {
        print("🔄 [MIGRATION] Начинаем восстановление формулировок из правил для существующих нарушений")
        
        // Загружаем библиотеку нарушений
        let violationsLibrary = ViolationsModel.returnAvailableViolation()
        guard !violationsLibrary.isEmpty else {
            print("⚠️ [MIGRATION] Библиотека нарушений пуста, пропускаем миграцию")
            return
        }
        
        print("📚 [MIGRATION] Загружено нарушений из библиотеки: \(violationsLibrary.count)")
        
        // Создаем словарь для быстрого поиска по заголовку и ссылке
        var violationsDict: [String: ViolationsModel.Violation] = [:]
        for violation in violationsLibrary {
            let key = "\(violation.title)|\(violation.subTitle)"
            violationsDict[key] = violation
        }
        
        print("🔍 [MIGRATION] Создан словарь для поиска: \(violationsDict.count) ключей")
        
        var totalUpdated = 0
        var totalChecked = 0
        
        // Обрабатываем все АКТы из истории
        let allAkts = DataFlowAKT.loadArr()
        print("📊 [MIGRATION] Загружено АКТов из истории: \(allAkts.count)")
        
        var updatedAkts: [AKT] = []
        
        for akt in allAkts {
            var hasUpdates = false
            var updatedViolations: [Violations] = []
            
            for violation in akt.violations {
                totalChecked += 1
                
                // Если у нарушения уже есть formulaFromRules, пропускаем
                if let existingFormula = violation.formulaFromRules,
                   !existingFormula.isEmpty && existingFormula != "-" {
                    updatedViolations.append(violation)
                    continue
                }
                
                // Ищем соответствующее нарушение в библиотеке
                let key = "\(violation.title)|\(violation.urlToPravilo)"
                
                if let libraryViolation = violationsDict[key],
                   let formulaFromRules = libraryViolation.formulaFromRules,
                   !formulaFromRules.isEmpty && formulaFromRules != "-" {
                    
                    // Создаем обновленное нарушение с формулировкой из правил
                    let updatedViolation = Violations(
                        title: violation.title,
                        mesto: violation.mesto,
                        urlToPravilo: violation.urlToPravilo,
                        photo: violation.photo,
                        vid: violation.vid,
                        formulaFromRules: formulaFromRules
                    )
                    
                    updatedViolations.append(updatedViolation)
                    hasUpdates = true
                    totalUpdated += 1
                    
                    print("✅ [MIGRATION] Восстановлена формулировка для нарушения: \(violation.title.prefix(50))...")
                } else {
                    // Не найдено в библиотеке, оставляем как есть
                    updatedViolations.append(violation)
                }
            }
            
            // Если были обновления, создаем новый АКТ
            if hasUpdates {
                let updatedAkt = AKT(
                    id: akt.id,
                    number: akt.number,
                    date: akt.date,
                    comission: akt.comission,
                    organization: akt.organization,
                    objectsCheck: akt.objectsCheck,
                    predstavitelyComission: akt.predstavitelyComission,
                    violations: updatedViolations,
                    description: akt.description,
                    actustranenDate: akt.actustranenDate,
                    actPredostavlenDate: akt.actPredostavlenDate,
                    actUtverzdenDate: akt.actUtverzdenDate,
                    urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: akt.realDateCreate
                )
                updatedAkts.append(updatedAkt)
            }
        }
        
        // Обрабатываем редактируемый АКТ
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("📝 [MIGRATION] Обрабатываем редактируемый АКТ №\(editableAkt.akt.number)")
            
            var hasUpdates = false
            var updatedViolations: [Violations] = []
            
            for violation in editableAkt.akt.violations {
                totalChecked += 1
                
                // Если у нарушения уже есть formulaFromRules, пропускаем
                if let existingFormula = violation.formulaFromRules,
                   !existingFormula.isEmpty && existingFormula != "-" {
                    updatedViolations.append(violation)
                    continue
                }
                
                // Ищем соответствующее нарушение в библиотеке
                let key = "\(violation.title)|\(violation.urlToPravilo)"
                
                if let libraryViolation = violationsDict[key],
                   let formulaFromRules = libraryViolation.formulaFromRules,
                   !formulaFromRules.isEmpty && formulaFromRules != "-" {
                    
                    // Создаем обновленное нарушение с формулировкой из правил
                    let updatedViolation = Violations(
                        title: violation.title,
                        mesto: violation.mesto,
                        urlToPravilo: violation.urlToPravilo,
                        photo: violation.photo,
                        vid: violation.vid,
                        formulaFromRules: formulaFromRules
                    )
                    
                    updatedViolations.append(updatedViolation)
                    hasUpdates = true
                    totalUpdated += 1
                    
                    print("✅ [MIGRATION] Восстановлена формулировка для нарушения в редактируемом АКТ: \(violation.title.prefix(50))...")
                } else {
                    // Не найдено в библиотеке, оставляем как есть
                    updatedViolations.append(violation)
                }
            }
            
            // Если были обновления, обновляем редактируемый АКТ
            if hasUpdates {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: updatedViolations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                
                DataFlowAKT.updateEditableAKT(updatedAkt)
                print("✅ [MIGRATION] Обновлен редактируемый АКТ")
            }
        }
        
        // Сохраняем обновленные АКТы
        if !updatedAkts.isEmpty {
            // Обновляем только измененные АКТы
            var finalAkts = allAkts
            for updatedAkt in updatedAkts {
                if let index = finalAkts.firstIndex(where: { $0.id == updatedAkt.id }) {
                    finalAkts[index] = updatedAkt
                }
            }
            
            DataFlowAKT.saveArr(arr: finalAkts)
            print("💾 [MIGRATION] Сохранено обновленных АКТов: \(updatedAkts.count)")
        }
        
        print("✅ [MIGRATION] Миграция завершена:")
        print("   📊 Проверено нарушений: \(totalChecked)")
        print("   ✅ Восстановлено формулировок: \(totalUpdated)")
        print("   📝 Обновлено АКТов: \(updatedAkts.count)")
    }
    
    private func setupPerformanceOptimization() {
        // Настраиваем оптимизацию производительности
        print("🚀 Настройка оптимизации производительности")
        
        // Очищаем временные файлы при запуске
        FileHandler.shared.cleanupTemporaryFiles()
        
        // Оптимизируем UserDefaults
        UserDefaultsCleanupManager.shared.performCleanup()
        
        // Настраиваем периодическую очистку кэша
        setupPeriodicCacheCleanup()
    }
    
    
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        // Обрабатываем предупреждение о нехватке памяти
        print("⚠️ Получено предупреждение о нехватке памяти")
        
        // Очищаем временные файлы
        FileHandler.shared.cleanupTemporaryFiles()
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        print("📱 Приложение завершает работу")
        
        // Очищаем временные файлы при завершении работы
        FileHandler.shared.cleanupTemporaryFiles()
    }
    
    private func setupPeriodicCacheCleanup() {
        // Таймер создаём на главном потоке, чтобы он был в RunLoop.main
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.cacheCleanupTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                _ = self
                _ = CacheManager.shared.clearAllCache()
                UserDefaultsCleanupManager.shared.performCleanup()
                print("🔄 Периодическая очистка кэша выполнена")
            }
        }
    }
    
}


