//
//  SettingsViolationsViewController.swift
//  Gazprom
//
//  Created by Владимир on 08.07.2025.
//

import UIKit
import UniformTypeIdentifiers
import AudioToolbox

class SettingsViolationsViewController: UIViewController, UIDocumentPickerDelegate {
    
    var items: [ViolationsModel.Violation] = []
    private var filteredItems: [ViolationsModel.Violation] = []
    
    /// Поколение поиска: только результат последнего запроса применяется к UI (защита от race при быстром вводе).
    private var searchGeneration = 0
    
    // Сохраняем путь к файлу Excel для защиты от потери при работе с модальными окнами
    private var savedExcelFilePath: String?
    
    // Таймер для периодической проверки пути
    private var pathCheckTimer: Timer?
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.register(UITableViewCell.self, forCellReuseIdentifier: "1")
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .clear
        return view
    }()
    
    private let searchTextField: UISearchTextField = {
        let textField = UISearchTextField()
        textField.placeholder = "Поиск по формулировке, документу, примечанию..."
        textField.returnKeyType = .done
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textField
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Просмотр нарушений"
        
        // Сохраняем путь к файлу Excel при появлении экрана
        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        print("📂 [SETTINGS_VIOLATIONS] Сохранен путь к файлу: \(savedExcelFilePath ?? "не найден")")
        
        // Восстанавливаем путь к файлу, если он был утерян
        restoreExcelFilePathIfNeeded()
        
        // ЗАЩИТА: Восстанавливаем путь перед загрузкой нарушений
        print("🔒 [SETTINGS_VIOLATIONS] Защита перед загрузкой нарушений")
        restoreExcelFilePathIfNeeded()
        
        // Перезагружаем данные после возврата на экран (на случай если были изменения)
        items = ViolationsModel.returnAvailableViolation()
        
        // ЗАЩИТА: Восстанавливаем путь после загрузки нарушений
        print("🔒 [SETTINGS_VIOLATIONS] Защита после загрузки нарушений")
        restoreExcelFilePathIfNeeded()
        
        filteredItems = items
        tableView.reloadData()
        
        // Запускаем таймер проверки пути
        startPathCheckTimer()
        
        // Ищем SettingsTabViewController в стеке навигации и устанавливаем backBarButtonItem из него
        if let navController = navigationController {
            // Проходим по всем контроллерам в стеке, начиная с конца (предыдущие)
            let viewControllers = navController.viewControllers
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let settingsVC = viewControllers[i] as? SettingsTabViewController {
                    // Нашли SettingsTabViewController в стеке, используем его backBarButtonItem
                    let backButton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
                    settingsVC.navigationItem.backBarButtonItem = backButton
                    settingsVC.navigationItem.backButtonTitle = ""
                    settingsVC.navigationItem.backButtonDisplayMode = .minimal
                    break
                }
            }
            
            // Также устанавливаем напрямую в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = ""
                prevVC.navigationItem.backButtonDisplayMode = .minimal
            }
        }
    }
    
    /// Восстанавливает путь к файлу Excel, если он был утерян
    private func restoreExcelFilePathIfNeeded() {
        // Проверяем текущий путь в UserDefaults
        let currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        
        if currentPath == nil || currentPath?.isEmpty == true {
            // Путь утерян, восстанавливаем из сохраненного значения
            if let savedPath = savedExcelFilePath, !savedPath.isEmpty {
                print("⚠️ [SETTINGS_VIOLATIONS] Обнаружена потеря пути к файлу Excel!")
                print("   Текущий путь: \(currentPath ?? "отсутствует")")
                print("   🔄 Восстанавливаем путь: \(savedPath)")
                
                UserDefaults.standard.set(savedPath, forKey: "ImportedExcelFilePath")
                
                print("   ✅ Путь к файлу Excel восстановлен")
                
                // Проверяем, что файл действительно существует
                if FileManager.default.fileExists(atPath: savedPath) {
                    print("   ✅ Файл существует по восстановленному пути")
                } else {
                    print("   ⚠️ ВНИМАНИЕ: Файл не существует по пути \(savedPath)")
                    // Пытаемся найти файл автоматически
                    print("   🔄 Пытаемся найти файл автоматически...")
                    if ViolationsModel.autoFindAndSetExcelPath() {
                        print("   ✅ Файл найден автоматически")
                        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
                    } else {
                        print("   ❌ Не удалось найти файл автоматически")
                    }
                }
            } else {
                print("⚠️ [SETTINGS_VIOLATIONS] Путь к файлу отсутствует, пытаемся найти автоматически...")
                if ViolationsModel.autoFindAndSetExcelPath() {
                    print("   ✅ Файл найден автоматически")
                    savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
                } else {
                    print("   ❌ Не удалось найти файл автоматически")
                }
            }
        } else {
            print("✅ [SETTINGS_VIOLATIONS] Путь к файлу Excel сохранен корректно")
            
            // Дополнительная проверка существования файла
            if let path = currentPath, !FileManager.default.fileExists(atPath: path) {
                print("⚠️ [SETTINGS_VIOLATIONS] ВНИМАНИЕ: Файл не существует по сохраненному пути!")
                print("   Путь: \(path)")
                print("   🔄 Пытаемся найти файл автоматически...")
                if ViolationsModel.autoFindAndSetExcelPath() {
                    print("   ✅ Файл найден автоматически")
                    savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
                } else {
                    print("   ❌ Не удалось найти файл автоматически")
                }
            }
        }
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Сохраняем путь к файлу Excel ДО загрузки данных
        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        print("📂 [SETTINGS_VIOLATIONS] viewDidLoad - сохранен путь: \(savedExcelFilePath ?? "не найден")")
        
        // Добавляем наблюдатель за изменениями в UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        // Обновляем список при любом изменении реестра нарушений (сохранение в настройках, добавление, удаление)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(violationsRegistryDidChange),
            name: ViolationsModel.violationsDidChangeNotification,
            object: nil
        )
        
        // Загружаем данные синхронно (это быстрая операция)
        items = ViolationsModel.returnAvailableViolation()
        
        // Настройка темной темы
        setupDarkTheme()
       
        setupSearchField()
        setupTableView()
        setupButtons()
        checkitems()
        
        // Инициализируем отфильтрованный список
        filteredItems = items
        
        // Принудительно обновляем таблицу
        tableView.reloadData()
        
        // Запускаем таймер для периодической проверки пути (каждые 2 секунды)
        startPathCheckTimer()
    }
    
    private func startPathCheckTimer() {
        // Останавливаем существующий таймер, если есть
        pathCheckTimer?.invalidate()
        
        // Создаем новый таймер
        pathCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkAndRestorePath()
        }
        
        print("⏰ [SETTINGS_VIOLATIONS] Запущен таймер проверки пути")
    }
    
    private func stopPathCheckTimer() {
        pathCheckTimer?.invalidate()
        pathCheckTimer = nil
        print("⏰ [SETTINGS_VIOLATIONS] Остановлен таймер проверки пути")
    }
    
    private func checkAndRestorePath() {
        let currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        if currentPath == nil || currentPath?.isEmpty == true {
            print("⚠️ [TIMER] Обнаружена потеря пути - восстанавливаем...")
            restoreExcelFilePathIfNeeded()
        }
    }
    
    @objc private func userDefaultsDidChange() {
        // Проверяем путь при каждом изменении UserDefaults
        let currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        if currentPath == nil || currentPath?.isEmpty == true {
            print("⚠️ [SETTINGS_VIOLATIONS] ОБНАРУЖЕНА ПОТЕРЯ ПУТИ в UserDefaults!")
            print("   Немедленно восстанавливаем...")
            restoreExcelFilePathIfNeeded()
        }
    }
    
    @objc private func violationsRegistryDidChange() {
        items = ViolationsModel.returnAvailableViolation()
        filteredItems = items
        tableView.reloadData()
    }
    
    deinit {
        stopPathCheckTimer()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        stopPathCheckTimer()
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
            tableView.reloadData()
        }
    }
    
    
    private func setupSearchField() {
        searchTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
        view.addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
            make.height.equalTo(42)
        }
    }
    
    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(searchTextField.snp.bottom).offset(4)
        }
        
        // Добавляем длительное нажатие для редактирования
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        tableView.addGestureRecognizer(longPressGesture)
    }
    
    private func setupButtons() {
        let loadButton = UIFactory.createButton(title: "Импорт", color: .systemBlue)
        let exportButton = UIFactory.createButton(title: "Экспорт", color: .systemBlue)
        
        loadButton.addTarget(self, action: #selector(importData), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportData), for: .touchUpInside)
        
        // Сначала добавляем все view в hierarchy
        view.addSubview(loadButton)
        view.addSubview(exportButton)
        
        // Затем создаем constraints для кнопок
        loadButton.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.left.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.centerX).offset(-4)
        }
        
        exportButton.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.left.equalTo(view.safeAreaLayoutGuide.snp.centerX).offset(4)
        }
    }
    
    
    @objc private func importData() {
        let types: [UTType] = [UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "xls")!]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    @objc private func exportData() {
        guard let path = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("❌ Файл не найден")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Файл не существует по пути: \(fileURL.path)")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }
    

    
    // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        // Начинаем доступ к security-scoped ресурсу
        guard url.startAccessingSecurityScopedResource() else {
            print("🚫 Не удалось получить доступ к файлу")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            print("✅ Файл скопирован в: \(destinationURL.path)")

            UserDefaults.standard.set(destinationURL.path, forKey: "ImportedExcelFilePath")
            // Принудительно синхронизируем UserDefaults для надежности
            print("✅ Путь сохранен в UserDefaults: \(destinationURL.path)")

            print("🔍 Загружаем нарушения из файла...")
            items = ViolationsModel.returnAvailableViolation()
            filteredItems = items
            print("📊 Загружено нарушений в UI: \(items.count)")
            
            // Проверяем, что данные действительно загружены
            if items.isEmpty {
                print("⚠️ Нарушения не загружены после импорта. Пытаемся найти файл автоматически...")
                if ViolationsModel.autoFindAndSetExcelPath() {
                    items = ViolationsModel.returnAvailableViolation()
                    filteredItems = items
                    print("📊 После автоматического поиска загружено нарушений: \(items.count)")
                }
            }
            
            tableView.reloadData()
            print("✅ Таблица обновлена")
        } catch {
            print("❌ Ошибка копирования файла: \(error.localizedDescription)")
        }
    }


    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("🚫 Выбор файла отменен")
    }
    
    
    func checkitems() {
        // Кнопка добавления нарушения
        let plusButton = UIButton(type: .system)
        let plusImage = UIImage(systemName: "plus")
        plusButton.setImage(plusImage, for: .normal)
        plusButton.tintColor = .systemBlue
        // Используем intrinsic content size вместо явных ограничений
        // Это предотвращает конфликты с системными ограничениями navigation bar
        // Система автоматически установит правильный размер для кнопок в navigation bar
        plusButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        
        // Кнопка обучения модели по фото (иконка: голова с мозгами)
        let mlTrainingButton = UIButton(type: .system)
        let mlTrainingImage = UIImage(systemName: "brain.head.profile")
        mlTrainingButton.setImage(mlTrainingImage, for: .normal)
        mlTrainingButton.tintColor = .systemBlue
        mlTrainingButton.addTarget(self, action: #selector(openMLTraining), for: .touchUpInside)
        
        let plusItem = UIBarButtonItem(customView: plusButton)
        let mlTrainingItem = UIBarButtonItem(customView: mlTrainingButton)
        
        self.navigationItem.setRightBarButtonItems([plusItem, mlTrainingItem], animated: true)
    }
    
    @objc private func openMLTraining() {
        let trainingVC = ViolationMLTrainingViewController()
        navigationController?.pushViewController(trainingVC, animated: true)
    }
    
    
    @objc private func addNew() {
        // Сохраняем путь к файлу Excel перед открытием модального окна
        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        print("📂 [SETTINGS_VIOLATIONS] Сохраняем путь перед добавлением нарушения: \(savedExcelFilePath ?? "не найден")")
        
        let unifiedFormVC = UnifiedViolationFormViewController { [weak self] violation in
            guard let self = self else { return }
            
            // Восстанавливаем путь к файлу перед сохранением
            self.restoreExcelFilePathIfNeeded()
            
            // Добавляем нарушение - файл Excel автоматически сохраняется внутри метода
            ViolationsModel.addNewViolation(violation: violation)
            
            // Обновляем UI
            self.items = ViolationsModel.returnAvailableViolation()
            self.filteredItems = self.items
            self.tableView.reloadData()
            
            // Показываем уведомление после закрытия модального окна
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: "Успешно",
                    message: "Нарушение добавлено в реестр. Файл Excel автоматически сохранен.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        
        let navController = UINavigationController(rootViewController: unifiedFormVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true) { [weak self] in
            // После открытия модального окна проверяем, что путь не был утерян
            self?.restoreExcelFilePathIfNeeded()
        }
    }
    
    @objc private func addNewViolationFromSearch() {
        // Вибрационный отклик
        triggerHapticFeedback(.light)
        
        // Получаем текст из поиска
        let searchText = searchTextField.text ?? ""
        
        // Очищаем поле поиска
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        // Вызываем метод добавления с предзаполненным текстом
        addNewWithSearchText(searchText)
    }
    
    private func addNewWithSearchText(_ searchText: String) {
        // Сохраняем путь к файлу Excel перед открытием модального окна
        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        print("📂 [SETTINGS_VIOLATIONS] Сохраняем путь перед добавлением нарушения с поиском: \(savedExcelFilePath ?? "не найден")")
        
        let unifiedFormVC = UnifiedViolationFormViewController(searchText: searchText) { [weak self] violation in
            guard let self = self else { return }
            
            // Восстанавливаем путь к файлу перед сохранением
            self.restoreExcelFilePathIfNeeded()
            
            // Добавляем нарушение - файл Excel автоматически сохраняется внутри метода
            ViolationsModel.addNewViolation(violation: violation)
            
            // Обновляем UI
            self.items = ViolationsModel.returnAvailableViolation()
            self.filteredItems = self.items
            self.tableView.reloadData()
            
            // Показываем уведомление после закрытия модального окна
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                guard let self = self else { return }
                let alert = UIAlertController(
                    title: "Успешно",
                    message: "Нарушение добавлено в реестр. Файл Excel автоматически сохранен.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        
        let navController = UINavigationController(rootViewController: unifiedFormVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true) { [weak self] in
            // После открытия модального окна проверяем, что путь не был утерян
            self?.restoreExcelFilePathIfNeeded()
        }
    }
    
    private func showViolationInfo(for violation: ViolationsModel.Violation) {
        // Вибрационный отклик для просмотра
        triggerHapticFeedback(.light)
        
        let previewVC = SettingsViolationPreviewViewController(violation: violation)
        previewVC.modalPresentationStyle = .pageSheet
        
        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(previewVC, animated: true)
    }
    
    // MARK: - Haptic Feedback Methods
    private func triggerHapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let impactFeedback = UIImpactFeedbackGenerator(style: style)
        impactFeedback.impactOccurred()
    }
    
    private func triggerHapticFeedback(_ style: UINotificationFeedbackGenerator.FeedbackType) {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(style)
    }
    
    // MARK: - Long Press Gesture Handler
    @objc private func handleLongPress(_ gestureRecognizer: UILongPressGestureRecognizer) {
        let point = gestureRecognizer.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        
        switch gestureRecognizer.state {
        case .began:
            // Вибрационный отклик при начале длительного нажатия
            triggerHapticFeedback(.medium)
            
            // Анимация ячейки
            if let cell = tableView.cellForRow(at: indexPath) {
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    cell.alpha = 0.8
                })
            }
            
        case .ended, .cancelled:
            // Возвращаем ячейку в исходное состояние
            if let cell = tableView.cellForRow(at: indexPath) {
                UIView.animate(withDuration: 0.1, animations: {
                    cell.transform = .identity
                    cell.alpha = 1.0
                })
            }
            
            // Открываем редактирование только если жест завершился успешно
            if gestureRecognizer.state == .ended {
                let violation = filteredItems[indexPath.row]
                // Находим индекс в оригинальном массиве для корректного обновления
                if let originalIndex = items.firstIndex(where: { $0.title == violation.title && $0.subTitle == violation.subTitle }) {
                    let originalIndexPath = IndexPath(row: originalIndex, section: 0)
                    openEditAlert(for: violation, at: originalIndexPath)
                }
            }
            
        default:
            break
        }
    }
    
    private func openEditAlert(for violation: ViolationsModel.Violation, at indexPath: IndexPath) {
        // Вибрационный отклик для редактирования
        triggerHapticFeedback(.medium)
        
        // Сохраняем путь к файлу Excel перед открытием модального окна
        savedExcelFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        print("📂 [SETTINGS_VIOLATIONS] Сохраняем путь перед редактированием: \(savedExcelFilePath ?? "не найден")")
        
        let editVC = UnifiedViolationFormViewController(existingViolation: violation) { [weak self] updatedViolation in
            guard let self = self else { return }
            
            print("🔄 Обновляем нарушение в настройках:")
            print("   Старое: \(violation.title)")
            print("   Новое: \(updatedViolation.title)")
            
            // Восстанавливаем путь к файлу перед сохранением
            self.restoreExcelFilePathIfNeeded()
            
            // Используем новый метод для обновления нарушения - файл Excel автоматически сохраняется внутри метода
            ViolationsModel.updateViolation(oldViolation: violation, newViolation: updatedViolation)
            
            // Обновляем локальный массив
            self.items = ViolationsModel.returnAvailableViolation()
            self.filteredItems = self.items
            print("📊 Количество нарушений после обновления: \(self.items.count)")
            self.tableView.reloadData()
            
            // Показываем уведомление о том, что файл сохранен
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Успешно",
                    message: "Нарушение обновлено. Файл Excel автоматически сохранен.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true) { [weak self] in
            // После открытия модального окна проверяем, что путь не был утерян
            self?.restoreExcelFilePathIfNeeded()
        }
    }
    
    // MARK: - Search Methods
    @objc private func searchTextChanged(_ textField: UITextField) {
        let query = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        
        AppLogger.shared.info("[ПОИСК] searchTextChanged запрос=\(query.prefix(50)) queryLength=\(query.count) itemsCount=\(items.count)")
        
        guard !query.isEmpty else {
            AppLogger.shared.info("[ПОИСК] запрос пустой — сбрасываем фильтр")
            filteredItems = items
            tableView.reloadData()
            return
        }
        
        searchGeneration += 1
        let currentGeneration = searchGeneration
        AppLogger.shared.info("[ПОИСК] поколение=\(currentGeneration) уход в фоновый поиск")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            AppLogger.shared.info("[ПОИСК] фоновый поток: вызов ViolationContextSearchEngine.search")
            let context = SearchContext(
                searchQuery: query,
                objectName: nil,
                relatedViolationIds: [],
                commonRules: nil
            )
            let scoredResults = ViolationContextSearchEngine.shared.search(
                query: query,
                violations: self.items,
                context: context
            )
            let filtered = scoredResults.map { $0.violation }
            AppLogger.shared.info("[ПОИСК] фоновый поток: поиск завершён, найдено=\(filtered.count)")
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                AppLogger.shared.info("[ПОИСК] main: поколение=\(currentGeneration) текущее=\(self.searchGeneration) filteredCount=\(filtered.count)")
                if currentGeneration != self.searchGeneration {
                    AppLogger.shared.info("[ПОИСК] main: устаревшее поколение, не обновляем UI")
                    return
                }
                self.filteredItems = filtered
                self.tableView.reloadData()
                AppLogger.shared.info("[ПОИСК] main: UI обновлён, строк=\(filtered.count)")
            }
        }
    }
    
    private func highlightText(_ text: String, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Ищем все вхождения поискового текста (без учета регистра)
        let searchRange = text.range(of: searchText, options: .caseInsensitive)
        if let searchRange = searchRange {
            let nsRange = NSRange(searchRange, in: text)
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: nsRange)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: nsRange)
        }
        
        return attributedString
    }
    
    // MARK: - Add Violation Cell Setup
    private func setupAddViolationCell(containerView: UIView) {
        // Создаем кнопку с иконкой плюс
        let addButton = UIButton(type: .system)
        addButton.setTitle("", for: .normal)
        addButton.backgroundColor = .clear
        addButton.layer.cornerRadius = 0
        addButton.addTarget(self, action: #selector(addNewViolationFromSearch), for: .touchUpInside)
        
        // Добавляем кнопку в контейнер
        containerView.addSubview(addButton)
        addButton.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Создаем горизонтальный стек для содержимого (плюс и текст в одну строку)
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.isUserInteractionEnabled = false
        
        // Иконка плюс
        let plusImageView = UIImageView()
        plusImageView.image = UIImage(systemName: "plus.circle.fill")
        plusImageView.tintColor = .systemBlue
        plusImageView.contentMode = .scaleAspectFit
        
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            plusImageView.tintColor = .white
        }
        
        // Заголовок
        let titleLabel = UILabel()
        titleLabel.text = "Добавить нарушение"
        titleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        titleLabel.textAlignment = .left
        
        // Настройка цветов для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            titleLabel.textColor = .white
        } else {
            titleLabel.textColor = .label
        }
        
        // Добавляем элементы в стек
        stackView.addArrangedSubview(plusImageView)
        stackView.addArrangedSubview(titleLabel)
        
        // Добавляем стек в контейнер
        containerView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(20)
        }
        
        // Ограничения для иконки
        plusImageView.snp.makeConstraints { make in
            make.width.height.equalTo(24)
        }
    }
    
    
    
}

