//
//  EditViolationViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit
import PhotosUI
import Combine

// MARK: - Simple Realtime AKT System (Integrated)
// Типы определены в MainAKTViewModel.swift для избежания дублирования

class EditViolationViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    private let violation: Violations
    private let onSave: (Violations) -> Void
    private var photos: [UIImage] = []
    private var violations: [ViolationsModel.Violation] = ViolationsModel.returnAvailableViolation()
    private var filteredViolations: [ViolationsModel.Violation] = []
    private var selectedViolation: ViolationsModel.Violation?
    
    // Realtime AKT Integration
    var cancellables = Set<AnyCancellable>()
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    private let violationTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Формулировка нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let textView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        return textView
    }()
    
    private let characterCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // Поле для места нарушения
    private let mestoLabel: UILabel = {
        let label = UILabel()
        label.text = "Место нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let mestoTextField: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textColor = .label
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        return textView
    }()
    
    // Поле для выбора пункта нарушения
    private let violationPointLabel: UILabel = {
        let label = UILabel()
        label.text = "Пункт нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    // Поле для вида нарушения
    private let violationTypeLabel: UILabel = {
        let label = UILabel()
        label.text = "Вид нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let violationTypeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        
        // Используем современный UIButton.Configuration вместо устаревшего titleEdgeInsets
        var config = UIButton.Configuration.plain()
        config.title = "Выберите вид нарушения"
        config.baseForegroundColor = .label
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 16, weight: .regular)
            return outgoing
        }
        config.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        config.baseBackgroundColor = .clear
        button.configuration = config
        
        button.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        
        // Добавляем стрелку вниз
        let arrowImageView = UIImageView(image: UIImage(systemName: "chevron.down"))
        arrowImageView.tintColor = .systemGray3
        arrowImageView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(arrowImageView)
        NSLayoutConstraint.activate([
            arrowImageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -16),
            arrowImageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 16),
            arrowImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
        
        return button
    }()
    
    private var selectedViolationType: ViolationType?
    
    private let violationPointTextField: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textColor = .label
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.isUserInteractionEnabled = true
        return textView
    }()
    
    private let violationPointButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Выбрать пункт", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        return button
    }()
    
    // Коллекция фотографий
    private let photosLabel: UILabel = {
        let label = UILabel()
        label.text = "Фотографии:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let photoCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.layer.cornerRadius = 12
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collection.showsHorizontalScrollIndicator = false
        layout.scrollDirection = .horizontal
        return collection
    }()
    
    // Строка поиска для выбора пункта нарушения
    private let searchTextField: UISearchTextField = {
        let textField = UISearchTextField()
        textField.placeholder = "Поиск по формулировке, документу, примечанию..."
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.isHidden = true
        return textField
    }()
    
    // Таблица для выбора пункта нарушения
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .systemBackground
        tableView.layer.cornerRadius = 12
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.isHidden = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ViolationCell")
        return tableView
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Сохранить", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Отмена", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        return button
    }()
    
    init(violation: Violations, onSave: @escaping (Violations) -> Void) {
        self.violation = violation
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Обновляем реестр нарушений при каждом появлении экрана
        violations = ViolationsModel.returnAvailableViolation()
        filteredViolations = violations
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
        setupKeyboardObservers()
        
        // Настройка темной темы
        setupDarkTheme()
        
        // Настройка интеграции с системой реального времени
        setupRealtimeIntegration()
        setupRealtimeTextFields()
        
        // Обновляем список при изменении реестра нарушений (редактирование в настройках)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(violationsRegistryDidChange),
            name: ViolationsModel.violationsDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func violationsRegistryDidChange() {
        violations = ViolationsModel.returnAvailableViolation()
        filteredViolations = violations
        tableView.reloadData()
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
            scrollView.backgroundColor = .systemBackground
            contentView.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
            
            // Обновляем цвета текста для темной темы
            violationTitleLabel.textColor = .white
            mestoLabel.textColor = .white
            violationPointLabel.textColor = .white
            violationTypeLabel.textColor = .white
            photosLabel.textColor = .white
            characterCountLabel.textColor = .white.withAlphaComponent(0.7)
            
            // Обновляем цвета текстовых полей
            textView.textColor = .white
            textView.backgroundColor = .systemGray6
            textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            mestoTextField.textColor = .white
            mestoTextField.backgroundColor = .systemGray6
            mestoTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            violationPointTextField.textColor = .white
            violationPointTextField.backgroundColor = .systemGray6
            violationPointTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            violationTypeButton.configuration?.baseForegroundColor = .white
            violationTypeButton.backgroundColor = .systemGray6
            violationTypeButton.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            searchTextField.textColor = .white
            searchTextField.backgroundColor = .systemGray6
            searchTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        } else {
            // Светлая тема
            violationTitleLabel.textColor = .label
            mestoLabel.textColor = .label
            violationPointLabel.textColor = .label
            violationTypeLabel.textColor = .label
            photosLabel.textColor = .label
            characterCountLabel.textColor = .secondaryLabel
            
            textView.textColor = .label
            textView.backgroundColor = .systemGray6
            textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            mestoTextField.textColor = .label
            mestoTextField.backgroundColor = .systemGray6
            mestoTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            violationPointTextField.textColor = .label
            violationPointTextField.backgroundColor = .systemGray6
            violationPointTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            violationTypeButton.configuration?.baseForegroundColor = .label
            violationTypeButton.backgroundColor = .systemGray6
            violationTypeButton.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            searchTextField.textColor = .label
            searchTextField.backgroundColor = .systemGray6
            searchTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        cleanupRealtimeIntegration()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Настройка навигации
        navigationItem.title = "Редактирование нарушения"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Настройка клавиатуры с кнопкой "Готово"
        setupKeyboardToolbar()
        
        // Добавление обработчика нажатия вне поля ввода
        setupTapGesture()
        
        // Добавление scroll view
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        
        // Добавление элементов
        contentView.addSubview(mestoLabel)
        contentView.addSubview(mestoTextField)
        contentView.addSubview(violationTitleLabel)
        contentView.addSubview(textView)
        contentView.addSubview(characterCountLabel)
        contentView.addSubview(violationPointLabel)
        contentView.addSubview(violationPointTextField)
        contentView.addSubview(violationPointButton)
        contentView.addSubview(violationTypeLabel)
        contentView.addSubview(violationTypeButton)
        contentView.addSubview(photosLabel)
        contentView.addSubview(photoCollection)
        contentView.addSubview(searchTextField)
        contentView.addSubview(tableView)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        
        setupConstraints()
        setupActions()
        setupDelegates()
    }
    
    private func setupConstraints() {
        // Место нарушения
        mestoLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        mestoTextField.snp.makeConstraints { make in
            make.top.equalTo(mestoLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        // Формулировка нарушения
        violationTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(mestoTextField.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        textView.snp.makeConstraints { make in
            make.top.equalTo(violationTitleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        characterCountLabel.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(8)
            make.right.equalToSuperview().inset(20)
        }
        
        // Пункт нарушения
        violationPointLabel.snp.makeConstraints { make in
            make.top.equalTo(characterCountLabel.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        violationPointTextField.snp.makeConstraints { make in
            make.top.equalTo(violationPointLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        violationPointButton.snp.makeConstraints { make in
            make.top.equalTo(violationPointTextField.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(36)
        }
        
        // Вид нарушения
        violationTypeLabel.snp.makeConstraints { make in
            make.top.equalTo(violationPointButton.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        violationTypeButton.snp.makeConstraints { make in
            make.top.equalTo(violationTypeLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        
        // Фотографии
        photosLabel.snp.makeConstraints { make in
            make.top.equalTo(violationTypeButton.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        photoCollection.snp.makeConstraints { make in
            make.top.equalTo(photosLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(120)
        }
        
        // Строка поиска для выбора пункта нарушения
        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(violationPointButton.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
        
        // Таблица выбора пункта нарушения
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(200)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(photoCollection.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(saveButton.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func setupActions() {
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        violationPointButton.addTarget(self, action: #selector(violationPointButtonTapped), for: .touchUpInside)
        violationTypeButton.addTarget(self, action: #selector(violationTypeButtonTapped), for: .touchUpInside)
        
        // Добавляем обработчик изменения текста
        textView.delegate = self
        
        // Интегрируем текстовые поля с системой реального времени
        setupRealtimeTextFields()
    }
    
    private func setupDelegates() {
        photoCollection.delegate = self
        photoCollection.dataSource = self
        tableView.delegate = self
        tableView.dataSource = self
        mestoTextField.delegate = self
        violationPointTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
    }
    
    private func configureContent() {
        mestoTextField.text = violation.mesto
        textView.text = violation.title
        violationPointTextField.text = violation.urlToPravilo
        
        // Устанавливаем вид нарушения
        if !violation.vid.isEmpty {
            let vid = violation.vid
            // Пытаемся найти соответствующий тип нарушения
            if let violationType = ViolationType.allCases.first(where: { $0.rawValue == vid }) {
                selectedViolationType = violationType
                violationTypeButton.configuration?.title = violationType.displayName
            } else {
                // Если тип не найден в enum, показываем как есть
                violationTypeButton.configuration?.title = vid
            }
        } else {
            violationTypeButton.configuration?.title = "Выберите вид нарушения"
        }
        
        // Загружаем фотографии
        photos = violation.photo.compactMap { UIImage(data: $0) }
        photoCollection.reloadData()
        
        // Инициализируем список нарушений
        filteredViolations = violations
        
        updateCharacterCount()
    }
    
    private func setupKeyboardToolbar() {
        // Убираем toolbar - кнопка "Готово" больше не нужна
        // Клавиатура будет закрываться при нажатии на пустое место или свайпом
        textView.inputAccessoryView = nil
        mestoTextField.inputAccessoryView = nil
        violationPointTextField.inputAccessoryView = nil
        searchTextField.inputAccessoryView = nil
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func updateCharacterCount() {
        let count = textView.text.count
        characterCountLabel.text = "\(count) символов"
    }
    
    @objc private func saveButtonTapped() {
        // #region agent log
        let logDict: [String: Any] = ["location": "EditViolationViewController.swift:saveButtonTapped:start", "message": "НАЧАЛО СОХРАНЕНИЯ НАРУШЕНИЯ", "data": ["violation_id": violation.id.uuidString, "old_vid": violation.vid, "selected_violation_type": selectedViolationType?.rawValue ?? "nil"], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "E"]
        DataFlowAKT.writeDebugLog(logDict)
        // #endregion
        
        let newMesto = mestoTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newUrlToPravilo = violationPointTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Получаем вид нарушения из выбранного типа или текста кнопки
        let newVid: String
        if let selectedType = selectedViolationType {
            newVid = selectedType.rawValue
        } else {
            let buttonTitle = violationTypeButton.configuration?.title ?? ""
            newVid = buttonTitle == "Выберите вид нарушения" ? "" : buttonTitle
        }
        
        print("💾 [EDIT_VIOLATION] Сохранение нарушения")
        print("   🆔 ID нарушения: \(violation.id.uuidString)")
        print("   📋 Старый тип (vid): \(violation.vid)")
        print("   📋 Новый тип (vid): \(newVid)")
        
        if newMesto.isEmpty {
            showAlert(title: "Ошибка", message: "Место нарушения не может быть пустым")
            return
        }
        
        if newTitle.isEmpty {
            showAlert(title: "Ошибка", message: "Название нарушения не может быть пустым")
            return
        }
        
        if newUrlToPravilo.isEmpty {
            showAlert(title: "Ошибка", message: "Пункт нарушения не может быть пустым")
            return
        }
        
        // Создаем обновленное нарушение с сохранением вида нарушения и формулировки из правил
        let updatedViolation = Violations(
            title: newTitle,
            mesto: newMesto,
            urlToPravilo: newUrlToPravilo,
            photo: photos.map { $0.jpegData(compressionQuality: 0.5) ?? Data() },
            vid: newVid,
            formulaFromRules: violation.formulaFromRules
        )
        
        // ИСПРАВЛЕНИЕ: Обновляем нарушение в системе реального времени перед вызовом onSave
        // Это гарантирует, что изменения сохраняются независимо от способа открытия акта
        print("   🔄 Обновляем нарушение в системе реального времени перед сохранением...")
        if let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt {
            var updatedViolations = currentAkt.violations
            
            // Находим и обновляем нарушение
            if let index = updatedViolations.firstIndex(where: { $0.id == violation.id }) {
                print("   ✅ Найдено нарушение в акте на позиции \(index)")
                updatedViolations[index] = updatedViolation
                SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
                print("   ✅ Нарушение обновлено в системе реального времени")
            } else {
                print("   ⚠️ Нарушение не найдено в акте, добавляем новое")
                updatedViolations.append(updatedViolation)
                SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
                print("   ✅ Новое нарушение добавлено в систему реального времени")
            }
        } else {
            print("   ⚠️ currentAkt is nil в SimpleRealtimeAKTManager, изменения могут не сохраниться")
        }
        
        // #region agent log
        let logDict2: [String: Any] = ["location": "EditViolationViewController.swift:saveButtonTapped:end", "message": "СОХРАНЕНИЕ НАРУШЕНИЯ ЗАВЕРШЕНО", "data": ["violation_id": violation.id.uuidString, "new_vid": newVid, "has_realtime_akt": SimpleRealtimeAKTManager.shared.currentAkt != nil], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "E"]
        DataFlowAKT.writeDebugLog(logDict2)
        // #endregion
        
        onSave(updatedViolation)
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func violationPointButtonTapped() {
        let isHidden = tableView.isHidden
        tableView.isHidden = !isHidden
        searchTextField.isHidden = !isHidden
        
        if !isHidden {
            // Скрываем элементы
            searchTextField.text = ""
            filteredViolations = violations
        } else {
            // Показываем элементы
            tableView.reloadData()
            searchTextField.becomeFirstResponder()
        }
    }
    
    @objc private func violationTypeButtonTapped() {
        // #region agent log
        let logDict: [String: Any] = ["location": "EditViolationViewController.swift:violationTypeButtonTapped", "message": "НАЧАЛО ВЫБОРА ТИПА НАРУШЕНИЯ", "data": ["violation_id": violation.id.uuidString, "current_vid": violation.vid], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "E"]
        DataFlowAKT.writeDebugLog(logDict)
        // #endregion
        
        let alert = UIAlertController(title: "Выберите вид нарушения", message: nil, preferredStyle: .actionSheet)
        
        // Настройка цветов для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            alert.view.tintColor = .white
        }
        
        // Добавляем опции для каждого типа нарушения
        for violationType in ViolationType.allCases {
            let action = UIAlertAction(title: violationType.displayName, style: .default) { [weak self] _ in
                guard let self = self else { return }
                
                // #region agent log
                let logDict2: [String: Any] = ["location": "EditViolationViewController.swift:violationTypeButtonTapped:selected", "message": "ВЫБРАН ТИП НАРУШЕНИЯ", "data": ["violation_id": self.violation.id.uuidString, "old_vid": self.violation.vid, "new_vid": violationType.rawValue, "new_display_name": violationType.displayName], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "E"]
                DataFlowAKT.writeDebugLog(logDict2)
                // #endregion
                
                print("🔄 [EDIT_VIOLATION] Изменение типа нарушения")
                print("   🆔 ID нарушения: \(self.violation.id.uuidString)")
                print("   📋 Старый тип (vid): \(self.violation.vid)")
                print("   📋 Новый тип (vid): \(violationType.rawValue)")
                print("   📋 Новый тип (displayName): \(violationType.displayName)")
                
                self.selectedViolationType = violationType
                self.violationTypeButton.configuration?.title = violationType.displayName
                
                // ИСПРАВЛЕНИЕ: Немедленно обновляем нарушение в системе реального времени
                // Это исправляет проблему с сохранением при открытии через историю
                print("   🔄 Обновляем нарушение в системе реального времени...")
                self.updateViolationInRealtime()
                print("   ✅ Нарушение обновлено в системе реального времени")
            }
            alert.addAction(action)
        }
        
        // Добавляем отмену
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancelAction)
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = violationTypeButton
            popover.sourceRect = violationTypeButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    @objc private func addPhotoTapped() {
        let alert = UIAlertController(title: "Откуда загрузить фото?", message: "", preferredStyle: .alert)
        
        let galAction = UIAlertAction(title: "Из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        }
        alert.addAction(galAction)
        
        let photoAction = UIAlertAction(title: "Сделать фото", style: .default) { [weak self] _ in
            self?.presentImagePicker(sourceType: .camera)
        }
        alert.addAction(photoAction)
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        present(alert, animated: true)
    }
    
    @objc private func deletePhotoTapped(_ sender: UIButton) {
        photos.remove(at: sender.tag)
        photoCollection.reloadData()
    }
    
    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0 // 0 = без ограничений
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            print("Источник не доступен: \(sourceType)")
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    @objc private func searchTextChanged(_ textField: UITextField) {
        guard let query = textField.text?.lowercased(), !query.isEmpty else {
            filteredViolations = violations
            tableView.reloadData()
            return
        }
        
        filteredViolations = violations.filter { violation in
            // Поиск по формулировке нарушения
            let titleMatch = violation.title.lowercased().contains(query)
            
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
        tableView.reloadData()
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Add Violation Cell Setup
    private func setupAddViolationCell(cell: UITableViewCell, containerView: UIView) {
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
    
    @objc private func addNewViolationFromSearch() {
        // Получаем текст из поиска
        let searchText = searchTextField.text ?? ""
        
        // Очищаем поле поиска
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        // Вызываем метод добавления с предзаполненным текстом
        addNewViolationWithSearchText(searchText)
    }
    
    private func addNewViolationWithSearchText(_ searchText: String) {
        let unifiedFormVC = UnifiedViolationFormViewController(searchText: searchText) { [weak self] violation in
            guard let self = self else { return }
            
            ViolationsModel.addNewViolation(violation: violation)
            self.violations = ViolationsModel.returnAvailableViolation()
            self.filteredViolations = self.violations
            self.tableView.reloadData()
        }
        
        let navController = UINavigationController(rootViewController: unifiedFormVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
    @objc private func addNewViol() {
        let searchText = searchTextField.text ?? ""
        
        let unifiedFormVC = UnifiedViolationFormViewController(searchText: searchText) { [weak self] violation in
            guard let self = self else { return }
            
            ViolationsModel.addNewViolation(violation: violation)
            self.violations = ViolationsModel.returnAvailableViolation()
            self.filteredViolations = self.violations
            self.tableView.reloadData()
        }
        
        let navController = UINavigationController(rootViewController: unifiedFormVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
    // MARK: - Helper Methods
    private func getNextViolationNumber() -> Int {
        let allViolations = ViolationsModel.returnAvailableViolation()
        let maxNumber = allViolations.compactMap { $0.number }.max() ?? 0
        return maxNumber + 1
    }
    
    
    
}


// MARK: - UITextViewDelegate
extension EditViolationViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCount()
    }
}

// MARK: - UITextFieldDelegate
extension EditViolationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - PHPickerViewControllerDelegate
extension EditViolationViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else { return }
        
        let group = DispatchGroup()
        var newImages: [UIImage] = []
        
        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                defer { group.leave() }
                
                if let image = object as? UIImage {
                    newImages.append(image)
                } else if let error = error {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            self.photos.append(contentsOf: newImages)
            self.photoCollection.reloadData()
            print("✅ Добавлено \(newImages.count) фотографий")
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension EditViolationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            photos.append(image)
            photoCollection.reloadData()
            print("✅ Фото добавлено")
        } else {
            print("❌ Не удалось получить изображение")
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension EditViolationViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 12
        cell.backgroundColor = .white
        
        if indexPath.row == photos.count {
            let buttonAdd = UIButton(type: .system)
            buttonAdd.setTitle("+", for: .normal)
            buttonAdd.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
            buttonAdd.setTitleColor(.systemBlue, for: .normal)
            buttonAdd.backgroundColor = .systemGray6
            buttonAdd.layer.cornerRadius = 12
            cell.addSubview(buttonAdd)
            buttonAdd.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            buttonAdd.addTarget(self, action: #selector(addPhotoTapped), for: .touchUpInside)
        } else {
            let item = photos[indexPath.row]
            let imageView = UIImageView(image: item)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            cell.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let delButton = UIButton(type: .system)
            delButton.tag = indexPath.row
            delButton.setBackgroundImage(UIImage(systemName: "trash.fill")?.withTintColor(.red), for: .normal)
            cell.addSubview(delButton)
            delButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
                make.right.top.equalToSuperview().inset(8)
            }
            delButton.addTarget(self, action: #selector(deletePhotoTapped(_:)), for: .touchUpInside)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension EditViolationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // Если результаты поиска пусты, показываем одну ячейку с кнопкой добавления
        if filteredViolations.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            return 1
        }
        return filteredViolations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ViolationCell") ?? UITableViewCell()
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
        if filteredViolations.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            setupAddViolationCell(cell: cell, containerView: containerView)
            return cell
        }
        
        let violation = filteredViolations[indexPath.row]
        
        let numbLabel = UILabel()
        numbLabel.text = violation.title
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
        normLabel.text = violation.subTitle
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
        let descriptionText = violation.description == nil ? "---" : violation.description!
        mainPrimLabel.text = descriptionText
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
        let vidText = violation.vid ?? "---"
        mainVidLabel.text = vidText
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Проверяем, если это кнопка добавления нарушения
        if filteredViolations.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            addNewViolationFromSearch()
            return
        }
        
        let violation = filteredViolations[indexPath.row]
        selectedViolation = violation
        violationPointTextField.text = violation.subTitle
        tableView.isHidden = true
        searchTextField.isHidden = true
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Если это кнопка добавления нарушения, делаем её компактной по высоте текста
        if filteredViolations.isEmpty && !(searchTextField.text?.isEmpty ?? true) {
            return 60
        }
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 220
    }
}

// MARK: - Realtime Integration Methods
extension EditViolationViewController {
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        print("🔗 [REALTIME] Интеграция настроена для \(type(of: self))")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        cancellables.removeAll()
        print("🔗 [REALTIME] Интеграция очищена для \(type(of: self))")
    }
    
    private func setupRealtimeTextFields() {
        // Формулировка: дебаунс 1000 мс, чтобы при быстром наборе реже обновлять realtime и не блокировать клавиатуру
        NotificationCenter.default.publisher(for: UITextView.textDidChangeNotification, object: textView)
            .debounce(for: .milliseconds(1000), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateViolationInRealtime()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: mestoTextField)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateViolationInRealtime()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: violationPointTextField)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateViolationInRealtime()
            }
            .store(in: &cancellables)
    }
    
    private func updateViolationInRealtime() {
        let title = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let mesto = mestoTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlToPravilo = violationPointTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let formulaFromRules = violation.formulaFromRules
        let violationId = violation.id
        let photosToEncode = photos
        let vid: String
        if let selectedType = selectedViolationType {
            vid = selectedType.rawValue
        } else {
            let buttonTitle = violationTypeButton.configuration?.title ?? ""
            vid = buttonTitle == "Выберите вид нарушения" ? "" : buttonTitle
        }
        
        let applyViolation: ([Data]) -> Void = { [weak self] photoData in
            guard let self = self else { return }
            let updatedViolation = Violations(
                title: title,
                mesto: mesto,
                urlToPravilo: urlToPravilo,
                photo: photoData,
                vid: vid,
                formulaFromRules: formulaFromRules
            )
            self.applyUpdatedViolationToRealtime(updatedViolation, violationId: violationId)
        }
        
        if photosToEncode.isEmpty {
            applyViolation([])
            return
        }
        
        // Сжатие фото в фоне, чтобы не блокировать главный поток при наборе текста
        DispatchQueue.global(qos: .userInitiated).async {
            let photoData = photosToEncode.map { $0.jpegData(compressionQuality: 0.5) ?? Data() }
            DispatchQueue.main.async {
                applyViolation(photoData)
            }
        }
    }
    
    private func applyUpdatedViolationToRealtime(_ updatedViolation: Violations, violationId: UUID) {
        if let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt {
            var updatedViolations = currentAkt.violations
            if let index = updatedViolations.firstIndex(where: { $0.id == violationId }) {
                updatedViolations[index] = updatedViolation
                SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
            } else if let index = updatedViolations.firstIndex(where: { $0.title == updatedViolation.title && $0.mesto == updatedViolation.mesto }) {
                updatedViolations[index] = updatedViolation
                SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
            } else {
                updatedViolations.append(updatedViolation)
                SimpleRealtimeAKTManager.shared.updateViolations(updatedViolations)
            }
        }
    }
    
    // MARK: - SimpleRealtimeAKTObserver Methods
    
    func aktDidChange(_ change: String) {
        print("📝 [REALTIME] Получено изменение в EditViolationViewController: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            // Здесь можно добавить логику обновления UI
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [REALTIME] Акт сохранен в EditViolationViewController")
        
        // Обновляем локальное состояние при необходимости
        DispatchQueue.main.async {
            // Здесь можно добавить логику обновления UI после сохранения
        }
    }
}
