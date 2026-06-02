//
//  ViolationsMainViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import SnapKit
import Combine

class ViolationsMainViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    private let viewModel: MainAKTViewModel
    private var akt: AKT // Изменено на var для обновления после drag and drop
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Reorder (Smooth Long-Press) State
    private var reorderSnapshotView: UIView?
    private var reorderSourceIndexPath: IndexPath?
    private var touchOffsetFromCellCenterY: CGFloat = 0
    private var lastTouchLocationInTable: CGPoint = .zero
    private var autoScrollDisplayLink: CADisplayLink?
    private var autoScrollDirection: CGFloat = 0 // -1 вверх, 1 вниз, 0 нет
    private var autoScrollSpeed: CGFloat = 0 // pts/sec
    private var lastAutoScrollDirection: CGFloat = 0
    private var lastAutoScrollSpeed: CGFloat = 0
    
    
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
    
    private let violationsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.showsVerticalScrollIndicator = false
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ViolationCell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        return tableView
    }()
    
    private let emptyStateView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    private let emptyStateLabel: UILabel = {
        let label = UILabel()
        label.text = "Нарушения не обнаружены"
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let emptyStateImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark.circle")
        imageView.tintColor = .systemGreen
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()
    
    init(viewModel: MainAKTViewModel, akt: AKT) {
        self.viewModel = viewModel
        self.akt = akt
        super.init(nibName: nil, bundle: nil)
        navigationItem.backBarButtonItem = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRealtimeIntegration()
        configureData()
        setupDarkTheme()
    }
    
    deinit {
        cleanupRealtimeIntegration()
        NotificationCenter.default.removeObserver(self)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
            violationsTableView.reloadData()
        }
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            violationsTableView.backgroundColor = .systemBackground
            headerView.backgroundColor = .clear
            emptyStateView.backgroundColor = .clear
            
            // Обновляем цвета текста для темной темы
            aktNumberLabel.textColor = .white
            dateLabel.textColor = .white.withAlphaComponent(0.9)
            emptyStateLabel.textColor = .white.withAlphaComponent(0.8)
        } else {
            // Светлая тема
            aktNumberLabel.textColor = .label
            dateLabel.textColor = .label
            emptyStateLabel.textColor = .label
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("🔵 [VIOLATIONS] viewWillAppear вызван")
        
        // Подтягиваем акт из редактируемого при возврате (например, после добавления нарушений на другом экране)
        if let editable = DataFlowAKT.getEditableAKT(), editable.akt.id == akt.id {
            akt = editable.akt
            configureData()
            updateEmptyState()
            violationsTableView.reloadData()
        }
        
        // Проверяем, есть ли уже кнопка с текстом "История" (установленная из HistoryTabViewController)
        // Проверяем и текст, и action, чтобы точно определить, что это кнопка из HistoryTabViewController
        if let existingButton = navigationItem.leftBarButtonItem?.customView as? UIButton {
            var existingTitle: String? = nil
            if #available(iOS 15.0, *) {
                existingTitle = existingButton.configuration?.title
                print("🔵 [VIOLATIONS] viewWillAppear: existingButton найден, iOS 15+, title из configuration: '\(existingTitle ?? "nil")'")
            } else {
                existingTitle = existingButton.title(for: .normal)
                print("🔵 [VIOLATIONS] viewWillAppear: existingButton найден, iOS < 15, title: '\(existingTitle ?? "nil")'")
            }
            
            // Если кнопка уже установлена с текстом "История", не перезаписываем её
            // Это означает, что кнопка была установлена из HistoryTabViewController
            // Проверяем также, что кнопка не пустая и имеет текст
            if let title = existingTitle, title == "История" {
                print("✅ [VIOLATIONS] viewWillAppear: Кнопка 'История' найдена, не перезаписываем")
                // Только убираем заголовок, но не трогаем кнопку
                navigationItem.title = nil
                navigationItem.titleView = nil
                navigationItem.largeTitleDisplayMode = .never
                return
            } else {
                print("⚠️ [VIOLATIONS] viewWillAppear: Кнопка найдена, но title не 'История': '\(existingTitle ?? "nil")'")
            }
        } else {
            print("🔵 [VIOLATIONS] viewWillAppear: existingButton не найден, вызываем setupNavigationBar")
        }
        setupNavigationBar()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [VIOLATIONS] viewDidAppear вызван")
        
        // В viewDidAppear проверяем еще раз, но только если кнопка не установлена правильно
        // Здесь стек навигации уже обновлен, поэтому проверка должна работать надежнее
        if let existingButton = navigationItem.leftBarButtonItem?.customView as? UIButton {
            var existingTitle: String? = nil
            if #available(iOS 15.0, *) {
                existingTitle = existingButton.configuration?.title
                print("🔵 [VIOLATIONS] viewDidAppear: existingButton найден, iOS 15+, title из configuration: '\(existingTitle ?? "nil")'")
            } else {
                existingTitle = existingButton.title(for: .normal)
                print("🔵 [VIOLATIONS] viewDidAppear: existingButton найден, iOS < 15, title: '\(existingTitle ?? "nil")'")
            }
            
            // Если кнопка уже установлена с текстом "История", не перезаписываем её
            // Это означает, что кнопка была установлена из HistoryTabViewController
            // Проверяем также, что кнопка не пустая и имеет текст
            if let title = existingTitle, title == "История" {
                print("✅ [VIOLATIONS] viewDidAppear: Кнопка 'История' найдена, не перезаписываем")
                // Только убираем заголовок, но не трогаем кнопку
                navigationItem.title = nil
                navigationItem.titleView = nil
                return
            } else {
                print("⚠️ [VIOLATIONS] viewDidAppear: Кнопка найдена, но title не 'История': '\(existingTitle ?? "nil")'")
            }
        } else {
            print("🔵 [VIOLATIONS] viewDidAppear: existingButton не найден, вызываем setupNavigationBar")
        }
        // Вызываем setupNavigationBar только если кнопка не установлена или установлена неправильно
        // В viewDidAppear стек навигации уже обновлен, поэтому проверка источника должна работать
        setupNavigationBar()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Проверяем и исправляем размер кнопки после layout
        if let leftItem = navigationItem.leftBarButtonItem, let customView = leftItem.customView, let button = customView as? UIButton {
            let minWidth: CGFloat = 100
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
    
    private func setupNavigationBar() {
        print("🔵 [VIOLATIONS] setupNavigationBar вызван")
        
        // Полностью убираем заголовок, чтобы стрелочка назад была видна
        navigationItem.title = nil
        navigationItem.titleView = nil
        navigationItem.largeTitleDisplayMode = .never
        
        // Также убираем title у topItem, если он есть
        if let navBar = navigationController?.navigationBar, let topItem = navBar.topItem {
            topItem.title = nil
            topItem.titleView = nil
        }
        
        // Сначала проверяем, есть ли уже установленная кнопка с текстом "История"
        // Если есть, значит она установлена из HistoryTabViewController, и мы её не трогаем
        // Проверяем более тщательно, чтобы не перезаписать кнопку из HistoryTabViewController
        if let existingButton = navigationItem.leftBarButtonItem?.customView as? UIButton {
            var existingTitle: String? = nil
            
            if #available(iOS 15.0, *) {
                existingTitle = existingButton.configuration?.title
                print("🔵 [VIOLATIONS] setupNavigationBar: existingButton найден, iOS 15+, title из configuration: '\(existingTitle ?? "nil")'")
            } else {
                existingTitle = existingButton.title(for: .normal)
                print("🔵 [VIOLATIONS] setupNavigationBar: existingButton найден, iOS < 15, title: '\(existingTitle ?? "nil")'")
            }
            
            // Если кнопка уже установлена с текстом "История", не перезаписываем её
            // Это означает, что кнопка была установлена из HistoryTabViewController
            // Проверяем также, что кнопка не пустая и имеет текст
            if let title = existingTitle, title == "История" {
                print("✅ [VIOLATIONS] setupNavigationBar: Кнопка 'История' найдена, не перезаписываем")
                // Только убираем заголовок, но не трогаем кнопку
                navigationItem.title = nil
                navigationItem.titleView = nil
                return
            } else {
                print("⚠️ [VIOLATIONS] setupNavigationBar: Кнопка найдена, но title не 'История': '\(existingTitle ?? "nil")'")
            }
        } else {
            print("🔵 [VIOLATIONS] setupNavigationBar: existingButton не найден")
        }
        
        // Определяем, откуда пришли, проверяя стек навигации
        // Это нужно для случаев, когда кнопка еще не установлена или установлена неправильно
        var backButtonTitle = "Главная"
        
        if let viewControllers = navigationController?.viewControllers {
            print("🔵 [VIOLATIONS] setupNavigationBar: viewControllers.count = \(viewControllers.count)")
            let currentIndex = viewControllers.firstIndex(where: { $0 === self }) ?? 0
            print("🔵 [VIOLATIONS] setupNavigationBar: currentIndex = \(currentIndex)")
            if currentIndex > 0 {
                let previousVC = viewControllers[currentIndex - 1]
                // Проверяем тип через имя класса для надежности
                let previousVCTypeName = String(describing: type(of: previousVC))
                print("🔵 [VIOLATIONS] setupNavigationBar: previousVCTypeName = '\(previousVCTypeName)'")
                // Проверяем точное совпадение или содержит имя класса (может быть с модулем, например "Gazprom.HistoryTabViewController")
                if previousVCTypeName == "HistoryTabViewController" || 
                   previousVCTypeName.hasSuffix(".HistoryTabViewController") ||
                   previousVCTypeName.contains("HistoryTabViewController") {
                    backButtonTitle = "История"
                    print("✅ [VIOLATIONS] setupNavigationBar: Определен источник 'История', устанавливаем backButtonTitle = 'История'")
                } else {
                    print("🔵 [VIOLATIONS] setupNavigationBar: Источник не 'История', используем 'Главная'")
                }
            } else {
                print("⚠️ [VIOLATIONS] setupNavigationBar: currentIndex <= 0, не можем определить предыдущий контроллер")
            }
        } else {
            print("⚠️ [VIOLATIONS] setupNavigationBar: viewControllers == nil")
        }
        
        print("🔵 [VIOLATIONS] setupNavigationBar: Создаем кнопку с текстом '\(backButtonTitle)'")
        
        // Создаем или обновляем кнопку
        // Скрываем стандартную кнопку назад и создаем кастомную с достаточным размером
        navigationItem.hidesBackButton = true
            
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
        let minWidth: CGFloat = 100
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
        
        // Добавляем кнопку "домик" для возврата на главный экран
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        goBackButton.frame = CGRect(x: 0, y: 0, width: 24, height: 24)
        goBackButton.translatesAutoresizingMaskIntoConstraints = true
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
        goBackButton.alpha = 0.5
        let homeButton = UIBarButtonItem(customView: goBackButton)
        navigationItem.rightBarButtonItem = homeButton
        
        // Принудительно обновляем навигационную панель
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
    }
    
    @objc private func goBack() {
        navigationController?.popViewController(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        SimpleRealtimeAKTManager.shared.updateViolations(akt.violations)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Настройка header view
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
        
        // Настройка table view
        view.addSubview(violationsTableView)
        violationsTableView.snp.makeConstraints { make in
            make.top.equalTo(headerView.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        
        // Настройка empty state
        view.addSubview(emptyStateView)
        emptyStateView.snp.makeConstraints { make in
            make.center.equalTo(violationsTableView)
            make.left.right.equalToSuperview().inset(32)
        }
        
        emptyStateView.addSubview(emptyStateImageView)
        emptyStateView.addSubview(emptyStateLabel)
        
        emptyStateImageView.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(60)
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.top.equalTo(emptyStateImageView.snp.bottom).offset(16)
            make.left.right.bottom.equalToSuperview()
        }
        
        // Настройка table view
        violationsTableView.delegate = self
        violationsTableView.dataSource = self
        
        violationsTableView.isEditing = false
        violationsTableView.allowsSelectionDuringEditing = true
        violationsTableView.separatorStyle = .none
        violationsTableView.delaysContentTouches = false
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleReorderGesture(_:)))
        longPress.minimumPressDuration = 0.6
        longPress.allowableMovement = 80
        longPress.cancelsTouchesInView = false
        longPress.delaysTouchesBegan = false
        longPress.delaysTouchesEnded = false
        longPress.delegate = self
        
        violationsTableView.addGestureRecognizer(longPress)
        
        editButton.addTarget(self, action: #selector(editButtonTapped), for: .touchUpInside)
    }
    
    private func configureData() {
        // Настройка заголовка
        aktNumberLabel.text = "АКТ №\(akt.number)"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        formatter.locale = Locale(identifier: "ru_RU")
        dateLabel.text = "Дата проверки: \(formatter.string(from: akt.date))"
        
        // Обновление состояния
        updateEmptyState()
    }
    
    private func updateEmptyState() {
        let hasViolations = !akt.violations.isEmpty
        emptyStateView.isHidden = hasViolations
        violationsTableView.isHidden = !hasViolations
    }
    
    @objc private func editButtonTapped() {
        showEditMenu()
    }
    
    @objc private func goHome() {
        // Переходим на главную вкладку (индекс 0)
        tabBarController?.selectedIndex = 0
    }
    
    private func showEditMenu() {
        let alert = UIAlertController(
            title: "Редактирование АКТ №\(akt.number)",
            message: "Выберите раздел для редактирования",
            preferredStyle: .actionSheet
        )
        
        // Добавляем действия для каждого раздела
        let dateAndNumberAction = UIAlertAction(title: "📅 Дата и номер", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.dateAndNumber)
        }
        
        let organizationsAction = UIAlertAction(title: "🏢 Организации", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.organizations)
        }
        
        let objectCheckAction = UIAlertAction(title: "🏗️ Объекты проверки", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.objectCheck)
        }
        
        let violationsAction = UIAlertAction(title: "⚠️ Нарушения", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.violations)
        }
        
        let userDescriptionAction = UIAlertAction(title: "📝 Выводы", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.userDescription)
        }
        
        let predstavitelyAction = UIAlertAction(title: "👥 Представители", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.predstavitely)
        }
        
        let generateAction = UIAlertAction(title: "📄 Генерация АКТ", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.generate)
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(dateAndNumberAction)
        alert.addAction(organizationsAction)
        alert.addAction(objectCheckAction)
        alert.addAction(violationsAction)
        alert.addAction(userDescriptionAction)
        alert.addAction(predstavitelyAction)
        alert.addAction(generateAction)
        alert.addAction(cancelAction)
        
        // Для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = editButton
            popover.sourceRect = editButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func navigateToEditStep(_ step: AKTCreationStep) {
        // Загружаем данные акта в template model
        loadAktToTemplate()
        
        // Создаем соответствующий контроллер
        let targetVC = createEditViewControllerForStep(step)
        
        // Переходим к редактированию
        navigationController?.pushViewController(targetVC, animated: true)
    }
    
    private func loadAktToTemplate() {
        // Очищаем текущий template
        viewModel.templateModel.reset()
        
        // Загружаем данные из акта
        viewModel.templateModel.date = akt.date
        viewModel.templateModel.aktNumber = akt.number
        viewModel.templateModel.comissionPeople = akt.comission
        viewModel.templateModel.organizations = [akt.organization]
        viewModel.templateModel.objectCheck = akt.objectsCheck
        viewModel.templateModel.violations = akt.violations
        viewModel.templateModel.descripUser = akt.description
        viewModel.templateModel.predstavitely = akt.predstavitelyComission
        viewModel.templateModel.ustranenDatePicker = akt.actustranenDate
        viewModel.templateModel.predostavlenDatePicker = akt.actPredostavlenDate
        viewModel.templateModel.utverzdenDatePicker = akt.actUtverzdenDate
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep) -> UIViewController {
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: viewModel, akt: akt)
        case .organizations:
            return OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                act: akt
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                akt: akt
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
                akt: akt
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
                akt: akt
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
                akt: akt
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
    
    // MARK: - Violation Actions
    private func showViolationInfo(for violation: Violations) {
        let previewVC = AddedViolationPreviewViewController(violation: violation)
        previewVC.modalPresentationStyle = .pageSheet
        
        // Устанавливаем черный фон для темной темы перед презентацией
        if traitCollection.userInterfaceStyle == .dark {
            previewVC.view.backgroundColor = .black
        }
        
        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(previewVC, animated: true)
    }
    
    private func editViolation(_ violation: Violations, at index: Int) {
        // Создаем контроллер редактирования нарушения
        let editVC = EditViolationViewController(violation: violation) { [weak self] updatedViolation in
            // Обновляем нарушение в АКТ
            self?.updateViolation(updatedViolation, at: index)
        }
        
        navigationController?.pushViewController(editVC, animated: true)
    }
    
    private func copyViolation(at index: Int) {
        guard index >= 0 && index < akt.violations.count else {
            return
        }
        
        let originalViolation = akt.violations[index]
        
        let copiedViolation = Violations(
            title: originalViolation.title,
            mesto: originalViolation.mesto,
            urlToPravilo: originalViolation.urlToPravilo,
            photo: originalViolation.photo,
            vid: originalViolation.vid,
            formulaFromRules: originalViolation.formulaFromRules
        )
        
        var updatedViolations = akt.violations
        updatedViolations.insert(copiedViolation, at: index + 1)
        
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
        
        if DataFlowAKT.getEditableAKT() != nil {
            DataFlowAKT.updateEditableAKT(updatedAkt)
        }
        
        if let historyIndex = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            var arr = viewModel.aktArray
            arr[historyIndex] = updatedAkt
            viewModel.aktArray = arr
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
        
        akt = updatedAkt
        violationsTableView.reloadData()
        updateEmptyState()
    }
    
    private func deleteViolation(at index: Int) {
        let alert = UIAlertController(
            title: "Удалить нарушение",
            message: "Вы уверены, что хотите удалить это нарушение?",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.performDeleteViolation(at: index)
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func performDeleteViolation(at index: Int) {
        var updatedViolations = akt.violations
        updatedViolations.remove(at: index)
        
        // Создаем обновленный АКТ с сохранением оригинального ID
        let updatedAkt = AKT(
            id: akt.id, // ВАЖНО: Сохраняем оригинальный ID
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
        
        if DataFlowAKT.getEditableAKT() != nil {
            DataFlowAKT.updateEditableAKT(updatedAkt)
        }
        
        if let historyIndex = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            var arr = viewModel.aktArray
            arr[historyIndex] = updatedAkt
            viewModel.aktArray = arr
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        akt = updatedAkt
        SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
        
        violationsTableView.reloadData()
        updateEmptyState()
    }
    
    private func updateViolation(_ updatedViolation: Violations, at index: Int) {
        var updatedViolations = akt.violations
        updatedViolations[index] = updatedViolation
        
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
        
        if DataFlowAKT.getEditableAKT() != nil {
            DataFlowAKT.updateEditableAKT(updatedAkt)
        }
        
        if let historyIndex = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            var arr = viewModel.aktArray
            arr[historyIndex] = updatedAkt
            viewModel.aktArray = arr
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        akt = updatedAkt
        SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
        
        violationsTableView.reloadData()
    }
    
    #if false // legacy iOS drag/drop (disabled)
    // MARK: - UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        guard indexPath.row < akt.violations.count else {
            return []
        }
        
        let violation = akt.violations[indexPath.row]
        let itemProvider = NSItemProvider(object: violation.title as NSString)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = violation
        
        return [dragItem]
    }
    
    func tableView(_ tableView: UITableView, dragPreviewParametersForRowAt indexPath: IndexPath) -> UIDragPreviewParameters? {
        let parameters = UIDragPreviewParameters()
        parameters.backgroundColor = .clear
        
        if let cell = tableView.cellForRow(at: indexPath) {
            let cellRect = cell.bounds
            parameters.visiblePath = UIBezierPath(rect: cellRect)
        }
        
        return parameters
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        return session.canLoadObjects(ofClass: NSString.self)
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        if session.localDragSession != nil {
            return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
        }
        
        return UITableViewDropProposal(operation: .forbidden)
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        
        guard let destinationIndexPath = coordinator.destinationIndexPath else {
            return
        }
        
        guard let dragItem = coordinator.items.first else {
            return
        }
        
        guard let sourceIndexPath = dragItem.sourceIndexPath else {
            return
        }
        
        guard sourceIndexPath.row < akt.violations.count,
              destinationIndexPath.row <= akt.violations.count else {
            return
        }
        
        guard sourceIndexPath.row != destinationIndexPath.row else {
            return
        }
        
        var updatedViolations = akt.violations
        let movedViolation = updatedViolations.remove(at: sourceIndexPath.row)
        
        let adjustedDestinationIndex = destinationIndexPath.row > sourceIndexPath.row ? destinationIndexPath.row - 1 : destinationIndexPath.row
        updatedViolations.insert(movedViolation, at: adjustedDestinationIndex)
        
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
        
        akt = updatedAkt
        
        if DataFlowAKT.getEditableAKT() != nil {
            DataFlowAKT.updateEditableAKT(updatedAkt)
        }
        
        if let index = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            viewModel.aktArray[index] = updatedAkt
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
        
        tableView.performBatchUpdates({
            tableView.moveRow(at: sourceIndexPath, to: IndexPath(row: adjustedDestinationIndex, section: 0))
        }, completion: nil)
    }
    
    private func setupDragAndDropErrorHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDragAndDropError),
            name: NSNotification.Name("DragAndDropError"),
            object: nil
        )
    }
    
    @objc private func handleDragAndDropError() {
        violationsTableView.dragInteractionEnabled = false
        violationsTableView.dragDelegate = nil
        violationsTableView.dropDelegate = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.violationsTableView.dragInteractionEnabled = true
            self.violationsTableView.dragDelegate = self
            self.violationsTableView.dropDelegate = self
        }
    }
