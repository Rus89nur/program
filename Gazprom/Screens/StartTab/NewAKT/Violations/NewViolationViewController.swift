//
//  NewViolationViewController.swift
//  Gazprom
//
//  Created by Владимир on 11.07.2025.
//

import UIKit

class NewViolationViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    var comissionPeople: [ComissionPeople] // Изменено на var для обновления при возврате из других экранов
    var date: Date // Изменено на var для обновления при возврате из других экранов
    var aktNumber: String // Изменено на var для обновления при возврате из других экранов
    var organizations: [Organization] // Изменено на var для обновления при возврате из других экранов
    var objectCheck: [ObjectCheck] // Изменено на var для обновления при возврате из других экранов
    var violations: [Violations] = []
    
    var akt: AKT?
    var isEditingMode: Bool = false // Флаг для различения создания нового акта и редактирования существующего
    private var isDragModeEnabled = false
    private var isDragging = false
    private var draggedIndexPath: IndexPath?
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var autoScrollCurrentSpeed: CGFloat = 0
    private var autoScrollArmed: Bool = false
    private var autoScrollEdgeHoldStart: CFTimeInterval?
    
    // Ссылки на кнопки для скрытия в режиме перетаскивания
    private var nextButton: UIButton?
    private var saveButton: UIButton?
    private var addButton: UIBarButtonItem?
    private var homeButton: UIBarButtonItem?
    
    // CADisplayLink для плавной автоматической прокрутки (синхронизирован с частотой обновления экрана)
    private var scrollDisplayLink: CADisplayLink?
    
    // Текущая позиция пальца для автоматической прокрутки
    private var currentTouchLocation: CGPoint = .zero
    
    // Последнее время перемещения для дебаунса
    private var lastMoveTime: TimeInterval = 0
    
    // Последний индекс перемещения для дебаунса
    private var lastMovedIndex: Int?
    
    // Последняя позиция пальца для предотвращения лишних обновлений
    private var lastTouchLocation: CGPoint = .zero
    
    // Генератор вибрации
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    // Пороговое значение для минимального перемещения (в пикселях)
    private let minMoveThreshold: CGFloat = 0.5
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], akt: AKT?, isEditingMode: Bool = false) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.akt = akt
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.register(UITableViewCell.self, forCellReuseIdentifier: "1")
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .clear
        return view
    }()
    
    // MARK: - Header Elements
    private let headerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()
    
    private let aktNumberLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        return label
    }()
    
    private let editButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Редактировать", for: .normal)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .clear
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        return button
    }()
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Убираем title, чтобы освободить место для кнопок навигации
        navigationItem.title = nil
        navigationItem.titleView = nil
        navigationItem.largeTitleDisplayMode = .never
        
        setupNavigationButtons()
        
        // Убираем title у topItem тоже
        if let navBar = navigationController?.navigationBar, let topItem = navBar.topItem {
            topItem.title = nil
            topItem.titleView = nil
        }
        
        // Обновляем кнопку "назад" на случай, если стек навигации изменился
        setupBackButtonTitle()
        
        setupViewModel()
        
        // Оптимизированная инициализация в фоновом потоке
        setupViolationsAsync()
        
        // Настройка навигации
        setupNavigationButtons()
        
        // ВАЖНО: Обновляем заголовок при возврате из других экранов
        if akt != nil {
            configureHeaderData()
        }
    }
    
    private func setupViolationsAsync() {
        // ПРИОРИТЕТ 1: Если есть редактируемый акт, используем его
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            // Обновляем локальную ссылку на акт из редактируемого акта
            self.akt = editableAkt.akt
            
            // ВАЖНО: Обновляем все свойства из редактируемого акта для синхронизации
            self.comissionPeople = editableAkt.akt.comission
            self.date = editableAkt.akt.date
            self.aktNumber = editableAkt.akt.number
            self.organizations = [editableAkt.akt.organization]
            self.objectCheck = editableAkt.akt.objectsCheck
            // Загружаем нарушения из редактируемого акта, чтобы внешние акты были видны
            self.violations = editableAkt.akt.violations
        }
        // ПРИОРИТЕТ 2: Если есть акт, но нет редактируемого акта, создаем его
        else if let akt = akt {
            viewModel.editExistingAkt(akt)
            // ВАЖНО: Обновляем все свойства из переданного акта для синхронизации
            self.comissionPeople = akt.comission
            self.date = akt.date
            self.aktNumber = akt.number
            self.organizations = [akt.organization]
            self.objectCheck = akt.objectsCheck
            // Загружаем нарушения из переданного акта
            self.violations = akt.violations
        }
        
        // Синхронизируем изменения с актом в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Выполняем тяжелые операции в фоновом потоке
            self.syncViolationsWithAkt()
            
            // Обновляем UI в главном потоке
            DispatchQueue.main.async {
                // Обновляем таблицу
                self.tableView.reloadData()
            }
        }
    }
    
    private func setupNavigationButtons() {
        print("🔵 [NEW_VIOLATION] setupNavigationButtons вызван")
        
        // Убираем title, чтобы освободить место для кнопок
        navigationItem.title = nil
        navigationItem.titleView = nil
        navigationItem.largeTitleDisplayMode = .never
        
        // ВАЖНО: Сначала всегда устанавливаем правые кнопки ("Добавить" и "Домик"),
        // чтобы они были видны независимо от того, откуда пришли
        let addButton = UIFactory.createButton(title: "Добавить", color: .systemBlue)
        addButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        addButton.layer.cornerRadius = 12
        addButton.sizeToFit()
        addButton.translatesAutoresizingMaskIntoConstraints = true
        if addButton.frame.width < 110 {
            addButton.frame = CGRect(x: 0, y: 0, width: 110, height: 34)
        }
        let item = UIBarButtonItem(customView: addButton)
        self.addButton = item
        addButton.addTarget(self, action: #selector(openAddNewViolatation), for: .touchUpInside)
        
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        goBackButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        goBackButton.translatesAutoresizingMaskIntoConstraints = true
        let item1 = UIBarButtonItem(customView: goBackButton)
        self.homeButton = item1
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
        goBackButton.alpha = 0.5
        
        navigationItem.rightBarButtonItems = [item1, item]
        
        // Теперь проверяем, есть ли уже установленная кнопка с текстом "История"
        // Если есть, значит она установлена из HistoryTabViewController, и мы её не трогаем
        if let existingButton = navigationItem.leftBarButtonItem?.customView as? UIButton {
            var existingTitle: String? = nil
            if #available(iOS 15.0, *) {
                existingTitle = existingButton.configuration?.title
                print("🔵 [NEW_VIOLATION] setupNavigationButtons: existingButton найден, iOS 15+, title из configuration: '\(existingTitle ?? "nil")'")
            } else {
                existingTitle = existingButton.title(for: .normal)
                print("🔵 [NEW_VIOLATION] setupNavigationButtons: existingButton найден, iOS < 15, title: '\(existingTitle ?? "nil")'")
            }
            
            // Если кнопка уже установлена с текстом "История", не перезаписываем её
            if let title = existingTitle, title == "История" {
                print("✅ [NEW_VIOLATION] setupNavigationButtons: Кнопка 'История' найдена, не перезаписываем левую кнопку, но правые кнопки уже установлены")
                return
            } else {
                print("⚠️ [NEW_VIOLATION] setupNavigationButtons: Кнопка найдена, но title не 'История': '\(existingTitle ?? "nil")'")
            }
        } else {
            print("🔵 [NEW_VIOLATION] setupNavigationButtons: existingButton не найден")
        }
        
        // Определяем, откуда пришли, проверяя стек навигации
        var backButtonTitle = "Главная"
        
        if let viewControllers = navigationController?.viewControllers {
            print("🔵 [NEW_VIOLATION] setupNavigationButtons: viewControllers.count = \(viewControllers.count)")
            let currentIndex = viewControllers.firstIndex(where: { $0 === self }) ?? 0
            print("🔵 [NEW_VIOLATION] setupNavigationButtons: currentIndex = \(currentIndex)")
            if currentIndex > 0 {
                let previousVC = viewControllers[currentIndex - 1]
                let previousVCTypeName = String(describing: type(of: previousVC))
                print("🔵 [NEW_VIOLATION] setupNavigationButtons: previousVCTypeName = '\(previousVCTypeName)'")
                if previousVCTypeName == "HistoryTabViewController" || 
                   previousVCTypeName.hasSuffix(".HistoryTabViewController") ||
                   previousVCTypeName.contains("HistoryTabViewController") {
                    backButtonTitle = "История"
                    print("✅ [NEW_VIOLATION] setupNavigationButtons: Определен источник 'История', устанавливаем backButtonTitle = 'История'")
                } else {
                    print("🔵 [NEW_VIOLATION] setupNavigationButtons: Источник не 'История', используем 'Главная'")
                }
            } else {
                print("⚠️ [NEW_VIOLATION] setupNavigationButtons: currentIndex <= 0, не можем определить предыдущий контроллер")
            }
        } else {
            print("⚠️ [NEW_VIOLATION] setupNavigationButtons: viewControllers == nil")
        }
        
        // Скрываем стандартную кнопку назад и создаем кастомную с достаточным размером
        navigationItem.hidesBackButton = true
        
        print("🔵 [NEW_VIOLATION] setupNavigationButtons: Создаем кнопку с текстом '\(backButtonTitle)'")
        
        // Создаем кастомную кнопку с правильным текстом в зависимости от источника
        let backButton = UIButton(type: .system)
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = backButtonTitle
            config.image = UIImage(systemName: "chevron.left")
            config.imagePlacement = .leading
            config.imagePadding = 6
            config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8)
            backButton.configuration = config
        } else {
            backButton.setTitle(backButtonTitle, for: .normal)
            backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
            backButton.semanticContentAttribute = .forceLeftToRight
            backButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
            backButton.titleEdgeInsets = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 0)
        }
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.sizeToFit()
        let minWidth: CGFloat = 110
        if backButton.frame.width < minWidth {
            backButton.frame = CGRect(
                x: backButton.frame.origin.x,
                y: backButton.frame.origin.y,
                width: minWidth,
                height: max(backButton.frame.height, 34)
            )
        }
        backButton.translatesAutoresizingMaskIntoConstraints = true
        
        let backBarButtonItem = UIBarButtonItem(customView: backButton)
        navigationItem.leftBarButtonItem = backBarButtonItem
    }
    
