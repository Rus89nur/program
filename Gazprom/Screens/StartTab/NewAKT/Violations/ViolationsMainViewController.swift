//
//  ViolationsMainViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import SnapKit

class ViolationsMainViewController: UIViewController, UITableViewDragDelegate, UITableViewDropDelegate {
    
    private let viewModel: MainAKTViewModel
    private let akt: AKT
    
    
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
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureData()
        
        // Настройка темной темы
        setupDarkTheme()
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
        navigationItem.title = "Нарушения"
        navigationItem.largeTitleDisplayMode = .never
        
        // Добавляем кнопку "домик" для возврата на главный экран
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        let homeButton = UIBarButtonItem(customView: goBackButton)
        goBackButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
        goBackButton.alpha = 0.5
        
        navigationItem.rightBarButtonItem = homeButton
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
        
        // Включаем перетаскивание для изменения порядка
        violationsTableView.dragInteractionEnabled = true
        violationsTableView.dragDelegate = self
        violationsTableView.dropDelegate = self
        
        // Настраиваем обработку ошибок drag and drop
        setupDragAndDropErrorHandling()
        
        // Настройка действий
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
        
        let userDescriptionAction = UIAlertAction(title: "📝 Описание", style: .default) { [weak self] _ in
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
        // Удаляем нарушение из АКТ
        var updatedViolations = akt.violations
        updatedViolations.remove(at: index)
        
        // Создаем обновленный АКТ
        let updatedAkt = AKT(
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
        
        // Обновляем АКТ в массиве
        if let index = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            viewModel.aktArray[index] = updatedAkt
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        // Обновляем текущий АКТ
        // Нужно обновить akt в контроллере, но поскольку он let, создадим новый экземпляр
        // В реальном приложении лучше было бы использовать ссылку на массив
        
        // Обновляем отображение
        violationsTableView.reloadData()
        updateEmptyState()
    }
    
    private func updateViolation(_ updatedViolation: Violations, at index: Int) {
        // Обновляем нарушение в АКТ
        var updatedViolations = akt.violations
        updatedViolations[index] = updatedViolation
        
        // Создаем обновленный АКТ
        let updatedAkt = AKT(
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
        
        // Обновляем АКТ в массиве
        if let index = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            viewModel.aktArray[index] = updatedAkt
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
        }
        
        // Обновляем отображение
        violationsTableView.reloadData()
    }
    
    // MARK: - UITableViewDragDelegate
    func tableView(_ tableView: UITableView, itemsForBeginning session: UIDragSession, at indexPath: IndexPath) -> [UIDragItem] {
        // Проверяем, что индекс валидный
        guard indexPath.row < akt.violations.count else {
            print("⚠️ Неверный индекс для drag: \(indexPath.row), всего нарушений: \(akt.violations.count)")
            return []
        }
        
        let violation = akt.violations[indexPath.row]
        
        // Создаем itemProvider с правильным типом данных
        let itemProvider = NSItemProvider()
        
        // Регистрируем данные с правильной обработкой ошибок
        itemProvider.registerDataRepresentation(forTypeIdentifier: "public.text", visibility: .all) { completion in
            guard let data = violation.title.data(using: .utf8) else {
                print("❌ Ошибка кодирования текста нарушения")
                completion(nil, NSError(domain: "DragError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ошибка кодирования текста"]))
                return nil
            }
            completion(data, nil)
            return nil
        }
        
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = violation
        return [dragItem]
    }
    
    // MARK: - UITableViewDropDelegate
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        return UITableViewDropProposal(operation: .move, intent: .insertAtDestinationIndexPath)
    }
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        guard let destinationIndexPath = coordinator.destinationIndexPath,
              let sourceIndexPath = coordinator.items.first?.sourceIndexPath else {
            print("⚠️ Неверные индексы для drop операции")
            return
        }
        
        // Проверяем валидность индексов
        guard sourceIndexPath.row < akt.violations.count,
              destinationIndexPath.row <= akt.violations.count,
              sourceIndexPath.row != destinationIndexPath.row else {
            print("⚠️ Недопустимые индексы для drop: source=\(sourceIndexPath.row), destination=\(destinationIndexPath.row), всего=\(akt.violations.count)")
            return
        }
        
        // Перемещаем нарушение в новую позицию
        var updatedViolations = akt.violations
        let movedViolation = updatedViolations.remove(at: sourceIndexPath.row)
        
        // Корректируем индекс назначения если нужно
        let adjustedDestinationIndex = destinationIndexPath.row > sourceIndexPath.row ? destinationIndexPath.row - 1 : destinationIndexPath.row
        updatedViolations.insert(movedViolation, at: adjustedDestinationIndex)
        
        // Создаем обновленный АКТ
        let updatedAkt = AKT(
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
        
        // Обновляем АКТ в массиве
        if let index = viewModel.aktArray.firstIndex(where: { $0.id == akt.id }) {
            viewModel.aktArray[index] = updatedAkt
            DataFlowAKT.saveArr(arr: viewModel.aktArray)
            print("✅ Нарушение перемещено с позиции \(sourceIndexPath.row) на \(adjustedDestinationIndex)")
        }
        
        // Обновляем отображение
        violationsTableView.reloadData()
    }
    
    // MARK: - Drag and Drop Error Handling
    private func setupDragAndDropErrorHandling() {
        // Обработка ошибок drag and drop
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDragAndDropError),
            name: NSNotification.Name("DragAndDropError"),
            object: nil
        )
    }
    
    @objc private func handleDragAndDropError() {
        print("⚠️ Обнаружена ошибка drag and drop")
        print("🔄 Очистка ресурсов drag and drop...")
        
        // Очищаем ресурсы drag and drop
        violationsTableView.dragInteractionEnabled = false
        violationsTableView.dragDelegate = nil
        violationsTableView.dropDelegate = nil
        
        // Перезапускаем drag and drop через небольшую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.violationsTableView.dragInteractionEnabled = true
            self.violationsTableView.dragDelegate = self
            self.violationsTableView.dropDelegate = self
            print("✅ Ресурсы drag and drop очищены")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - UITableViewDataSource
extension ViolationsMainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return akt.violations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ViolationCell", for: indexPath)
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
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ViolationsMainViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Показываем подробную информацию о нарушении
        let violation = akt.violations[indexPath.row]
        showViolationInfo(for: violation)
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 100
    }
    
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let violation = akt.violations[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let editAction = UIAction(title: "Редактировать", image: UIImage(systemName: "pencil")) { _ in
                self.editViolation(violation, at: indexPath.row)
            }
            
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.deleteViolation(at: indexPath.row)
            }
            
        return UIMenu(title: "", children: [editAction, deleteAction])
        }
    }
}

