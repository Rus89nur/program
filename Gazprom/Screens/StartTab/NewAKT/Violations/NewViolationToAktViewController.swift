//
//  NewViolationToAktViewController.swift
//  Gazprom
//
//  Created by Владимир on 11.07.2025.
//

import UIKit
import PhotosUI
import SnapKit

// MARK: - AutocompleteTableView
class AutocompleteTableView: UIView {
    
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .systemBackground
        tableView.layer.cornerRadius = 12
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.showsVerticalScrollIndicator = false
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return tableView
    }()
    
    // Информационное окно для отображения полного названия
    private let infoWindow: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 12
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        view.layer.shadowRadius = 8
        view.layer.shadowOpacity = 0.3
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray4.cgColor
        view.isHidden = true
        view.alpha = 0
        return view
    }()
    
    private let infoLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private var suggestions: [String] = []
    private var onSuggestionSelected: ((String) -> Void)?
    private var longPressRecognizer: UILongPressGestureRecognizer?
    private var currentLongPressIndexPath: IndexPath?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Настройка информационного окна
        infoWindow.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        // Добавляем информационное окно в родительский view (не в tableView)
        // Оно будет добавлено позже в родительский view контроллера
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SuggestionCell")
        
        // Настройка длительного нажатия
        setupLongPressGesture()
        
        // Скрываем по умолчанию
        isHidden = true
    }
    
    /// Настраивает обработчик длительного нажатия
    private func setupLongPressGesture() {
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        longPress.delegate = self
        tableView.addGestureRecognizer(longPress)
        self.longPressRecognizer = longPress
    }
    
    /// Обработчик длительного нажатия
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: tableView)
        
        switch gesture.state {
        case .began:
            guard let indexPath = tableView.indexPathForRow(at: location) else { return }
            currentLongPressIndexPath = indexPath
            // Выделяем ячейку
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
            showInfoWindow(for: suggestions[indexPath.row], at: location)
            
        case .changed:
            // Обновляем позицию окна при движении пальца
            if let indexPath = tableView.indexPathForRow(at: location) {
                if currentLongPressIndexPath != indexPath {
                    // Снимаем выделение с предыдущей ячейки
                    if let previousIndexPath = currentLongPressIndexPath {
                        tableView.deselectRow(at: previousIndexPath, animated: true)
                    }
                    // Выделяем новую ячейку
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                    currentLongPressIndexPath = indexPath
                    showInfoWindow(for: suggestions[indexPath.row], at: location)
                } else {
                    updateInfoWindowPosition()
                }
            }
            
        case .ended, .cancelled, .failed:
            // Снимаем выделение с ячейки
            if let indexPath = currentLongPressIndexPath {
                tableView.deselectRow(at: indexPath, animated: true)
            }
            hideInfoWindow()
            currentLongPressIndexPath = nil
            
        default:
            break
        }
    }
    
    /// Показывает информационное окно
    private func showInfoWindow(for text: String, at location: CGPoint) {
        guard let parentView = superview else { return }
        
        // Устанавливаем текст
        infoLabel.text = text
        
        // Настройка для темной темы (получаем из родительского view)
        let isDarkMode = parentView.traitCollection.userInterfaceStyle == .dark
        if isDarkMode {
            infoWindow.backgroundColor = .systemGray6
            infoLabel.textColor = .white
            infoWindow.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        } else {
            infoWindow.backgroundColor = .systemBackground
            infoLabel.textColor = .label
            infoWindow.layer.borderColor = UIColor.systemGray4.cgColor
        }
        
        // Добавляем окно в родительский view, если его там еще нет
        if infoWindow.superview == nil {
            parentView.addSubview(infoWindow)
        }
        
        // Вычисляем позицию окна (ниже таблицы автодополнения)
        let windowWidth: CGFloat = min(300, parentView.bounds.width - 32)
        let windowHeight: CGFloat = min(150, text.height(withConstrainedWidth: windowWidth - 32, font: infoLabel.font) + 32)
        
        // Получаем нижнюю границу таблицы автодополнения в координатах parentView
        let tableViewBottomInParent = self.convert(CGPoint(x: 0, y: self.bounds.maxY), to: parentView)
        
        // Позиционируем окно ниже таблицы с небольшим отступом
        let spacing: CGFloat = 8
        let x = max(16, min((parentView.bounds.width - windowWidth) / 2, parentView.bounds.width - windowWidth - 16))
        let y = tableViewBottomInParent.y + spacing
        
        // Проверяем, чтобы окно не выходило за границы экрана
        let maxY = parentView.bounds.height - windowHeight - 16
        let finalY = min(y, maxY)
        
        infoWindow.frame = CGRect(x: x, y: finalY, width: windowWidth, height: windowHeight)
        
        // Показываем с анимацией
        infoWindow.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.infoWindow.alpha = 1.0
        }
    }
    
    /// Обновляет позицию информационного окна
    private func updateInfoWindowPosition() {
        guard let parentView = superview, !infoWindow.isHidden else { return }
        
        let windowWidth = infoWindow.frame.width
        let windowHeight = infoWindow.frame.height
        
        // Получаем нижнюю границу таблицы автодополнения в координатах parentView
        let tableViewBottomInParent = self.convert(CGPoint(x: 0, y: self.bounds.maxY), to: parentView)
        
        // Позиционируем окно ниже таблицы с небольшим отступом
        let spacing: CGFloat = 8
        let x = max(16, min((parentView.bounds.width - windowWidth) / 2, parentView.bounds.width - windowWidth - 16))
        let y = tableViewBottomInParent.y + spacing
        
        // Проверяем, чтобы окно не выходило за границы экрана
        let maxY = parentView.bounds.height - windowHeight - 16
        let finalY = min(y, maxY)
        
        UIView.animate(withDuration: 0.1) {
            self.infoWindow.frame = CGRect(x: x, y: finalY, width: windowWidth, height: windowHeight)
        }
    }
    
    /// Скрывает информационное окно
    private func hideInfoWindow() {
        UIView.animate(withDuration: 0.15, animations: {
            self.infoWindow.alpha = 0.0
        }) { _ in
            self.infoWindow.isHidden = true
        }
    }
    
    /// Скрывает информационное окно при скрытии таблицы
    override var isHidden: Bool {
        didSet {
            if isHidden {
                hideInfoWindow()
            }
        }
    }
    
    /// Обновляет тему информационного окна
    func updateTheme() {
        guard !infoWindow.isHidden, let parentView = superview else { return }
        
        let isDarkMode = parentView.traitCollection.userInterfaceStyle == .dark
        if isDarkMode {
            infoWindow.backgroundColor = .systemGray6
            infoLabel.textColor = .white
            infoWindow.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
        } else {
            infoWindow.backgroundColor = .systemBackground
            infoLabel.textColor = .label
            infoWindow.layer.borderColor = UIColor.systemGray4.cgColor
        }
    }
    
    /// Обновляет предложения и показывает/скрывает таблицу
    func updateSuggestions(_ suggestions: [String], onSelection: @escaping (String) -> Void) {
        print("🔧 AutocompleteTableView.updateSuggestions вызван с \(suggestions.count) предложениями")
        self.suggestions = suggestions
        self.onSuggestionSelected = onSelection
        
        if suggestions.isEmpty {
            print("🔧 Предложений нет, скрываем таблицу")
            hide()
        } else {
            print("🔧 Обновляем данные таблицы и показываем")
            
            // Убеждаемся, что таблица может получать события касания
            isUserInteractionEnabled = true
            tableView.isUserInteractionEnabled = true
            
            // Обновляем данные таблицы
            tableView.reloadData()
            
            // Принудительно показываем таблицу
            isHidden = false
            alpha = 1.0
            transform = .identity
            
            // Обновляем layout
            layoutIfNeeded()
            
            print("🔍 Состояние таблицы после updateSuggestions:")
            print("   - isHidden: \(isHidden)")
            print("   - alpha: \(alpha)")
            print("   - frame: \(frame)")
            print("   - suggestions.count: \(suggestions.count)")
            print("   - isUserInteractionEnabled: \(isUserInteractionEnabled)")
            print("   - tableView.isUserInteractionEnabled: \(tableView.isUserInteractionEnabled)")
        }
    }
    
    /// Показывает таблицу с анимацией
    func show() {
        print("🔍 AutocompleteTableView.show() вызван, isHidden: \(isHidden)")
        guard isHidden else { 
            print("🔍 Таблица уже видима, выходим")
            return 
        }
        
        print("✅ Показываем таблицу автодополнения")
        isHidden = false
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut], animations: {
            self.alpha = 1
            self.transform = .identity
        }) { _ in
            print("✅ Анимация показа завершена")
        }
    }
    
    /// Скрывает таблицу с анимацией
    func hide() {
        guard !isHidden else { return }
        
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn], animations: {
            self.alpha = 0
            self.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            self.isHidden = true
            self.transform = .identity
        }
    }
    
    /// Вычисляет оптимальную высоту для таблицы
    func calculateOptimalHeight(maxHeight: CGFloat = 200) -> CGFloat {
        let cellHeight: CGFloat = 44
        let totalHeight = CGFloat(suggestions.count) * cellHeight
        return min(totalHeight, maxHeight)
    }
}