//    private func setupNav() {
//        let goBackButton = UIButton(type: .system)
//        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
//        let item = UIBarButtonItem(customView: goBackButton)
//        goBackButton.snp.makeConstraints { make in
//            make.height.width.equalTo(24)
//        }
//        self.navigationItem.rightBarButtonItem = item
//        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
//    }
    
    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Проверяем и исправляем размер кнопки после layout
        if let leftItem = navigationItem.leftBarButtonItem, let customView = leftItem.customView, let button = customView as? UIButton {
            let minWidth: CGFloat = 110
            if button.frame.width < minWidth {
                button.frame = CGRect(
                    x: button.frame.origin.x,
                    y: button.frame.origin.y,
                    width: minWidth,
                    height: max(button.frame.height, 34)
                )
                button.setNeedsLayout()
                button.layoutIfNeeded()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Оптимизированная синхронизация в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Синхронизируем все изменения с актом или черновиком
            self.syncViolationsWithAkt()
            
            // НЕ переносим редактируемый акт в историю при закрытии экрана нарушений
            if DataFlowAKT.getEditableAKT() != nil {
                // Обновляем массив актов в ViewModel
                self.viewModel.refreshAktArray()
                
                // Уведомляем о необходимости обновления кнопки "Продолжить" в главном потоке
                DispatchQueue.main.async {
                    self.viewModel.continueButtonUpdateBinding?()
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела ДО появления экрана
        setupBackButtonTitle()
        
        setupUI()
        checkOld()
        setupLongPressGesture()
        
        // Настройка данных header (только если есть akt)
        if akt != nil {
            configureHeaderData()
        }
        
        // Настройка темной темы
        setupDarkTheme()
        
    }
    
    private func setupBackButtonTitle() {
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        guard let navController = navigationController else { return }
        
        let viewControllers = navController.viewControllers
        // Определяем, откуда пришел пользователь, проверяя стек навигации
        var backButtonTitle = "Назад" // По умолчанию
        
        // Ищем текущий индекс этого контроллера
        guard let currentIndex = viewControllers.firstIndex(where: { $0 === self }),
              currentIndex > 0 else {
            return
        }
        
        let previousVC = viewControllers[currentIndex - 1]
        
        // Проверяем тип предыдущего контроллера
        if previousVC is StartTabViewController {
            // Пришли с главной страницы
            backButtonTitle = "Главная"
        } else if previousVC is HistoryTabViewController {
            // Пришли из истории
            backButtonTitle = "История"
        } else if previousVC is ObjectReviewViewController {
            // Пришли из раздела объектов проверки
            backButtonTitle = "Объекты проверки"
        } else {
            // Проверяем весь стек навигации, чтобы найти StartTab или HistoryTab
            // Это нужно, если между ними есть другие контроллеры
            for i in (0..<currentIndex).reversed() {
                if viewControllers[i] is StartTabViewController {
                    backButtonTitle = "Главная"
                    break
                } else if viewControllers[i] is HistoryTabViewController {
                    backButtonTitle = "История"
                    break
                } else if viewControllers[i] is ObjectReviewViewController {
                    backButtonTitle = "Объекты проверки"
                    break
                }
            }
        }
        
        // Устанавливаем кнопку "назад" в предыдущем контроллере
        // ВАЖНО: это должно быть установлено ДО того, как экран появится
        let backButton = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
        previousVC.navigationItem.backBarButtonItem = backButton
        previousVC.navigationItem.backButtonTitle = backButtonTitle
        previousVC.navigationItem.backButtonDisplayMode = .default
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
            tableView.reloadData()
        }
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
            headerView.backgroundColor = .clear
            
            // Обновляем цвета текста для темной темы
            aktNumberLabel.textColor = .white
            dateLabel.textColor = .white.withAlphaComponent(0.9)
        } else {
            // Светлая тема
            view.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
            headerView.backgroundColor = .clear
            aktNumberLabel.textColor = .label
            dateLabel.textColor = .label
        }
    }
    
    private func checkOld() {
        if let a = akt {
            violations = a.violations
            tableView.reloadData()
        }
    }
    
    private func configureHeaderData() {
        guard let akt = akt else { return }
        
        // Настройка заголовка
        aktNumberLabel.text = "АКТ №\(akt.number)"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        dateLabel.text = "Дата проверки: \(formatter.string(from: akt.date))"
    }
    
    @objc private func editButtonTapped() {
        let actualAkt: AKT?
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            actualAkt = editableAkt.akt
        } else if let akt = akt {
            actualAkt = akt
        } else {
            return
        }
        guard let akt = actualAkt else { return }
        showEditMenu(for: akt)
    }
    
    private func showEditMenu(for akt: AKT) {
        let alert = UIAlertController(
            title: "Редактирование АКТ №\(akt.number)",
            message: "Выберите раздел для редактирования",
            preferredStyle: .actionSheet
        )
        
        // Добавляем действия для каждого раздела
        let dateAndNumberAction = UIAlertAction(title: "📅 Дата и номер", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.dateAndNumber, akt: akt)
        }
        
        let organizationsAction = UIAlertAction(title: "🏢 Организации", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.organizations, akt: akt)
        }
        
        let objectCheckAction = UIAlertAction(title: "🏗️ Объекты проверки", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.objectCheck, akt: akt)
        }
        
        let userDescriptionAction = UIAlertAction(title: "📝 Выводы", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.userDescription, akt: akt)
        }
        
        let predstavitelyAction = UIAlertAction(title: "👥 Представители", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.predstavitely, akt: akt)
        }
        
        let generateAction = UIAlertAction(title: "📄 Генерация АКТ", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.generate, akt: akt)
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(dateAndNumberAction)
        alert.addAction(organizationsAction)
        alert.addAction(objectCheckAction)
        alert.addAction(userDescriptionAction)
        alert.addAction(predstavitelyAction)
        alert.addAction(generateAction)
        alert.addAction(cancelAction)
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = editButton
            popover.sourceRect = editButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func navigateToEditStep(_ step: AKTCreationStep, akt: AKT) {
        let actualAkt: AKT
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.id == akt.id {
            actualAkt = editableAkt.akt
        } else {
            actualAkt = akt
        }
        let targetVC = createEditViewControllerForStep(step, akt: actualAkt)
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButtonTitle: String
        switch step {
        case .dateAndNumber:
            backButtonTitle = "Нарушения"
        case .organizations:
            backButtonTitle = "Основные данные"
        case .objectCheck:
            backButtonTitle = "Организации"
        case .violations:
            backButtonTitle = "Объекты проверки"
        case .userDescription:
            backButtonTitle = "Нарушения"
        case .predstavitely:
            backButtonTitle = "Выводы"
        case .generate:
            backButtonTitle = "Представители"
        }
        
        let backButton = UIBarButtonItem(title: backButtonTitle, style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = backButtonTitle
        
        if let navigationController = navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep, akt: AKT) -> UIViewController {
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: viewModel, akt: akt, isEditingMode: true)
        case .organizations:
            return OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                act: akt,
                isEditingMode: true
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                akt: akt,
                isEditingMode: true
            )
        case .violations:
            return NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt,
                isEditingMode: true
            )
        case .userDescription:
            return UserDescriptionViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt,
                isEditingMode: true
            )
        case .predstavitely:
            return PredstavViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt,
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
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.tableView.reloadData()
        }
        
        if let a = viewModel.templateModel.violations {
            self.violations = a
            tableView.reloadData()
        }
    }

    private func setupUI() {
        // Настройка header view (только если есть akt)
        if akt != nil {
            view.addSubview(headerView)
            headerView.snp.makeConstraints { make in
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
                make.left.right.equalToSuperview().inset(16)
                make.height.equalTo(80)
            }
            
            // Настройка элементов header
            headerView.addSubview(aktNumberLabel)
            headerView.addSubview(dateLabel)
            headerView.addSubview(editButton)
            
            aktNumberLabel.snp.makeConstraints { make in
                make.left.top.equalToSuperview()
                make.right.lessThanOrEqualTo(editButton.snp.left).offset(-16)
            }
            
            dateLabel.snp.makeConstraints { make in
                make.left.equalToSuperview()
                make.top.equalTo(aktNumberLabel.snp.bottom).offset(4)
                make.right.lessThanOrEqualTo(editButton.snp.left).offset(-16)
            }
            
            editButton.snp.makeConstraints { make in
                make.right.equalToSuperview()
                make.centerY.equalToSuperview()
                make.height.equalTo(30)
            }
            
            // Настройка действий
            editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
        }
        
        tableView.delegate  = self
        tableView.dataSource = self
        tableView.delaysContentTouches = false
        view.addSubview(tableView)
        
        if akt != nil {
            // Если есть akt, размещаем tableView под header
            tableView.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.bottom.equalToSuperview()
                make.top.equalTo(headerView.snp.bottom).offset(16)
            }
        } else {
            // Если нет akt, размещаем tableView как обычно
            tableView.snp.makeConstraints { make in
                make.left.right.equalToSuperview()
                make.bottom.equalToSuperview()
                make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            }
        }
        
        if isEditingMode {
            // Создаем кнопку "Сохранить" для режима редактирования
            let saveButton = UIFactory.createButton(title: "Сохранить", color: .systemBlue)
            view.addSubview(saveButton)
            saveButton.snp.makeConstraints { make in
                make.left.right.equalToSuperview().inset(16)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                make.height.equalTo(54)
            }
            saveButton.addTarget(self, action: #selector(saveAndClose), for: .touchUpInside)
            self.saveButton = saveButton
            
            // Создаем скрытую кнопку "Далее" для совместимости с режимом перетаскивания
            let nextButton = UIFactory.createButton(title: "Далее", color: .systemBlue)
            nextButton.isHidden = true
            view.addSubview(nextButton)
            nextButton.snp.makeConstraints { make in
                make.left.right.equalToSuperview().inset(16)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                make.height.equalTo(54)
            }
            nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
            self.nextButton = nextButton
        } else {
            // Создаем кнопку "Далее" для создания нового акта
            let nextButton = UIFactory.createButton(title: "Далее", color: .systemBlue)
            view.addSubview(nextButton)
            nextButton.snp.makeConstraints { make in
                make.left.right.equalToSuperview().inset(16)
                make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
                make.height.equalTo(54)
            }
            nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
            self.nextButton = nextButton
        }
    }
    
    @objc private func saveAndClose() {
        syncViolationsWithAkt()
        
        if akt != nil {
            SimpleRealtimeAKTManager.shared.saveChangesImmediately()
            SimpleRealtimeAKTManager.shared.finishEditing()
            navigationController?.popViewController(animated: true)
        }
    }
    
    @objc func goNext() {
        viewModel.templateModel.violations = self.violations
        viewModel.saveDraft(currentStep: .userDescription)
        
        let backButton = UIBarButtonItem(title: "Нарушения", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Нарушения"
        
        let actualComission = akt?.comission ?? comissionPeople
        let actualDate = akt?.date ?? date
        let actualAktNumber = akt?.number ?? aktNumber
        let actualOrganizations = akt != nil ? [akt!.organization] : organizations
        let actualObjectCheck = akt?.objectsCheck ?? objectCheck
        let vc = UserDescriptionViewController(viewModel: viewModel, comissionPeople: actualComission, date: actualDate, aktNumber: actualAktNumber, organizations: actualOrganizations, objectCheck: actualObjectCheck, violations: violations, akt: akt, isEditingMode: isEditingMode)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openAddNewViolatation() {
        let vc = NewViolationToAktViewController(vc: self, model: viewModel)
        present(vc, animated: true)
    }
    
    private func copyViolation(at index: Int) {
        guard index >= 0 && index < violations.count else {
            return
        }
        
        let originalViolation = violations[index]
        
        let copiedViolation = Violations(
            title: originalViolation.title,
            mesto: originalViolation.mesto,
            urlToPravilo: originalViolation.urlToPravilo,
            photo: originalViolation.photo,
            vid: originalViolation.vid,
            formulaFromRules: originalViolation.formulaFromRules
        )
        
        violations.insert(copiedViolation, at: index + 1)
        tableView.reloadData()
        syncViolationsWithAkt()
    }
    
    private func openEditAlert(index: Int) {
        guard index >= 0 && index < violations.count else {
            return
        }
        
        let violation = violations[index]
        let editVC = EditViolationViewController(violation: violation) { [weak self] updatedViolation in
            guard let self = self else { return }
            
            guard index >= 0 && index < self.violations.count else {
                return
            }
            
            self.violations[index] = updatedViolation
            self.tableView.reloadData()
            
            // Синхронизируем изменения с актом
            self.syncViolationsWithAkt()
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.15
        longPressGesture.delegate = self
        longPressGesture.allowableMovement = 30
        longPressGesture.cancelsTouchesInView = true
        longPressGesture.delaysTouchesBegan = false
        tableView.addGestureRecognizer(longPressGesture)
        self.longPressRecognizer = longPressGesture
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: tableView)
        currentTouchLocation = location
        
        switch gesture.state {
        case .began:
            guard let indexPath = tableView.indexPathForRow(at: location) else {
                return
            }
            
            impactFeedback.impactOccurred()
            startDragMode(for: indexPath)
            lastMoveTime = CACurrentMediaTime()
            lastMovedIndex = nil
            lastTouchLocation = location
            
        case .changed:
            currentTouchLocation = gesture.location(in: tableView)
            updateAutoScrollArming(at: currentTouchLocation)
            
            if isDragModeEnabled && isDragging {
                let newLocation = gesture.location(in: tableView)
                lastTouchLocation = newLocation
                _ = processDragMove(at: newLocation)
            }
            
        case .ended:
            if isDragModeEnabled {
                isDragging = false
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.viewModel.templateModel.violations = self.violations
                    self.viewModel.saveDraft(currentStep: .violations)
                    
                    DispatchQueue.global(qos: .userInitiated).async {
                        self.syncViolationsWithAkt()
                    }
                }
                
                endDragMode()
            }
            
            lastMoveTime = 0
            lastMovedIndex = nil
            lastTouchLocation = .zero
            autoScrollArmed = false
            autoScrollEdgeHoldStart = nil
            stopAutoScroll()
            
        case .cancelled:
            if isDragModeEnabled {
                isDragging = false
                endDragMode()
            }
            
            lastMoveTime = 0
            lastMovedIndex = nil
            lastTouchLocation = .zero
            autoScrollArmed = false
            autoScrollEdgeHoldStart = nil
            stopAutoScroll()
            
        case .failed:
            if isDragModeEnabled {
                isDragging = false
                endDragMode()
            }
            lastMoveTime = 0
            lastMovedIndex = nil
            lastTouchLocation = .zero
            autoScrollArmed = false
            autoScrollEdgeHoldStart = nil
            stopAutoScroll()
            
        default:
            break
        }
    }
    
    private func showViolationInfo(for violation: Violations) {
        let previewVC = AddedViolationPreviewViewController(violation: violation)
        previewVC.modalPresentationStyle = .pageSheet
        
        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(previewVC, animated: true)
    }
    
    func syncViolationsWithAkt() {
        // Обновляем нарушения в templateModel
        viewModel.templateModel.violations = violations
        
        // Проверяем, есть ли редактируемый акт
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            // Создаем обновленный акт с новыми нарушениями
            let updatedAkt = AKT(
                id: editableAkt.akt.id,
                number: editableAkt.akt.number,
                date: editableAkt.akt.date,
                comission: editableAkt.akt.comission,
                organization: editableAkt.akt.organization,
                objectsCheck: editableAkt.akt.objectsCheck,
                predstavitelyComission: editableAkt.akt.predstavitelyComission,
                violations: violations,
                description: editableAkt.akt.description,
                actustranenDate: editableAkt.akt.actustranenDate,
                actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: editableAkt.akt.realDateCreate
            )
            
            // Сохраняем изменения в редактируемый акт
            viewModel.saveChangesToEditableAkt(updatedAkt)
            
            // Сохраняем в историю, чтобы при следующем открытии акта данные не перезаписывались старыми
            if let historyIndex = viewModel.aktArray.firstIndex(where: { $0.id == updatedAkt.id }) {
                var arr = viewModel.aktArray
                arr[historyIndex] = updatedAkt
                viewModel.aktArray = arr
                DataFlowAKT.saveArr(arr: viewModel.aktArray)
            }
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        } else if let akt = akt {
            
            let updatedAkt = AKT(
                id: akt.id,
                number: akt.number,
                date: akt.date,
                comission: akt.comission,
                organization: akt.organization,
                objectsCheck: akt.objectsCheck,
                predstavitelyComission: akt.predstavitelyComission,
                violations: violations,
                description: akt.description,
                actustranenDate: akt.actustranenDate,
                actPredostavlenDate: akt.actPredostavlenDate,
                actUtverzdenDate: akt.actUtverzdenDate,
                urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: akt.realDateCreate
            )
            
            // Создаем редактируемый акт из обновленного
            viewModel.createEditableAKT(from: updatedAkt)
            self.akt = updatedAkt
            
            // Сохраняем в историю, если акт уже есть в списке
            if let historyIndex = viewModel.aktArray.firstIndex(where: { $0.id == updatedAkt.id }) {
                var arr = viewModel.aktArray
                arr[historyIndex] = updatedAkt
                viewModel.aktArray = arr
                DataFlowAKT.saveArr(arr: viewModel.aktArray)
            }
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        } else {
            guard let date = viewModel.templateModel.date,
                  let aktNumber = viewModel.templateModel.aktNumber else {
                return
            }
            
            // Подготавливаем данные для создания акта
            let comissionPeople = viewModel.templateModel.comissionPeople ?? []
            let organization = viewModel.templateModel.organizations?.first ?? Organization(title: "Не указана")
            let objectCheck = viewModel.templateModel.objectCheck ?? []
            let predstavitelyComission = viewModel.templateModel.predstavitely ?? []
            let description = viewModel.templateModel.descripUser ?? ""
            let actustranenDate = viewModel.templateModel.ustranenDatePicker ?? Date()
            let actPredostavlenDate = viewModel.templateModel.predostavlenDatePicker ?? Date()
            let actUtverzdenDate = viewModel.templateModel.utverzdenDatePicker ?? Date()
            let urlAct = URL(fileURLWithPath: "")
            let realDateCreate = Date()
            
            // Создаем новый акт
            let newAkt = AKT(
                number: aktNumber,
                date: date,
                comission: comissionPeople,
                organization: organization,
                objectsCheck: objectCheck,
                predstavitelyComission: predstavitelyComission,
                violations: violations,
                description: description,
                actustranenDate: actustranenDate,
                actPredostavlenDate: actPredostavlenDate,
                actUtverzdenDate: actUtverzdenDate,
                urlAct: urlAct,
                realDateCreate: realDateCreate
            )
            
            // Создаем новый акт и делаем его редактируемым
            viewModel.createNewAktAndMakeEditable(newAkt)
            self.akt = newAkt
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        }
    }
    
    private func startDragMode(for indexPath: IndexPath) {
        isDragModeEnabled = true
        draggedIndexPath = indexPath
        isDragging = true
        
        tableView.isScrollEnabled = false
        tableView.panGestureRecognizer.isEnabled = false
        
        autoScrollArmed = false
        autoScrollEdgeHoldStart = nil
        
        nextButton?.isHidden = true
        saveButton?.isHidden = true
        navigationItem.rightBarButtonItems = nil
        
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            tableView.reloadRows(at: visibleIndexPaths, with: .none)
        }
    }
    
    private func endDragMode() {
        isDragModeEnabled = false
        isDragging = false
        
        stopAutoScroll()
        autoScrollArmed = false
        autoScrollEdgeHoldStart = nil
        
        tableView.isScrollEnabled = true
        tableView.panGestureRecognizer.isEnabled = true
        
        if isEditingMode {
            saveButton?.isHidden = false
            nextButton?.isHidden = true
        } else {
            nextButton?.isHidden = false
            saveButton?.isHidden = true
        }
        if let homeButton = homeButton, let addButton = addButton {
            navigationItem.rightBarButtonItems = [homeButton, addButton]
        }
        
        if let visibleIndexPaths = tableView.indexPathsForVisibleRows {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            tableView.reloadRows(at: visibleIndexPaths, with: .none)
            CATransaction.commit()
        }
        
        draggedIndexPath = nil
    }
    
    // MARK: - Автоматическая прокрутка с использованием CADisplayLink
    private func startAutoScroll() {
        stopAutoScroll()
        scrollDisplayLink = CADisplayLink(target: self, selector: #selector(performAutoScroll))
        scrollDisplayLink?.preferredFramesPerSecond = 60
        scrollDisplayLink?.add(to: .main, forMode: .common)
    }
    
    private func stopAutoScroll() {
        if scrollDisplayLink != nil {
            scrollDisplayLink?.invalidate()
            scrollDisplayLink = nil
        }
    }
    
    @objc private func performAutoScroll() {
        guard isDragModeEnabled && isDragging && autoScrollArmed else {
            stopAutoScroll()
            autoScrollCurrentSpeed = 0
            return
        }

        // Более предсказуемая автопрокрутка: меньшая скорость, сглаживание, меньшая зона активации
        let scrollThreshold: CGFloat = 100
        let maxScrollSpeed: CGFloat = 6.0
        let minScrollSpeed: CGFloat = 0.6
        let smoothing: CGFloat = 0.25 // 0..1, чем больше — тем быстрее реакция
        let upSpeedMultiplier: CGFloat = 0.85 // Множитель для выравнивания скорости вверх относительно вниз

        // Возможность прокрутки
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        let currentOffset = tableView.contentOffset.y

        // Положение пальца внутри видимой области таблицы (относительно bounds)
        // currentTouchLocation - это координаты относительно tableView (учитывают contentOffset)
        // Нужно преобразовать в координаты относительно видимой области (bounds)
        let touchYInBounds = currentTouchLocation.y - currentOffset
        let distanceToBottom = tableView.bounds.height - touchYInBounds
        let distanceToTop = touchYInBounds

        var shouldScroll = false
        var sign: CGFloat = 0
        var targetAbsSpeed: CGFloat = 0

        // Проверяем оба направления независимо
        var shouldScrollDown = false
        var shouldScrollUp = false
        var speedDown: CGFloat = 0
        var speedUp: CGFloat = 0
        
        // Вниз - проверяем, что палец близко к нижнему краю И есть куда прокручивать
        if distanceToBottom < scrollThreshold && currentOffset < maxOffset - 0.5 {
            shouldScrollDown = true
            let normalized = max(0, min(1, distanceToBottom / scrollThreshold))
            let multiplier = pow(1.0 - normalized, 3) // плавная кривая
            speedDown = minScrollSpeed + (maxScrollSpeed - minScrollSpeed) * multiplier
        }
        
        // Вверх - проверяем, что палец близко к верхнему краю И есть куда прокручивать (симметрично с вниз)
        if distanceToTop < scrollThreshold && currentOffset > 0.5 {
            shouldScrollUp = true
            let normalized = max(0, min(1, distanceToTop / scrollThreshold))
            let multiplier = pow(1.0 - normalized, 3) // та же плавная кривая
            // Применяем множитель для выравнивания скорости вверх с вниз
            speedUp = (minScrollSpeed + (maxScrollSpeed - minScrollSpeed) * multiplier) * upSpeedMultiplier
        }
        
        // Выбираем направление с более сильным сигналом (ближе к краю = больше скорость)
        if shouldScrollDown && shouldScrollUp {
            // Если оба активны, выбираем направление с большей скоростью (ближе к краю)
            if speedDown > speedUp {
                shouldScroll = true
                sign = 1
                targetAbsSpeed = speedDown
            } else {
                shouldScroll = true
                sign = -1
                targetAbsSpeed = speedUp
            }
        } else if shouldScrollDown {
            shouldScroll = true
            sign = 1
            targetAbsSpeed = speedDown
        } else if shouldScrollUp {
            shouldScroll = true
            sign = -1
            targetAbsSpeed = speedUp
        }

        if !shouldScroll {
            autoScrollCurrentSpeed = 0
            autoScrollArmed = false
            stopAutoScroll()
            return
        }

        // Сглаживание скорости
        let targetSignedSpeed = targetAbsSpeed * sign
        autoScrollCurrentSpeed += (targetSignedSpeed - autoScrollCurrentSpeed) * smoothing

        // Применяем смещение и учитываем реальные границы
        let proposedOffsetY = max(0, min(currentOffset + autoScrollCurrentSpeed, maxOffset))
        let actualDeltaY = proposedOffsetY - currentOffset
        
        // Проверяем, что изменение достаточно значимо
        if abs(actualDeltaY) < 0.1 {
            autoScrollCurrentSpeed = 0
            return
        }

        // ВРЕМЕННО включаем скролл для автопрокрутки
        let wasScrollEnabled = tableView.isScrollEnabled
        tableView.isScrollEnabled = true
        
        let newOffset = CGPoint(x: tableView.contentOffset.x, y: proposedOffsetY)
        tableView.setContentOffset(newOffset, animated: false)
        
        // Возвращаем предыдущее состояние скролла
        tableView.isScrollEnabled = wasScrollEnabled

        // Корректируем логическую позицию пальца относительно фактического сдвига контента
        currentTouchLocation.y += actualDeltaY

        // Одна попытка перестановки за тик
        _ = processDragMove(at: currentTouchLocation)
    }

}