#endif
}

// MARK: - UITableViewDataSource
extension ViolationsMainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return akt.violations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ViolationCell", for: indexPath)
        
        // Очищаем только содержимое contentView, не трогая системные subviews ячейки
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        // Сбрасываем все свойства ячейки
        cell.layer.cornerRadius = 0
        cell.layer.shadowOpacity = 0
        cell.transform = .identity
        cell.alpha = 1.0
        
        // Убеждаемся, что ячейка поддерживает drag and drop
        cell.isUserInteractionEnabled = true
        
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
        
        cell.contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(4)
        }
        
        let item = akt.violations[indexPath.row]
        
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
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ViolationsMainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let violation = akt.violations[indexPath.row]
        showViolationInfo(for: violation)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 100
    }
    
    /// Свайп вправо: копирование в акте и добавление в базу.
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row >= 0 && indexPath.row < akt.violations.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        let violation = akt.violations[indexPath.row]
        
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
    
    /// Свайп влево: редактирование и удаление.
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row >= 0 && indexPath.row < akt.violations.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        let violation = akt.violations[indexPath.row]
        
        let editAction = UIContextualAction(style: .normal, title: "Редактировать") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.editViolation(violation, at: indexPath.row)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemOrange
        editAction.image = UIImage(systemName: "pencil")
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.deleteViolation(at: indexPath.row)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    /// Добавляет нарушение из акта в реестр нарушений (базу) с предзаполненной формой.
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
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let violation = akt.violations[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let addToDbAction = UIAction(title: "В базу", image: UIImage(systemName: "plus.circle.fill")) { _ in
                self.addViolationToDatabase(violation: violation)
            }
            let copyAction = UIAction(title: "В акт", image: UIImage(systemName: "doc.on.doc")) { _ in
                self.copyViolation(at: indexPath.row)
            }
            let editAction = UIAction(title: "Редактировать", image: UIImage(systemName: "pencil")) { _ in
                self.editViolation(violation, at: indexPath.row)
            }
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteViolation(at: indexPath.row)
            }
            return UIMenu(title: "", children: [addToDbAction, copyAction, editAction, deleteAction])
        }
    }
    
    #if false // legacy iOS drag/drop (disabled)
    // Улучшенная поддержка drag - разрешаем drag даже если есть context menu
    func tableView(_ tableView: UITableView, dragSessionWillBegin session: UIDragSession) {
    }
    
    func tableView(_ tableView: UITableView, dragSessionDidEnd session: UIDragSession) {
    }
    
    func tableView(_ tableView: UITableView, dragSessionAllowsMoveOperation session: UIDragSession) -> Bool {
        return true
    }
    #endif
}