// MARK: - AutocompleteTableView DataSource & Delegate
extension AutocompleteTableView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return suggestions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SuggestionCell", for: indexPath)
        
        // Настройка ячейки
        let suggestionText = suggestions[indexPath.row]
        cell.textLabel?.text = suggestionText
        cell.textLabel?.font = .systemFont(ofSize: 16, weight: .regular)
        cell.textLabel?.textColor = .label
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        
        print("🔧 Создана ячейка \(indexPath.row): '\(suggestionText)'")
        
        // Настройка для темной темы
        let isDarkMode = self.traitCollection.userInterfaceStyle == .dark
        if isDarkMode {
            cell.textLabel?.textColor = .white
            cell.backgroundColor = .systemGray6
        }
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Небольшая задержка, чтобы длительное нажатие имело приоритет
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            // Проверяем, не активен ли длительный жест
            if self.longPressRecognizer?.state != .began && 
               self.longPressRecognizer?.state != .changed &&
               self.currentLongPressIndexPath == nil {
                tableView.deselectRow(at: indexPath, animated: true)
                let selectedSuggestion = self.suggestions[indexPath.row]
                self.onSuggestionSelected?(selectedSuggestion)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
}

// MARK: - UIGestureRecognizerDelegate
extension AutocompleteTableView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
}

// MARK: - String Extension для вычисления высоты текста
extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(boundingBox.height)
    }
}

// MARK: - ObjectAutocompleteManager
class ObjectAutocompleteManager {
    
    // Ключ для хранения названий объектов текущего акта
    private static let currentAktObjectsKey = "CurrentAktObjectNames"
    
    // Тестовый ID для проверки автодополнения
    static let testAktId = UUID()
    
    /// Добавляет название объекта в список для автодополнения
    static func addObjectName(_ objectName: String, forAkt aktId: UUID) {
        guard !objectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let trimmedName = objectName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Получаем текущие названия объектов для данного акта
        var objectNames = getObjectNames(forAkt: aktId)
        
        // Добавляем новое название, если его еще нет
        if !objectNames.contains(trimmedName) {
            objectNames.append(trimmedName)
            saveObjectNames(objectNames, forAkt: aktId)
            print("✅ Добавлено название объекта для автодополнения: '\(trimmedName)' для акта \(aktId)")
        }
    }
    
    /// Получает список названий объектов для автодополнения
    static func getObjectNames(forAkt aktId: UUID) -> [String] {
        let key = "\(currentAktObjectsKey)_\(aktId.uuidString)"
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }
    
    /// Получает предложения для автодополнения на основе введенного текста
    static func getSuggestions(for searchText: String, aktId: UUID) -> [String] {
        print("🔍 ObjectAutocompleteManager.getSuggestions вызван с текстом: '\(searchText)' для акта: \(aktId)")
        
        let objectNames = getObjectNames(forAkt: aktId)
        print("🔍 Всего названий объектов для акта: \(objectNames.count)")
        print("🔍 Названия объектов: \(objectNames)")
        
        let trimmedSearchText = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        print("🔍 Обработанный поисковый текст: '\(trimmedSearchText)'")
        
        guard !trimmedSearchText.isEmpty else { 
            print("🔍 Поисковый текст пустой, возвращаем все названия")
            return objectNames 
        }
        
        // Фильтруем названия, которые содержат введенный текст
        let suggestions = objectNames.filter { objectName in
            let contains = objectName.lowercased().contains(trimmedSearchText)
            print("🔍 '\(objectName)' содержит '\(trimmedSearchText)': \(contains)")
            return contains
        }
        
        print("🔍 Найдено совпадений: \(suggestions.count)")
        
        // Сортируем по релевантности (начинающиеся с введенного текста идут первыми)
        let sortedSuggestions = suggestions.sorted { first, second in
            let firstLower = first.lowercased()
            let secondLower = second.lowercased()
            
            // Если одно начинается с поискового текста, а другое нет
            if firstLower.hasPrefix(trimmedSearchText) && !secondLower.hasPrefix(trimmedSearchText) {
                return true
            } else if !firstLower.hasPrefix(trimmedSearchText) && secondLower.hasPrefix(trimmedSearchText) {
                return false
            }
            
            // Иначе сортируем по алфавиту
            return first < second
        }
        
        print("🔍 Отсортированные предложения: \(sortedSuggestions)")
        return sortedSuggestions
    }
    
