//
//  SettingsTabViewController.swift
//  Gazprom
//
// 

import UIKit
import UniformTypeIdentifiers

class SettingsTabViewController: UIViewController {
    
    let model: MainAKTViewModel
    private var templateStatusLabel: UILabel!
    private var cacheInfoLabel: UILabel!
    
    init(model: MainAKTViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.title = "Настройки"
        navigationItem.title = "Настройки"
        
        // Явно показываем TabBar, чтобы она не пропадала после выбора раздела
        tabBarController?.tabBar.isHidden = false
        tabBarController?.tabBar.alpha = 1.0
        
        // Настройка navigation bar и tab bar для прозрачности
        setupNavigationBarAppearance()
        setupTabBarAppearance()
        
        updateTemplateStatus()
        updateCacheInfo()
        
        // Проверяем и создаем бэкапы при запуске
        DispatchQueue.global(qos: .utility).async {
            // Создаем ежедневный бэкап (если нужно)
            BackupManager.checkAndCreateDailyBackup()
            // Создаем обычный бэкап при каждом запуске
            BackupManager.createManualBackupOnLaunch()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Явно показываем TabBar, чтобы она не пропадала после выбора раздела
        tabBarController?.tabBar.isHidden = false
        tabBarController?.tabBar.alpha = 1.0
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Убираем множественные вызовы setup методов, чтобы избежать конфликтов с gesture recognizers
        // Настройки уже применены в viewWillAppear и viewDidAppear
    }
    
    private func setupNavigationBarAppearance() {
        guard let navBar = navigationController?.navigationBar else {
            return
        }
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = nil
        appearance.backgroundColor = .clear
        
        // Адаптивный цвет: черный в светлой теме, белый в темной
        let adaptiveTitleColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? .black : .white
        }
        appearance.titleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        
        // Применяем напрямую к navigation bar
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.prefersLargeTitles = false
        navBar.isTranslucent = true
        
        // Убеждаемся, что navigation bar полностью прозрачный
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        navBar.tintColor = adaptiveTitleColor
        navBar.barTintColor = nil
        navBar.backgroundColor = nil
    }
    