// MARK: - Autoscroll arming
extension NewViolationViewController {
    private func updateAutoScrollArming(at location: CGPoint) {
        let threshold: CGFloat = 100
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        if maxOffset <= 0 { // нет смысла прокручивать
            autoScrollArmed = false
            autoScrollEdgeHoldStart = nil
            stopAutoScroll()
            return
        }

        // Преобразуем координаты в систему координат видимой области таблицы
        let currentOffset = tableView.contentOffset.y
        let locationYInBounds = location.y - currentOffset
        let distanceToBottom = tableView.bounds.height - locationYInBounds
        let distanceToTop = locationYInBounds
        
        // Проверяем, близко ли к краям и есть ли куда прокручивать
        // Используем те же пороги, что и в performAutoScroll для симметрии
        let nearBottomEdge = distanceToBottom < threshold && currentOffset < maxOffset - 0.5
        let nearTopEdge = distanceToTop < threshold && currentOffset > 0.5
        let nearEdge = nearBottomEdge || nearTopEdge

        if nearEdge {
            if autoScrollEdgeHoldStart == nil {
                autoScrollEdgeHoldStart = CACurrentMediaTime()
            }
            let hold = CACurrentMediaTime() - (autoScrollEdgeHoldStart ?? CACurrentMediaTime())
            let requiredHold: CFTimeInterval = 0.15
            if hold >= requiredHold {
                if !autoScrollArmed {
                    autoScrollArmed = true
                    if scrollDisplayLink == nil { startAutoScroll() }
                }
            }
        } else {
            autoScrollArmed = false
            autoScrollEdgeHoldStart = nil
            stopAutoScroll()
        }
    }
}