    /// Очищает названия объектов для конкретного акта
    static func clearObjectNames(forAkt aktId: UUID) {
        let key = "\(currentAktObjectsKey)_\(aktId.uuidString)"
        UserDefaults.standard.removeObject(forKey: key)
        print("🧹 Очищены названия объектов для акта \(aktId)")
    }
    
    /// Инициализирует названия объектов из существующего акта
    static func initializeFromAkt(_ akt: AKT) {
        print("🔄 ObjectAutocompleteManager.initializeFromAkt для акта №\(akt.number)")
        
        // Очищаем старые данные для этого акта
        clearObjectNames(forAkt: akt.id)
        
        print("🔍 Нарушения: \(akt.violations.count)")
        // Добавляем только места нарушений из существующих нарушений
        // НЕ добавляем названия объектов из библиотеки объектов
        for violation in akt.violations {
            print("🔍 Добавляем место нарушения: '\(violation.mesto)'")
            addObjectName(violation.mesto, forAkt: akt.id)
        }
        
        let finalCount = getObjectNames(forAkt: akt.id).count
        print("🔄 Инициализированы названия объектов для акта №\(akt.number): \(finalCount) названий")
        print("🔍 Финальный список: \(getObjectNames(forAkt: akt.id))")
    }
    
    /// Сохраняет названия объектов для конкретного акта
    private static func saveObjectNames(_ objectNames: [String], forAkt aktId: UUID) {
        let key = "\(currentAktObjectsKey)_\(aktId.uuidString)"
        UserDefaults.standard.set(objectNames, forKey: key)
    }
}

class NewViolationToAktViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let vc: NewViolationViewController
    let model: MainAKTViewModel
    
    var photos: [UIImage] = []
    var violations: [ViolationsModel.Violation] = ViolationsModel.returnAvailableViolation()
    private var filteredViolations: [ViolationsModel.Violation] = []
    
    var selectedViolation: ViolationsModel.Violation?
    var updatedViolatation: Violations?
    
    // Генератор вибрации
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(vc: NewViolationViewController, model: MainAKTViewModel) {
        self.vc = vc
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    let searchTextField = UISearchTextField()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.isEditing = false
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .systemBackground
        view.keyboardDismissMode = .onDrag // Закрытие клавиатуры при прокрутке
        return view
    }()
    
    let photoCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.layer.cornerRadius = 24
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.showsHorizontalScrollIndicator = false
        layout.scrollDirection = .horizontal
        return collection
    }()
    
    let mestoTextField: UITextField = {
        let view = UITextField()
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1) 
        view.layer.cornerRadius = 12
        view.textColor = .label
        view.placeholder = "Место нарушения"
        let left = UIView(frame: .init(x: 0, y: 0, width: 16, height: 16))
        view.leftView = left
        view.leftViewMode = .always
        
        let right = UIView(frame: .init(x: 0, y: 0, width: 16, height: 16))
        view.rightView = left
        view.rightViewMode = .always
        
        return view
    }()
    
    // Таблица для автодополнения названий объектов
    private let autocompleteTableView = AutocompleteTableView()
    
    // Высота клавиатуры для определения области нажатий
    private var keyboardHeight: CGFloat = 0
    
    // Debounce таймер для поиска (чтобы не искать при каждом изменении текста)
    private var searchDebounceTimer: Timer?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Обновляем реестр нарушений при каждом появлении экрана (после добавления в настройках и т.д.)
        violations = ViolationsModel.returnAvailableViolation()
        filteredViolations = violations
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🚀 NewViolationToAktViewController viewDidLoad")
        view.backgroundColor = .systemBackground
        
        // Настройка навигации
        navigationItem.title = "Новое нарушение в акте"
        
        print("🔧 Вызываем setupUI...")
        setupUI()
        print("🔧 Вызываем checkEdit...")
        checkEdit()
        print("🔧 Вызываем setupLongPressGesture...")
        setupLongPressGesture()
        
        // Настройка автодополнения для текущего акта
        print("🔧 Вызываем setupAutocompleteForCurrentAkt...")
        setupAutocompleteForCurrentAkt()
        
        // Настройка темной темы
        print("🔧 Вызываем setupDarkTheme...")
        setupDarkTheme()
        
        // Настройка отслеживания клавиатуры
        setupKeyboardObservers()
        
        // Обновляем список при изменении реестра нарушений (редактирование в настройках)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(violationsRegistryDidChange),
            name: ViolationsModel.violationsDidChangeNotification,
            object: nil
        )
        
        print("✅ viewDidLoad завершен")
    }
    
    @objc private func violationsRegistryDidChange() {
        violations = ViolationsModel.returnAvailableViolation()
        filteredViolations = violations
        tableView.reloadData()
    }
    
    deinit {
        // Отменяем таймер поиска
        searchDebounceTimer?.invalidate()
        // Удаляем наблюдатели при деинициализации
        NotificationCenter.default.removeObserver(self)
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
            tableView.reloadData()
            // Обновляем тему информационного окна автодополнения
            autocompleteTableView.updateTheme()
        }
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            tableView.backgroundColor = .black
            
            // Обновляем цвета текстовых полей
            mestoTextField.textColor = .white
            mestoTextField.backgroundColor = .systemGray6
            mestoTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            searchTextField.textColor = .white
            searchTextField.backgroundColor = .systemGray6
            searchTextField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        } else {
            // Светлая тема
            view.backgroundColor = .systemBackground
            tableView.backgroundColor = .systemBackground
            
            mestoTextField.textColor = .label
            mestoTextField.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1)
            mestoTextField.tintColor = .systemBlue
            searchTextField.textColor = .label
            searchTextField.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1)
            searchTextField.tintColor = .systemBlue
        }
    }
    
    private func setupUI() {
        if  ViolationsModel.returnAvailableViolation().count > 0 {
            let plusButton = UIButton(type: .system)
            plusButton.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
            view.addSubview(plusButton)
            plusButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
                make.top.equalTo(view.safeAreaLayoutGuide).inset(16)
                make.right.equalToSuperview().inset(16)
            }
            plusButton.addTarget(self, action: #selector(addNewViol), for: .touchUpInside)
        }
        
        mestoTextField.delegate = self
        view.addSubview(mestoTextField)
        mestoTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(42)
        }
        
        // Настройка клавиатуры с кнопкой "Готово"
        setupKeyboardToolbar()
        
        // Настройка автодополнения
        setupAutocomplete()
        
        // Добавляем обработчик нажатия вне поля ввода
        setupTapGesture()
        
        view.addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(mestoTextField.snp.bottom).inset(-8)
            make.height.equalTo(42)
        }
        searchTextField.placeholder = "Поиск по формулировке, документу, примечанию..."
        searchTextField.returnKeyType = .done
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
        searchTextField.delegate = self
        
        let doneButton = UIFactory.createButton(title: "Добавить", color: .systemBlue)
        view.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(54)
        }
        doneButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        
        photoCollection.delegate = self
        photoCollection.dataSource = self
        view.addSubview(photoCollection)
        photoCollection.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(doneButton.snp.top).inset(-16)
            make.height.equalTo(200)
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(photoCollection.snp.top).inset(-16)
        }
        
        filteredViolations = violations

    }
    
    @objc private func addNewViol() {
        let unifiedFormVC = UnifiedViolationFormViewController { [weak self] violation in
            guard let self = self else { return }
            
            ViolationsModel.addNewViolation(violation: violation)
            self.violations = ViolationsModel.returnAvailableViolation()
            self.filteredViolations = self.violations
            self.searchTextField.text = ""
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
    
    
    @objc private func addNew() {
        
        if let unvItem = updatedViolatation {
            if let index = vc.violations.firstIndex(where: {$0.title == unvItem.title}) {
                selectedViolation = filteredViolations.first(where: {$0.title ==  vc.violations[index].title})
            }
        }
        
        
        if let item = selectedViolation {
            if let updateditem = updatedViolatation {
                if let index = vc.violations.firstIndex(where: {$0.title == updateditem.title}) {
                    selectedViolation = filteredViolations.first(where: {$0.title ==  vc.violations[index].title})
                let vidValue = item.vid ?? ""
                // Используем сжатие изображений для уменьшения размера акта
                let compressedPhotos = photos.compactMap { compressImageForAct($0) }
                vc.violations[index] =  Violations(title: item.title, mesto:  mestoTextField.text ?? "Неизвестно", urlToPravilo: item.subTitle, photo: compressedPhotos, vid: vidValue, formulaFromRules: item.formulaFromRules)
                
                // Добавляем название объекта в автодополнение
                if let objectName = mestoTextField.text, !objectName.isEmpty {
                    addObjectNameToAutocomplete(objectName)
                }
                }
            } else {
                let vidValue = item.vid ?? ""
                // Используем сжатие изображений для уменьшения размера акта
                let compressedPhotos = photos.compactMap { compressImageForAct($0) }
                let violation = Violations(title: item.title, mesto:  mestoTextField.text ?? "Неизвестно", urlToPravilo: item.subTitle, photo: compressedPhotos, vid: vidValue, formulaFromRules: item.formulaFromRules)
                vc.violations.append(violation)
                
                // Добавляем название объекта в автодополнение
                if let objectName = mestoTextField.text, !objectName.isEmpty {
                    addObjectNameToAutocomplete(objectName)
                }
            }
            
            vc.tableView.reloadData()
            
            // Синхронизируем изменения (для акта или черновика)
            vc.syncViolationsWithAkt()
            
            self.dismiss(animated: true)
        } else {
            let alert = UIAlertController(title: "Ошибка!", message: "Выберите нарушение", preferredStyle: .alert)
            let ok = UIAlertAction(title: "Хорошо", style: .cancel)
            alert.addAction(ok)
            self.present(alert, animated: true)
        }
    }
    
    func openedMain(violation: Violations) {
        mestoTextField.text = violation.mesto
        self.photos = violation.photo.map({UIImage(data: $0) ?? UIImage()})
        searchTextField.text = violation.title
        photoCollection.reloadData()
    }
    
    func checkEdit() {
        if let item = updatedViolatation {
            openedMain(violation: item)
        }
    }
    
    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        tableView.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        
        // Добавляем вибрацию при удержании пальца
        impactFeedback.impactOccurred()
        
        let violation = filteredViolations[indexPath.row]
        showViolationPreview(for: violation)
    }
    
    private func showViolationPreview(for violation: ViolationsModel.Violation) {
        let previewVC = ViolationPreviewViewController(violation: violation)
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
    
}

extension NewViolationToAktViewController: UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let hasSearchQuery = !(searchTextField.text?.isEmpty ?? true)
        
        // Если результаты поиска пусты, показываем одну ячейку с кнопкой добавления
        if filteredViolations.isEmpty && hasSearchQuery {
            return 1
        }
        
        // Если есть результаты поиска и есть поисковый запрос, добавляем дополнительную строку для кнопки
        if !filteredViolations.isEmpty && hasSearchQuery {
            return filteredViolations.count + 1
        }
        
        return filteredViolations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "1")
        let hasSearchQuery = !(searchTextField.text?.isEmpty ?? true)
        
        // Проверяем, нужно ли показать кнопку добавления нарушения
        // Случай 1: результаты пусты и есть поисковый запрос
        if filteredViolations.isEmpty && hasSearchQuery {
            setupAddViolationCell(cell: cell)
            return cell
        }
        
        // Случай 2: есть результаты и это последняя строка (кнопка "добавить нарушение")
        if !filteredViolations.isEmpty && hasSearchQuery && indexPath.row == filteredViolations.count {
            setupAddViolationCell(cell: cell)
            return cell
        }
        
        // Проверка безопасности: убеждаемся, что индекс находится в допустимых пределах
        guard indexPath.row < filteredViolations.count else {
            // Если индекс выходит за границы, возвращаем пустую ячейку
            return cell
        }
        
        let violation = filteredViolations[indexPath.row]
        
        // Получаем иконку на основе типа нарушения (vid)
        let categoryIcon = ViolationContextSearchEngine.shared.getIconForViolation(violation)
        
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
        
        // Единый стиль заголовка: фиксированный размер шрифта, 1 строка, обрезка многоточием, без автоуменьшения
        cell.textLabel?.numberOfLines = 1
        cell.textLabel?.lineBreakMode = .byTruncatingTail
        cell.textLabel?.font = .systemFont(ofSize: 17, weight: .regular)
        cell.textLabel?.adjustsFontSizeToFitWidth = false
        cell.textLabel?.minimumScaleFactor = 1.0
        cell.textLabel?.allowsDefaultTighteningForTruncation = false

        // Подсвечиваем найденный текст в заголовке с сохранением базового шрифта
        if let searchText = searchTextField.text, !searchText.isEmpty {
            cell.textLabel?.attributedText = highlightText(violation.title, searchText: searchText)
        } else {
            cell.textLabel?.text = violation.title
        }
        
        cell.backgroundColor = .clear
        // Улучшенный контраст для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            cell.textLabel?.textColor = .white
            cell.detailTextLabel?.textColor = .white.withAlphaComponent(0.8)
        } else {
            cell.textLabel?.textColor = .label
            cell.detailTextLabel?.textColor = .label.withAlphaComponent(0.7)
        }
        
        // Показываем нормативный документ в качестве подзаголовка с иконкой категории
        if !violation.subTitle.isEmpty && violation.subTitle != "---" {
            let subtitleText = "\(categoryIcon) \(violation.subTitle)"
            if let searchText = searchTextField.text, !searchText.isEmpty {
                cell.detailTextLabel?.attributedText = highlightText(subtitleText, searchText: searchText)
            } else {
                cell.detailTextLabel?.text = subtitleText
            }
        } else if let description = violation.description, !description.isEmpty && description != "---" {
            let descriptionText = "\(categoryIcon) \(description)"
            if let searchText = searchTextField.text, !searchText.isEmpty {
                cell.detailTextLabel?.attributedText = highlightText(descriptionText, searchText: searchText)
            } else {
                cell.detailTextLabel?.text = descriptionText
            }
        }
        
        return cell
    }
    
    private func highlightText(_ text: String, searchText: String) -> NSAttributedString {
        // Базовый шрифт для единообразия размера
        let baseFont = UIFont.systemFont(ofSize: 17, weight: .regular)
        let attributedString = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: baseFont
            ]
        )
        
        // Ищем вхождение поискового текста (без учета регистра)
        if let range = text.range(of: searchText, options: .caseInsensitive) {
            let nsRange = NSRange(range, in: text)
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: nsRange)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 17), range: nsRange)
        }
        
        return attributedString
    }
    
    @objc private func searchTextChanged(_ textField: UITextField) {
        // Отменяем предыдущий таймер
        searchDebounceTimer?.invalidate()
        
        guard let query = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            filteredViolations = violations
            tableView.reloadData()
            return
        }
        
        // Если запрос пустой, сразу показываем все нарушения
        if query.isEmpty {
            filteredViolations = violations
            tableView.reloadData()
            return
        }
        
        // Устанавливаем debounce - поиск выполнится через 0.3 секунды после последнего изменения
        searchDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.performSearch(query: query)
        }
    }
    
    /// Выполняет поиск нарушений (вызывается после debounce)
    private func performSearch(query: String) {
        // Сохраняем текущий запрос для проверки актуальности результатов
        let currentQuery = query
        
        // Получаем значения UI элементов на главном потоке перед переходом на фоновый
        let objectName = mestoTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let relatedViolationIds = vc.violations.map { violation in
            // Создаем ID для связанных нарушений
            let identifier = "\(violation.title)-\(violation.urlToPravilo)"
            return identifier.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
        }
        
        // Выполняем поиск на фоновом потоке для предотвращения блокировки UI
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Создаем контекст поиска
            let context = SearchContext(
                searchQuery: currentQuery,
                objectName: objectName,
                relatedViolationIds: relatedViolationIds,
                commonRules: nil
            )
            
            // Используем контекстный поиск (он сам проверит флаг isIntelligentSearchEnabled)
            let scoredResults = ViolationContextSearchEngine.shared.search(
                query: currentQuery,
                violations: self.violations,
                context: context
            )
            
            // Результаты контекстного поиска (ML по тексту отключён, используется только обучение по фото)
            let finalResults = scoredResults
            let sortedResults = finalResults.sorted { $0.score > $1.score }
            let filtered = sortedResults.map { $0.violation }
            
            // Обновляем UI на главном потоке
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Проверяем, что запрос не изменился (пользователь мог продолжить ввод)
                if self.searchTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) == currentQuery {
                    self.filteredViolations = filtered
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    // MARK: - Add Violation Cell Setup
    private func setupAddViolationCell(cell: UITableViewCell) {
        // Очищаем ячейку
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        // Настройка внешнего вида ячейки
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
        // Вибрационный отклик
        impactFeedback.impactOccurred()
        
        // Получаем текст из поиска
        let searchText = searchTextField.text ?? ""
        
        // Очищаем поле поиска
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        
        // Вызываем метод добавления с предзаполненным текстом
        addNewViolWithSearchText(searchText)
    }
    
    private func addNewViolWithSearchText(_ searchText: String) {
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
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let hasSearchQuery = !(searchTextField.text?.isEmpty ?? true)
        
        // Проверяем, если это кнопка добавления нарушения
        // Случай 1: результаты пусты и есть поисковый запрос
        if filteredViolations.isEmpty && hasSearchQuery {
            addNewViolationFromSearch()
            return
        }
        
        // Случай 2: есть результаты и это последняя строка (кнопка "добавить нарушение")
        if !filteredViolations.isEmpty && hasSearchQuery && indexPath.row == filteredViolations.count {
            addNewViolationFromSearch()
            return
        }
        
        // Проверка безопасности: убеждаемся, что индекс находится в допустимых пределах
        guard indexPath.row < filteredViolations.count else {
            return
        }
        
        selectedViolation = filteredViolations[indexPath.row]
        searchTextField.text = selectedViolation?.title
        // Закрываем клавиатуру при выборе элемента
        searchTextField.resignFirstResponder()
        mestoTextField.resignFirstResponder()
        autocompleteTableView.hide()
        
        // Регистрируем использование для обучения модели
        if let selected = selectedViolation {
            let context = SearchContext(
                searchQuery: searchTextField.text,
                objectName: mestoTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                relatedViolationIds: vc.violations.map { violation in
                    let identifier = "\(violation.title)-\(violation.urlToPravilo)"
                    return identifier.data(using: .utf8)?.base64EncodedString() ?? UUID().uuidString
                },
                commonRules: nil
            )
            
            // Регистрируем в контекстном поиске
            ViolationContextSearchEngine.shared.recordUsage(
                violation: selected,
                context: context
            )
            
            // Обучение по текстовому выбору отключено; обучение модели только по фото в разделе «Обучение по фото»
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        let hasSearchQuery = !(searchTextField.text?.isEmpty ?? true)
        
        // Если это кнопка добавления нарушения, делаем её компактной по высоте текста
        // Случай 1: результаты пусты и есть поисковый запрос
        if filteredViolations.isEmpty && hasSearchQuery {
            return 60
        }
        
        // Случай 2: есть результаты и это последняя строка (кнопка "добавить нарушение")
        if !filteredViolations.isEmpty && hasSearchQuery && indexPath.row == filteredViolations.count {
            return 60
        }
        
        // Проверка безопасности: если индекс выходит за границы, возвращаем стандартную высоту
        guard indexPath.row < filteredViolations.count else {
            return 100
        }
        
        // Увеличиваем высоту строк для лучшего отображения в темной теме
        return 100
    }
    
    // Закрытие клавиатуры при прокрутке таблицы
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dismissKeyboard()
        autocompleteTableView.hide()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Закрываем клавиатуру при нажатии на "Готово"
        textField.resignFirstResponder()
        // Также скрываем автодополнение для поля места нарушения
        if textField == mestoTextField {
            autocompleteTableView.hide()
        }
        return true
    }
    
    @objc private func addTapped() {
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
        
        self.present(alert, animated: true)
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

// MARK: - PHPickerViewControllerDelegate
extension NewViolationToAktViewController: PHPickerViewControllerDelegate {
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
    
    @objc private func delPhoto(sender: UIButton) {
        photos.remove(at: sender.tag)
        photoCollection.reloadData()
    }
    
    // MARK: - Image Compression
    private func compressImageForAct(_ image: UIImage) -> Data? {
        print("🖼️ Сжимаем изображение для акта")
        print("   Исходный размер: \(image.size.width)x\(image.size.height)")
        
        // Оптимальные настройки сжатия для актов
        let maxSize: CGFloat = 1024  // Оптимальный размер для документов
        let quality: CGFloat = 0.75  // Хорошее качество с экономией места
        let maxFileSize = 200 * 1024 // 200KB - оптимальный размер для актов
        
        // 1. Изменяем размер изображения если необходимо
        let resizedImage = resizeImageIfNeeded(image, maxSize: maxSize)
        print("   Изменен размер до: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // 2. Сжимаем с адаптивным качеством
        let compressedData = compressImageToTargetSize(resizedImage, targetQuality: quality, maxFileSize: maxFileSize)
        
        if let data = compressedData {
            let finalSizeKB = data.count / 1024
            print("   ✅ Сжатие завершено. Размер файла: \(finalSizeKB)KB")
            return data
        } else {
            print("   ❌ Ошибка сжатия изображения")
            return nil
        }
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let originalSize = image.size
        let maxDimension = max(originalSize.width, originalSize.height)
        
        // Если изображение уже меньше максимального размера, возвращаем как есть
        if maxDimension <= maxSize {
            return image
        }
        
        let scale = maxSize / maxDimension
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Создаем контекст для изменения размера
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func compressImageToTargetSize(_ image: UIImage, targetQuality: CGFloat, maxFileSize: Int) -> Data? {
        var quality = targetQuality
        var data: Data?
        
        // Пробуем разные уровни качества пока не достигнем нужного размера
        while quality > 0.1 {
            if let jpegData = image.jpegData(compressionQuality: quality) {
                if jpegData.count <= maxFileSize {
                    data = jpegData
                    print("   Найдено подходящее качество: \(quality)")
                    break
                } else {
                    quality -= 0.1
                    print("   Качество \(quality) слишком большое, уменьшаем...")
                }
            } else {
                break
            }
        }
        
        // Если даже с минимальным качеством не помещается, используем последнее доступное
        if data == nil {
            data = image.jpegData(compressionQuality: 0.1)
            print("   ⚠️ Используем минимальное качество из-за ограничений размера")
        }
        
        return data
    }
    
    // MARK: - Autocomplete Methods
    
    /// Настраивает автодополнение для текущего акта
    private func setupAutocompleteForCurrentAkt() {
        print("🔄 Начинаем инициализацию автодополнения...")
        
        // Получаем ID текущего акта из модели
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("✅ Найден редактируемый акт №\(editableAkt.akt.number)")
            ObjectAutocompleteManager.initializeFromAkt(editableAkt.akt)
            print("🔄 Инициализировано автодополнение для редактируемого акта №\(editableAkt.akt.number)")
            
            // Проверяем, что данные загружены
            let loadedNames = ObjectAutocompleteManager.getObjectNames(forAkt: editableAkt.akt.id)
            print("📊 Загружено \(loadedNames.count) названий для автодополнения: \(loadedNames)")
            
        } else if let currentAkt = model.templateModel.getCurrentAkt() {
            print("✅ Найден текущий акт №\(currentAkt.number)")
            ObjectAutocompleteManager.initializeFromAkt(currentAkt)
            print("🔄 Инициализировано автодополнение для текущего акта №\(currentAkt.number)")
            
            // Проверяем, что данные загружены
            let loadedNames = ObjectAutocompleteManager.getObjectNames(forAkt: currentAkt.id)
            print("📊 Загружено \(loadedNames.count) названий для автодополнения: \(loadedNames)")
            
        } else {
            print("⚠️ Не удалось найти акт для инициализации автодополнения")
            print("   Проверяем templateModel:")
            print("   - date: \(model.templateModel.date != nil ? "есть" : "нет")")
            print("   - aktNumber: \(model.templateModel.aktNumber != nil ? "есть" : "нет")")
            print("   - comissionPeople: \(model.templateModel.comissionPeople != nil ? "есть" : "нет")")
            print("   - organizations: \(model.templateModel.organizations != nil ? "есть" : "нет")")
            print("   - objectCheck: \(model.templateModel.objectCheck != nil ? "есть" : "нет")")
            print("   - violations: \(model.templateModel.violations != nil ? "есть" : "нет")")
            print("   - predstavitely: \(model.templateModel.predstavitely != nil ? "есть" : "нет")")
            print("   - ustranenDatePicker: \(model.templateModel.ustranenDatePicker != nil ? "есть" : "нет")")
            print("   - predostavlenDatePicker: \(model.templateModel.predostavlenDatePicker != nil ? "есть" : "нет")")
            print("   - utverzdenDatePicker: \(model.templateModel.utverzdenDatePicker != nil ? "есть" : "нет")")
            
            // Инициализируем с тестовыми данными для проверки
            print("🧪 Инициализируем с тестовыми данными для проверки автодополнения...")
            let testNames = ["Вагон", "Локомотив", "Путь", "Станция", "Цех №1", "Депо"]
            for name in testNames {
                ObjectAutocompleteManager.addObjectName(name, forAkt: ObjectAutocompleteManager.testAktId)
            }
            let loadedNames = ObjectAutocompleteManager.getObjectNames(forAkt: ObjectAutocompleteManager.testAktId)
            print("📊 Тестовые данные загружены для акта \(ObjectAutocompleteManager.testAktId): \(loadedNames)")
        }
    }
    
    /// Настраивает компоненты автодополнения
    private func setupAutocomplete() {
        print("🔧 Настройка автодополнения...")
        
        // Добавляем таблицу автодополнения
        view.addSubview(autocompleteTableView)
        autocompleteTableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(mestoTextField.snp.bottom).offset(4)
            make.height.equalTo(0) // Начальная высота 0
        }
        
        // Устанавливаем высокий z-index, чтобы таблица была поверх других элементов
        // Используем безопасное значение в пределах FLT_MAX (обычно 100 достаточно)
        autocompleteTableView.layer.zPosition = 100
        autocompleteTableView.backgroundColor = .systemBackground
        autocompleteTableView.layer.borderWidth = 1
        autocompleteTableView.layer.borderColor = UIColor.systemGray4.cgColor
        autocompleteTableView.layer.cornerRadius = 8
        autocompleteTableView.layer.shadowColor = UIColor.black.cgColor
        autocompleteTableView.layer.shadowOffset = CGSize(width: 0, height: 2)
        autocompleteTableView.layer.shadowRadius = 4
        autocompleteTableView.layer.shadowOpacity = 0.1
        
        print("✅ Таблица автодополнения добавлена в view с zPosition: 100")
        
        // Настраиваем обработчик выбора предложения
        autocompleteTableView.updateSuggestions([]) { [weak self] (selectedSuggestion: String) in
            print("✅ Выбрано предложение: \(selectedSuggestion)")
            self?.mestoTextField.text = selectedSuggestion
            self?.autocompleteTableView.hide()
            self?.mestoTextField.resignFirstResponder()
        }
        print("✅ Обработчик выбора предложения настроен")
        
        // Добавляем обработчик изменения текста
        mestoTextField.addTarget(self, action: #selector(mestoTextFieldChanged(_:)), for: .editingChanged)
        print("✅ Обработчик изменения текста добавлен к mestoTextField")
        
        // Проверяем, что обработчик добавлен
        let targets = mestoTextField.allTargets
        print("🔍 Цели mestoTextField: \(targets)")
        
        // Добавляем дополнительный обработчик для тестирования
        mestoTextField.addTarget(self, action: #selector(testTextFieldChanged(_:)), for: .editingChanged)
        print("✅ Тестовый обработчик добавлен")
    }
    
    /// Тестовый обработчик для проверки работы
    @objc private func testTextFieldChanged(_ textField: UITextField) {
        print("🧪 ТЕСТ: Обработчик изменения текста сработал! Текст: '\(textField.text ?? "")'")
    }
    
    /// Обработчик изменения текста в поле места нарушения
    @objc private func mestoTextFieldChanged(_ textField: UITextField) {
        print("🔍 mestoTextFieldChanged вызван с текстом: '\(textField.text ?? "")'")
        
        guard let text = textField.text, !text.isEmpty else {
            print("🔍 Текст пустой, скрываем автодополнение")
            autocompleteTableView.hide()
            return
        }
        
        // Получаем ID текущего акта
        guard let aktId = getCurrentAktId() else {
            print("❌ Не удалось получить ID акта для автодополнения")
            autocompleteTableView.hide()
            return
        }
        
        print("✅ ID акта получен: \(aktId)")
        
        // Получаем предложения автодополнения
        let suggestions = ObjectAutocompleteManager.getSuggestions(for: text, aktId: aktId)
        print("🔍 Найдено предложений: \(suggestions.count)")
        print("🔍 Предложения: \(suggestions)")
        
        if suggestions.isEmpty {
            print("🔍 Предложений нет, скрываем автодополнение")
            autocompleteTableView.hide()
        } else {
            print("✅ Показываем \(suggestions.count) предложений")
            
            // Обновляем высоту таблицы ДО обновления предложений
            let optimalHeight = autocompleteTableView.calculateOptimalHeight()
            autocompleteTableView.snp.updateConstraints { make in
                make.height.equalTo(optimalHeight)
            }
            
            // Обновляем предложения
            autocompleteTableView.updateSuggestions(suggestions) { [weak self] (selectedSuggestion: String) in
                print("✅ Выбрано предложение: \(selectedSuggestion)")
                self?.mestoTextField.text = selectedSuggestion
                self?.autocompleteTableView.hide()
                self?.mestoTextField.resignFirstResponder()
            }
            
            // Принудительно показываем таблицу и обновляем layout
            print("🔧 Принудительно показываем таблицу...")
            autocompleteTableView.isHidden = false
            autocompleteTableView.alpha = 1.0
            autocompleteTableView.transform = .identity
            
            // Убеждаемся, что таблица находится поверх других элементов
            view.bringSubviewToFront(autocompleteTableView)
            
            // Обновляем layout с анимацией
            UIView.animate(withDuration: 0.2) {
                self.autocompleteTableView.layoutIfNeeded()
                self.view.layoutIfNeeded()
            }
            
            // Убеждаемся, что таблица может получать события касания
            autocompleteTableView.isUserInteractionEnabled = true
            
            print("🔍 Состояние таблицы после принудительного показа:")
            print("   - isHidden: \(autocompleteTableView.isHidden)")
            print("   - alpha: \(autocompleteTableView.alpha)")
            print("   - frame: \(autocompleteTableView.frame)")
            print("   - superview: \(autocompleteTableView.superview != nil ? "есть" : "нет")")
            print("   - isUserInteractionEnabled: \(autocompleteTableView.isUserInteractionEnabled)")
        }
    }
    
    /// Получает ID текущего акта
    private func getCurrentAktId() -> UUID? {
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("🔍 Используем ID редактируемого акта: \(editableAkt.akt.id)")
            return editableAkt.akt.id
        } else if let currentAkt = model.templateModel.getCurrentAkt() {
            print("🔍 Используем ID текущего акта: \(currentAkt.id)")
            return currentAkt.id
        } else {
            // Возвращаем тестовый ID для проверки
            print("🧪 Используем тестовый ID акта для автодополнения: \(ObjectAutocompleteManager.testAktId)")
            return ObjectAutocompleteManager.testAktId
        }
    }
    
    /// Добавляет название объекта в автодополнение
    private func addObjectNameToAutocomplete(_ objectName: String) {
        guard let aktId = getCurrentAktId() else { return }
        ObjectAutocompleteManager.addObjectName(objectName, forAkt: aktId)
    }
    
    /// Настраивает toolbar для текстовых полей (без кнопки "Готово")
    private func setupKeyboardToolbar() {
        // Убираем toolbar - кнопка "Готово" больше не нужна
        // Клавиатура будет закрываться при нажатии на пустое место или свайпом
        mestoTextField.inputAccessoryView = nil
        searchTextField.inputAccessoryView = nil
    }
    
    /// Настраивает отслеживание клавиатуры для определения её области
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            keyboardHeight = keyboardFrame.height
            print("⌨️ Клавиатура показана, высота: \(keyboardHeight)")
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        keyboardHeight = 0
        print("⌨️ Клавиатура скрыта")
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    /// Настраивает обработчик нажатия вне поля ввода
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapOutside))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Добавляем жест свайпа вниз для закрытия клавиатуры
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDown))
        swipeDownGesture.direction = .down
        swipeDownGesture.delegate = self
        view.addGestureRecognizer(swipeDownGesture)
    }
    
    /// Обработчик свайпа вниз для закрытия клавиатуры
    @objc private func handleSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        dismissKeyboard()
        autocompleteTableView.hide()
    }
    
    /// Обработчик нажатия вне поля ввода
    @objc private func handleTapOutside(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: view)
        
        // Проверяем, не нажали ли на поле ввода или таблицу автодополнения
        let tapInTextField = mestoTextField.frame.contains(location)
        let tapInSearchField = searchTextField.frame.contains(location)
        let tapInAutocomplete = autocompleteTableView.frame.contains(location) && !autocompleteTableView.isHidden
        let tapInTableView = tableView.frame.contains(location)
        
        // Проверяем, не находится ли точка нажатия в области клавиатуры
        // Используем реальную высоту клавиатуры, если она видна
        let keyboardAreaHeight: CGFloat = keyboardHeight > 0 ? keyboardHeight : 300
        let keyboardAreaY = view.bounds.height - keyboardAreaHeight
        let tapInKeyboardArea = keyboardHeight > 0 && location.y > keyboardAreaY
        
        // Если нажатие было на таблицу автодополнения или клавиатуру, не обрабатываем его здесь
        if tapInAutocomplete || tapInKeyboardArea {
            return
        }
        
        // Закрываем клавиатуру и автодополнение при нажатии вне полей ввода
        // Также закрываем при нажатии на таблицу (для удобства)
        if (!tapInTextField && !tapInSearchField && !tapInAutocomplete) || tapInTableView {
            autocompleteTableView.hide()
            dismissKeyboard()
        }
    }
    
}


