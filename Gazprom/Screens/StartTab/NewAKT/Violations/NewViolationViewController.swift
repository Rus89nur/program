//
//  NewViolationViewController.swift
//  Gazprom
//
//  Created by Владимир on 11.07.2025.
//

import UIKit

class NewViolationViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    var violations: [Violations] = []
    
    var akt: AKT?
    private var isDragModeEnabled = false
    private var isDragging = false
    private var draggedIndexPath: IndexPath?
    
    // Ссылки на кнопки для скрытия в режиме перетаскивания
    private var nextButton: UIButton?
    private var addButton: UIBarButtonItem?
    private var homeButton: UIBarButtonItem?
    
    // Таймер для автоматической прокрутки
    private var scrollTimer: Timer?
    
    // Текущая позиция пальца для автоматической прокрутки
    private var currentTouchLocation: CGPoint = .zero
    
    // Последнее время прокрутки для дебаунса
    private var lastScrollTime: TimeInterval = 0
    
    // Последнее время обновления визуальных эффектов
    private var lastVisualUpdateTime: TimeInterval = 0
    
    // Генератор вибрации
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], akt: AKT?) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.akt = akt
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
        title = "Нарушения"
        setupViewModel()
        
        // Если есть акт, но нет редактируемого акта, создаем его
        if let akt = akt, DataFlowAKT.getEditableAKT() == nil {
            print("🔧 Создаем редактируемый акт из переданного акта №\(akt.number)")
            viewModel.editExistingAkt(akt)
        }
        
        // Синхронизируем изменения с актом при появлении экрана
        syncViolationsWithAkt()
        
        let addButton = UIFactory.createButton(title: "Добавить", color: .systemBlue)
        addButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        addButton.layer.cornerRadius = 12
        addButton.snp.makeConstraints { make in
            make.width.equalTo(110)
            make.height.equalTo(34)
        }
        let item = UIBarButtonItem(customView: addButton)
        self.addButton = item
        
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        let item1 = UIBarButtonItem(customView: goBackButton)
        self.homeButton = item1
        goBackButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
        goBackButton.alpha = 0.5
        
        navigationItem.rightBarButtonItems = [item1, item]
        addButton.addTarget(self, action: #selector(openAddNewViolatation), for: .touchUpInside)
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
    
    @objc private func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Синхронизируем все изменения с актом или черновиком
        syncViolationsWithAkt()
        
        // Если есть редактируемый акт, переносим его в историю
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("🔄 Переносим редактируемый акт в историю")
            
            // Проверяем, есть ли уже акт с таким номером в истории
            let historyArray = DataFlowAKT.loadHistoryArrFromFile() ?? []
            let existingAkt = historyArray.first(where: { $0.number == editableAkt.akt.number })
            
            if existingAkt != nil {
                print("   Акт №\(editableAkt.akt.number) уже существует в истории, обновляем его")
                // Если акт уже существует, обновляем его
                DataFlowAKT.updateExistingAktInHistory(editableAkt.akt)
            } else {
                print("   Акт №\(editableAkt.akt.number) новый, добавляем в историю")
                // Если акт новый, добавляем в историю
                DataFlowAKT.moveEditableToHistory()
            }
            
            // Обновляем массив актов в ViewModel
            viewModel.refreshAktArray()
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        checkOld()
        setupLongPressGesture()
        
        // Настройка данных header (только если есть akt)
        if akt != nil {
            configureHeaderData()
        }
        
        // Настройка темной темы
        setupDarkTheme()
        
        // Отладочная информация
        print("🔍 NewViolationViewController viewDidLoad:")
        print("   isDragModeEnabled: \(isDragModeEnabled)")
        print("   isDragging: \(isDragging)")
        print("   violations.count: \(violations.count)")
        print("   akt: \(akt != nil ? "есть" : "нет")")
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
        guard let akt = akt else { return }
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
        
        let violationsAction = UIAlertAction(title: "⚠️ Нарушения", style: .default) { [weak self] _ in
            self?.navigateToEditStep(.violations, akt: akt)
        }
        
        let userDescriptionAction = UIAlertAction(title: "📝 Описание", style: .default) { [weak self] _ in
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
        alert.addAction(violationsAction)
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
        let targetVC = createEditViewControllerForStep(step, akt: akt)
        
        if let navigationController = navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep, akt: AKT) -> UIViewController {
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
    
    @objc func goNext() {
        // Сохраняем черновик перед переходом к следующему шагу
        viewModel.templateModel.violations = self.violations
        viewModel.saveDraft(currentStep: .userDescription)
        
        let vc = UserDescriptionViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, akt: akt)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openAddNewViolatation() {
        let vc = NewViolationToAktViewController(vc: self, model: viewModel)
        present(vc, animated: true)
    }
    
    private func openEditAlert(index: Int) {
        let violation = violations[index]
        let editVC = EditViolationViewController(violation: violation) { [weak self] updatedViolation in
            guard let self = self else { return }
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
        longPressGesture.minimumPressDuration = 0.3
        longPressGesture.delegate = self
        tableView.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        
        // Сохраняем текущую позицию пальца для автоматической прокрутки
        currentTouchLocation = location
        
        switch gesture.state {
        case .began:
            // Добавляем вибрацию при удержании пальца
            impactFeedback.impactOccurred()
            
            // Входим в режим перетаскивания
            startDragMode(for: indexPath)
            
        case .changed:
            // Обновляем позицию пальца
            currentTouchLocation = gesture.location(in: tableView)
            print("📍 Touch location updated: \(currentTouchLocation)")
            
            // Обновляем позицию перетаскиваемой ячейки
            if isDragModeEnabled && isDragging {
                let newLocation = gesture.location(in: tableView)
                
                // Более точная проверка позиции - проверяем, что палец действительно находится над другой ячейкой
                if let newIndexPath = tableView.indexPathForRow(at: newLocation), 
                   newIndexPath != draggedIndexPath,
                   newIndexPath.row < violations.count {
                    
                    // Дополнительная проверка: убеждаемся, что палец находится в центре ячейки
                    let cellRect = tableView.rectForRow(at: newIndexPath)
                    let touchY = newLocation.y
                    
                    // Проверяем, что палец находится в пределах ячейки (с небольшим отступом)
                    let cellTop = cellRect.minY + 20
                    let cellBottom = cellRect.maxY - 20
                    
                    if touchY >= cellTop && touchY <= cellBottom {
                        // Перемещаем элемент в массиве
                        let movedViolation = violations.remove(at: draggedIndexPath!.row)
                        violations.insert(movedViolation, at: newIndexPath.row)
                        
                        // Используем moveRowAt вместо reloadData для плавного перемещения
                        tableView.moveRow(at: draggedIndexPath!, to: newIndexPath)
                        
                        // Обновляем draggedIndexPath только после успешного перемещения
                        draggedIndexPath = newIndexPath
                        
                        // Сохраняем изменения (только периодически для производительности)
                        if newIndexPath.row % 3 == 0 { // Сохраняем каждые 3 перемещения
                            viewModel.templateModel.violations = violations
                            viewModel.saveDraft(currentStep: .violations)
                            
                            // Синхронизируем изменения с актом
                            syncViolationsWithAkt()
                        }
                    }
                }
            }
            
        case .ended, .cancelled:
            // Завершаем перетаскивание
            if isDragModeEnabled {
                isDragging = false
                
                // Финальное сохранение изменений
                viewModel.templateModel.violations = violations
                viewModel.saveDraft(currentStep: .violations)
                
                // Синхронизируем изменения с актом
                syncViolationsWithAkt()
                
                endDragMode()
            }
            
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
        print("🔄 Синхронизируем нарушения")
        print("   Количество нарушений: \(violations.count)")
        print("   Есть ли акт: \(akt != nil ? "да" : "нет")")
        if let akt = akt {
            print("   ID акта: \(akt.id)")
            print("   Номер акта: \(akt.number)")
        }
        
        // Обновляем нарушения в templateModel
        viewModel.templateModel.violations = violations
        
        // Проверяем, есть ли редактируемый акт
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("   Редактируемый акт найден: №\(editableAkt.akt.number)")
            
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
            
            // Обновляем локальную ссылку на акт
            self.akt = updatedAkt
            
            print("   ✅ Редактируемый акт обновлен")
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        } else if let akt = akt {
            // Если есть локальный акт, но нет редактируемого (старая логика)
            print("   Локальный акт найден: №\(akt.number)")
            
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
            
            print("   ✅ Создан редактируемый акт из локального")
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.viewModel.continueButtonUpdateBinding?()
            }
        } else {
            // Если нет ни редактируемого, ни локального акта (черновик)
            print("   Черновик режим - создаем новый акт")
            
            guard let date = viewModel.templateModel.date,
                  let aktNumber = viewModel.templateModel.aktNumber else {
                print("   ⚠️ Недостаточно данных для создания акта")
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
            
            print("   ✅ Новый акт создан и сделан редактируемым: №\(aktNumber)")
            
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
        
        print("🚀 Starting drag mode for row \(indexPath.row)")
        
        // Отключаем прокрутку таблицы во время перетаскивания
        tableView.isScrollEnabled = false
        
        // Запускаем автоматическую прокрутку
        startAutoScroll()
        print("🔄 Auto scroll started")
        
        // Скрываем кнопки "Далее" и "Добавить"
        nextButton?.isHidden = true
        navigationItem.rightBarButtonItems = nil
        
        // Обновляем ячейки для показа индикаторов перетаскивания
        tableView.reloadData()
    }
    
    private func endDragMode() {
        isDragModeEnabled = false
        isDragging = false
        draggedIndexPath = nil
        
        // Останавливаем автоматическую прокрутку
        stopAutoScroll()
        
        // Включаем прокрутку таблицы обратно
        tableView.isScrollEnabled = true
        
        // Восстанавливаем кнопки "Далее" и "Добавить"
        nextButton?.isHidden = false
        if let homeButton = homeButton, let addButton = addButton {
            navigationItem.rightBarButtonItems = [homeButton, addButton]
        }
        
        // Обновляем ячейки для скрытия индикаторов
        tableView.reloadData()
    }
    
    // MARK: - Автоматическая прокрутка
    private func startAutoScroll() {
        print("⏰ Starting auto scroll timer with interval 0.12")
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            self?.performAutoScroll()
        }
    }
    
    private func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    private func performAutoScroll() {
        guard isDragModeEnabled && isDragging else { return }
        
        // Дебаунс - не чаще чем раз в 0.08 секунды для более стабильной работы
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastScrollTime > 0.08 else { return }
        
        let scrollThreshold: CGFloat = 100 // Увеличиваем зону для прокрутки
        let scrollSpeed: CGFloat = 6 // Уменьшаем скорость для более плавной прокрутки
        
        // Проверяем, можем ли прокручиваться
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        let currentOffset = tableView.contentOffset.y
        
        // Определяем направление прокрутки
        let distanceToBottom = tableView.bounds.height - currentTouchLocation.y
        let distanceToTop = currentTouchLocation.y
        
        print("🔄 Auto scroll: bottom=\(Int(distanceToBottom)), top=\(Int(distanceToTop)), offset=\(Int(currentOffset))/\(Int(maxOffset)), threshold=\(Int(scrollThreshold))")
        
        // Улучшенная логика прокрутки
        var shouldScroll = false
        var scrollDirection: String = ""
        
        // Проверяем прокрутку вниз
        if distanceToBottom < scrollThreshold && currentOffset < maxOffset - 10 {
            shouldScroll = true
            scrollDirection = "down"
            print("⬇️ Should scroll down - distance to bottom: \(Int(distanceToBottom))")
        }
        // Проверяем прокрутку вверх
        else if distanceToTop < scrollThreshold && currentOffset > 10 {
            shouldScroll = true
            scrollDirection = "up"
            print("⬆️ Should scroll up - distance to top: \(Int(distanceToTop))")
        }
        
        if shouldScroll {
            if scrollDirection == "down" {
                scrollDown(speed: scrollSpeed)
            } else if scrollDirection == "up" {
                scrollUp(speed: scrollSpeed)
            }
            lastScrollTime = currentTime
        } else {
            print("⏸️ No scroll needed")
        }
    }
    
    private func scrollDown(speed: CGFloat = 8) {
        let currentOffset = tableView.contentOffset
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        let newOffset = CGPoint(x: currentOffset.x, y: min(currentOffset.y + speed, maxOffset))
        
        // Проверяем, что новая позиция отличается от текущей
        guard newOffset.y != currentOffset.y else { return }
        
        print("⬇️ Scrolling from \(currentOffset.y) to \(newOffset.y)")
        
        // Временно включаем прокрутку для программной прокрутки
        let wasScrollEnabled = tableView.isScrollEnabled
        tableView.isScrollEnabled = true
        tableView.setContentOffset(newOffset, animated: false)
        tableView.isScrollEnabled = wasScrollEnabled
    }
    
    private func scrollUp(speed: CGFloat = 8) {
        let currentOffset = tableView.contentOffset
        let newOffset = CGPoint(x: currentOffset.x, y: max(currentOffset.y - speed, 0))
        
        // Проверяем, что новая позиция отличается от текущей
        guard newOffset.y != currentOffset.y else { return }
        
        print("⬆️ Scrolling from \(currentOffset.y) to \(newOffset.y)")
        
        // Временно включаем прокрутку для программной прокрутки
        let wasScrollEnabled = tableView.isScrollEnabled
        tableView.isScrollEnabled = true
        tableView.setContentOffset(newOffset, animated: false)
        tableView.isScrollEnabled = wasScrollEnabled
    }

}

// MARK: - UIGestureRecognizerDelegate
extension NewViolationViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
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
            mainLabel.textColor = .black
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
            subLabel.textColor = .black.withAlphaComponent(0.7)
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
            mestoLabel.textColor = .black.withAlphaComponent(0.7)
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
        
        // Визуальные эффекты для перетаскиваемой ячейки (с дебаунсом для производительности)
        let currentTime = CACurrentMediaTime()
        if isDragModeEnabled && draggedIndexPath == indexPath && isDragging && 
           currentTime - lastVisualUpdateTime > 0.1 {
            
            // Изменяем шрифт на больший
            mainLabel.font = .systemFont(ofSize: 18, weight: .bold)
            subLabel.font = .systemFont(ofSize: 17, weight: .medium)
            mestoLabel.font = .systemFont(ofSize: 17, weight: .medium)
            
            // Изменяем цвет фона на серый
            containerView.backgroundColor = UIColor.systemGray5
            
            lastVisualUpdateTime = currentTime
        } else if !isDragModeEnabled || draggedIndexPath != indexPath || !isDragging {
            // Возвращаем обычные стили
            mainLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            subLabel.font = .systemFont(ofSize: 16, weight: .regular)
            mestoLabel.font = .systemFont(ofSize: 16, weight: .regular)
            // Восстанавливаем правильный цвет фона для темы
            if traitCollection.userInterfaceStyle == .dark {
                containerView.backgroundColor = .systemGray6
            } else {
                containerView.backgroundColor = .systemGray6
            }
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Отключаем свайп-действия во время перетаскивания
        if isDragModeEnabled {
            print("🚫 Свайп-действия отключены - режим перетаскивания активен")
            return UISwipeActionsConfiguration(actions: [])
        }
        
        print("✅ Свайп-действия включены для строки \(indexPath.row)")
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            self.violations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
            // Синхронизируем изменения с актом
            self.syncViolationsWithAkt()
            
            completionHandler(true)
        }
        
        let editAction = UIContextualAction(style: .destructive, title: "Изменить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            openEditAlert(index: indexPath.row)
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .systemRed
        editAction.backgroundColor = .systemOrange

        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 100
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isDragModeEnabled {
            // В режиме перетаскивания не показываем информацию
            tableView.deselectRow(at: indexPath, animated: true)
        } else {
            // Показываем информацию о нарушении при коротком нажатии
            tableView.deselectRow(at: indexPath, animated: true)
            let violation = violations[indexPath.row]
            showViolationInfo(for: violation)
        }
    }
    
}