// MARK: - UIGestureRecognizerDelegate
extension ViolationsMainViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let point = gestureRecognizer.location(in: violationsTableView)
        _ = violationsTableView.indexPathForRow(at: point)
        
        // Для long press gesture - проверяем, не является ли это горизонтальным свайпом
        if gestureRecognizer is UILongPressGestureRecognizer {
            // Проверяем все pan gesture recognizers в tableView
            if let panGestures = violationsTableView.gestureRecognizers?.filter({ $0 is UIPanGestureRecognizer }) as? [UIPanGestureRecognizer] {
                for panGesture in panGestures {
                    // Проверяем, является ли движение горизонтальным
                    let velocity = panGesture.velocity(in: violationsTableView)
                    let horizontalVelocity = abs(velocity.x)
                    let verticalVelocity = abs(velocity.y)
                    
                    if horizontalVelocity > verticalVelocity && horizontalVelocity > 50 {
                        return false
                    }
                }
            }
            
            return true
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer {
            return true
        }
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if (gestureRecognizer is UILongPressGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) ||
           (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UILongPressGestureRecognizer) {
            return false
        }
        return false
    }
}

// MARK: - SimpleRealtimeAKTObserver Methods
extension ViolationsMainViewController {
    
    func aktDidChange(_ change: String) {
        DispatchQueue.main.async {
            self.violationsTableView.reloadData()
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        DispatchQueue.main.async {
            self.violationsTableView.reloadData()
        }
    }
    
    private func setupRealtimeIntegration() {
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
    }
    
    private func cleanupRealtimeIntegration() {
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
    }
}

// MARK: - Reorder (Long Press) Implementation
extension ViolationsMainViewController {
    private func makeAkt(with violations: [Violations]) -> AKT {
        return AKT(
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
    }
    @objc private func handleReorderGesture(_ gesture: UILongPressGestureRecognizer) {
        let tableView = violationsTableView
        let location = gesture.location(in: tableView)
        lastTouchLocationInTable = location
        
        switch gesture.state {
        case .began:
            guard let indexPath = tableView.indexPathForRow(at: location) else {
                return
            }
            guard let cell = tableView.cellForRow(at: indexPath) else {
                return
            }
            reorderSourceIndexPath = indexPath
            touchOffsetFromCellCenterY = location.y - cell.center.y
            let snapshot = makeSnapshot(from: cell)
            snapshot.center = CGPoint(x: cell.center.x, y: location.y - touchOffsetFromCellCenterY)
            snapshot.alpha = 0.95
            tableView.addSubview(snapshot)
            reorderSnapshotView = snapshot
            cell.isHidden = true
            tableView.isScrollEnabled = false
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            UIView.animate(withDuration: 0.15) {
                snapshot.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
            }
        case .changed:
            guard let snapshot = reorderSnapshotView else {
                return
            }
            snapshot.center.y = location.y - touchOffsetFromCellCenterY
            configureAutoscrollIfNeeded(at: location)
            updateReorder(at: location)
        default:
            stopAutoscroll()
            guard let sourceIndexPath = reorderSourceIndexPath,
                  let cell = tableView.cellForRow(at: sourceIndexPath) else {
                reorderSnapshotView?.removeFromSuperview()
                reorderSnapshotView = nil
                reorderSourceIndexPath = nil
                tableView.isScrollEnabled = true
                return
            }
            UIView.animate(withDuration: 0.15, animations: {
                self.reorderSnapshotView?.transform = .identity
                self.reorderSnapshotView?.center = cell.center
            }, completion: { _ in
                cell.isHidden = false
                self.reorderSnapshotView?.removeFromSuperview()
                self.reorderSnapshotView = nil
                self.reorderSourceIndexPath = nil
                tableView.isScrollEnabled = true
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                self.persistViolationsOrder()
            })
        }
    }

    private func updateReorder(at location: CGPoint) {
        let tableView = violationsTableView
        guard let sourceIndexPath = reorderSourceIndexPath else {
            return
        }
        guard let newIndexPath = tableView.indexPathForRow(at: location) else {
            return
        }
        guard newIndexPath != sourceIndexPath else {
            // Ничего не делаем, палец внутри той же ячейки
            return
        }

        // Обновляем данные и UI мгновенно (без мутации let массива в AKT)
        var newViolations = akt.violations
        let movedViolation = newViolations.remove(at: sourceIndexPath.row)
        newViolations.insert(movedViolation, at: newIndexPath.row)
        akt = makeAkt(with: newViolations)
        tableView.moveRow(at: sourceIndexPath, to: newIndexPath)
        reorderSourceIndexPath = newIndexPath
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func configureAutoscrollIfNeeded(at location: CGPoint) {
        let tableView = violationsTableView
        let edgeInset: CGFloat = 140
        let maxSpeed: CGFloat = 720 // pt/sec
        var direction: CGFloat = 0
        var speed: CGFloat = 0

        if location.y < edgeInset {
            direction = -1
            let distance = max(0, edgeInset - location.y)
            speed = maxSpeed * (distance / edgeInset)
        } else if location.y > tableView.bounds.height - edgeInset {
            direction = 1
            let distance = max(0, location.y - (tableView.bounds.height - edgeInset))
            speed = maxSpeed * (distance / edgeInset)
        }

        if direction == 0 {
            stopAutoscroll()
            return
        }

        autoScrollDirection = direction
        autoScrollSpeed = speed

        if direction != lastAutoScrollDirection || abs(speed - lastAutoScrollSpeed) > 10 {
            lastAutoScrollDirection = direction
            lastAutoScrollSpeed = speed
        }

        if autoScrollDisplayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(handleAutoscrollTick))
            link.add(to: .main, forMode: .common)
            autoScrollDisplayLink = link
        }
    }

