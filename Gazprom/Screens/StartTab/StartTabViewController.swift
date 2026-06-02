//
//  StartTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import SnapKit

class StartTabViewController: UIViewController {
    
    private let viewModel: MainAKTViewModel
    private var timer: Timer?
    
    private lazy var welcomeAnimator = RandomWelcomeAnimator(hostViewProvider: { [weak self] in
        self?.view
    })
    
    private let dateTimeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24, weight: .light)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private var continueButton: UIButton?
    private var aktNumberLabel: UILabel?
    private var backupInfoLabel: UILabel?
    
    // Прогресс выполнения графика проверок
    private let inspectionsProgressView: UIProgressView = {
        let progress = UIProgressView(progressViewStyle: .default)
        progress.trackTintColor = .systemGray5
        progress.progressTintColor = .systemBlue
        progress.layer.cornerRadius = 4
        progress.clipsToBounds = true
        progress.setProgress(0.0, animated: false)
        return progress
    }()
    
    private let inspectionsProgressLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 1
        return label
    }()
    
    // Защита от повторных обновлений кнопки
    private var lastUpdateTime: Date?
    private let updateCooldown: TimeInterval = 0.5 // 0.5 секунды между обновлениями
    
    // Кэш для быстрого обновления кнопки
    private var cachedButtonState: (title: String, aktNumber: String?)?
    private var lastButtonUpdateTime: Date?
    
    // Индикатор загрузки
    private var loadingIndicator: UIView?
    
    // Режим отображения прогресса графика: false — весь период, true — только текущий месяц
    private var showCurrentMonthProgress: Bool = false
    
    // Режим редактирования
    var isEditingMode: Bool = false
    var editingAkt: AKT?
    
    // Флаг для предотвращения множественных вызовов setupNavigationBarAppearance
    private var navigationBarAppearanceSetup = false
    
    init(viewModel: MainAKTViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    private func updateInspectionsProgressUI() {
        let (done, plan, percent) = showCurrentMonthProgress 
            ? viewModel.getInspectionProgressCurrentMonth() 
            : viewModel.getInspectionProgress()
        inspectionsProgressView.setProgress(Float(percent), animated: true)
        let percentText = Int(round(percent * 100))
        let scopeText = showCurrentMonthProgress ? "за месяц" : "за весь период"
        let yearSuffix: String
        if let year = viewModel.getSelectedYear(), year > 0 {
            yearSuffix = " \(year) г."
        } else {
            yearSuffix = ""
        }
        if plan > 0 {
            inspectionsProgressLabel.text = "График проверок\(yearSuffix) \(scopeText): \(percentText)% (\(done)/\(plan))"
        } else {
            inspectionsProgressLabel.text = "График проверок\(yearSuffix) \(scopeText): план не задан (\(done)/0)"
        }
    }
    
    @objc private func toggleProgressScope() {
        showCurrentMonthProgress.toggle()
        updateInspectionsProgressUI()
    }
    
    @objc private func openScheduleScreen(_ gesture: UILongPressGestureRecognizer) {
        // Запускаем только один раз на начале удержания
        if gesture.state == .began {
            setupBackButtonForChildScreen()
            let scheduleVC = SettingsScheduleViewController(model: viewModel)
            navigationController?.pushViewController(scheduleVC, animated: true)
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupBackButtonForChildScreen() {
        // Устанавливаем кнопку "назад" с текстом "Главная" перед push
        let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Главная"
        navigationItem.title = "Главная"
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔵 [START] viewWillAppear вызван")
        tabBarController?.title = "Главная"
        navigationItem.title = "Главная"
        
        // Явно показываем TabBar, чтобы она не пропадала после выбора раздела
        tabBarController?.tabBar.isHidden = false
        tabBarController?.tabBar.alpha = 1.0
        
        // Устанавливаем текст кнопки "назад" для всех дочерних экранов
        let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Главная"
        
        // Настройка navigation bar с blur эффектом
        navigationBarAppearanceSetup = false // Сбрасываем флаг при появлении экрана
        setupNavigationBarAppearance()
        // НЕ вызываем setupTabBarAppearance() - используем глобальные настройки из TabBarViewController, как в HistoryTabViewController
        
        startTimer()
        
        // Оптимизированная загрузка данных в фоновом потоке
        loadDataAsync()
        
        // Обновляем кнопку "Продолжить заполнение" при возврате на экран
        updateContinueButton()
        updateBackupInfo()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [START] viewDidAppear вызван")
        
        // Явно показываем TabBar, чтобы она не пропадала после выбора раздела
        tabBarController?.tabBar.isHidden = false
        tabBarController?.tabBar.alpha = 1.0
        
        // Повторно применяем настройки navigation bar для надежности
        setupNavigationBarAppearance()
        // НЕ вызываем setupTabBarAppearance() - используем глобальные настройки из TabBarViewController, как в HistoryTabViewController
        welcomeAnimator.startIfNeeded()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Убираем множественные вызовы setupNavigationBarAppearance
        // Настройки уже применены в viewWillAppear и viewDidAppear
    }
    
    private func setupNavigationBarAppearance() {
        // Предотвращаем множественные вызовы
        guard !navigationBarAppearanceSetup else {
            return
        }
        
        print("🔵 [START] setupNavigationBarAppearance вызван")
        guard let navBar = navigationController?.navigationBar else {
            print("❌ [START] navigationController?.navigationBar == nil")
            return
        }
        
        navigationBarAppearanceSetup = true
        
        print("🔵 [START] Настройка navigation bar для прозрачности")
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        print("   ✅ configureWithTransparentBackground применен")
        
        // Убираем blur эффект для полной прозрачности (как в истории)
        appearance.backgroundEffect = nil
        print("   ✅ backgroundEffect = nil")
        
        // Полностью прозрачный фон
        appearance.backgroundColor = .clear
        print("   ✅ appearance.backgroundColor = .clear")
        
        // Настройка текста заголовка с адаптацией к теме
        // Адаптивный цвет: черный в светлой теме, белый в темной
        let adaptiveTitleColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? .black : .white
        }
        appearance.titleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        print("   ✅ titleTextAttributes установлен")
        
        // Применяем напрямую к navigation bar
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.prefersLargeTitles = false
        navBar.isTranslucent = true
        print("   ✅ appearance применен к navBar")
        
        // Логируем состояние ДО установки
        print("   📊 Состояние ДО установки прозрачности:")
        print("      - barTintColor: \(String(describing: navBar.barTintColor))")
        print("      - backgroundColor: \(String(describing: navBar.backgroundColor))")
        
        // Убеждаемся, что navigation bar полностью прозрачный (как в истории)
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        // Адаптивный цвет для кнопок навигации
        navBar.tintColor = adaptiveTitleColor
        
        // Пробуем установить nil вместо .clear
        navBar.barTintColor = nil
        navBar.backgroundColor = nil
        
        // Если nil не работает, пробуем .clear
        if navBar.barTintColor != nil {
            print("   ⚠️ barTintColor не nil после установки nil, пробуем .clear")
            navBar.barTintColor = .clear
        }
        if navBar.backgroundColor != nil {
            print("   ⚠️ backgroundColor не nil после установки nil, пробуем .clear")
            navBar.backgroundColor = .clear
        }
        
        print("   ✅ setBackgroundImage, shadowImage, barTintColor, backgroundColor установлены")
        
        // Логируем финальное состояние
        print("   📊 Финальное состояние navigation bar:")
        print("      - isTranslucent: \(navBar.isTranslucent)")
        print("      - barTintColor: \(String(describing: navBar.barTintColor))")
        print("      - backgroundColor: \(String(describing: navBar.backgroundColor))")
        print("      - standardAppearance.backgroundColor: \(String(describing: navBar.standardAppearance.backgroundColor))")
        print("      - standardAppearance.backgroundEffect: \(String(describing: navBar.standardAppearance.backgroundEffect))")
        
        // Дополнительная проверка - пробуем принудительно установить прозрачность через layer
        print("   🔍 Проверка layer navigation bar:")
        print("      - navBar.layer.backgroundColor ДО: \(String(describing: navBar.layer.backgroundColor))")
        navBar.layer.backgroundColor = UIColor.clear.cgColor
        print("      - navBar.layer.backgroundColor ПОСЛЕ установки clear.cgColor: \(String(describing: navBar.layer.backgroundColor))")
        
        // Также устанавливаем для всех sublayers (только фон, не трогаем opacity чтобы заголовки были видимы)
        if let sublayers = navBar.layer.sublayers {
            print("      - Количество sublayers: \(sublayers.count)")
            for (index, sublayer) in sublayers.enumerated() {
                print("         sublayer[\(index)].backgroundColor ДО: \(String(describing: sublayer.backgroundColor))")
                sublayer.backgroundColor = UIColor.clear.cgColor
                // Явно устанавливаем opacity = 1.0 для гарантированной видимости заголовков
                sublayer.opacity = 1.0
                print("         sublayer[\(index)].backgroundColor ПОСЛЕ: \(String(describing: sublayer.backgroundColor))")
                print("         sublayer[\(index)].opacity: \(sublayer.opacity)")
            }
            print("      - Все sublayers установлены в clear.cgColor с opacity = 1.0 для видимости заголовков")
        }
        
        // Явно показываем все элементы NavigationBar (включая заголовки)
        for subview in navBar.subviews {
            subview.isHidden = false
            subview.alpha = 1.0
        }
        
        // Дополнительная проверка через небольшой delay, чтобы увидеть, не перезаписывается ли
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("   🔍 [START] Проверка layer navigation bar ПОСЛЕ 0.1 сек:")
            print("      - navBar.layer.backgroundColor: \(String(describing: navBar.layer.backgroundColor))")
            if let sublayers = navBar.layer.sublayers {
                for (index, sublayer) in sublayers.enumerated() {
                    print("         sublayer[\(index)].backgroundColor: \(String(describing: sublayer.backgroundColor))")
                }
            }
        }
        
        print("✅ [START] setupNavigationBarAppearance завершен")
    }
    
    private func setupTabBarAppearance() {
        print("🔵 [START] setupTabBarAppearance вызван")
        guard let tabBar = tabBarController?.tabBar else {
            print("❌ [START] tabBarController?.tabBar == nil")
            return
        }
        
        print("🔵 [START] Настройка tab bar для прозрачности")
        
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
        
        // Логируем состояние ДО установки
        print("   📊 Состояние ДО установки прозрачности:")
        print("      - barTintColor: \(String(describing: tabBar.barTintColor))")
        print("      - backgroundColor: \(String(describing: tabBar.backgroundColor))")
        
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.isTranslucent = true
        
        // Пробуем установить nil вместо .clear
        tabBar.barTintColor = nil
        tabBar.backgroundColor = nil
        
        // Если nil не работает, пробуем .clear
        if tabBar.barTintColor != nil {
            print("   ⚠️ barTintColor не nil после установки nil, пробуем .clear")
            tabBar.barTintColor = .clear
        }
        if tabBar.backgroundColor != nil {
            print("   ⚠️ backgroundColor не nil после установки nil, пробуем .clear")
            tabBar.backgroundColor = .clear
        }
        
        print("   ✅ Tab bar настроен для прозрачности")
        print("   📊 Финальное состояние tab bar:")
        print("      - isTranslucent: \(tabBar.isTranslucent)")
        print("      - barTintColor: \(String(describing: tabBar.barTintColor))")
        print("      - backgroundColor: \(String(describing: tabBar.backgroundColor))")
        print("      - standardAppearance.backgroundColor: \(String(describing: tabBar.standardAppearance.backgroundColor))")
        print("      - standardAppearance.backgroundEffect: \(String(describing: tabBar.standardAppearance.backgroundEffect))")
        
        // Дополнительная проверка - пробуем принудительно установить прозрачность через layer
        print("   🔍 Проверка layer tab bar:")
        print("      - tabBar.layer.backgroundColor ДО: \(String(describing: tabBar.layer.backgroundColor))")
        tabBar.layer.backgroundColor = UIColor.clear.cgColor
        print("      - tabBar.layer.backgroundColor ПОСЛЕ установки clear.cgColor: \(String(describing: tabBar.layer.backgroundColor))")
        
        // Также устанавливаем для всех sublayers
        if let sublayers = tabBar.layer.sublayers {
            print("      - Количество sublayers: \(sublayers.count)")
            for (index, sublayer) in sublayers.enumerated() {
                print("         sublayer[\(index)].backgroundColor ДО: \(String(describing: sublayer.backgroundColor))")
                sublayer.backgroundColor = UIColor.clear.cgColor
                print("         sublayer[\(index)].backgroundColor ПОСЛЕ: \(String(describing: sublayer.backgroundColor))")
            }
            print("      - Все sublayers установлены в clear.cgColor")
        }
        
        // Дополнительная проверка через небольшой delay, чтобы увидеть, не перезаписывается ли
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("   🔍 [START] Проверка layer tab bar ПОСЛЕ 0.1 сек:")
            print("      - tabBar.layer.backgroundColor: \(String(describing: tabBar.layer.backgroundColor))")
            if let sublayers = tabBar.layer.sublayers {
                for (index, sublayer) in sublayers.enumerated() {
                    print("         sublayer[\(index)].backgroundColor: \(String(describing: sublayer.backgroundColor))")
                }
            }
        }
        
        print("✅ [START] setupTabBarAppearance завершен")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        // Устанавливаем кнопку "назад" с текстом "Главная" для всех дочерних экранов
        let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Главная"
        navigationItem.backButtonDisplayMode = .default
        setupUI()
        
        // Подписываемся на обновления кнопки "Продолжить"
        viewModel.continueButtonUpdateBinding = { [weak self] in
            self?.updateContinueButton()
        }
        
        // Подписываемся на уведомления об изменении фильтров в разделе графиков
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReportFiltersChanged),
            name: .reportFiltersChanged,
            object: nil
        )
    }

    private func setupUI() {
        
        // Добавляем лейбл с датой и временем
        view.addSubview(dateTimeLabel)
        dateTimeLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.left.right.equalToSuperview().inset(16)
        }
        updateDateTime()
        
        // Создаем контейнер для прогресса графика проверок с увеличенной зоной тапа
        let progressContainer = UIView()
        progressContainer.backgroundColor = .clear
        view.addSubview(progressContainer)
        progressContainer.snp.makeConstraints { make in
            make.top.equalTo(dateTimeLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(16)
        }
        
        // Добавляем прогресс-бар в контейнер
        progressContainer.addSubview(inspectionsProgressView)
        inspectionsProgressView.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8) // Верхний padding для зоны тапа
            make.left.right.equalToSuperview()
            make.height.equalTo(8)
        }
        
        // Добавляем лейбл в контейнер
        progressContainer.addSubview(inspectionsProgressLabel)
        inspectionsProgressLabel.snp.makeConstraints { make in
            make.top.equalTo(inspectionsProgressView.snp.bottom).offset(6)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview().inset(8) // Нижний padding для зоны тапа
        }
        
        // Делаем весь контейнер кликабельным для переключения режима
        progressContainer.isUserInteractionEnabled = true
        let progressTap = UITapGestureRecognizer(target: self, action: #selector(toggleProgressScope))
        progressContainer.addGestureRecognizer(progressTap)
        
        // Долгое нажатие на контейнер — открыть экран "График проверок"
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(openScheduleScreen(_:)))
        longPress.minimumPressDuration = 0.5
        progressContainer.addGestureRecognizer(longPress)
        
        updateInspectionsProgressUI()
        
        let fioLabel = UILabel()
        fioLabel.text = "Powered by Шелудько Руслан Игоревич"
        fioLabel.textColor = .systemGray
        fioLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        view.addSubview(fioLabel)
        fioLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        
        
        // Добавляем информацию о последнем резервном копировании
        let backupInfoLabel = UILabel()
        backupInfoLabel.text = getLastBackupInfo()
        backupInfoLabel.textAlignment = .center
        backupInfoLabel.textColor = .systemGreen
        backupInfoLabel.font = .systemFont(ofSize: 12, weight: .regular)
        backupInfoLabel.numberOfLines = 0
        view.addSubview(backupInfoLabel)
        self.backupInfoLabel = backupInfoLabel
        backupInfoLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(fioLabel.snp.top).offset(-8)
        }
        
        // Кнопка проверки приложения (диагностика)
        let diagnosticButton = UIFactory.createButton(title: "Проверка приложения", color: .systemOrange)
        view.addSubview(diagnosticButton)
        diagnosticButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.bottom.equalTo(backupInfoLabel.snp.top).offset(-8)
        }
        diagnosticButton.addTarget(self, action: #selector(runDiagnostic), for: .touchUpInside)

        // Кнопка экспорта отладочного лога
        let exportLogButton = UIFactory.createButton(title: "Экспорт отладочного лога", color: .systemGray)
        view.addSubview(exportLogButton)
        exportLogButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.bottom.equalTo(diagnosticButton.snp.top).offset(-8)
        }
        exportLogButton.addTarget(self, action: #selector(exportDebugLog), for: .touchUpInside)
        
        // Добавляем информацию о версии приложения (кликабельная надпись)
        let versionLabel = UILabel()
        versionLabel.text = getAppVersion()
        versionLabel.textColor = .systemBlue
        versionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 0
        versionLabel.isUserInteractionEnabled = true
        
        // Добавляем жест нажатия
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(versionLabelTapped))
        versionLabel.addGestureRecognizer(tapGesture)
        
        view.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(exportLogButton.snp.top).offset(-4)
        }
    
        let newButton = createButton(title: "Новый АКТ", color: .systemGreen)
        view.addSubview(newButton)
        newButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.centerY).offset(-8)
        }
        newButton.addTarget(self, action: #selector(createNew), for: .touchUpInside)
        
        
        continueButton = createContinueButton()
        view.addSubview(continueButton!)
        continueButton!.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.centerY).offset(8)
        }
        continueButton!.addTarget(self, action: #selector(nextAct), for: .touchUpInside)
        
        // Добавляем лейбл с номером акта под кнопкой "Продолжить"
        aktNumberLabel = createAktNumberLabel()
        view.addSubview(aktNumberLabel!)
        aktNumberLabel!.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(continueButton!.snp.bottom).offset(8)
        }
    }
    
    
    private func createButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        return button
    }
    
    private func createContinueButton() -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        
        if let draftInfo = viewModel.getDraftInfo() {
            let violationsText = draftInfo.violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(draftInfo.violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
        } else {
            button.setTitle("Продолжить заполнение", for: .normal)
        }
        
        return button
    }
    
    private func createAktNumberLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        label.numberOfLines = 1
        return label
    }
    
    private func updateContinueButton() {
        guard continueButton != nil else { return }
        
        // Проверяем cooldown для предотвращения частых обновлений
        if let lastUpdate = lastUpdateTime,
           Date().timeIntervalSince(lastUpdate) < updateCooldown {
            return
        }
        
        lastUpdateTime = Date()
        
        // Оптимизируем обновление UI - делаем это в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Подготавливаем данные в фоновом потоке
            let draftInfo = self.viewModel.getDraftInfo()
            let lastAkt = self.viewModel.getLastAktForContinue()
            
            // Обновляем UI в главном потоке
            DispatchQueue.main.async {
                self.updateButtonUI(draftInfo: draftInfo, lastAkt: lastAkt)
            }
        }
    }
    
    
    private func updateButtonUI(draftInfo: (step: AKTCreationStep, violationsCount: Int)?, lastAkt: AKT?) {
        guard let button = continueButton else { return }
        
        // Проверяем кэш для быстрого обновления
        if let cachedState = cachedButtonState,
           let lastUpdate = lastButtonUpdateTime,
           Date().timeIntervalSince(lastUpdate) < 2.0 { // Кэш действителен 2 секунды
            button.setTitle(cachedState.title, for: .normal)
            updateAktNumberLabel(cachedState.aktNumber)
            button.layoutIfNeeded()
            return
        }
        
        var newTitle = "Продолжить заполнение"
        var newAktNumber: String? = nil
        
        // Проверяем наличие черновика
        if let draftInfo = draftInfo {
            let violationsText = draftInfo.violationsCount == 1 ? "нарушение" : "нарушений"
            newTitle = "Продолжить заполнение\n(\(draftInfo.violationsCount) \(violationsText))"
            
            // Получаем номер акта из черновика
            if let draft = viewModel.loadDraft(), !draft.aktNumber.isEmpty {
                newAktNumber = draft.aktNumber
            }
        } else if let lastAkt = lastAkt {
            let violationsCount = lastAkt.violations.count
            let violationsText = violationsCount == 1 ? "нарушение" : "нарушений"
            newTitle = "Продолжить заполнение\n(\(violationsCount) \(violationsText))"
            
            // Проверяем, находится ли акт в режиме редактирования
            let isEditable = DataFlowAKT.getEditableAKT() != nil
            if isEditable {
                newAktNumber = "\(lastAkt.number) (Редактирование)"
            } else {
                newAktNumber = lastAkt.number
            }
        }
        
        // Обновляем UI
        button.setTitle(newTitle, for: .normal)
        button.titleLabel?.numberOfLines = newTitle.contains("\n") ? 2 : 1
        button.titleLabel?.textAlignment = .center
        updateAktNumberLabel(newAktNumber)
        
        // Сохраняем в кэш
        cachedButtonState = (newTitle, newAktNumber)
        lastButtonUpdateTime = Date()
        
        // Принудительно обновляем отображение кнопки
        button.layoutIfNeeded()
    }
    
    
    private func updateAktNumberLabel(_ aktNumber: String?) {
        guard let label = aktNumberLabel else { return }
        
        if let number = aktNumber {
            // Убираем "(Редактирование)" из номера если оно есть
            let cleanNumber = number.replacingOccurrences(of: " (Редактирование)", with: "")
            label.text = "АКТ №\(cleanNumber)"
            label.isHidden = false
        } else {
            label.text = ""
            label.isHidden = true
        }
    }
    
    @objc private func createNew() {
        // Показываем индикатор загрузки
        showLoadingIndicator(message: "Подготовка нового акта...")
        
        // Очищаем последний открытый АКТ при создании нового (это означает, что последним делаем новый акт)
        viewModel.clearLastOpenedAkt()
        
        // Очищаем редактируемый акт при создании нового
        DataFlowAKT.deleteEditableAKT()
        
        // ВАЖНО: Очищаем templateModel перед созданием нового акта
        // Это предотвращает копирование данных (нарушений, представителей и т.д.) из предыдущего акта
        viewModel.templateModel.reset()
        print("✅ [CREATE_NEW] templateModel очищен")
        
        // ВАЖНО: Удаляем черновик перед созданием нового акта
        // Это предотвращает загрузку старых данных из черновика
        viewModel.deleteDraft()
        print("✅ [CREATE_NEW] Черновик удален")
        
        // Небольшая задержка для показа индикатора загрузки
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.hideLoadingIndicator()
            self?.setupBackButtonForChildScreen()
            let vc = DateAndNumberAktViewController(viewModel: self?.viewModel ?? MainAKTViewModel())
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    
    
    
    @objc private func nextAct() {
        // Показываем индикатор загрузки
        showLoadingIndicator(message: "Загрузка данных...")
        
        // Небольшая задержка для показа индикатора
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            
            if let draft = self.viewModel.loadDraft() {
                // ВАРИАНТ 1: Преобразуем черновик в реальный AKT и используем единый сценарий редактирования
                self.hideLoadingIndicator()
                print("🔄 [CONTINUE] Преобразуем черновик в реальный AKT...")
                
                // Проверяем, есть ли минимальные данные для создания акта
                guard !draft.aktNumber.isEmpty else {
                    // Если нет номера, переходим к первому шагу создания
                    self.setupBackButtonForChildScreen()
                    let vc = DateAndNumberAktViewController(viewModel: self.viewModel)
                    self.navigationController?.pushViewController(vc, animated: true)
                    return
                }
                
                // Преобразуем черновик в реальный AKT
                if let realAkt = self.convertDraftToRealAkt(draft) {
                    // Сохраняем акт в историю
                    self.viewModel.addNewAktToArray(realAkt)
                    print("✅ [CONTINUE] Черновик преобразован в реальный AKT №\(realAkt.number) и сохранен в историю")
                    
                    // Удаляем черновик, так как теперь у нас есть реальный акт
                    self.viewModel.deleteDraft()
                    print("✅ [CONTINUE] Черновик удален")
                    
                    // Используем ту же логику, что и при открытии акта в истории
                    self.openAktForEditing(realAkt)
                } else {
                    // Если не удалось преобразовать, показываем ошибку
                    let alert = UIAlertController(title: "Ошибка!", message: "Не удалось загрузить черновик", preferredStyle: .alert)
                    let ok = UIAlertAction(title: "OK", style: .cancel)
                    alert.addAction(ok)
                    self.present(alert, animated: true)
                }
            } else if let lastAkt = self.viewModel.getLastAktForContinue() {
                // Для существующего акта используем ту же логику, что и при открытии акта в истории
                self.hideLoadingIndicator()
                self.openAktForEditing(lastAkt)
            } else {
                self.hideLoadingIndicator()
                let alert = UIAlertController(title: "Ошибка!", message: "Нет сохраненного прогресса для продолжения", preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .cancel)
                alert.addAction(ok)
                self.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Универсальный метод для открытия акта (используется и в истории, и при продолжении заполнения)
    
    /// Открывает акт для редактирования используя ту же логику, что и при открытии акта в истории
    private func openAktForEditing(_ akt: AKT) {
        // ИСПРАВЛЕНИЕ: Загружаем актуальный акт из файла по ID, чтобы получить свежие данные
        // Это исправляет проблему, когда дата предоставления отчета не обновляется в форме
        let allAkts = DataFlowAKT.loadArr()
        let actualAkt = allAkts.first(where: { $0.id == akt.id }) ?? akt
        
        print("🔄 [CONTINUE] НАЧАЛО РЕДАКТИРОВАНИЯ АКТА")
        print("   📋 Номер акта: \(actualAkt.number)")
        print("   📅 Дата проверки: \(actualAkt.date)")
        print("   📅 Дата предоставления отчета: \(actualAkt.actPredostavlenDate)")
        print("   🏢 Организация: \(actualAkt.organization.title)")
        print("   👥 Количество представителей: \(actualAkt.predstavitelyComission.count)")
        
        // ИСПРАВЛЕНИЕ: Проверяем по ID, а не по номеру, чтобы избежать конфликтов
        // Приоритет ID над номером для правильной синхронизации изменений
        print("   🔍 Проверяем существующий редактируемый акт...")
        if let existingEditableAkt = DataFlowAKT.getEditableAKT() {
            // Сначала проверяем по ID (это правильный способ)
            if existingEditableAkt.akt.id == actualAkt.id {
                print("   ✅ Редактируемый акт уже существует с тем же ID")
                print("   🔄 Используем существующий редактируемый акт (изменения сохраняются)")
                
                // Используем существующий редактируемый акт - изменения уже сохранены
                print("   🔄 Запускаем редактирование существующего акта...")
                viewModel.startRealtimeEditing(existingEditableAkt.akt)
                print("   ✅ Редактирование запущено")
            } else if existingEditableAkt.akt.number == actualAkt.number {
                // Если номер совпадает, но ID разный - это конфликт
                // Заменяем редактируемый акт на актуальный из истории
                print("   ⚠️ Обнаружен конфликт: редактируемый акт с номером \(actualAkt.number), но другим ID")
                print("   🔄 Заменяем редактируемый акт на актуальный из истории...")
                
                // Заменяем редактируемый акт на актуальный из истории
                _ = DataFlowAKT.createEditableAKT(from: actualAkt)
                print("   ✅ Редактируемый акт заменен на актуальный")
                
                // Запускаем редактирование актуального акта
                print("   🔄 Запускаем редактирование актуального акта...")
                viewModel.startRealtimeEditing(actualAkt)
                print("   ✅ Редактирование запущено")
            } else {
                // Редактируемый акт существует, но для другого акта
                // Заменяем его на новый
                print("   ℹ️ Редактируемый акт существует для другого акта (№\(existingEditableAkt.akt.number))")
                print("   🔄 Заменяем на акт №\(actualAkt.number)...")
                
                _ = DataFlowAKT.createEditableAKT(from: actualAkt)
                print("   ✅ Редактируемый акт создан")
                
                viewModel.startRealtimeEditing(actualAkt)
                print("   ✅ Редактирование запущено")
            }
        } else {
            // Редактируемого акта нет - создаем новый
            print("   🔄 Создаем новый редактируемый акт в системе реального времени...")
            _ = DataFlowAKT.createEditableAKT(from: actualAkt)
            print("   ✅ Редактируемый акт создан")
            
            // Запускаем редактирование в системе реального времени
            print("   🔄 Запускаем редактирование в системе реального времени...")
            viewModel.startRealtimeEditing(actualAkt)
            print("   ✅ Редактирование запущено")
        }
        
        // Сохраняем акт как последний открытый, чтобы кнопка "Продолжить заполнение" открывала тот же файл
        viewModel.setLastOpenedAkt(actualAkt)
        print("   💾 Сохранен акт №\(actualAkt.number) как последний открытый")
        
        // Используем тот же метод editAkt(), что и при открытии из истории
        print("   🔄 Переходим к экрану редактирования...")
        isEditingMode = true
        editingAkt = actualAkt
        // Вызываем метод editAkt() для перехода к редактированию
        editAkt(actualAkt)
        print("✅ [CONTINUE] Редактирование акта запущено")
    }
    
    // MARK: - Short Akt Detection
    
    private func isShortAkt(_ akt: AKT) -> Bool {
        return akt.isShortFormat
    }
    
    // MARK: - Continue Short Akt from Start
    
    private func continueShortAktFromStart(_ akt: AKT) {
        print("🔄 [START_TAB] continueShortAktFromStart: Начинаем редактирование сокращенного акта №\(akt.number)")
        
        // Сохраняем акт как последний открытый для продолжения заполнения
        viewModel.setLastOpenedAkt(akt)
        
        // Открываем тот же редактор, что и в истории при нажатии на сокращенный акт
        let form = ShortAktFormViewController(viewModel: viewModel, editingAkt: akt)
        form.onSaveCompletion = { [weak self] in
            // Обновляем кнопку "Продолжить" после сохранения
            DispatchQueue.main.async {
                self?.updateContinueButton()
            }
        }
        let nav = UINavigationController(rootViewController: form)
        nav.modalPresentationStyle = UIModalPresentationStyle.formSheet
        present(nav, animated: true)
    }
    
    private func continueToViolationsFromAkt(_ akt: AKT) {
        // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
        // Если редактируемый акт существует, используем его данные вместо данных из истории
        var aktToUse = akt
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == akt.number {
            print("🔄 [START_TAB] continueToViolationsFromAkt: Найден редактируемый акт с номером \(akt.number), используем его данные")
            print("   👥 Количество членов комиссии в редактируемом акте: \(editableAkt.akt.comission.count)")
            print("   👥 Количество членов комиссии в акте из истории: \(akt.comission.count)")
            aktToUse = editableAkt.akt
        } else {
            print("🔄 [START_TAB] continueToViolationsFromAkt: Редактируемый акт не найден, создаем новый из акта №\(akt.number)")
            // Создаем редактируемый акт из существующего
            viewModel.editExistingAkt(aktToUse)
        }
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(aktToUse)
        
        // Сразу переходим к нарушениям для редактирования (используем актуальные данные)
        let violationsVC = NewViolationViewController(
            viewModel: viewModel,
            comissionPeople: aktToUse.comission,
            date: aktToUse.date,
            aktNumber: aktToUse.number,
            organizations: [aktToUse.organization],
            objectCheck: aktToUse.objectsCheck,
            violations: aktToUse.violations,
            akt: aktToUse,
            isEditingMode: true
        )
        
        // Создаем кастомную кнопку "назад" с иконкой стрелки и текстом ДО push
        let backButton = UIButton(type: .system)
        backButton.setTitle("Главная", for: .normal)
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.addTarget(self, action: #selector(self.customBackAction), for: .touchUpInside)
        
        // Настраиваем расположение изображения слева от текста (iOS 15+)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.imagePlacement = .leading
            config.imagePadding = 4
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -8, bottom: 0, trailing: 8)
            backButton.configuration = config
        } else {
            backButton.semanticContentAttribute = .forceLeftToRight
            backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
            backButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
        }
        
        backButton.sizeToFit()
        
        let customBackButtonWithTitle = UIBarButtonItem(customView: backButton)
        
        // Устанавливаем кнопку на созданном контроллере ДО push, чтобы она сразу появилась
        violationsVC.navigationItem.leftBarButtonItem = customBackButtonWithTitle
        violationsVC.navigationItem.hidesBackButton = true
        
        navigationController?.pushViewController(violationsVC, animated: true)
    }
    
    private func editAktWithNewSystem(_ akt: AKT) {
        // Создаем редактируемый акт из существующего
        viewModel.editExistingAkt(akt)
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(akt)
        
        // Определяем шаг, с которого начинать редактирование
        let startStep = determineStartStep(for: akt)
        
        // Переходим к соответствующему экрану редактирования
        navigateToEditStep(startStep, akt: akt)
    }
    
    func editAkt(_ akt: AKT) {
        // Очищаем черновик при редактировании акта
        viewModel.deleteDraft()
        
        // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
        // Если редактируемый акт существует, используем его данные вместо данных из истории
        var aktToUse = akt
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == akt.number {
            print("🔄 [EDIT_AKT] Найден редактируемый акт с номером \(akt.number), используем его данные")
            print("   🆔 ID редактируемого акта: \(editableAkt.akt.id)")
            print("   🆔 ID переданного акта: \(akt.id)")
            aktToUse = editableAkt.akt
        } else {
            print("🔄 [EDIT_AKT] Редактируемый акт не найден, создаем новый из акта №\(akt.number)")
            // Создаем редактируемый акт из существующего
            viewModel.editExistingAkt(aktToUse)
        }
        
        // Сохраняем акт как последний открытый (это означает, что последним открывали из истории)
        viewModel.setLastOpenedAkt(aktToUse)
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(aktToUse)
        
        // Определяем шаг, с которого начинать редактирование
        let startStep = determineStartStep(for: aktToUse)
        
        // Переходим к соответствующему экрану редактирования
        navigateToEditStep(startStep, akt: aktToUse)
    }
    
    private func loadAktToTemplate(_ akt: AKT) {
        // Очищаем текущий template
        viewModel.templateModel.reset()
        
        // ПРИОРИТЕТ 1: Загружаем данные из редактируемого акта (если он существует)
        let sourceAkt: AKT
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == akt.number {
            print("🔄 [LOAD_TEMPLATE] Используем данные из редактируемого акта")
            print("   🆔 ID редактируемого акта: \(editableAkt.akt.id)")
            print("   🆔 ID переданного акта: \(akt.id)")
            sourceAkt = editableAkt.akt
            print("   👥 Количество представителей: \(sourceAkt.predstavitelyComission.count)")
            print("   📋 Количество нарушений: \(sourceAkt.violations.count)")
        } else {
            print("🔄 [LOAD_TEMPLATE] Используем данные из переданного акта")
            sourceAkt = akt
            print("   👥 Количество представителей: \(sourceAkt.predstavitelyComission.count)")
            print("   📋 Количество нарушений: \(sourceAkt.violations.count)")
        }
        
        // Загружаем данные из актуального акта
        viewModel.templateModel.date = sourceAkt.date
        viewModel.templateModel.aktNumber = sourceAkt.number
        viewModel.templateModel.comissionPeople = sourceAkt.comission
        viewModel.templateModel.organizations = [sourceAkt.organization]
        viewModel.templateModel.objectCheck = sourceAkt.objectsCheck
        viewModel.templateModel.violations = sourceAkt.violations
        viewModel.templateModel.descripUser = sourceAkt.description
        viewModel.templateModel.predstavitely = sourceAkt.predstavitelyComission
        viewModel.templateModel.ustranenDatePicker = sourceAkt.actustranenDate
        viewModel.templateModel.predostavlenDatePicker = sourceAkt.actPredostavlenDate
        viewModel.templateModel.utverzdenDatePicker = sourceAkt.actUtverzdenDate
        
        print("✅ [LOAD_TEMPLATE] Данные загружены в templateModel")
    }
    
    private func determineStartStep(for akt: AKT) -> AKTCreationStep {
        // Определяем с какого шага начинать редактирование
        // Начинаем с нарушений, чтобы пользователь мог сразу работать с нарушениями
        return .violations
    }
    
    private func navigateToEditStep(_ step: AKTCreationStep, akt: AKT) {
        let targetVC = createEditViewControllerForStep(step, akt: akt)
        
        if let navigationController = navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep, akt: AKT) -> UIViewController {
        // ПРИОРИТЕТ 1: Используем данные из редактируемого акта (если он существует)
        let sourceAkt: AKT
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == akt.number {
            print("🔄 [CREATE_VC] Используем данные из редактируемого акта")
            print("   🆔 ID редактируемого акта: \(editableAkt.akt.id)")
            print("   🆔 ID переданного акта: \(akt.id)")
            sourceAkt = editableAkt.akt
            print("   👥 Количество представителей: \(sourceAkt.predstavitelyComission.count)")
            print("   📋 Количество нарушений: \(sourceAkt.violations.count)")
        } else {
            print("🔄 [CREATE_VC] Используем данные из переданного акта")
            sourceAkt = akt
            print("   👥 Количество представителей: \(sourceAkt.predstavitelyComission.count)")
            print("   📋 Количество нарушений: \(sourceAkt.violations.count)")
        }
        
        // В режиме редактирования всегда передаем isEditingMode: true
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: viewModel, akt: sourceAkt, isEditingMode: true)
        case .organizations:
            return OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: sourceAkt.comission,
                date: sourceAkt.date,
                aktNumber: sourceAkt.number,
                act: sourceAkt,
                isEditingMode: true
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: sourceAkt.comission,
                date: sourceAkt.date,
                aktNumber: sourceAkt.number,
                organizations: [sourceAkt.organization],
                akt: sourceAkt,
                isEditingMode: true
            )
        case .violations:
            return NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: sourceAkt.comission,
                date: sourceAkt.date,
                aktNumber: sourceAkt.number,
                organizations: [sourceAkt.organization],
                objectCheck: sourceAkt.objectsCheck,
                violations: sourceAkt.violations,
                akt: sourceAkt,
                isEditingMode: true
            )
        case .userDescription:
            return UserDescriptionViewController(
                viewModel: viewModel,
                comissionPeople: sourceAkt.comission,
                date: sourceAkt.date,
                aktNumber: sourceAkt.number,
                organizations: [sourceAkt.organization],
                objectCheck: sourceAkt.objectsCheck,
                violations: sourceAkt.violations,
                akt: sourceAkt,
                isEditingMode: true
            )
        case .predstavitely:
            return PredstavViewController(
                viewModel: viewModel,
                comissionPeople: sourceAkt.comission,
                date: sourceAkt.date,
                aktNumber: sourceAkt.number,
                organizations: [sourceAkt.organization],
                objectCheck: sourceAkt.objectsCheck,
                violations: sourceAkt.violations,
                descripUser: sourceAkt.description,
                predstavitely: sourceAkt.predstavitelyComission,
                akt: sourceAkt,
                isEditingMode: true
            )
        case .generate:
            return GenerateAktViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt
            )
        }
    }
    
    private func continueFromDraftToViolations(_ draft: DraftAKT) {
        // Создаем временный АКТ из черновика для отображения на странице нарушений
        setupBackButtonForChildScreen()
        guard let tempAkt = convertDraftToRealAkt(draft) else {
            print("❌ Не удалось преобразовать черновик в AKT")
            return
        }
        let violationsVC = ViolationsMainViewController(viewModel: viewModel, akt: tempAkt)
        navigationController?.pushViewController(violationsVC, animated: true)
    }
    
    /// Преобразует черновик в реальный AKT и сохраняет его в историю
    /// Возвращает созданный AKT или nil если не удалось создать
    private func convertDraftToRealAkt(_ draft: DraftAKT) -> AKT? {
        print("🔄 [CONVERT_DRAFT] Преобразование черновика в реальный AKT")
        print("   📋 Номер акта: \(draft.aktNumber)")
        print("   📅 Дата: \(draft.date)")
        
        // Проверяем минимальные требования
        guard !draft.aktNumber.isEmpty else {
            print("   ❌ Номер акта пустой, невозможно создать AKT")
            return nil
        }
        
        // Рассчитываем даты на основе даты проверки
        let ustranenDate = draft.ustranenDatePicker ?? Calendar.current.date(byAdding: .month, value: 1, to: draft.date) ?? draft.date
        let predostavlenDate = draft.predostavlenDatePicker ?? Calendar.current.date(byAdding: .month, value: 1, to: draft.date) ?? draft.date
        let utverzdenDate = draft.utverzdenDatePicker ?? Calendar.current.date(byAdding: .day, value: 7, to: draft.date) ?? draft.date
        
        // Создаем реальный AKT (не временный!)
        let realAkt = AKT(
            number: draft.aktNumber,
            date: draft.date,
            comission: draft.comissionPeople,
            organization: draft.organizations.first ?? Organization(title: "Организация не указана"),
            objectsCheck: draft.objectCheck,
            predstavitelyComission: draft.predstavitely,
            violations: draft.violations,
            description: draft.descripUser,
            actustranenDate: ustranenDate,
            actPredostavlenDate: predostavlenDate,
            actUtverzdenDate: utverzdenDate,
            urlAct: URL(fileURLWithPath: ""), // Пустой URL, так как документ еще не сгенерирован
            realDateCreate: draft.createdAt
        )
        
        print("✅ [CONVERT_DRAFT] Реальный AKT создан:")
        print("   🆔 ID: \(realAkt.id.uuidString)")
        print("   🔢 Номер: \(realAkt.number)")
        print("   👥 Комиссия: \(realAkt.comission.count) членов")
        print("   📋 Нарушения: \(realAkt.violations.count)")
        
        return realAkt
    }
    
    // MARK: - Deprecated Methods (для обратной совместимости, но не используются)
    
    @available(*, deprecated, message: "Используйте convertDraftToRealAkt() вместо этого метода")
    private func createTempAktFromDraft(_ draft: DraftAKT) -> AKT {
        // Создаем временный АКТ из данных черновика
        let tempId = UUID()
        let tempUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("temp_\(tempId.uuidString).docx")
        
        return AKT(
            number: draft.aktNumber,
            date: draft.date,
            comission: draft.comissionPeople,
            organization: draft.organizations.first ?? Organization(title: "Не указана"),
            objectsCheck: draft.objectCheck,
            predstavitelyComission: draft.predstavitely,
            violations: draft.violations,
            description: draft.descripUser,
            actustranenDate: draft.ustranenDatePicker ?? Date(),
            actPredostavlenDate: draft.predostavlenDatePicker ?? Date(),
            actUtverzdenDate: draft.utverzdenDatePicker ?? Date(),
            urlAct: tempUrl,
            realDateCreate: Date()
        )
    }
    
    // MARK: - Deprecated Methods (для обратной совместимости, но не используются)
    
    @available(*, deprecated, message: "Используйте convertDraftToRealAkt() и editAkt() вместо этого метода")
    private func continueFromDraft(_ draft: DraftAKT) {
        // Загружаем данные из черновика в templateModel
        viewModel.templateModel.date = draft.date
        viewModel.templateModel.aktNumber = draft.aktNumber
        viewModel.templateModel.comissionPeople = draft.comissionPeople
        viewModel.templateModel.organizations = draft.organizations
        viewModel.templateModel.objectCheck = draft.objectCheck
        viewModel.templateModel.violations = draft.violations
        viewModel.templateModel.descripUser = draft.descripUser
        viewModel.templateModel.predstavitely = draft.predstavitely
        viewModel.templateModel.ustranenDatePicker = draft.ustranenDatePicker
        viewModel.templateModel.predostavlenDatePicker = draft.predostavlenDatePicker
        viewModel.templateModel.utverzdenDatePicker = draft.utverzdenDatePicker
        
        // Всегда переходим к нарушениям, если есть минимально необходимые данные
        if !draft.aktNumber.isEmpty {
            // Создаем временный акт из черновика для редактирования
            let tempAkt = createTempAktFromDraft(draft)
            
            // Создаем редактируемый акт
            viewModel.createEditableAKT(from: tempAkt)
            
            // Переходим к нарушениям
            let vc = NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                akt: tempAkt,
                isEditingMode: true
            )
            
            // Создаем кастомную кнопку "назад" с иконкой стрелки и текстом ДО push
            let backButton = UIButton(type: .system)
            backButton.setTitle("Главная", for: .normal)
            backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            backButton.addTarget(self, action: #selector(self.customBackAction), for: .touchUpInside)
            
            // Настраиваем расположение изображения слева от текста (iOS 15+)
            if #available(iOS 15.0, *) {
                var config = UIButton.Configuration.plain()
                config.imagePlacement = .leading
                config.imagePadding = 4
                config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: -8, bottom: 0, trailing: 8)
                backButton.configuration = config
            } else {
                backButton.semanticContentAttribute = .forceLeftToRight
                backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
                backButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)
            }
            
            backButton.sizeToFit()
            
            let customBackButtonWithTitle = UIBarButtonItem(customView: backButton)
            
            // Устанавливаем кнопку на созданном контроллере ДО push, чтобы она сразу появилась
            vc.navigationItem.leftBarButtonItem = customBackButtonWithTitle
            vc.navigationItem.hidesBackButton = true
            
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // Если недостаточно данных, переходим к первому шагу
            setupBackButtonForChildScreen()
            let vc = DateAndNumberAktViewController(viewModel: viewModel)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - Timer Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateDateTime), userInfo: nil, repeats: true)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    
    @objc private func updateDateTime() {
        let now = Date()
        
        // Форматирование дня недели
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "EEEE"
        let dayString = dayFormatter.string(from: now)
        
        // Форматирование даты
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let dateString = dateFormatter.string(from: now)
        
        // Форматирование времени
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ru_RU")
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeString = timeFormatter.string(from: now)
        
        let fullText = "\(dayString)\n\(dateString)\n\(timeString)"
        let attributedText = NSMutableAttributedString(string: fullText)
        
        // Делаем строку с днем недели желтой на главном экране.
        attributedText.addAttribute(
            .foregroundColor,
            value: UIColor.systemYellow,
            range: NSRange(location: 0, length: (dayString as NSString).length)
        )
        
        dateTimeLabel.attributedText = attributedText
    }
    
    private func getLastBackupInfo() -> String {
        guard let info = BackupManager.getLastBackupInfo() else {
            return "Резервная копия: нет данных"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        let dateString = formatter.string(from: info.date)
        return "Резервная копия: \(dateString)"
    }
    
    private func updateBackupInfo() {
        backupInfoLabel?.text = getLastBackupInfo()
    }
    
    // MARK: - Version Info
    
    private func getAppVersion() -> String {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let versionString = infoDictionary["CFBundleShortVersionString"] as? String,
              let buildNumber = infoDictionary["CFBundleVersion"] as? String else {
            return "Версия неизвестна"
        }
        
        // Отображаем версию в формате "основная_версия (сборка)"
        return "Версия \(versionString) (\(buildNumber))"
    }
    
    @objc private func versionLabelTapped() {
        let versionHistoryVC = VersionHistoryViewController()
        let navController = UINavigationController(rootViewController: versionHistoryVC)
        present(navController, animated: true)
    }
    
    @objc private func runDiagnostic() {
        showLoadingIndicator(message: "Проверка приложения…")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = AppDiagnosticRunner.run()
            DispatchQueue.main.async {
                self?.hideLoadingIndicator()
                self?.showDiagnosticResult(result)
            }
        }
    }

    private func showDiagnosticResult(_ result: DiagnosticResult) {
        let title = result.hasErrors ? "Обнаружены проблемы" : "Проверка завершена"
        var message: String
        if result.logFileURL != nil {
            message = result.hasErrors
                ? "Создан отчёт. Вы можете отправить файл разработчику."
                : "Ошибок не обнаружено. Отчёт сохранён."
            if result.hasErrors {
                let failedSteps = result.steps.filter { !$0.success }
                let details = failedSteps.prefix(5).map { "• \($0.name): \($0.detail)" }.joined(separator: "\n")
                if !details.isEmpty {
                    message += "\n\n" + details
                }
            }
        } else {
            message = "Не удалось создать файл отчёта (проверьте доступ к папке Документы)."
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let url = result.logFileURL {
            alert.addAction(UIAlertAction(title: "Отправить отчёт", style: .default) { [weak self] _ in
                let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                if let popover = activityVC.popoverPresentationController {
                    popover.sourceView = self?.view
                    popover.sourceRect = CGRect(x: self?.view.bounds.midX ?? 0, y: self?.view.bounds.midY ?? 0, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                self?.present(activityVC, animated: true)
            })
        }
        if !DiagnosticIncidentStore.load().isEmpty {
            alert.addAction(UIAlertAction(title: "Очистить инциденты", style: .destructive) { _ in
                DiagnosticIncidentStore.clear()
            })
        }
        alert.addAction(UIAlertAction(title: "Закрыть", style: .cancel))
        present(alert, animated: true)
    }

    @objc private func exportDebugLog() {
        guard let url = DataFlowAKT.getDebugLogFileURL() else {
            let alert = UIAlertController(title: "Нет лога", message: "Файл отладочного лога пока не создан. Воспроизведите сценарий (редактирование акта, удаление в корзину), затем нажмите снова.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        present(activityVC, animated: true)
    }
    
    @objc private func customBackAction() {
        navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Async Data Loading
    
    private func loadDataAsync() {
        // Показываем индикатор загрузки только если данных много
        let shouldShowLoading = viewModel.aktArray.count > 50
        
        if shouldShowLoading {
            // Показываем легкий индикатор загрузки
            let loadingView = createLoadingIndicator()
            view.addSubview(loadingView)
            loadingView.snp.makeConstraints { make in
                make.center.equalToSuperview()
                make.size.equalTo(40)
            }
        }
        
        // Используем новый асинхронный метод загрузки
        viewModel.loadAktArrayAsync { [weak self] aktArray in
            guard let self = self else { return }
            
            if shouldShowLoading {
                // Убираем индикатор загрузки
                self.view.subviews.forEach { view in
                    if view.tag == 999 { // Тег для индикатора загрузки
                        view.removeFromSuperview()
                    }
                }
            }
            
            // Обновляем кнопку продолжения
            self.updateContinueButton()
            // Обновляем прогресс графика (после загрузки данных)
            self.updateInspectionsProgressUI()
            
            // Синхронизируем UserDefaults в фоновом потоке
            DispatchQueue.global(qos: .utility).async {
                UserDefaults.standard.synchronize()
            }
        }
    }
    
    private func createLoadingIndicator() -> UIView {
        let container = UIView()
        container.tag = 999
        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        container.layer.cornerRadius = 8
        
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        container.addSubview(indicator)
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        return container
    }
    
    // MARK: - Loading Indicator Methods
    
    private func showLoadingIndicator(message: String = "Загрузка...") {
        hideLoadingIndicator() // Убираем предыдущий индикатор если есть
        loadingIndicator = UIFactory.showLoadingIndicator(on: view, message: message)
    }
    
    private func hideLoadingIndicator() {
        UIFactory.hideLoadingIndicator(from: view)
        loadingIndicator = nil
    }
    
    // MARK: - Deinitialization
    
    @objc private func handleReportFiltersChanged() {
        // Обновляем прогресс графика при изменении фильтров в разделе графиков
        DispatchQueue.main.async { [weak self] in
            self?.updateInspectionsProgressUI()
        }
    }
    
    deinit {
        stopTimer()
        NotificationCenter.default.removeObserver(self)
        print("✅ StartTabViewController deallocated")
    }

}