// MARK: - UISearchTextFieldDelegate
extension SettingsViolationsViewController: UISearchTextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

extension SettingsViolationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Если результаты поиска пусты, показываем одну ячейку с кнопкой добавления
        if filteredItems.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            return 1
        }
        return filteredItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "1") ?? UITableViewCell()
        // Полностью очищаем ячейку от всех subviews
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        // Сбрасываем все свойства ячейки
        cell.layer.cornerRadius = 0
        cell.layer.shadowOpacity = 0
        cell.transform = .identity
        cell.alpha = 1.0
        
        // Настройка внешнего вида ячейки в стиле кнопок главного меню
        cell.layer.cornerRadius = 16
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowOpacity = 0.1
        cell.layer.shadowRadius = 4
        
        // Создаем контейнер для содержимого ячейки
        let containerView = UIView()
        
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            containerView.backgroundColor = .systemGray6
            containerView.layer.cornerRadius = 16
            containerView.layer.masksToBounds = false
            // Добавляем белую рамку для темной темы
            containerView.layer.borderWidth = 1.0
            containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            containerView.layer.shadowColor = UIColor.white.withAlphaComponent(0.1).cgColor
            containerView.layer.shadowOffset = CGSize(width: 0, height: 1)
            containerView.layer.shadowOpacity = 1.0
            containerView.layer.shadowRadius = 2
        } else {
            containerView.backgroundColor = .systemGray6
            containerView.layer.cornerRadius = 16
            containerView.layer.masksToBounds = true
        }
        
        cell.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        
        // Проверяем, нужно ли показать кнопку добавления нарушения
        if filteredItems.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            setupAddViolationCell(containerView: containerView)
            return cell
        }
        
        let item = filteredItems[indexPath.row]
        
        let numbLabel = UILabel()
        // Подсвечиваем найденный текст в заголовке
        if let searchText = searchTextField.text, !searchText.isEmpty {
            numbLabel.attributedText = highlightText(item.title, searchText: searchText)
        } else {
            numbLabel.text = item.title
        }
        numbLabel.textAlignment = .left
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            numbLabel.textColor = .white
        } else {
            numbLabel.textColor = .label
        }
        numbLabel.font = .systemFont(ofSize: 20, weight: .medium)
        containerView.addSubview(numbLabel)
        numbLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(4)
            make.left.equalToSuperview().inset(8)
            make.right.equalToSuperview().inset(16)
          //  make.width.equalTo(50)
        }
        
        
        let urlLabel = UILabel()
        urlLabel.text = "Ссылка на норм. документ"
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            urlLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            urlLabel.textColor = .label
        }
        urlLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(urlLabel)
        urlLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(numbLabel.snp.bottom).inset(-2)
        }
        
        let normLabel = UILabel()
        // Подсвечиваем найденный текст в нормативном документе
        if let searchText = searchTextField.text, !searchText.isEmpty {
            normLabel.attributedText = highlightText(item.subTitle, searchText: searchText)
        } else {
            normLabel.text = item.subTitle
        }
        normLabel.textAlignment = .left
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            normLabel.textColor = .white.withAlphaComponent(0.9)
        } else {
            normLabel.textColor = .label
        }
        normLabel.font = .systemFont(ofSize: 16, weight: .regular)
        containerView.addSubview(normLabel)
        normLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(urlLabel.snp.bottom).inset(-2)
        }
        
        let primLabel = UILabel()
        primLabel.text = "Примечание"
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            primLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            primLabel.textColor = .label
        }
        primLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(primLabel)
        primLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(normLabel.snp.bottom).inset(-4)
        }
        
        let mainPrimLabel = UILabel()
        let descriptionText = item.description == nil ? "---" : item.description!
        // Подсвечиваем найденный текст в примечании
        if let searchText = searchTextField.text, !searchText.isEmpty {
            mainPrimLabel.attributedText = highlightText(descriptionText, searchText: searchText)
        } else {
            mainPrimLabel.text = descriptionText
        }
        mainPrimLabel.textAlignment = .left
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            mainPrimLabel.textColor = .white.withAlphaComponent(0.9)
        } else {
            mainPrimLabel.textColor = .label
        }
        mainPrimLabel.font = .systemFont(ofSize: 16, weight: .regular)
        containerView.addSubview(mainPrimLabel)
        mainPrimLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(primLabel.snp.bottom).inset(-2)
        }
        
        let narushLabel = UILabel()
        narushLabel.text = "Вид нарушения"
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            narushLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            narushLabel.textColor = .label
        }
        narushLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(narushLabel)
        narushLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(mainPrimLabel.snp.bottom).inset(-4)
        }
        
        let mainVidLabel = UILabel()
        let vidText = item.vid ?? "---"
        // Подсвечиваем найденный текст в виде нарушения
        if let searchText = searchTextField.text, !searchText.isEmpty {
            mainVidLabel.attributedText = highlightText(vidText, searchText: searchText)
        } else {
            mainVidLabel.text = vidText
        }
        mainVidLabel.textAlignment = .left
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            mainVidLabel.textColor = .white.withAlphaComponent(0.9)
        } else {
            mainVidLabel.textColor = .label
        }
        mainVidLabel.font = .systemFont(ofSize: 16, weight: .regular)
        mainVidLabel.numberOfLines = 0
        containerView.addSubview(mainVidLabel)
        mainVidLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(narushLabel.snp.bottom).inset(-2)
            make.bottom.equalToSuperview().inset(16)
        }
        
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Если это кнопка добавления нарушения, делаем её компактной по высоте текста
        if filteredItems.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            return 60
        }
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 220
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Проверяем, если это кнопка добавления нарушения
        if filteredItems.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            addNewViolationFromSearch()
            return
        }
        
        let violation = filteredItems[indexPath.row]
        
        // Анимация ячейки при нажатии
        if let cell = tableView.cellForRow(at: indexPath) {
            UIView.animate(withDuration: 0.1, animations: {
                cell.transform = CGAffineTransform(scaleX: 0.98, y: 0.98)
            }) { _ in
                UIView.animate(withDuration: 0.1) {
                    cell.transform = .identity
                }
            }
        }
        
        // Показываем подробную информацию при одиночном нажатии
        showViolationInfo(for: violation)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let itemToDelete = filteredItems[indexPath.row]
            // Находим и удаляем из оригинального массива
            if let originalIndex = items.firstIndex(where: { $0.title == itemToDelete.title && $0.subTitle == itemToDelete.subTitle }) {
                items.remove(at: originalIndex)
            }
            // Обновляем отфильтрованный массив
            filteredItems = items
            tableView.reloadData()
            ViolationsModel.delete(item: itemToDelete)
            checkitems()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let editAction = UIContextualAction(style: .normal, title: "Редактировать") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            let violation = self.filteredItems[indexPath.row]
            // Находим индекс в оригинальном массиве для корректного обновления
            if let originalIndex = self.items.firstIndex(where: { $0.title == violation.title && $0.subTitle == violation.subTitle }) {
                let originalIndexPath = IndexPath(row: originalIndex, section: 0)
                self.openEditAlert(for: violation, at: originalIndexPath)
            }
            completionHandler(true)
        }
        
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            let itemToDelete = self.filteredItems[indexPath.row]
            // Находим и удаляем из оригинального массива
            if let originalIndex = self.items.firstIndex(where: { $0.title == itemToDelete.title && $0.subTitle == itemToDelete.subTitle }) {
                self.items.remove(at: originalIndex)
            }
            // Обновляем отфильтрованный массив
            self.filteredItems = self.items
            tableView.reloadData()
            ViolationsModel.delete(item: itemToDelete)
            self.checkitems()
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        // Порядок в массиве: сначала "Удалить" (будет справа), потом "Редактировать" (будет слева)
        // В iOS trailing swipe actions отображаются справа налево в обратном порядке массива
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }


    
}
