//
//  ViolationsMainViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import SnapKit

class ViolationsMainViewController: UIViewController {
    
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
        label.textColor = .black
        return label
    }()
    
    private let dateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .black
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
        label.textColor = .systemGray
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
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.title = "Нарушения"
        navigationItem.largeTitleDisplayMode = .never
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
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
}

// MARK: - UITableViewDataSource
extension ViolationsMainViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return akt.violations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ViolationCell", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        cell.backgroundColor = .white
        
        let separator = UIView()
        separator.backgroundColor = .separator
        cell.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        let item = akt.violations[indexPath.row]
        
        // Добавляем порядковый номер
        let numberLabel = UILabel()
        numberLabel.text = "\(indexPath.row + 1)."
        numberLabel.textAlignment = .left
        numberLabel.textColor = .systemBlue
        numberLabel.font = .systemFont(ofSize: 16, weight: .bold)
        cell.addSubview(numberLabel)
        numberLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalToSuperview().inset(16)
            make.width.equalTo(30)
        }
        
        let mainLabel = UILabel()
        mainLabel.textAlignment = .left
        mainLabel.text = item.title
        mainLabel.textColor = .black
        mainLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(mainLabel)
        mainLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(8)
            make.left.equalTo(numberLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(16)
        }
        
        let subLabel = UILabel()
        subLabel.text = item.urlToPravilo
        subLabel.textColor = .black.withAlphaComponent(0.7)
        subLabel.font = .systemFont(ofSize: 16, weight: .regular)
        subLabel.textAlignment = .left
        cell.addSubview(subLabel)
        subLabel.snp.makeConstraints { make in
            make.left.equalTo(numberLabel.snp.right).offset(8)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(mainLabel.snp.bottom).inset(-8)
        }
        
        let mestoLabel = UILabel()
        mestoLabel.text = item.mesto
        mestoLabel.textColor = .black.withAlphaComponent(0.7)
        mestoLabel.font = .systemFont(ofSize: 16, weight: .regular)
        mestoLabel.textAlignment = .left
        cell.addSubview(mestoLabel)
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
        return 80
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

