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
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Нарушения"
        setupViewModel()
        
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
        viewModel.templateModel.violations = self.violations
        
        // Сохраняем черновик при уходе с экрана
        if !violations.isEmpty {
            viewModel.saveDraft(currentStep: .violations)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
       setupUI()
        checkOld()
        setupLongPressGesture()
    }
    
    private func checkOld() {
        if let a = akt {
            violations = a.violations
            tableView.reloadData()
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
        tableView.delegate  = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
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
            
            // Обновляем позицию перетаскиваемой ячейки
            if isDragModeEnabled && isDragging {
                let newLocation = gesture.location(in: tableView)
                if let newIndexPath = tableView.indexPathForRow(at: newLocation), 
                   newIndexPath != draggedIndexPath,
                   newIndexPath.row < violations.count {
                    
                    // Перемещаем элемент в массиве
                    let movedViolation = violations.remove(at: draggedIndexPath!.row)
                    violations.insert(movedViolation, at: newIndexPath.row)
                    
                    // Обновляем таблицу без анимации для избежания дергания
                    tableView.reloadData()
                    
                    // Обновляем draggedIndexPath только после успешного перемещения
                    draggedIndexPath = newIndexPath
                    
                    // Сохраняем изменения
                    viewModel.templateModel.violations = violations
                    viewModel.saveDraft(currentStep: .violations)
                }
            }
            
            // Принудительно обновляем позицию для автоматической прокрутки
            currentTouchLocation = gesture.location(in: tableView)
            
        case .ended, .cancelled:
            // Завершаем перетаскивание
            if isDragModeEnabled {
                isDragging = false
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
    
    private func startDragMode(for indexPath: IndexPath) {
        isDragModeEnabled = true
        draggedIndexPath = indexPath
        isDragging = true
        
        // Отключаем прокрутку таблицы во время перетаскивания
        tableView.isScrollEnabled = false
        
        // Запускаем автоматическую прокрутку
        startAutoScroll()
        
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
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { [weak self] _ in
            self?.performAutoScroll()
        }
    }
    
    private func stopAutoScroll() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    
    private func performAutoScroll() {
        guard isDragModeEnabled && isDragging else { return }
        
        // Дебаунс - не чаще чем раз в 0.03 секунды
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastScrollTime > 0.03 else { return }
        
        let downScrollThreshold: CGFloat = 80 // Зона для прокрутки вниз
        let upScrollThreshold: CGFloat = 120 // Зона для прокрутки вверх
        let downScrollSpeed: CGFloat = 8 // Скорость прокрутки вниз
        let upScrollSpeed: CGFloat = 8 // Скорость прокрутки вверх
        
        // Проверяем, можем ли прокручиваться
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        let currentOffset = tableView.contentOffset.y
        
        // Прокрутка вниз, если палец в нижней части экрана и есть место для прокрутки
        if currentTouchLocation.y > tableView.bounds.height - downScrollThreshold && currentOffset < maxOffset - 5 {
            scrollDown(speed: downScrollSpeed)
            lastScrollTime = currentTime
        }
        // Прокрутка вверх, если палец в верхней части экрана и есть место для прокрутки
        else if currentTouchLocation.y < upScrollThreshold && currentOffset > 5 {
            scrollUp(speed: upScrollSpeed)
            lastScrollTime = currentTime
        }
        
        // Дополнительная проверка: если элемент перетаскивается вверх, принудительно прокручиваем вверх
        if let draggedIndexPath = draggedIndexPath {
            let cellRect = tableView.rectForRow(at: draggedIndexPath)
            let cellCenterY = cellRect.midY
            let viewCenterY = tableView.bounds.midY
            
            // Если ячейка выше центра экрана, прокручиваем вверх
            if cellCenterY < viewCenterY && currentOffset > 5 {
                scrollUp(speed: upScrollSpeed)
                lastScrollTime = currentTime
            }
            // Если ячейка ниже центра экрана, прокручиваем вниз
            else if cellCenterY > viewCenterY && currentOffset < maxOffset - 5 {
                scrollDown(speed: downScrollSpeed)
                lastScrollTime = currentTime
            }
        }
    }
    
    private func scrollDown(speed: CGFloat = 10) {
        let currentOffset = tableView.contentOffset
        let maxOffset = max(0, tableView.contentSize.height - tableView.bounds.height)
        let newOffset = CGPoint(x: currentOffset.x, y: min(currentOffset.y + speed, maxOffset))
        
        // Временно включаем прокрутку для программной прокрутки
        let wasScrollEnabled = tableView.isScrollEnabled
        tableView.isScrollEnabled = true
        tableView.setContentOffset(newOffset, animated: false)
        tableView.isScrollEnabled = wasScrollEnabled
    }
    
    private func scrollUp(speed: CGFloat = 10) {
        let currentOffset = tableView.contentOffset
        let newOffset = CGPoint(x: currentOffset.x, y: max(currentOffset.y - speed, 0))
        
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
        
        cell.backgroundColor = .white
        
        let separator = UIView()
        separator.backgroundColor = .separator
        cell.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.height.equalTo(0.5)
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        
        let item = violations[indexPath.row]
        
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
        
        // Добавляем индикатор перетаскивания в режиме редактирования
        if isDragModeEnabled {
            let dragIndicator = UIImageView(image: UIImage(systemName: "line.3.horizontal"))
            dragIndicator.tintColor = .systemGray3
            cell.addSubview(dragIndicator)
            dragIndicator.snp.makeConstraints { make in
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
                make.width.equalTo(20)
                make.height.equalTo(16)
            }
        }
        
        // Визуальные эффекты для перетаскиваемой ячейки
        if isDragModeEnabled && draggedIndexPath == indexPath && isDragging {
            // Изменяем шрифт на больший
            mainLabel.font = .systemFont(ofSize: 18, weight: .bold)
            subLabel.font = .systemFont(ofSize: 17, weight: .medium)
            mestoLabel.font = .systemFont(ofSize: 17, weight: .medium)
            
            // Изменяем цвет фона на серый
            cell.backgroundColor = UIColor.systemGray5
        } else {
            // Возвращаем обычные стили
            mainLabel.font = .systemFont(ofSize: 16, weight: .semibold)
            subLabel.font = .systemFont(ofSize: 16, weight: .regular)
            mestoLabel.font = .systemFont(ofSize: 16, weight: .regular)
            cell.backgroundColor = .white
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        // Отключаем свайп-действия во время перетаскивания
        if isDragModeEnabled {
            return UISwipeActionsConfiguration(actions: [])
        }
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            self.violations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
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
        return 86
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