// MARK: - Drag processing helpers
extension NewViolationViewController {
    @discardableResult
    private func processDragMove(at newLocation: CGPoint) -> Bool {
        guard isDragModeEnabled && isDragging, let sourceIndexPath = draggedIndexPath else {
            return false
        }

        let section = sourceIndexPath.section
        var targetIndexPath: IndexPath?
        let swapTriggerOffset: CGFloat = 14 // гистерезис для устойчивости

        // Проверяем движение вниз: сравниваем с серединой следующей строки
        if sourceIndexPath.row + 1 < violations.count {
            let next = IndexPath(row: sourceIndexPath.row + 1, section: section)
            let nextRect = tableView.rectForRow(at: next)
            let crossesNext = newLocation.y > (nextRect.midY + swapTriggerOffset)
            if crossesNext {
                targetIndexPath = next
            }
        }

        // Проверяем движение вверх: сравниваем с серединой предыдущей строки (если вниз не выбрано)
        if targetIndexPath == nil, sourceIndexPath.row - 1 >= 0 {
            let prev = IndexPath(row: sourceIndexPath.row - 1, section: section)
            let prevRect = tableView.rectForRow(at: prev)
            let crossesPrev = newLocation.y < (prevRect.midY - swapTriggerOffset)
            if crossesPrev {
                targetIndexPath = prev
            }
        }

        guard let target = targetIndexPath, target != sourceIndexPath else {
            // Нет пересечения середин соседних ячеек
            return false
        }

        impactFeedback.impactOccurred(intensity: 0.5)

        // ВАЖНО: Проверяем границы массива перед перемещением
        guard sourceIndexPath.row >= 0 && sourceIndexPath.row < violations.count else {
            return false
        }
        
        guard target.row >= 0 && target.row <= violations.count else {
            return false
        }

        // Обновляем данные сначала
        let movedViolation = violations.remove(at: sourceIndexPath.row)
        violations.insert(movedViolation, at: target.row)

        // Визуально двигаем строку
        CATransaction.begin()
        CATransaction.setDisableActions(false)
        CATransaction.setAnimationDuration(0.12)
        tableView.performBatchUpdates({
            self.tableView.moveRow(at: sourceIndexPath, to: target)
        }, completion: { finished in
            self.lastMoveTime = CACurrentMediaTime()
        })
        CATransaction.commit()

        draggedIndexPath = target
        return true
    }
}

