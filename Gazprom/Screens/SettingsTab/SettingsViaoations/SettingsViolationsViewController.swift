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
    
    var items = ViolationsModel.returnAvialableViolation()
    private var filteredItems: [ViolationsModel.Violation] = []
    
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
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
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
        
        view.addSubview(loadButton)
        loadButton.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.left.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.centerX).offset(-4)
        }
        
        view.addSubview(exportButton)
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
            print("✅ Путь сохранен в UserDefaults: \(destinationURL.path)")

            print("🔍 Загружаем нарушения из файла...")
            items = ViolationsModel.returnAvialableViolation()
            filteredItems = items
            print("📊 Загружено нарушений в UI: \(items.count)")
            
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
        if items.count > 0 {
            let plusButton = UIButton(type: .system)
            plusButton.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
            plusButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
            }
            plusButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
            let item = UIBarButtonItem(customView: plusButton)
            self.navigationItem.setRightBarButton(item, animated: true)
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    
    @objc private func addNew() {
        let alert = UIAlertController(title: "Добавление нарушения", message: "Заполните все поля", preferredStyle: .alert)
        
        alert.addTextField() //0
        alert.addTextField() //1
        alert.addTextField() //2
        alert.addTextField() //3
        alert.addTextField() //4
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        alert.textFields?[0].placeholder = "Номер"
        alert.textFields?[1].placeholder = "Формулировка"
        alert.textFields?[2].placeholder = "Ссылка на норм. документ"
        alert.textFields?[3].placeholder = "Примечание"
        alert.textFields?[4].placeholder = "Вид нарушения"
        
        let save = UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            let number: Int =  Int(alert.textFields?[0].text ?? "0") ?? 0
            let form: String =  alert.textFields?[1].text ?? "-"
            let url: String =  alert.textFields?[2].text ?? "-"
            let desc: String =  alert.textFields?[3].text ?? "-"
            let vid: String =  alert.textFields?[4].text ?? "-"
            
            let violataion = ViolationsModel.Violation(number: number, titie: form, subTitle: url, description: desc, vid: vid)
            ViolationsModel.addNewViolation(violation: violataion)
            
            items = ViolationsModel.returnAvialableViolation()
            filteredItems = items
            tableView.reloadData()
            
        }
        alert.addAction(save)
        
        present(alert, animated: true)
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
        // Подсчитываем количество нарушений в базе для автоматического номера
        let allViolations = ViolationsModel.returnAvialableViolation()
        let nextNumber = allViolations.count + 1
        
        let alert = UIAlertController(title: "Добавление нарушения", message: "Заполните все поля", preferredStyle: .alert)
        
        alert.addTextField() //0 - Номер
        alert.addTextField() //1 - Формулировка
        alert.addTextField() //2 - Ссылка на норм. документ
        alert.addTextField() //3 - Примечание
        alert.addTextField() //4 - Вид нарушения
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        alert.textFields?[0].placeholder = "Номер"
        alert.textFields?[1].placeholder = "Формулировка"
        alert.textFields?[2].placeholder = "Ссылка на норм. документ"
        alert.textFields?[3].placeholder = "Примечание"
        alert.textFields?[4].placeholder = "Вид нарушения"
        
        // Предзаполняем поля
        alert.textFields?[0].text = "\(nextNumber)"
        alert.textFields?[1].text = searchText.isEmpty ? "" : searchText
        
        let save = UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            let number: Int = Int(alert.textFields?[0].text ?? "0") ?? 0
            let form: String = alert.textFields?[1].text ?? "-"
            let url: String = alert.textFields?[2].text ?? "-"
            let desc: String = alert.textFields?[3].text ?? "-"
            let vid: String = alert.textFields?[4].text ?? "-"
            
            let violation = ViolationsModel.Violation(number: number, titie: form, subTitle: url, description: desc, vid: vid)
            ViolationsModel.addNewViolation(violation: violation)
            self.items = ViolationsModel.returnAvialableViolation()
            self.filteredItems = self.items
            self.tableView.reloadData()
        }
        alert.addAction(save)
        
        present(alert, animated: true)
    }
    
    private func showViolationInfo(for violation: ViolationsModel.Violation) {
        // Вибрационный отклик для просмотра
        triggerHapticFeedback(.light)
        
        let previewVC = ViolationPreviewViewController(violation: violation)
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
                if let originalIndex = items.firstIndex(where: { $0.titie == violation.titie && $0.subTitle == violation.subTitle }) {
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
        
        let editVC = SettingsEditViolationViewController(violation: violation) { [weak self] updatedViolation in
            guard let self = self else { return }
            
            print("🔄 Обновляем нарушение в настройках:")
            print("   Старое: \(violation.titie)")
            print("   Новое: \(updatedViolation.titie)")
            
            // Используем новый метод для обновления нарушения
            ViolationsModel.updateViolation(oldViolation: violation, newViolation: updatedViolation)
            
            // Обновляем локальный массив
            self.items = ViolationsModel.returnAvialableViolation()
            self.filteredItems = self.items
            print("📊 Количество нарушений после обновления: \(self.items.count)")
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
    
    // MARK: - Search Methods
    @objc private func searchTextChanged(_ textField: UITextField) {
        guard let query = textField.text?.lowercased(), !query.isEmpty else {
            filteredItems = items
            tableView.reloadData()
            return
        }
        
        filteredItems = items.filter { violation in
            // Поиск по формулировке нарушения
            let titleMatch = violation.titie.lowercased().contains(query)
            
            // Поиск по нормативному документу
            let documentMatch = violation.subTitle.lowercased().contains(query)
            
            // Поиск по примечанию
            let descriptionMatch = violation.description?.lowercased().contains(query) ?? false
            
            // Поиск по виду нарушения
            let typeMatch = violation.vid?.lowercased().contains(query) ?? false
            
            // Поиск по номеру нарушения
            let numberMatch = violation.number?.description.contains(query) ?? false
            
            // Возвращаем true если хотя бы одно поле содержит запрос
            return titleMatch || documentMatch || descriptionMatch || typeMatch || numberMatch
        }
        
        // Принудительно обновляем таблицу
        DispatchQueue.main.async {
            self.tableView.reloadData()
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
            numbLabel.attributedText = highlightText(item.titie, searchText: searchText)
        } else {
            numbLabel.text = item.titie
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
            if let originalIndex = items.firstIndex(where: { $0.titie == itemToDelete.titie && $0.subTitle == itemToDelete.subTitle }) {
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
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            let itemToDelete = self.filteredItems[indexPath.row]
            // Находим и удаляем из оригинального массива
            if let originalIndex = self.items.firstIndex(where: { $0.titie == itemToDelete.titie && $0.subTitle == itemToDelete.subTitle }) {
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
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }


    
}