    private func setupTabBarAppearance() {
        guard let tabBar = tabBarController?.tabBar else {
            return
        }
        
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        tabBarAppearance.backgroundEffect = nil
        
        // Адаптивный цвет для текста: черный в светлой теме, серый в темной
        let adaptiveTextColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? .black : .systemGray
        }
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .systemGray
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: adaptiveTextColor]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.isTranslucent = true
        tabBar.barTintColor = nil
        tabBar.backgroundColor = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Устанавливаем фон view ПЕРВЫМ, чтобы избежать черного квадрата
        view.backgroundColor = .systemBackground
        
        // Настройка navigation bar ДО setupUI, чтобы избежать визуальных артефактов
        setupNavigationBarAppearance()
        
        // Устанавливаем кнопку "назад" только со стрелочкой без текста для всех дочерних экранов
        // Устанавливаем один раз в viewDidLoad, чтобы избежать конфликтов constraints
        // Используем .default вместо .minimal для избежания конфликтов ограничений
        if #available(iOS 14.0, *) {
            navigationItem.backButtonDisplayMode = .default
        }
        
        setupUI()
        updateTemplateStatus()
    }

    private func setupUI() {
        // view.backgroundColor уже установлен в viewDidLoad
        
        let violationsSelectButton = UIFactory.createButton(title: "Нарушения", color: .systemBlue)
        view.addSubview(violationsSelectButton)
        violationsSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.height.equalTo(54)
        }
        violationsSelectButton.addTarget(self, action: #selector(openViolations), for: .touchUpInside)
        
        let orgSelectButton = UIFactory.createButton(title: "Организации", color: .systemBlue)
        view.addSubview(orgSelectButton)
        orgSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(violationsSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        orgSelectButton.addTarget(self, action: #selector(openOrganizations), for: .touchUpInside)
        
        let objSelectButton = UIFactory.createButton(title: "Обьекты проверки", color: .systemBlue)
        view.addSubview(objSelectButton)
        objSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(orgSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        objSelectButton.addTarget(self, action: #selector(openObjects), for: .touchUpInside)
        
        let predSelectButton = UIFactory.createButton(title: "Представители", color: .systemBlue)
        view.addSubview(predSelectButton)
        predSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(objSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        predSelectButton.addTarget(self, action: #selector(openPredstav), for: .touchUpInside)
        
        
        let comSelectButton = UIFactory.createButton(title: "Члены комиссии", color: .systemBlue)
        view.addSubview(comSelectButton)
        comSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(predSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        comSelectButton.addTarget(self, action: #selector(openComissionPeople), for: .touchUpInside)
        
        let scheduleSelectButton = UIFactory.createButton(title: "График", color: .systemBlue)
        view.addSubview(scheduleSelectButton)
        scheduleSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(comSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        scheduleSelectButton.addTarget(self, action: #selector(openSchedule), for: .touchUpInside)
        
        // Кнопка загрузки шаблона
        let notificationsButton = UIFactory.createButton(title: "Уведомления", color: .systemBlue)
        view.addSubview(notificationsButton)
        notificationsButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(scheduleSelectButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        notificationsButton.addTarget(self, action: #selector(openNotifications), for: .touchUpInside)

        let templateButton = UIFactory.createButton(title: "Загрузить шаблон", color: .systemBlue)
        view.addSubview(templateButton)
        templateButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(notificationsButton.snp.bottom).inset(-8)
            make.height.equalTo(54)
        }
        templateButton.addTarget(self, action: #selector(loadTemplate), for: .touchUpInside)
        
        // Надпись о статусе шаблона
        let templateStatusLabel = UILabel()
        templateStatusLabel.text = "Шаблон не загружен"
        templateStatusLabel.textColor = .label
        templateStatusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        templateStatusLabel.textAlignment = .center
        view.addSubview(templateStatusLabel)
        templateStatusLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(templateButton.snp.bottom).offset(4)
        }
        
        // Сохраняем ссылку на label для обновления статуса
        self.templateStatusLabel = templateStatusLabel
        
        // Кнопка «Очистка кэша» — открывает экран с разбивкой и действиями
        let cacheButton = UIFactory.createButton(title: "Очистка кэша", color: .systemOrange)
        view.addSubview(cacheButton)
        cacheButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(templateStatusLabel.snp.bottom).offset(8)
            make.height.equalTo(54)
        }
        cacheButton.addTarget(self, action: #selector(openStorageCleanup), for: .touchUpInside)
        
        // Информация о размере кэша
        let cacheInfoLabel = UILabel()
        cacheInfoLabel.text = "Размер кэша: \(CacheManager.shared.getCacheSize())"
        cacheInfoLabel.textColor = .secondaryLabel
        cacheInfoLabel.font = .systemFont(ofSize: 12, weight: .regular)
        cacheInfoLabel.textAlignment = .center
        view.addSubview(cacheInfoLabel)
        cacheInfoLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(cacheButton.snp.bottom).offset(4)
        }
        
        // Сохраняем ссылку на label для обновления информации о кэше
        self.cacheInfoLabel = cacheInfoLabel
        
        // Кнопка создания резервной копии (левая) - с иконкой
        let backupButton = UIButton(type: .system)
        backupButton.layer.cornerRadius = 10
        backupButton.backgroundColor = .systemGreen
        backupButton.tintColor = .white
        let backupIcon = UIImage(systemName: "arrow.down.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        backupButton.setImage(backupIcon, for: .normal)
        view.addSubview(backupButton)
        backupButton.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.right.equalTo(view.snp.centerX).offset(-4)
            make.top.equalTo(cacheInfoLabel.snp.bottom).offset(12)
            make.height.equalTo(36)
        }
        backupButton.addTarget(self, action: #selector(createBackup), for: .touchUpInside)
        
        // Кнопка управления резервными копиями (правая) - с иконкой
        let manageBackupsButton = UIButton(type: .system)
        manageBackupsButton.layer.cornerRadius = 10
        manageBackupsButton.backgroundColor = .systemBlue
        manageBackupsButton.tintColor = .white
        let folderIcon = UIImage(systemName: "folder.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
        manageBackupsButton.setImage(folderIcon, for: .normal)
        view.addSubview(manageBackupsButton)
        manageBackupsButton.snp.makeConstraints { make in
            make.left.equalTo(view.snp.centerX).offset(4)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(cacheInfoLabel.snp.bottom).offset(12)
            make.height.equalTo(36)
        }
        manageBackupsButton.addTarget(self, action: #selector(manageBackups), for: .touchUpInside)
        
        let developerToolsButton = UIFactory.createButton(title: "Импорт бэкапа и журнал отладки", color: .systemTeal)
        view.addSubview(developerToolsButton)
        developerToolsButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(backupButton.snp.bottom).offset(12)
            make.height.equalTo(54)
        }
        developerToolsButton.addTarget(self, action: #selector(openDeveloperTools), for: .touchUpInside)
    }
    
    @objc private func openDeveloperTools() {
        let vc = DeveloperToolsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openOrganizations() {
        let vc = SettingsOrganizationsViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openObjects() {
        let vc = SettingsObjectsViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openPredstav() {
        let vc = SettingsPredstavViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openComissionPeople() {
        let vc = SettingsComissionPeopleViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openViolations() {
        let vc = SettingsViolationsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openSchedule() {
        let vc = SettingsScheduleViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openNotifications() {
        let vc = SettingsNotificationsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    // MARK: - Template Methods
    
    private func updateTemplateStatus() {
        if let filePath = UserDefaults.standard.string(forKey: "ShabPath") {
            let url = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: url.path) {
                templateStatusLabel.text = "Шаблон загружен"
                templateStatusLabel.textColor = .systemGreen
            } else {
                templateStatusLabel.text = "Шаблон не загружен"
                templateStatusLabel.textColor = .label
            }
        } else {
            templateStatusLabel.text = "Шаблон не загружен"
            templateStatusLabel.textColor = .label
        }
    }
    
    @objc private func loadTemplate() {
        let docxType = UTType(filenameExtension: "docx") ?? .item
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docxType], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        
        present(documentPicker, animated: true, completion: nil)
    }
    
    // MARK: - Cache Management
    
    @objc private func openStorageCleanup() {
        let vc = StorageCleanupViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func clearCache() {
        // Показываем предупреждение о влиянии очистки кэша
        // Используем правильный стиль в зависимости от устройства
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let alert = UIAlertController(
            title: "Очистка кэша",
            message: CacheManager.shared.getCacheImpactInfo(),
            preferredStyle: preferredStyle
        )
        
        // Действие очистки
        let clearAction = UIAlertAction(title: "Очистить", style: .destructive) { [weak self] _ in
            self?.performCacheClearing()
        }
        
        // Действие отмены
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(clearAction)
        alert.addAction(cancelAction)
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(alert, animated: true)
        }
    }
    
    private func performCacheClearing() {
        // Показываем индикатор загрузки
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let loadingAlert = UIAlertController(title: "Очистка кэша...", message: "Пожалуйста, подождите", preferredStyle: preferredStyle)
        
        // Настройка для iPad
        if let popover = loadingAlert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(loadingAlert, animated: true)
        }
        
        // Выполняем очистку в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = CacheManager.shared.clearAllCache()
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    // Показываем результат
                    let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
                    let resultAlert = UIAlertController(
                        title: result.success ? "Кэш очищен" : "Ошибка очистки",
                        message: result.message,
                        preferredStyle: preferredStyle
                    )
                    
                    let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                        self?.updateCacheInfo()
                    }
                    
                    resultAlert.addAction(okAction)
                    
                    // Настройка для iPad
                    if let popover = resultAlert.popoverPresentationController {
                        popover.sourceView = self?.view
                        popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    // Убеждаемся, что view загружен перед показом alert
                    if self?.view.window != nil {
                        self?.present(resultAlert, animated: true)
                    }
                }
            }
        }
    }
    
    private func updateCacheInfo() {
        cacheInfoLabel.text = "Размер кэша: \(CacheManager.shared.getCacheSize())"
    }
    
    // MARK: - Backup Methods
    @objc private func createBackup() {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let alert = UIAlertController(
            title: "Создание резервной копии",
            message: "Выберите тип резервной копии",
            preferredStyle: preferredStyle
        )
        
        alert.addAction(UIAlertAction(title: "📅 Бэкап на дату", style: .default) { [weak self] _ in
            self?.performDailyBackupCreation()
        })
        
        alert.addAction(UIAlertAction(title: "💾 Резервная копия", style: .default) { [weak self] _ in
            self?.performBackupCreation()
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(alert, animated: true)
        }
    }
    
    private func performDailyBackupCreation() {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let loadingAlert = UIAlertController(title: "Создание бэкапа на дату...", message: "Пожалуйста, подождите", preferredStyle: preferredStyle)
        
        // Настройка для iPad
        if let popover = loadingAlert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(loadingAlert, animated: true)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Создаем ежедневный бэкап на текущую дату
            let success = BackupManager.createBackup(type: .daily, targetDate: Date())
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
                    let resultAlert = UIAlertController(
                        title: success ? "Бэкап на дату создан" : "Ошибка создания",
                        message: success ? "Резервная копия успешно создана на текущую дату" : "Не удалось создать резервную копию",
                        preferredStyle: preferredStyle
                    )
                    
                    resultAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    // Настройка для iPad
                    if let popover = resultAlert.popoverPresentationController {
                        popover.sourceView = self?.view
                        popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    // Убеждаемся, что view загружен перед показом alert
                    if self?.view.window != nil {
                        self?.present(resultAlert, animated: true)
                    }
                }
            }
        }
    }
    
    private func performBackupCreation() {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let loadingAlert = UIAlertController(title: "Создание резервной копии...", message: "Пожалуйста, подождите", preferredStyle: preferredStyle)
        
        // Настройка для iPad
        if let popover = loadingAlert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(loadingAlert, animated: true)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Создаем обычный ручной бэкап
            let success = BackupManager.createBackup(type: .manual)
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
                    let resultAlert = UIAlertController(
                        title: success ? "Резервная копия создана" : "Ошибка создания",
                        message: success ? "Резервная копия успешно создана и сохранена на устройстве" : "Не удалось создать резервную копию",
                        preferredStyle: preferredStyle
                    )
                    
                    resultAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    
                    // Настройка для iPad
                    if let popover = resultAlert.popoverPresentationController {
                        popover.sourceView = self?.view
                        popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    // Убеждаемся, что view загружен перед показом alert
                    if self?.view.window != nil {
                        self?.present(resultAlert, animated: true)
                    }
                }
            }
        }
    }
    
    @objc private func manageBackups() {
        let allBackups = BackupManager.listBackups()
        _ = BackupManager.listBackups(type: .daily)
        let manualBackups = BackupManager.listBackups(type: .manual)
        
        if allBackups.isEmpty {
            let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
            let alert = UIAlertController(
                title: "Резервные копии",
                message: "Резервные копии не найдены. Создайте первую резервную копию.",
                preferredStyle: preferredStyle
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // Настройка для iPad
            if let popover = alert.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            // Убеждаемся, что view загружен перед показом alert
            if view.window != nil {
                present(alert, animated: true)
            }
            return
        }
        
        let alert = UIAlertController(
            title: "Управление резервными копиями",
            message: "Выберите действие",
            preferredStyle: .actionSheet
        )
        
        // Добавляем опцию восстановления по дате
        alert.addAction(UIAlertAction(
            title: "📅 Восстановить по дате",
            style: .default
        ) { [weak self] _ in
            self?.openBackupCalendar()
        })
        
        // Показываем обычные бэкапы (все, включая старые)
        if !manualBackups.isEmpty {
            alert.addAction(UIAlertAction(title: "─── Обычные бэкапы ───", style: .default, handler: nil))
            alert.actions.last?.isEnabled = false
            
            for backup in manualBackups {
                let action = UIAlertAction(
                    title: "\(backup.formattedDate) (\(backup.formattedSize))",
                    style: .default
                ) { [weak self] _ in
                    self?.showBackupOptions(backup: backup)
                }
                alert.addAction(action)
            }
        }
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        // Для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(alert, animated: true)
        }
    }
    
    private func showBackupOptions(backup: BackupInfo) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let alert = UIAlertController(
            title: "Резервная копия",
            message: "Дата: \(backup.formattedDate)\nРазмер: \(backup.formattedSize)",
            preferredStyle: preferredStyle
        )
        
        alert.addAction(UIAlertAction(title: "Восстановить (заменить)", style: .destructive) { [weak self] _ in
            self?.restoreBackup(backup: backup, replace: true)
        })
        
        alert.addAction(UIAlertAction(title: "Восстановить (объединить)", style: .default) { [weak self] _ in
            self?.restoreBackup(backup: backup, replace: false)
        })
        
        alert.addAction(UIAlertAction(title: "Поделиться", style: .default) { [weak self] _ in
            self?.shareBackup(backup: backup)
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(alert, animated: true)
        }
    }
    
    private func restoreBackup(backup: BackupInfo, replace: Bool) {
        let message = replace ? "Все текущие данные будут заменены данными из резервной копии. Продолжить?" : "Данные из резервной копии будут объединены с текущими данными. Продолжить?"
        
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let alert = UIAlertController(
            title: "Восстановление резервной копии",
            message: message,
            preferredStyle: preferredStyle
        )
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Восстановить", style: .destructive) { [weak self] _ in
            self?.performRestore(backup: backup, replace: replace)
        })
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(alert, animated: true)
        }
    }
    
    private func performRestore(backup: BackupInfo, replace: Bool) {
        let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
        let loadingAlert = UIAlertController(
            title: "Восстановление...",
            message: "Пожалуйста, подождите",
            preferredStyle: preferredStyle
        )
        
        // Настройка для iPad
        if let popover = loadingAlert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Убеждаемся, что view загружен перед показом alert
        if view.window != nil {
            present(loadingAlert, animated: true)
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let success = BackupManager.restoreBackup(from: backup.fileURL, replaceExisting: replace)
            
            DispatchQueue.main.async {
                loadingAlert.dismiss(animated: true) {
                    let preferredStyle: UIAlertController.Style = UIDevice.current.userInterfaceIdiom == .pad ? .alert : .alert
                    let resultAlert = UIAlertController(
                        title: success ? "Данные восстановлены" : "Ошибка восстановления",
                        message: success ? "Резервная копия успешно восстановлена" : "Не удалось восстановить резервную копию",
                        preferredStyle: preferredStyle
                    )
                    
                    resultAlert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                        if success {
                            // Обновляем данные в приложении
                            NotificationCenter.default.post(name: NSNotification.Name("DataRestored"), object: nil)
                        }
                    })
                    
                    // Настройка для iPad
                    if let popover = resultAlert.popoverPresentationController {
                        popover.sourceView = self?.view
                        popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    // Убеждаемся, что view загружен перед показом alert
                    if self?.view.window != nil {
                        self?.present(resultAlert, animated: true)
                    }
                }
            }
        }
    }
    
    private func shareBackup(backup: BackupInfo) {
        let activityVC = UIActivityViewController(activityItems: [backup.fileURL], applicationActivities: nil)
        
        // Для iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func openBackupCalendar() {
        let vc = BackupCalendarViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
}

// MARK: - UIDocumentPickerDelegate

extension SettingsTabViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }

        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(sourceURL.lastPathComponent)

        var success = false

        if sourceURL.startAccessingSecurityScopedResource() {
            success = true
        }

        defer {
            if success {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Файл шаблона скопирован в: \(destinationURL.path)")

            // Сохраняем путь только после успешного копирования
            UserDefaults.standard.set(destinationURL.path, forKey: "ShabPath")
            
            // Обновляем статус
            updateTemplateStatus()

        } catch {
            print("❌ Ошибка при копировании файла шаблона: \(error.localizedDescription)")
            // Удаляем старое значение, если копирование не удалось
            UserDefaults.standard.removeObject(forKey: "ShabPath")
            updateTemplateStatus()
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Отмена выбора документа шаблона")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