    private func stopAutoscroll() {
        guard let link = autoScrollDisplayLink else { return }
        link.invalidate()
        autoScrollDisplayLink = nil
        autoScrollDirection = 0
        autoScrollSpeed = 0
    }

    @objc private func handleAutoscrollTick() {
        guard autoScrollDirection != 0,
              let snapshot = reorderSnapshotView else { return }

        let tableView = violationsTableView
        let frameDuration: CGFloat = CGFloat(autoScrollDisplayLink?.duration ?? (1.0/60.0))
        let delta = autoScrollSpeed * autoScrollDirection * frameDuration
        let oldOffsetY = tableView.contentOffset.y
        let maxOffsetY = max(0, tableView.contentSize.height - tableView.bounds.height)
        var newOffsetY = oldOffsetY + delta
        newOffsetY = min(max(newOffsetY, 0), maxOffsetY)

        guard newOffsetY != oldOffsetY else { return }

        tableView.contentOffset.y = newOffsetY

        // Двигаем snapshot и запоминаем позицию пальца в координатах таблицы
        let scrollDelta = newOffsetY - oldOffsetY
        snapshot.center.y += scrollDelta
        lastTouchLocationInTable.y += scrollDelta

        // Обновляем порядок при автопрокрутке (без движения пальца)
        updateReorder(at: lastTouchLocationInTable)
    }

    private func makeSnapshot(from view: UIView) -> UIView {
        let snapshot = UIView(frame: view.bounds)
        snapshot.layer.cornerRadius = 16
        snapshot.layer.masksToBounds = false
        snapshot.layer.shadowColor = UIColor.black.cgColor
        snapshot.layer.shadowOpacity = 0.15
        snapshot.layer.shadowRadius = 8
        snapshot.layer.shadowOffset = CGSize(width: 0, height: 4)
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        let image = renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let imageView = UIImageView(image: image)
        imageView.frame = snapshot.bounds
        imageView.layer.cornerRadius = 16
        imageView.layer.masksToBounds = true
        snapshot.addSubview(imageView)
        return snapshot
    }

    private func persistViolationsOrder() {
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate
        )
        akt = updatedAkt
        if DataFlowAKT.getEditableAKT() != nil {
            DataFlowAKT.updateEditableAKT(updatedAkt)
        }
        if let index = viewModel.aktArray.firstIndex(where: { $0.id == updatedAkt.id }) {
            var arr = viewModel.aktArray
            arr[index] = updatedAkt
            viewModel.aktArray = arr
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        SimpleRealtimeAKTManager.shared.updateViolations(updatedAkt.violations)
    }
}