// MARK: - UIGestureRecognizerDelegate
extension NewViolationToAktViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        let location = touch.location(in: view)
        
        // Для свайпа вниз всегда разрешаем обработку (для закрытия клавиатуры)
        if gestureRecognizer is UISwipeGestureRecognizer {
            return true
        }
        
        // Если нажатие на таблицу автодополнения, не обрабатываем жестом
        if autocompleteTableView.frame.contains(location) && !autocompleteTableView.isHidden {
            return false
        }
        
        // Если нажатие на текстовые поля, не обрабатываем жестом
        if mestoTextField.frame.contains(location) || searchTextField.frame.contains(location) {
            return false
        }
        
        // Проверяем, не находится ли точка нажатия в области клавиатуры
        // Используем реальную высоту клавиатуры, если она видна
        let keyboardAreaHeight: CGFloat = keyboardHeight > 0 ? keyboardHeight : 300
        let keyboardAreaY = view.bounds.height - keyboardAreaHeight
        if keyboardHeight > 0 && location.y > keyboardAreaY {
            // Нажатие в области клавиатуры - не обрабатываем жестом
            return false
        }
        
        return true
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Разрешаем одновременное распознавание жестов для закрытия клавиатуры
        if gestureRecognizer is UISwipeGestureRecognizer || otherGestureRecognizer is UISwipeGestureRecognizer {
            return true
        }
        return false
    }
}

extension NewViolationToAktViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 24
        
        // Настройка фона ячейки для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            cell.backgroundColor = .systemGray6
        } else {
            cell.backgroundColor = .white
        }
        
        if indexPath.row == photos.count {
            let buttonAdd = UIFactory.createButton(title: "Новое фото", color: .systemBlue.withAlphaComponent(0.2))
            // Улучшенный контраст для темной темы
            if traitCollection.userInterfaceStyle == .dark {
                buttonAdd.setTitleColor(.white, for: .normal)
            } else {
                buttonAdd.setTitleColor(.label, for: .normal)
            }
            cell.addSubview(buttonAdd)
            buttonAdd.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            buttonAdd.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        } else {
            let item = photos[indexPath.row]
            let imageView = UIImageView(image: item)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 24
            cell.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let delButton = UIButton(type: .system)
            delButton.tag = indexPath.row
            delButton.setBackgroundImage(UIImage(systemName: "trash.fill")?.withTintColor(.red), for: .normal)
            cell.addSubview(delButton)
            delButton.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.right.top.equalToSuperview().inset(16)
            }
            delButton.addTarget(self, action: #selector(delPhoto(sender:)), for: .touchUpInside)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 200)
    }
    
}