// MARK: - UIGestureRecognizerDelegate
extension NewViolationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Не разрешаем одновременное распознавание long press с прокруткой/панорамированием
        if gestureRecognizer === longPressRecognizer || otherGestureRecognizer === longPressRecognizer {
            return false
        }
        if gestureRecognizer is UIPanGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer {
            return false
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Не требуем, чтобы long press ждал tap
        if gestureRecognizer === longPressRecognizer && otherGestureRecognizer is UITapGestureRecognizer {
            return false
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Даем приоритет системной прокрутке таблицы: long press начнет работать только если пан-жест не активен
        if gestureRecognizer === longPressRecognizer && (otherGestureRecognizer === tableView.panGestureRecognizer || otherGestureRecognizer is UIPanGestureRecognizer) {
            return true
        }
        return false
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Начинаем long press только на ячейке и только когда таблица не скроллится
        if gestureRecognizer === longPressRecognizer {
            if tableView.isDragging || tableView.isDecelerating {
                return false
            }
            let point = gestureRecognizer.location(in: tableView)
            let ip = tableView.indexPathForRow(at: point)
            return ip != nil
        }
        return true
    }
}

extension NewViolationViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return violations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
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
        
        // ВАЖНО: Проверяем границы массива перед доступом
        guard indexPath.row >= 0 && indexPath.row < violations.count else {
            return cell
        }
        
        let item = violations[indexPath.row]
        
        // Добавляем порядковый номер
        let numberLabel = UILabel()
        numberLabel.text = "\(indexPath.row + 1)."
        numberLabel.textAlignment = .left
        numberLabel.textColor = .systemBlue
        numberLabel.font = .systemFont(ofSize: 16, weight: .bold)
        containerView.addSubview(numberLabel)
        numberLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalToSuperview().inset(16)
            make.width.equalTo(30)
        }
        
        let mainLabel = UILabel()
        mainLabel.textAlignment = .left
        mainLabel.text = item.title
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            mainLabel.textColor = .white
        } else {
            mainLabel.textColor = .label
        }
        mainLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(mainLabel)
        mainLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalTo(numberLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(16)
        }
        
        let subLabel = UILabel()
        subLabel.text = item.urlToPravilo
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            subLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            subLabel.textColor = .label.withAlphaComponent(0.7)
        }
        subLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subLabel.textAlignment = .left
        containerView.addSubview(subLabel)
        subLabel.snp.makeConstraints { make in
            make.left.equalTo(numberLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(mainLabel.snp.bottom).inset(-8)
        }
        
        let mestoLabel = UILabel()
        mestoLabel.text = item.mesto
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            mestoLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            mestoLabel.textColor = .label.withAlphaComponent(0.7)
        }
        mestoLabel.font = .systemFont(ofSize: 16, weight: .regular)
        mestoLabel.textAlignment = .left
        containerView.addSubview(mestoLabel)
        mestoLabel.snp.makeConstraints { make in
            make.left.equalTo(numberLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
        
        // Добавляем индикатор перетаскивания в режиме редактирования
        if isDragModeEnabled {
            let dragIndicator = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
            dragIndicator.tintColor = .systemGray3
            containerView.addSubview(dragIndicator)
            dragIndicator.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
                make.width.equalTo(20)
                make.height.equalTo(16)
            }
        }
        
        // Оптимизированные визуальные эффекты для перетаскиваемой ячейки
        let isDraggedCell = isDragModeEnabled && draggedIndexPath == indexPath && isDragging
        
        if isDraggedCell {
            // Визуальное выделение перетаскиваемой ячейки
            mainLabel.font = .systemFont(ofSize: 18, weight: .bold)
            subLabel.font = .systemFont(ofSize: 17, weight: .medium)
            mestoLabel.font = .systemFont(ofSize: 17, weight: .medium)
            
            // Изменяем цвет фона для выделения
            containerView.backgroundColor = UIColor.systemGray5
            
            // Легкое масштабирование для эффекта поднятия
            containerView.transform = CGAffineTransform(scaleX: 1.02, y: 1.02)
            containerView.layer.shadowOpacity = 0.3
            containerView.layer.shadowRadius = 8
        } else {
            // Возвращаем обычные стили
            mainLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            subLabel.font = .systemFont(ofSize: 16, weight: .regular)
            mestoLabel.font = .systemFont(ofSize: 16, weight: .regular)
            
            // Восстанавливаем цвет фона
            containerView.backgroundColor = .systemGray6
            containerView.transform = .identity
            containerView.layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 1.0 : 0.1
            containerView.layer.shadowRadius = traitCollection.userInterfaceStyle == .dark ? 2 : 4
        }
        
        return cell
    }
    
    /// Свайп вправо: копирование в акте и добавление в базу.
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isDragModeEnabled {
            return UISwipeActionsConfiguration(actions: [])
        }
        guard indexPath.row >= 0 && indexPath.row < violations.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        let violation = violations[indexPath.row]
        
        let copyInActAction = UIContextualAction(style: .normal, title: "В акт") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.copyViolation(at: indexPath.row)
            completionHandler(true)
        }
        copyInActAction.backgroundColor = .systemBlue
        copyInActAction.image = UIImage(systemName: "doc.on.doc")
        
        let addToDbAction = UIContextualAction(style: .normal, title: "В базу") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.addViolationToDatabase(violation: violation)
            completionHandler(true)
        }
        addToDbAction.backgroundColor = .systemGreen
        addToDbAction.image = UIImage(systemName: "plus.circle.fill")
        
        let config = UISwipeActionsConfiguration(actions: [copyInActAction, addToDbAction])
        config.performsFirstActionWithFullSwipe = false
        return config
    }
    
    /// Свайп влево: изменить и удалить.
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isDragModeEnabled {
            return UISwipeActionsConfiguration(actions: [])
        }
        guard indexPath.row >= 0 && indexPath.row < violations.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        
        let editAction = UIContextualAction(style: .normal, title: "Изменить") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.openEditAlert(index: indexPath.row)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemOrange
        editAction.image = UIImage(systemName: "pencil")
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            guard indexPath.row >= 0 && indexPath.row < self.violations.count else {
                completionHandler(false)
                return
            }
            self.violations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.syncViolationsWithAkt()
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    /// Добавляет нарушение из акта в реестр (настройки) с предзаполненной формой.
    private func addViolationToDatabase(violation: Violations) {
        let prefilled = ViolationsModel.Violation(
            number: ViolationsModel.nextViolationNumber(),
            title: violation.title,
            subTitle: violation.urlToPravilo,
            description: nil,
            vid: violation.vid.isEmpty ? nil : violation.vid,
            formulaFromRules: violation.formulaFromRules
        )
        let formVC = UnifiedViolationFormViewController(existingViolation: prefilled) { [weak self] savedViolation in
            ViolationsModel.addNewViolation(violation: savedViolation)
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Готово",
                    message: "Нарушение добавлено в реестр.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alert, animated: true)
            }
        }
        let nav = UINavigationController(rootViewController: formVC)
        nav.modalPresentationStyle = .pageSheet
        if let sheet = nav.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        present(nav, animated: true)
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Отключаем выбор ячейки во время перетаскивания
        if isDragModeEnabled || isDragging {
            tableView.deselectRow(at: indexPath, animated: false)
            return
        }
        
        // Небольшая задержка для различения tap от long press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, !self.isDragModeEnabled, !self.isDragging else {
                return
            }
            tableView.deselectRow(at: indexPath, animated: true)
            
            guard indexPath.row >= 0 && indexPath.row < self.violations.count else {
                return
            }
            
            let violation = self.violations[indexPath.row]
            self.showViolationInfo(for: violation)
        }
    }
    
}
