//
//  HistoryTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import AudioToolbox
import QuickLook
import SnapKit

class HistoryTabViewController: UIViewController, QLPreviewControllerDelegate, UIGestureRecognizerDelegate {
    
    let viewModel: MainAKTViewModel = MainAKTViewModel()
    var documentURL: URL?
    
    // Храним ссылку на текущее всплывающее окно для возможности его скрытия
    private var currentHintView: UIView?
    // Флаг для отслеживания состояния нажатия на бейдж
    private var isBadgePressed = false
    // Флаг для отслеживания видимости view controller (для предотвращения дергания title)
    private var isViewVisible = false
    // Таймер для отслеживания и восстановления стиля ячейки во время показа контекстного меню
    private var contextMenuStyleTimer: Timer?
    // CADisplayLink для более точного отслеживания изменений стиля
    private var styleDisplayLink: CADisplayLink?
    // Индекс ячейки, для которой показывается контекстное меню
    private var contextMenuIndexPath: IndexPath?
    // Snapshot view для preview контекстного меню (удаляем при закрытии)
    private weak var contextMenuPreviewSnapshotView: UIView?
    // Snapshot для анимации закрытия меню (убирает квадратную рамку при dismiss)
    private weak var contextMenuDismissSnapshotView: UIView?
    // Индекс ячейки, которая находится в состоянии highlight
    private var highlightedIndexPath: IndexPath?
    // CADisplayLink для мониторинга highlight состояния
    private var highlightDisplayLink: CADisplayLink?
    // Выбранный год для фильтрации (nil = показать все)
    private var selectedYear: Int? {
        didSet {
            // Сохраняем выбранный год в UserDefaults
            if let year = selectedYear {
                UserDefaults.standard.set(year, forKey: "HistorySelectedYear")
            } else {
                UserDefaults.standard.removeObject(forKey: "HistorySelectedYear")
            }
        }
    }
    // Отфильтрованный массив актов
    private var filteredAktArray: [AKT] = []
    
    // Ключ для сохранения выбранного года
    private let selectedYearKey = "HistorySelectedYear"
    
    // #region agent log
    private static let debugLogPath = "/Users/ruslan/Прога/06.02.2026work/Gazprom.xcodeproj/.cursor/debug.log"
    private func debugLog(_ message: String, data: [String: Any] = [:], hypothesisId: String = "H1") {
        var payload: [String: Any] = [
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "location": "HistoryTabViewController",
            "message": message,
            "hypothesisId": hypothesisId
        ]
        if !data.isEmpty { payload["data"] = data }
        guard let json = try? JSONSerialization.data(withJSONObject: payload),
              let line = String(data: json, encoding: .utf8) else { return }
        let path = Self.debugLogPath
        let lineWithNewline = line + "\n"
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile()
            handle.write(lineWithNewline.data(using: .utf8)!)
            handle.closeFile()
        } else {
            try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: path, contents: lineWithNewline.data(using: .utf8))
        }
    }
    // #endregion
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isViewVisible = true
        
        // Устанавливаем title синхронно и сразу, чтобы избежать дергания при быстром переключении
        tabBarController?.title = "История"
        navigationItem.title = "История"
        
        print("🔵 [HISTORY] viewWillAppear вызван")
        
        // Загружаем сохраненный выбранный год из UserDefaults (если еще не загружен)
        if selectedYear == nil {
            loadSelectedYear()
        }
        
        // Настройка navigation bar с blur эффектом (применяем после super для переопределения глобальных настроек)
        setupNavigationBarAppearance()
        
        // Быстрая загрузка данных
        loadHistoryData()
        
        // Обновляем заголовок кнопки фильтра года
        updateYearFilterButtonTitle()
        
        // Обновляем видимость кнопки корзины
        updateTrashButtonVisibility()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        isViewVisible = false
        print("🔵 [HISTORY] viewWillDisappear вызван - отменяем асинхронные обновления")
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🔵 [HISTORY] viewDidAppear вызван")
        
        // Убеждаемся, что title установлен (на случай, если что-то его перезаписало)
        if isViewVisible && tabBarController?.selectedViewController === self {
            tabBarController?.title = "История"
            navigationItem.title = "История"
        }
        
        // Повторно применяем настройки navigation bar для надежности
        setupNavigationBarAppearance()
    }
    
    private func setupNavigationBarAppearance() {
        print("🔵 [HISTORY] setupNavigationBarAppearance вызван")
        guard let navBar = navigationController?.navigationBar else {
            print("❌ [HISTORY] navigationController?.navigationBar == nil")
            return
        }
        
        print("🔵 [HISTORY] Настройка navigation bar для прозрачности")
        
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        print("   ✅ configureWithTransparentBackground применен")
        
        // Убираем blur эффект для полной прозрачности
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
        
        // Убеждаемся, что navigation bar полностью прозрачный
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        navBar.barTintColor = .clear
        navBar.backgroundColor = .clear
        print("   ✅ setBackgroundImage, shadowImage, barTintColor, backgroundColor установлены в .clear")
        
        // Логируем финальное состояние
        print("   📊 Финальное состояние navigation bar:")
        print("      - isTranslucent: \(navBar.isTranslucent)")
        print("      - barTintColor: \(String(describing: navBar.barTintColor))")
        print("      - backgroundColor: \(String(describing: navBar.backgroundColor))")
        print("      - standardAppearance.backgroundColor: \(String(describing: navBar.standardAppearance.backgroundColor))")
        print("      - standardAppearance.backgroundEffect: \(String(describing: navBar.standardAppearance.backgroundEffect))")
        print("✅ [HISTORY] setupNavigationBarAppearance завершен")
    }
    
    private func loadHistoryData() {
        // ВСЕГДА обновляем данные из файла, чтобы получить актуальную информацию
        // Это исправляет проблему с синхронизацией между редактируемым актом и историей
        print("🔄 [HISTORY_LOAD] Принудительное обновление данных истории")
        
        // Показываем индикатор загрузки только если данных много
        let shouldShowLoading = viewModel.aktArray.count > 20
        
        if shouldShowLoading {
            showLoadingIndicator()
        }
        
        // Принудительно обновляем данные из файла
        viewModel.forceRefreshAktArray()
        
        // Применяем фильтрацию по году
        applyYearFilter()
        
        // Обновляем коллекцию
        collection.reloadData()
        print("✅ История обновлена принудительно: \(viewModel.aktArray.count) актов, отфильтровано: \(filteredAktArray.count)")
        
        if shouldShowLoading {
            hideLoadingIndicator()
        }
    }
    
    // MARK: - Year Filtering
    
    /// Загружает сохраненный выбранный год из UserDefaults
    private func loadSelectedYear() {
        if UserDefaults.standard.object(forKey: selectedYearKey) != nil {
            let savedYear = UserDefaults.standard.integer(forKey: selectedYearKey)
            // Проверяем, что год валидный (больше 0)
            if savedYear > 0 {
                selectedYear = savedYear
            } else {
                selectedYear = nil
            }
        } else {
            selectedYear = nil
        }
    }
    
    /// Применяет фильтрацию по выбранному году
    private func applyYearFilter() {
        if let year = selectedYear {
            let calendar = Calendar.current
            filteredAktArray = viewModel.aktArray.filter { akt in
                let aktYear = calendar.component(.year, from: akt.date)
                return aktYear == year
            }
        } else {
            // Если год не выбран, показываем все акты
            filteredAktArray = viewModel.aktArray
        }
    }
    
    /// Получает список доступных годов из актов
    private func getAvailableYears() -> [Int] {
        let calendar = Calendar.current
        let years = Set(viewModel.aktArray.map { calendar.component(.year, from: $0.date) })
        return Array(years).sorted(by: >) // Сортируем по убыванию (новые годы первыми)
    }
    
    /// Показывает диалог выбора года
    @objc private func yearFilterButtonTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let availableYears = getAvailableYears()
        
        let alertController = UIAlertController(title: "Выберите год", message: nil, preferredStyle: .actionSheet)
        
        // Добавляем опцию "Все годы"
        let allYearsAction = UIAlertAction(title: "Все годы", style: .default) { [weak self] _ in
            self?.selectedYear = nil
            self?.applyYearFilter()
            self?.collection.reloadData()
            self?.updateYearFilterButtonTitle()
        }
        alertController.addAction(allYearsAction)
        
        // Добавляем опции для каждого года
        for year in availableYears {
            let yearAction = UIAlertAction(title: "\(year)", style: .default) { [weak self] _ in
                self?.selectedYear = year
                self?.applyYearFilter()
                self?.collection.reloadData()
                self?.updateYearFilterButtonTitle()
            }
            alertController.addAction(yearAction)
        }
        
        // Добавляем кнопку отмены
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        alertController.addAction(cancelAction)
        
        // Для iPad нужно указать источник
        if let popover = alertController.popoverPresentationController {
            if let yearButton = view.viewWithTag(102) as? UIButton {
                popover.sourceView = yearButton
                popover.sourceRect = yearButton.bounds
            }
        }
        
        present(alertController, animated: true)
    }
    
    /// Обновляет заголовок кнопки фильтра года: при «все годы» — иконка календаря, иначе — год.
    private func updateYearFilterButtonTitle() {
        guard let yearButton = view.viewWithTag(102) as? UIButton else { return }
        if let year = selectedYear {
            yearButton.setTitle("\(year)", for: .normal)
            yearButton.setImage(nil, for: .normal)
        } else {
            yearButton.setTitle(nil, for: .normal)
            yearButton.setImage(UIImage(systemName: "calendar"), for: .normal)
        }
    }
    
    private func showLoadingIndicator() {
        let loadingView = UIView()
        loadingView.tag = 888
        loadingView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.9)
        loadingView.layer.cornerRadius = 8
        
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.startAnimating()
        loadingView.addSubview(indicator)
        
        view.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(60)
        }
        
        indicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    private func hideLoadingIndicator() {
        view.subviews.forEach { view in
            if view.tag == 888 {
                view.removeFromSuperview()
            }
        }
    }
    
    // MARK: - Generate Loading Indicator
    
    private func showGenerateLoadingIndicator(message: String = "Формирование акта...") {
        hideGenerateLoadingIndicator() // Убираем предыдущий индикатор если есть
        
        // Создаем индикатор загрузки напрямую
        let loadingView = UIView()
        loadingView.tag = 999
        loadingView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        
        // Создаем контейнер для индикатора и текста
        let contentView = UIView()
        contentView.backgroundColor = UIColor.systemGray6
        contentView.layer.cornerRadius = 16
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOpacity = 0.1
        loadingView.addSubview(contentView)
        
        // Индикатор загрузки
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .systemBlue
        activityIndicator.startAnimating()
        contentView.addSubview(activityIndicator)
        
        // Текст загрузки
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        contentView.addSubview(messageLabel)
        
        // Настройка constraints
        view.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(280)
            make.height.greaterThanOrEqualTo(120)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        print("🔄 Показан индикатор загрузки: \(message)")
    }
    
    private func hideGenerateLoadingIndicator() {
        view.subviews.forEach { subview in
            if subview.tag == 999 {
                subview.removeFromSuperview()
                print("🔄 Скрыт индикатор загрузки")
            }
        }
    }
    
    let collection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.backgroundColor = .clear
        layout.scrollDirection = .vertical
        return collection
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Инициализируем отфильтрованный массив
        filteredAktArray = []
        
        // Загружаем сохраненный выбранный год из UserDefaults
        loadSelectedYear()
        
        setupUI()
        
        // Подписываемся на уведомления об изменении корзины
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTrashDidChange),
            name: NSNotification.Name("TrashDidChange"),
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("🔵 [HISTORY] viewDidLayoutSubviews вызван")
        
        // Применяем настройки navigation bar после layout
        setupNavigationBarAppearance()
        
        // Настраиваем contentInset - исправляем расчет отступа
        let safeAreaTop = view.safeAreaInsets.top
        let safeAreaBottom = view.safeAreaInsets.bottom
        let navBarHeight: CGFloat = 44 // Высота navigation bar
        
        // ИСПРАВЛЕНИЕ: safeAreaTop уже включает navigation bar, поэтому используем только safeAreaTop
        // или вычитаем из safeAreaTop высоту navigation bar, если она там учтена
        // По логам: safeAreaTop = 113, navBar.frame.y = 59, значит safeAreaTop включает navBar
        // Используем только safeAreaTop без добавления navBarHeight
        let totalTopInset = safeAreaTop
        
        // ИСПРАВЛЕНИЕ: Используем safeAreaBottom для нижнего отступа, чтобы учесть tab bar
        // Добавляем дополнительный отступ для комфортного просмотра
        let totalBottomInset = safeAreaBottom + 20
        
        // Логирование для отладки отступа
        print("🔍 [HISTORY_LAYOUT] Настройка contentInset:")
        print("   safeAreaTop: \(safeAreaTop)")
        print("   safeAreaBottom: \(safeAreaBottom)")
        print("   navBarHeight: \(navBarHeight)")
        print("   totalTopInset (исправлено): \(totalTopInset)")
        print("   totalBottomInset: \(totalBottomInset)")
        print("   collection.frame: \(collection.frame)")
        print("   collection.bounds: \(collection.bounds)")
        print("   view.safeAreaInsets: \(view.safeAreaInsets)")
        if let navBar = navigationController?.navigationBar {
            print("   navigationBar.bounds: \(navBar.bounds)")
        }
        
        collection.contentInset = UIEdgeInsets(top: totalTopInset, left: 0, bottom: totalBottomInset, right: 0)
        collection.contentInsetAdjustmentBehavior = .never
        
        print("   ✅ Установлен contentInset.top: \(collection.contentInset.top), bottom: \(collection.contentInset.bottom)")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopStyleMonitoringTimer()
        stopHighlightMonitoring()
    }
    
    @objc private func handleTrashDidChange() {
        updateTrashButtonVisibility()
        // Обновляем историю после изменения корзины
        loadHistoryData()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(collection)
        collection.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            // Контент начинается с самого верха, чтобы проходить под navigation bar
            make.top.equalToSuperview()
        }
        collection.delegate = self
        collection.dataSource = self
        
        // УБИРАЕМ кастомный long press gesture, так как используем стандартный UIContextMenuConfiguration
        // Стандартное контекстное меню iOS автоматически обрабатывает долгое нажатие с размытием фона
        // let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        // longPressGesture.minimumPressDuration = 0.5
        // collection.addGestureRecognizer(longPressGesture)

        // Кнопка добавления сокращенного акта
        let addButton = UIBarButtonItem(title: "Добавить", style: .plain, target: self, action: #selector(addShortAktTapped))
        navigationItem.rightBarButtonItem = addButton

        // Плавающая кнопка "+" если нет навбара
        let floatingButton = UIButton(type: .system)
        floatingButton.setImage(UIImage(systemName: "plus"), for: .normal)
        floatingButton.tintColor = .white
        floatingButton.backgroundColor = .systemGreen
        floatingButton.layer.cornerRadius = 28
        floatingButton.layer.shadowColor = UIColor.black.cgColor
        floatingButton.layer.shadowOpacity = 0.2
        floatingButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        floatingButton.layer.shadowRadius = 6
        floatingButton.addTarget(self, action: #selector(addShortAktTapped), for: .touchUpInside)
        floatingButton.tag = 100 // Тег для идентификации
        view.addSubview(floatingButton)
        floatingButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.right).inset(20)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(20)
        }
        
        // Плавающая кнопка корзины
        let trashButton = UIButton(type: .system)
        trashButton.setImage(UIImage(systemName: "trash"), for: .normal)
        trashButton.tintColor = .white
        trashButton.backgroundColor = .systemOrange
        trashButton.layer.cornerRadius = 28
        trashButton.layer.shadowColor = UIColor.black.cgColor
        trashButton.layer.shadowOpacity = 0.2
        trashButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        trashButton.layer.shadowRadius = 6
        trashButton.addTarget(self, action: #selector(trashButtonTapped), for: .touchUpInside)
        trashButton.tag = 101 // Тег для идентификации
        view.addSubview(trashButton)
        trashButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.right).inset(20)
            make.bottom.equalTo(floatingButton.snp.top).offset(-16)
        }
        
        // Плавающая кнопка выбора года (единый стиль: UIFactory)
        let yearFilterButton = UIFactory.createYearFilterButton()
        yearFilterButton.addTarget(self, action: #selector(yearFilterButtonTapped), for: .touchUpInside)
        yearFilterButton.tag = 102 // Тег для идентификации
        view.addSubview(yearFilterButton)
        yearFilterButton.snp.makeConstraints { make in
            make.width.height.equalTo(56)
            make.right.equalTo(floatingButton.snp.left).offset(-16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(20)
        }
        
        // Обновляем видимость кнопки корзины
        updateTrashButtonVisibility()
    }
    
    // MARK: - Trash Button Management
    
    private func updateTrashButtonVisibility() {
        let hasTrash = TrashManager.hasTrash()
        let trashCount = TrashManager.trashCount()
        
        // Находим кнопку корзины
        if let trashButton = view.viewWithTag(101) as? UIButton {
            trashButton.isHidden = !hasTrash
            trashButton.alpha = hasTrash ? 1.0 : 0.0
            
            // Добавляем бейдж с количеством
            if hasTrash && trashCount > 0 {
                trashButton.setBadge(count: trashCount)
            } else {
                trashButton.removeBadge()
            }
        }
    }
    
    @objc private func trashButtonTapped() {
        let trashVC = TrashViewController()
        let navController = UINavigationController(rootViewController: trashVC)
        
        if #available(iOS 15.0, *) {
            navController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
            if let sheet = navController.sheetPresentationController {
                sheet.detents = [UISheetPresentationController.Detent.large()]
                sheet.prefersGrabberVisible = true
                sheet.preferredCornerRadius = 20
            }
        } else {
            navController.modalPresentationStyle = UIModalPresentationStyle.formSheet
        }
        
        present(navController, animated: true)
    }
    
    private func formatter(date: Date) -> String {
        let form = DateFormatter()
        form.dateFormat = "dd.MM.yyyy"
        form.locale = .current
        return form.string(from: date)
    }
    
    // MARK: - Short Akt Detection
    
    private func isShortAkt(_ akt: AKT) -> Bool {
        return akt.isShortFormat
    }
    
    // MARK: - Full Akt Detection (legacy support)
    
    private func isFullAkt(_ akt: AKT) -> Bool {
        return akt.isFullFormat
    }
    
    // MARK: - Badge Hints
    
    @objc private func showShortAktHint() {
        // Устанавливаем флаг нажатия
        isBadgePressed = true
        
        // Скрываем предыдущее окно если есть
        hideHintView()
        
        let hintView = createHintView(
            title: "Сокращенный акт",
            message: "Акт, созданный вне программы. Внесены краткие данные из акта о количестве и видах нарушений, сроках устранения"
        )
        currentHintView = hintView
        view.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Анимация появления
        if let containerView = hintView.subviews.first {
            containerView.alpha = 0
            containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.2) {
                containerView.alpha = 1
                containerView.transform = .identity
            }
        }
        hintView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            hintView.alpha = 1
        }
    }
    
    @objc private func showFullAktHint() {
        // Устанавливаем флаг нажатия
        isBadgePressed = true
        
        // Скрываем предыдущее окно если есть
        hideHintView()
        
        let hintView = createHintView(
            title: "Полный акт",
            message: "Акт, созданный внутри программы с использованием инструментов программы. Содержит полную информацию о проверке"
        )
        currentHintView = hintView
        view.addSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Анимация появления
        if let containerView = hintView.subviews.first {
            containerView.alpha = 0
            containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
            UIView.animate(withDuration: 0.2) {
                containerView.alpha = 1
                containerView.transform = .identity
            }
        }
        hintView.alpha = 0
        UIView.animate(withDuration: 0.2) {
            hintView.alpha = 1
        }
    }
    
    @objc private func badgeTouchUp() {
        // Сбрасываем флаг при отпускании
        isBadgePressed = false
        // Закрываем окно при отпускании
        hideHintView()
    }
    
    private func createHintView(title: String, message: String) -> UIView {
        // Создаем контейнер без фона (прозрачный)
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        
        // Создаем основное окно с сообщением - темный серый полупрозрачный фон
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemGray4.withAlphaComponent(0.9)
        containerView.layer.cornerRadius = 16
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOffset = CGSize(width: 0, height: 4)
        containerView.layer.shadowRadius = 12
        containerView.layer.shadowOpacity = 0.3
        backgroundView.addSubview(containerView)
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .white // Белый текст для лучшей читаемости на сером фоне
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        containerView.addSubview(titleLabel)
        
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 15, weight: .regular)
        messageLabel.textColor = .white.withAlphaComponent(0.9) // Белый текст с небольшой прозрачностью
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        containerView.addSubview(messageLabel)
        
        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.left.right.equalToSuperview().inset(40)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().inset(20)
        }
        
        return backgroundView
    }
    
    private func hideHintView() {
        guard let hintView = currentHintView else { return }
        
        if let containerView = hintView.subviews.first {
            UIView.animate(withDuration: 0.2, animations: {
                containerView.alpha = 0
                containerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
                hintView.alpha = 0
            }) { _ in
                hintView.removeFromSuperview()
                self.currentHintView = nil
            }
        } else {
            hintView.removeFromSuperview()
            self.currentHintView = nil
        }
    }
    
    // MARK: - Edit Akt Method
    
    private func editAkt(_ akt: AKT) {
        // ИСПРАВЛЕНИЕ: Загружаем актуальный акт из файла по ID, чтобы получить свежие данные
        // Это исправляет проблему, когда дата предоставления отчета не обновляется в форме
        let allAkts = DataFlowAKT.loadArr()
        let actualAkt = allAkts.first(where: { $0.id == akt.id }) ?? akt
        
        print("🔄 [EDIT] НАЧАЛО РЕДАКТИРОВАНИЯ АКТА ИЗ ИСТОРИИ")
        print("   📋 Номер акта: \(actualAkt.number)")
        print("   📅 Дата проверки: \(actualAkt.date)")
        print("   📅 Дата предоставления отчета: \(actualAkt.actPredostavlenDate)")
        print("   🏢 Организация: \(actualAkt.organization.title)")
        print("   👥 Количество представителей: \(actualAkt.predstavitelyComission.count)")
        print("   📋 Список представителей: \(actualAkt.predstavitelyComission.map { $0.fio })")
        
        // ИСПРАВЛЕНИЕ: Проверяем по ID, а не по номеру, чтобы избежать конфликтов
        // Приоритет ID над номером для правильной синхронизации изменений
        print("   🔍 Проверяем существующий редактируемый акт...")
        if let existingEditableAkt = DataFlowAKT.getEditableAKT() {
            // Сначала проверяем по ID (это правильный способ)
            if existingEditableAkt.akt.id == actualAkt.id {
                print("   ✅ Редактируемый акт уже существует с тем же ID")
                print("      🆔 ID: \(existingEditableAkt.akt.id.uuidString)")
                print("      🔢 Номер: \(existingEditableAkt.akt.number)")
                print("      👥 Количество представителей: \(existingEditableAkt.akt.predstavitelyComission.count)")
                print("      📋 Количество нарушений: \(existingEditableAkt.akt.violations.count)")
                print("      📅 Последнее изменение: \(existingEditableAkt.lastModified)")
                print("   🔄 Используем существующий редактируемый акт (изменения сохраняются)")
                
                // Используем существующий редактируемый акт - изменения уже сохранены
                print("   🔄 Запускаем редактирование существующего акта...")
                viewModel.startRealtimeEditing(existingEditableAkt.akt)
                print("   ✅ Редактирование запущено")
            } else if existingEditableAkt.akt.number == actualAkt.number {
                // Если номер совпадает, но ID разный - это конфликт
                // Заменяем редактируемый акт на актуальный из истории
                print("   ⚠️ Обнаружен конфликт: редактируемый акт с номером \(actualAkt.number), но другим ID")
                print("      🆔 ID редактируемого акта: \(existingEditableAkt.akt.id.uuidString)")
                print("      🆔 ID акта из истории: \(actualAkt.id.uuidString)")
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
        
        // УНИФИЦИРОВАННАЯ ЛОГИКА: Используем тот же метод editAkt(), что и "Продолжить заполнение"
        print("   🔄 Переходим к экрану редактирования...")
        
        // Находим существующий StartTabViewController в TabBarController
        if let tabBarController = self.tabBarController,
           let startTabVC = tabBarController.viewControllers?.first as? StartTabViewController {
            // Используем существующий StartTabViewController
            print("   ✅ Найден существующий StartTabViewController")
            startTabVC.isEditingMode = true
            startTabVC.editingAkt = actualAkt
            // Вызываем тот же метод editAkt(), что и при "Продолжить заполнение"
            startTabVC.editAkt(actualAkt)
            tabBarController.selectedIndex = 0
            print("   ✅ Переключились на StartTab и запустили редактирование")
            // Проверка видимости TabBar после перехода в редактирование из истории (для отчёта диагностики)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak tabBarController] in
                guard let tabBar = tabBarController?.tabBar else { return }
                if tabBar.isHidden {
                    DiagnosticIncidentStore.record(
                        description: "TabBar скрыт после открытия редактирования акта из истории",
                        context: "История → Главная → редактирование акта №\(actualAkt.number)"
                    )
                }
            }
        } else {
            // Если StartTabViewController не найден, создаем новый (fallback)
            print("   ⚠️ StartTabViewController не найден, создаем новый")
            let startTabVC = StartTabViewController(viewModel: viewModel)
            startTabVC.isEditingMode = true
            startTabVC.editingAkt = actualAkt
            startTabVC.editAkt(actualAkt)
            
            if let tabBarController = self.tabBarController {
                tabBarController.selectedIndex = 0
                print("   ✅ Переключились на StartTab")
            }
        }
        
        print("✅ [EDIT] Редактирование акта из истории запущено")
    }
    
    // MARK: - Generate Akt Method
    
    private func generateAkt(for akt: AKT) {
        let isShort = isShortAkt(akt)
        let formatDescription = isShort ? "СОКРАЩЕННЫЙ" : "ПОЛНЫЙ"
        print("🚀 НАЧАЛО ФОРМИРОВАНИЯ АКТА ИЗ ИСТОРИИ")
        print("   📋 Номер акта: \(akt.number)")
        print("   📅 Дата проверки: \(akt.date)")
        print("   🏷️ Формат акта: \(formatDescription)")
        _ = formatDescription // Используем переменную для устранения предупреждения
        print("   👥 Количество представителей в оригинальном акте: \(akt.predstavitelyComission.count)")
        print("   📋 Список представителей в оригинальном акте: \(akt.predstavitelyComission.map { $0.fio })")
        if isShort {
            print("   🔍 Сокращенный акт: количество нарушений = \(akt.violations.count)")
        }
        
        // Проверяем состояние системы реального времени
        print("   🔍 Состояние системы реального времени:")
        let currentAktNumber = SimpleRealtimeAKTManager.shared.currentAkt?.number ?? "nil"
        print("      currentAkt: \(currentAktNumber)")
        print("      hasUnsavedChanges: \(SimpleRealtimeAKTManager.shared.hasUnsavedChanges)")
        _ = currentAktNumber // Используем переменную для устранения предупреждения
        if let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt {
            print("      Список представителей в currentAkt: \(currentAkt.predstavitelyComission.map { $0.fio })")
        }
        
        // Показываем индикатор загрузки с учетом типа акта
        let message = isShort ? "Формирование сокращенного акта..." : "Формирование полного акта..."
        showGenerateLoadingIndicator(message: message)
        
        // Небольшая задержка для показа индикатора
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            print("   🔄 Начинаем генерацию в фоновом потоке")
            // Создаем акт напрямую
            self?.createAktDirectly(for: akt) { generatedURL in
                DispatchQueue.main.async {
                    print("   ✅ Генерация завершена")
                    
                    // Минимальное время показа индикатора (1 секунда)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        self?.hideGenerateLoadingIndicator()
                        
                        if let url = generatedURL {
                            print("   ✅ [HISTORY_GENERATE] Акт успешно создан!")
                            print("      Путь: \(url.path)")
                            print("      Файл существует: \(FileManager.default.fileExists(atPath: url.path))")
                            self?.showSaveOrShareOptions(for: url, originalAkt: akt)
                        } else {
                            print("   ❌ [HISTORY_GENERATE] Ошибка создания акта - generatedURL = nil")
                            print("      Проверьте логи выше для деталей ошибки")
                            self?.showErrorAlert(message: "Не удалось создать акт. Проверьте логи в консоли для деталей.")
                        }
                    }
                }
            }
        }
    }
    
    private func createAktDirectly(for akt: AKT, completion: @escaping (URL?) -> Void) {
        print("📝 [HISTORY_GENERATE] ========== НАЧАЛО createAktDirectly ==========")
        print("   📋 Входные параметры:")
        print("      Номер акта: \(akt.number)")
        print("      ID акта: \(akt.id)")
        print("      Дата: \(akt.date)")
        print("      Количество комиссии: \(akt.comission.count)")
        print("      Количество организаций: 1 (\(akt.organization.title))")
        print("      Количество объектов: \(akt.objectsCheck.count)")
        print("      Количество нарушений: \(akt.violations.count)")
        print("      Количество представителей: \(akt.predstavitelyComission.count)")
        print("      Длина описания: \(akt.description.count) символов")
        
        // Проверка шаблона
        print("   🔍 Шаг 1: Проверка шаблона...")
        guard let filePath = UserDefaults.standard.string(forKey: "ShabPath") else {
            print("   ❌ [HISTORY_GENERATE] Шаблон не найден в UserDefaults")
            print("      Ключ 'ShabPath' отсутствует или пуст")
            DispatchQueue.main.async {
                self.showErrorAlert(message: "Шаблон не выбран. Пожалуйста, выберите шаблон в настройках.")
            }
            completion(nil)
            return
        }
        print("   ✅ Шаблон найден в UserDefaults: \(filePath)")
        
        let url = URL(fileURLWithPath: filePath)
        print("   🔍 Шаг 2: Проверка существования файла шаблона...")
        print("      Путь к файлу: \(url.path)")
        
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("   ❌ [HISTORY_GENERATE] Файл шаблона не существует: \(url.path)")
            print("      Проверьте, что файл не был удален или перемещен")
            DispatchQueue.main.async {
                self.showErrorAlert(message: "Файл шаблона не найден. Пожалуйста, выберите шаблон заново.")
            }
            completion(nil)
            return
        }
        print("   ✅ Файл шаблона существует")
        
        // Проверка размера файла
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int ?? 0
            print("   📊 Размер файла шаблона: \(fileSize) байт (\(fileSize / 1024) KB)")
        } catch {
            print("   ⚠️ Не удалось получить размер файла: \(error)")
        }
        
        print("   🔍 Шаг 3: Создание GenerateViewModel...")
        let generateViewModel = GenerateViewModel()
        print("   ✅ GenerateViewModel создан")
            
            // ПОЛУЧАЕМ АКТУАЛЬНЫЕ ДАННЫЕ ИЗ РЕДАКТИРУЕМОГО АКТА (ПРИОРИТЕТ 1)
            // Поддержка сокращенных и полных актов
            let isShortFormat = isShortAkt(akt)
            print("🔄 [HISTORY_GENERATE] Получаем актуальные данные...")
            print("   📋 Номер акта из истории: \(akt.number)")
            print("   🆔 ID акта из истории: \(akt.id)")
            if isShortFormat {
                print("   🏷️ Обработка СОКРАЩЕННОГО акта")
            }
            
            // ВАЖНО: Всегда используем номер акта из истории, чтобы избежать генерации неправильного номера
            let aktNumber = akt.number
            
            // Получаем актуальные данные, но только если они относятся к тому же акту
            let currentAkt: AKT
            if let editableAkt = DataFlowAKT.getEditableAKT(), 
               (editableAkt.akt.number == akt.number || editableAkt.akt.id == akt.id) {
                print("   🔄 Используем данные из редактируемого акта...")
                print("      🆔 ID редактируемого акта: \(editableAkt.akt.id)")
                print("      🆔 ID акта из истории: \(akt.id)")
                currentAkt = editableAkt.akt
                print("   ✅ Данные из редактируемого акта:")
                print("      Количество представителей: \(currentAkt.predstavitelyComission.count)")
                print("      Количество нарушений: \(currentAkt.violations.count)")
                print("      Список представителей: \(currentAkt.predstavitelyComission.map { $0.fio })")
            } else if let realtimeAkt = SimpleRealtimeAKTManager.shared.currentAkt,
                      (realtimeAkt.number == akt.number || realtimeAkt.id == akt.id) {
                print("   🔄 Используем данные из системы реального времени (тот же акт)...")
                print("      📋 Номер акта в системе реального времени: \(realtimeAkt.number)")
                print("      🆔 ID акта в системе реального времени: \(realtimeAkt.id)")
                currentAkt = realtimeAkt
                print("   ✅ Данные из системы реального времени:")
                print("      Количество представителей: \(currentAkt.predstavitelyComission.count)")
                print("      Количество нарушений: \(currentAkt.violations.count)")
                print("      Список представителей: \(currentAkt.predstavitelyComission.map { $0.fio })")
            } else {
                print("   🔄 Используем данные из истории...")
                if let realtimeAkt = SimpleRealtimeAKTManager.shared.currentAkt {
                    print("   ⚠️ ВНИМАНИЕ: В системе реального времени есть другой акт (№\(realtimeAkt.number)), но используем акт из истории (№\(akt.number))")
                }
                currentAkt = akt
                print("   ✅ Данные из истории:")
                print("      Количество представителей: \(currentAkt.predstavitelyComission.count)")
                print("      Количество нарушений: \(currentAkt.violations.count)")
                print("      Список представителей: \(currentAkt.predstavitelyComission.map { $0.fio })")
                if isShortFormat {
                    print("      🏷️ Сокращенный акт: нарушения отмечены префиксом")
                }
            }
            
            // ВАЖНО: Всегда используем номер акта из истории, а не из currentAkt
            print("   📋 Финальный номер акта для генерации: \(aktNumber)")
            
            print("   🔍 Шаг 4: Подготовка данных для генерации...")
            print("      Комиссия: \(currentAkt.comission.count) человек")
            print("      Организация: \(currentAkt.organization.title)")
            print("      Объекты проверки: \(currentAkt.objectsCheck.count)")
            print("      Нарушения: \(currentAkt.violations.count)")
            print("      Представители: \(currentAkt.predstavitelyComission.count)")
            print("      Дата проверки: \(currentAkt.date)")
            print("      Дата предоставления: \(currentAkt.actPredostavlenDate)")
            print("      Дата устранения: \(currentAkt.actustranenDate)")
            print("      Дата утверждения: \(currentAkt.actUtverzdenDate)")
            
            print("   🔍 Шаг 5: Вызов generateViewModel.generate...")
            print("   ⏳ Начинаем генерацию акта...")
            
            generateViewModel.generate(
                url: url,
                comissionPeople: currentAkt.comission,
                date: currentAkt.date,
                aktNumber: aktNumber, // Используем номер из истории, а не из currentAkt
                organizations: [currentAkt.organization],
                objectCheck: currentAkt.objectsCheck,
                violations: currentAkt.violations,
                descripUser: currentAkt.description,
                predstav: currentAkt.predstavitelyComission, // Используем актуальные данные
                datePredostavlen: currentAkt.actPredostavlenDate,
                dateUstranen: currentAkt.actustranenDate,
                utverzdenDate: currentAkt.actUtverzdenDate,
                escaping: { resultURL in
                    print("   📥 [HISTORY_GENERATE] Callback от generateViewModel.generate получен")
                    if let url = resultURL {
                        print("   ✅ [HISTORY_GENERATE] Генерация успешна!")
                        print("      Результирующий URL: \(url.path)")
                        print("      URL абсолютный: \(url.absoluteString)")
                        print("      Директория: \(url.deletingLastPathComponent().path)")
                        
                        // Проверяем существование файла
                        let fileExists = FileManager.default.fileExists(atPath: url.path)
                        print("      Файл существует: \(fileExists)")
                        
                        if fileExists {
                            do {
                                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                                let fileSize = attributes[.size] as? Int ?? 0
                                print("      Размер файла: \(fileSize) байт (\(fileSize / 1024) KB)")
                                
                                if fileSize == 0 {
                                    print("      ❌ [HISTORY_GENERATE] КРИТИЧЕСКАЯ ОШИБКА: Файл пустой!")
                                    completion(nil)
                                    return
                                }
                            } catch {
                                print("      ⚠️ Не удалось получить размер файла: \(error)")
                            }
                        } else {
                            print("      ❌ [HISTORY_GENERATE] КРИТИЧЕСКАЯ ОШИБКА: Файл не существует после генерации!")
                            print("      Возможные причины:")
                            print("         1. Файл был удален системой из-за нехватки памяти")
                            print("         2. Файл был сохранен в неправильной директории")
                            print("         3. Ошибка при сохранении файла")
                            
                            // Пробуем найти файл в Documents
                            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                            let fileName = url.lastPathComponent
                            let alternativeURL = documentsURL.appendingPathComponent(fileName)
                            print("      🔍 Проверяем альтернативный путь: \(alternativeURL.path)")
                            
                            if FileManager.default.fileExists(atPath: alternativeURL.path) {
                                print("      ✅ Файл найден по альтернативному пути!")
                                completion(alternativeURL)
                                return
                            }
                            
                            completion(nil)
                            return
                        }
                    } else {
                        print("   ❌ [HISTORY_GENERATE] Генерация вернула nil")
                        print("      Это означает, что произошла ошибка в процессе генерации")
                    }
                    print("   📝 [HISTORY_GENERATE] ========== КОНЕЦ createAktDirectly ==========")
                    completion(resultURL)
                }
            )
    }
    
    private func showSaveOrShareOptions(for url: URL, originalAkt: AKT) {
        print("💾 [HISTORY_SAVE_OPTIONS] НАЧАЛО СОХРАНЕНИЯ/ОТКРЫТИЯ АКТА")
        print("   📋 URL: \(url.path)")
        print("   📋 URL абсолютный: \(url.absoluteString)")
        print("   🔍 Проверка существования файла...")
        
        // ВАЖНО: Проверяем существование файла перед сохранением и открытием
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("   ❌ [HISTORY_SAVE_OPTIONS] Файл не существует: \(url.path)")
            
            // Пробуем найти файл в Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let alternativeURL = documentsURL.appendingPathComponent(fileName)
            print("   🔍 Проверяем альтернативный путь: \(alternativeURL.path)")
            
            if FileManager.default.fileExists(atPath: alternativeURL.path) {
                print("   ✅ Файл найден по альтернативному пути!")
                // Используем альтернативный путь
                saveAktToHistory(url: alternativeURL, originalAkt: originalAkt)
                openDocumentPreview(url: alternativeURL)
                return
            }
            
            // Если файл не найден, показываем ошибку
            showErrorAlert(message: "Файл не найден. Возможно, он был удален системой. Попробуйте сгенерировать акт снова.")
            return
        }
        
        print("   ✅ Файл существует")
        
        // Проверяем размер файла
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int {
            print("   📊 Размер файла: \(fileSize) байт (\(fileSize / 1024) KB)")
            
            if fileSize == 0 {
                print("   ❌ [HISTORY_SAVE_OPTIONS] Файл пустой!")
                showErrorAlert(message: "Файл пустой или поврежден. Попробуйте сгенерировать акт снова.")
                return
            }
        }
        
        // Сразу сохраняем акт в историю
        saveAktToHistory(url: url, originalAkt: originalAkt)
        
        // И сразу открываем для просмотра
        openDocumentPreview(url: url)
        print("   ✅ [HISTORY_SAVE_OPTIONS] Акт сохранен и открыт")
    }
    
    private func openDocumentPreview(url: URL) {
        print("📄 [OPEN_DOCUMENT] НАЧАЛО ОТКРЫТИЯ ДОКУМЕНТА")
        print("   📋 URL документа: \(url.path)")
        print("   📋 URL абсолютный: \(url.absoluteString)")
        
        // Проверяем существование файла
        print("   🔍 Проверка существования файла...")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("   ❌ [OPEN_DOCUMENT] Файл не существует: \(url.path)")
            print("      Проверяем альтернативные пути...")
            
            // Пробуем найти файл в Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let alternativeURL = documentsURL.appendingPathComponent(fileName)
            print("      Альтернативный путь: \(alternativeURL.path)")
            
            if FileManager.default.fileExists(atPath: alternativeURL.path) {
                print("      ✅ Файл найден по альтернативному пути!")
                openDocumentPreview(url: alternativeURL)
                return
            }
            
            showAlert(title: "Ошибка", message: "Файл не найден или недоступен. Путь: \(url.path)")
            return
        }
        print("   ✅ Файл существует")
        
        // Проверяем размер файла
        print("   🔍 Проверка размера файла...")
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? NSNumber ?? 0
            let fileSizeInt = fileSize.intValue
            _ = fileSize // Используем переменную для устранения предупреждения
            print("      Размер файла: \(fileSizeInt) байт (\(fileSizeInt / 1024) KB)")
            
            if fileSizeInt == 0 {
                print("   ❌ [OPEN_DOCUMENT] Файл пустой: \(url.path)")
                showAlert(title: "Ошибка", message: "Файл пустой или поврежден")
                return
            }
            print("   ✅ Размер файла корректен")
        } catch {
            print("   ❌ [OPEN_DOCUMENT] Ошибка при проверке файла: \(error)")
            print("      Тип ошибки: \(type(of: error))")
            showAlert(title: "Ошибка", message: "Не удалось проверить файл: \(error.localizedDescription)")
            return
        }
        
        print("   🔍 Открытие DocumentViewController...")
        // Используем кастомный DocumentViewController вместо QLPreviewController
        let documentViewController = DocumentViewController(documentURL: url)
        let navigationController = UINavigationController(rootViewController: documentViewController)
        print("   ✅ DocumentViewController создан")
        present(navigationController, animated: true)
        print("   ✅ [OPEN_DOCUMENT] Документ открыт успешно")
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Хорошо", style: .default))
        present(alert, animated: true)
    }
    
    private func saveAktToHistory(url: URL, originalAkt: AKT) {
        print("🔄 [HISTORY_SAVE] НАЧАЛО СОХРАНЕНИЯ АКТА В ИСТОРИИ")
        print("   📋 Детали акта для сохранения:")
        print("      Номер: \(originalAkt.number)")
        print("      ID: \(originalAkt.id)")
        print("      Оригинальная дата создания: \(originalAkt.realDateCreate)")
        print("      Новый URL: \(url.path)")
        
        // Получаем текущий массив актов
        let currentArray = viewModel.aktArray
        print("   📊 Текущее состояние массива:")
        print("      Размер массива: \(currentArray.count)")
        print("      Доступные ID: \(currentArray.map { $0.id })")
        
        // Обновляем существующий акт с новым URL, сохраняя ID и дату создания
        print("   🔄 Создаем обновленный акт...")
        let updatedAkt = originalAkt.updated(with: url)
        print("   ✅ Обновленный акт создан:")
        print("      ID: \(updatedAkt.id)")
        print("      Дата создания: \(updatedAkt.realDateCreate)")
        print("      URL: \(updatedAkt.urlToFllACT?.path ?? "нет")")
        
        // ИСПОЛЬЗУЕМ СИСТЕМУ РЕАЛЬНОГО ВРЕМЕНИ ВМЕСТО ПРЯМОГО СОХРАНЕНИЯ
        print("   🔄 Используем систему реального времени для сохранения...")
        
        // Создаем редактируемый акт
        print("   🔄 Создаем редактируемый акт...")
        _ = DataFlowAKT.createEditableAKT(from: updatedAkt)
        print("   ✅ Редактируемый акт создан")
        
        // Сохраняем изменения в редактируемый акт
        print("   🔄 Сохраняем изменения в редактируемый акт...")
        viewModel.saveChangesToEditableAkt(updatedAkt)
        print("   ✅ Изменения сохранены в редактируемый акт")
        
        // Финализируем акт в историю
        print("   🔄 Финализируем акт в историю...")
        viewModel.finalizeEditableAktToHistory()
        print("   ✅ Акт финализирован в историю")
        
        // Применяем фильтрацию по году
        applyYearFilter()
        
        // Обновляем UI
        print("   🔄 Обновляем UI...")
        collection.reloadData()
        print("   ✅ UI обновлен")
        
        print("✅ [HISTORY_SAVE] Сохранение акта в истории завершено")
        print("   📊 Финальное состояние:")
        print("      Размер массива: \(viewModel.aktArray.count)")
    }
    
    private func shareAkt(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Настройка для iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func showErrorAlert(message: String = "Не удалось создать акт. Проверьте наличие шаблона.") {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Хорошо", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Short AKT Quick Add (Variant 1)
    @objc private func addShortAktTapped() {
        // Показываем полноценную форму для ручного ввода
        let form = ShortAktFormViewController(viewModel: viewModel, editingAkt: nil)
        form.onSaveCompletion = { [weak self] in
            // Обновляем историю после сохранения нового акта
            DispatchQueue.main.async {
                self?.loadHistoryData()
            }
        }
        let nav = UINavigationController(rootViewController: form)
        nav.modalPresentationStyle = UIModalPresentationStyle.formSheet
        present(nav, animated: true)
    }
    
    private struct ShortAktDraft {
        var number: String = ""
        var contractor: String = ""
        var objectTitle: String = ""
        var inspectionDate: Date = Date()
        var reportDueDate: Date = Date()
        var violationsTotal: Int = 0
        var distributionRaw: String = ""
    }
    
    private func startShortAktWizard() {}
    
    private func askText(title: String, message: String, placeholder: String, keyboard: UIKeyboardType, completion: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = placeholder
            tf.keyboardType = keyboard
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Далее", style: .default, handler: { _ in
            completion(alert.textFields?.first?.text)
        }))
        present(alert, animated: true)
    }
    
    private func askNumber(title: String, message: String, placeholder: String, completion: @escaping (Int?) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = placeholder
            tf.keyboardType = .numberPad
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Далее", style: .default, handler: { _ in
            if let text = alert.textFields?.first?.text, let value = Int(text.trimmingCharacters(in: .whitespaces)) {
                completion(value)
            } else {
                completion(nil)
            }
        }))
        present(alert, animated: true)
    }
    
    private func askDate(title: String, message: String, completion: @escaping (Date?) -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.placeholder = "дд.мм.гггг"
            tf.keyboardType = .numbersAndPunctuation
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        alert.addAction(UIAlertAction(title: "Далее", style: .default, handler: { _ in
            let text = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespaces) ?? ""
            let df = DateFormatter()
            df.dateFormat = "dd.MM.yyyy"
            df.locale = .current
            let date = df.date(from: text)
            completion(date)
        }))
        present(alert, animated: true)
    }
    
    private func finishShortAktWizard(with draft: ShortAktDraft) {}
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Safe AKT Deletion
    
    private func deleteAktSafely(akt: AKT, at indexPath: IndexPath) {
        print("🗑️ Начинаем безопасное удаление акта №\(akt.number)")
        print("   ID акта: \(akt.id)")
        DataFlowAKT.writeDebugLog(["location": "HistoryTabViewController.swift:deleteAktSafely", "message": "DELETE_AKT_START", "data": ["deleted_akt_id": akt.id.uuidString, "deleted_akt_number": akt.number, "deleted_akt_isShort": akt.isShortFormat, "indexPath_row": indexPath.row, "array_before_numbers": viewModel.aktArray.map { $0.number }, "array_before_ids": viewModel.aktArray.map { $0.id.uuidString }] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "DEL"])
        
        // ИСПРАВЛЕНИЕ: Останавливаем таймер мониторинга стиля перед удалением
        // Это предотвращает зависание при попытке восстановить стиль удаленной ячейки
        stopStyleMonitoringTimer()
        contextMenuIndexPath = nil
        
        // ИСПРАВЛЕНИЕ: Всегда обновляем массив перед удалением, чтобы получить актуальные данные
        viewModel.forceRefreshAktArray()
        
        // Применяем фильтрацию по году
        applyYearFilter()
        
        // Получаем текущий массив актов после обновления
        let currentArray = viewModel.aktArray
        print("   Текущий размер массива: \(currentArray.count)")
        _ = currentArray // Используем переменную для устранения предупреждения
        print("   Номера актов в массиве: \(currentArray.map { $0.number })")
        
        // ИСПРАВЛЕНИЕ: Удаляем ВСЕ дубликаты по ID, а не только первый найденный
        let duplicatesCount = currentArray.filter { $0.id == akt.id }.count
        if duplicatesCount > 1 {
            print("   ⚠️ Обнаружено дубликатов по ID: \(duplicatesCount)")
        }
        
        // Проверяем, что акт существует в массиве по ID
        guard currentArray.contains(where: { $0.id == akt.id }) else {
            print("❌ Акт с ID \(akt.id) не найден в массиве!")
            print("   Доступные ID: \(currentArray.map { $0.id })")
            showAlert(title: "Ошибка", message: "Акт не найден в списке")
            return
        }
        
        // Находим индекс первого вхождения для UI (используем indexPath.row для правильного отображения)
        let index = indexPath.row < currentArray.count ? indexPath.row : currentArray.firstIndex(where: { $0.id == akt.id }) ?? 0
        print("   ✅ Найден акт №\(akt.number) в позиции \(index)")
        if index < currentArray.count {
            print("   Проверка: акт в массиве имеет номер \(currentArray[index].number)")
        }
        
        // Сопоставляем только по ID: при дубликатах по номеру иначе можно сбросить не тот акт
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.id == akt.id {
            print("   🗑️ Удаляем редактируемый акт, так как он был удален из истории (совпадение по ID)")
            DataFlowAKT.deleteEditableAKT()
            print("   ✅ Редактируемый акт удален")
        }
        if let lastOpenedAkt = viewModel.getLastOpenedAkt(), lastOpenedAkt.id == akt.id {
            print("   🗑️ Очищаем lastOpenedAkt, так как удаляемый акт был последним открытым (совпадение по ID)")
            viewModel.clearLastOpenedAkt()
            print("   ✅ lastOpenedAkt очищен")
        }
        if let currentRealtimeAkt = SimpleRealtimeAKTManager.shared.currentAkt, currentRealtimeAkt.id == akt.id {
            print("   🗑️ Очищаем SimpleRealtimeAKTManager (совпадение по ID)")
            SimpleRealtimeAKTManager.shared.finishEditing()
            print("   ✅ SimpleRealtimeAKTManager очищен")
        }
        
        // Перемещаем акт в корзину
        TrashManager.addToTrash(akt)
        print("   Акт перемещен в корзину")
        
        // ИСПРАВЛЕНИЕ: Удаляем ВСЕ дубликаты по ID из массива
        var newArray = currentArray
        newArray.removeAll { $0.id == akt.id }
        let removedCount = currentArray.count - newArray.count
        if removedCount > 1 {
            print("   🗑️ Удалено дубликатов по ID: \(removedCount)")
        }
        
        print("   Акт удален из массива, новый размер: \(newArray.count)")
        print("   Оставшиеся номера актов: \(newArray.map { $0.number })")
        DataFlowAKT.writeDebugLog(["location": "HistoryTabViewController.swift:deleteAktSafely", "message": "DELETE_AKT_AFTER", "data": ["array_after_count": newArray.count, "array_after_numbers": newArray.map { $0.number }, "array_after_ids": newArray.map { $0.id.uuidString }, "removed_count": removedCount] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "DEL"])
        
        // Сохраняем обновленный массив
        DataFlowAKT.saveArr(arr: newArray)
        
        // Обновляем локальный массив в viewModel
        viewModel.aktArray = newArray
        
        // Применяем фильтрацию по году
        applyYearFilter()
        
        // Обновляем видимость кнопки корзины
        updateTrashButtonVisibility()
        
        // ИСПРАВЛЕНИЕ: Используем правильный индекс для удаления из UI
        // Находим актуальный индекс в обновленном массиве для UI
        let correctIndexPath = IndexPath(row: index, section: 0)
        
        // Обновляем UI с анимацией
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Проверяем, что коллекция все еще существует и индекс валиден
            let currentItemCount = self.collection.numberOfItems(inSection: 0)
            print("   Количество элементов в коллекции: \(currentItemCount)")
            print("   Правильный индекс для удаления из UI: \(index)")
            print("   Старый indexPath.row: \(indexPath.row)")
            
            // Используем правильный индекс вместо indexPath.row
            if currentItemCount > index && index >= 0 {
                self.collection.performBatchUpdates({
                    self.collection.deleteItems(at: [correctIndexPath])
                }, completion: { success in
                    if success {
                        print("✅ Акт №\(akt.number) успешно удален с анимацией")
                    } else {
                        print("⚠️ Ошибка анимации удаления, перезагружаем коллекцию")
                        self.applyYearFilter()
                        self.collection.reloadData()
                    }
                })
            } else {
                print("⚠️ Индекс коллекции невалиден (\(index) из \(currentItemCount)), перезагружаем коллекцию")
                self.applyYearFilter()
                self.collection.reloadData()
            }
        }
    }
    
    // MARK: - Open Akt for Editing
    
    private func openAktForEditing(_ akt: AKT) {
        // УНИФИЦИРОВАННАЯ ЛОГИКА: Используем тот же метод editAkt(), что и "Продолжить заполнение"
        print("🔄 [HISTORY] openAktForEditing: Используем унифицированный метод редактирования")
        
        // Используем тот же метод editAkt(), что и при нажатии "Редактировать" в меню
        editAkt(akt)
    }
    
    private func loadAktToTemplate(_ akt: AKT) {
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
    
    // MARK: - Long Press Handler
    
    @objc private func handleBadgePress(_ gesture: UILongPressGestureRecognizer) {
        guard let button = gesture.view as? UIButton else { return }
        
        switch gesture.state {
        case .began:
            // Начало нажатия - показываем hint
            isBadgePressed = true
            
            if button.tag == 1000 {
                // Бейдж сокращенного формата
                showShortAktHint()
            } else if button.tag == 1001 {
                // Бейдж полного формата
                showFullAktHint()
            }
            
        case .ended, .cancelled, .failed:
            // Окончание нажатия - скрываем hint
            isBadgePressed = false
            hideHintView()
            
        default:
            break
        }
    }
    
    // УБИРАЕМ кастомный обработчик, так как используем стандартный UIContextMenuConfiguration
    // iOS автоматически обрабатывает долгое нажатие и показывает меню с размытием фона
    // @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
    //     guard gesture.state == .began else { return }
    //     ...
    // }
    
    // УБИРАЕМ старый метод showContextMenu, так как используем стандартный UIContextMenuConfiguration
    // private func showContextMenu(for akt: AKT, at indexPath: IndexPath) {
    //     ...
    // }
    

}

extension HistoryTabViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return filteredAktArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        // Очищаем только контент внутри contentView, не трогая саму ячейку — иначе ломается иерархия и возникает "invalid reuse after initialization failure"
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        
        guard indexPath.row < filteredAktArray.count else {
            return cell
        }
        
        let item = filteredAktArray[indexPath.row]
        let isShort = isShortAkt(item)
        let isFull = isFullAkt(item)
        
        let initialCornerRadius = cell.layer.cornerRadius
        print("🔵 [CORNER_RADIUS] cellForItemAt indexPath.row=\(indexPath.row) - начальный cornerRadius=\(initialCornerRadius)")
        
        // Отключаем стандартное выделение ячейки
        cell.isSelected = false
        cell.isHighlighted = false
        
        // Прозрачный backgroundView
        cell.backgroundView = nil
        let transparentBackgroundView = UIView()
        transparentBackgroundView.backgroundColor = .clear
        cell.backgroundView = transparentBackgroundView
        
        // Скруглённый selectedBackgroundView вместо nil — убирает квадратную рамку при долгом нажатии (контекстное меню)
        let roundedHighlightView = UIView()
        roundedHighlightView.backgroundColor = .clear
        roundedHighlightView.layer.cornerRadius = 20
        roundedHighlightView.layer.masksToBounds = true
        cell.selectedBackgroundView = roundedHighlightView
        
        // Настройка фона и границ с учетом типа акта
        // Используем CATransaction для принудительного применения стиля
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        if isShort {
            // Специальный фон для сокращенного акта - приглушенное выделение
            cell.backgroundColor = .systemGray6
            cell.layer.borderWidth = 1
            // Используем более приглушенный оранжевый цвет
            cell.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.25).cgColor
            cell.layer.cornerRadius = 20
        } else if isFull {
            // Специальный фон для полного акта - спокойное выделение
            cell.backgroundColor = .systemGray6
            cell.layer.borderWidth = 1
            // Используем спокойный зеленый цвет для полных актов (чтобы не конфликтовать с синим текстом даты)
            cell.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.2).cgColor
            cell.layer.cornerRadius = 20
        } else {
            cell.backgroundColor = .systemGray6
            cell.layer.borderWidth = 0
            cell.layer.cornerRadius = 20
        }
        
        cell.layer.masksToBounds = true
        cell.clipsToBounds = true
        
        // Принудительно устанавливаем cornerRadius
        if cell.layer.cornerRadius != 20 {
            print("⚠️ [CORNER_RADIUS] cellForItemAt indexPath.row=\(indexPath.row) - cornerRadius был \(cell.layer.cornerRadius), исправляем на 20")
            cell.layer.cornerRadius = 20
        }
        
        // Исправляем cornerRadius всех sublayers ячейки
        // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
        if let sublayers = cell.layer.sublayers {
            for (index, sublayer) in sublayers.enumerated() {
                if sublayer.cornerRadius != 0 {
                    if sublayer.cornerRadius != 20 {
                        print("⚠️ [CORNER_RADIUS] cellForItemAt indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                    }
                    sublayer.cornerRadius = 20
                    sublayer.masksToBounds = true
                }
            }
        }
        
        CATransaction.commit()
        
        let finalCornerRadius = cell.layer.cornerRadius
        print("✅ [CORNER_RADIUS] cellForItemAt indexPath.row=\(indexPath.row) - финальный cornerRadius=\(finalCornerRadius)")
        
        // Дата проверки (синим цветом)
        let checkDateLabel = UILabel()
        checkDateLabel.text = "Проверка: \(formatter(date: item.date))"
        checkDateLabel.textColor = .systemBlue
        checkDateLabel.font = .systemFont(ofSize: 14, weight: .medium)
        cell.contentView.addSubview(checkDateLabel)
        checkDateLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
        }
        
        // Дата создания
        let createDateLabel = UILabel()
        createDateLabel.text = "Создан: \(formatter(date: item.realDateCreate))"
        createDateLabel.textColor = .secondaryLabel
        createDateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        cell.contentView.addSubview(createDateLabel)
        createDateLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
        
        // Бейдж для сокращенного акта
        if isShort {
            let badgeButton = UIButton(type: .system)
            // Более приглушенный цвет бейджа - очень светлый фон
            badgeButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.15)
            badgeButton.layer.borderWidth = 1
            badgeButton.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
            badgeButton.layer.cornerRadius = 12
            badgeButton.layer.shadowColor = UIColor.systemOrange.withAlphaComponent(0.1).cgColor
            badgeButton.layer.shadowOpacity = 0.05
            badgeButton.layer.shadowOffset = CGSize(width: 0, height: 1)
            badgeButton.layer.shadowRadius = 2
            badgeButton.setTitle("СОКРАЩЕННЫЙ", for: .normal)
            badgeButton.setTitleColor(UIColor.systemOrange.withAlphaComponent(0.8), for: .normal)
            badgeButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .bold)
            badgeButton.titleLabel?.adjustsFontSizeToFitWidth = true
            badgeButton.titleLabel?.minimumScaleFactor = 0.7
            badgeButton.isExclusiveTouch = true
            // Используем gesture recognizer для более точного отслеживания
            let pressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleBadgePress(_:)))
            pressGesture.minimumPressDuration = 0
            pressGesture.allowableMovement = 100
            pressGesture.delegate = self
            badgeButton.addGestureRecognizer(pressGesture)
            badgeButton.tag = 1000 // Тег для идентификации сокращенного бейджа
            cell.contentView.addSubview(badgeButton)
            
            badgeButton.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.top.equalToSuperview().inset(8)
                make.height.equalTo(24)
                make.width.greaterThanOrEqualTo(130)
            }
            
            // Иконка для сокращенного акта
            let iconImageView = UIImageView()
            iconImageView.image = UIImage(systemName: "doc.text.magnifyingglass")
            // Более приглушенный цвет иконки
            iconImageView.tintColor = UIColor.systemOrange.withAlphaComponent(0.35)
            iconImageView.contentMode = .scaleAspectFit
            cell.contentView.addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.right.equalToSuperview().inset(16)
                make.top.equalTo(checkDateLabel.snp.bottom).offset(4)
                make.width.height.equalTo(16)
            }
        }
        
        // Бейдж для полного акта
        if isFull {
            let badgeButton = UIButton(type: .system)
            // Спокойный зеленый цвет бейджа - мягкий фон (чтобы не смешивался с синим цветом даты проверки)
            badgeButton.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.12)
            badgeButton.layer.borderWidth = 1
            badgeButton.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.25).cgColor
            badgeButton.layer.cornerRadius = 12
            badgeButton.layer.shadowColor = UIColor.systemGreen.withAlphaComponent(0.08).cgColor
            badgeButton.layer.shadowOpacity = 0.04
            badgeButton.layer.shadowOffset = CGSize(width: 0, height: 1)
            badgeButton.layer.shadowRadius = 2
            badgeButton.setTitle("ПОЛНЫЙ", for: .normal)
            badgeButton.setTitleColor(UIColor.systemGreen.withAlphaComponent(0.7), for: .normal)
            badgeButton.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
            badgeButton.titleLabel?.adjustsFontSizeToFitWidth = true
            badgeButton.titleLabel?.minimumScaleFactor = 0.7
            badgeButton.isExclusiveTouch = true
            // Используем gesture recognizer для более точного отслеживания
            let pressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleBadgePress(_:)))
            pressGesture.minimumPressDuration = 0
            pressGesture.allowableMovement = 100
            pressGesture.delegate = self
            badgeButton.addGestureRecognizer(pressGesture)
            badgeButton.tag = 1001 // Тег для идентификации полного бейджа
            cell.contentView.addSubview(badgeButton)
            
            badgeButton.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.top.equalToSuperview().inset(8)
                make.height.equalTo(24)
                make.width.greaterThanOrEqualTo(90)
            }
            
            // Иконка для полного акта
            let iconImageView = UIImageView()
            iconImageView.image = UIImage(systemName: "doc.text.fill")
            // Спокойный зеленый цвет иконки
            iconImageView.tintColor = UIColor.systemGreen.withAlphaComponent(0.3)
            iconImageView.contentMode = .scaleAspectFit
            cell.contentView.addSubview(iconImageView)
            iconImageView.snp.makeConstraints { make in
                make.right.equalToSuperview().inset(16)
                make.top.equalTo(checkDateLabel.snp.bottom).offset(4)
                make.width.height.equalTo(16)
            }
        }
        
        let numbLabel = UILabel()
        numbLabel.textColor = .label
        numbLabel.text = "Aкт №\(item.number)"
        numbLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.contentView.addSubview(numbLabel)
        numbLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset((isShort || isFull) ? 36 : 8) // Отступ для бейджа
        }
        
        let objectLabel = UILabel()
        
        // Формируем читаемый список объектов
        let objectTitles = item.objectsCheck.map { $0.title }
        let maxObjectsToShow = 2 // Показываем максимум 2 объекта
        let objectsText: String
        
        if objectTitles.isEmpty {
            objectsText = "Объекты не указаны"
        } else if objectTitles.count == 1 {
            objectsText = "Объект: \(objectTitles[0])"
        } else if objectTitles.count <= maxObjectsToShow {
            objectsText = "Объекты: \(objectTitles.joined(separator: ", "))"
        } else {
            let visibleObjects = Array(objectTitles.prefix(maxObjectsToShow))
            objectsText = "Объекты: \(visibleObjects.joined(separator: ", ")) и еще \(objectTitles.count - maxObjectsToShow)"
        }
        
        objectLabel.text = objectsText
        objectLabel.textAlignment = .left
        objectLabel.textColor = .secondaryLabel
        objectLabel.font = .systemFont(ofSize: 14, weight: .regular)
        objectLabel.numberOfLines = 2 // Разрешаем перенос строки
        objectLabel.lineBreakMode = .byTruncatingTail
        cell.contentView.addSubview(objectLabel)
        objectLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(numbLabel.snp.bottom).inset(-12)
        }
        
        let organizationLabel = UILabel()
        organizationLabel.textAlignment = .left
        organizationLabel.text = "Организация: \(item.organization.title)"
        organizationLabel.textColor = .secondaryLabel
        organizationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        organizationLabel.numberOfLines = 1
        organizationLabel.lineBreakMode = .byTruncatingTail
        cell.contentView.addSubview(organizationLabel)
        organizationLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(objectLabel.snp.bottom).inset(-6)
        }
        
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        guard indexPath.row < filteredAktArray.count else {
            return CGSize(width: collectionView.frame.width - 32, height: 140)
        }
        let item = filteredAktArray[indexPath.row]
        let isShort = isShortAkt(item)
        let isFull = isFullAkt(item)
        // Увеличиваем высоту для сокращенных и полных актов из-за бейджа
        let height: CGFloat = (isShort || isFull) ? 160 : 140
        return CGSize(width: collectionView.frame.width - 32, height: height)
    }
    
    // Разрешаем подсветку, чтобы тап по строке вызывал didSelectItemAt (вход в редактирование).
    // Квадратная рамка при долгом нажатии убрана за счёт snapshot-preview в previewForHighlightingContextMenu.
    func collectionView(_ collectionView: UICollectionView, shouldHighlightItemAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    // Контролируем состояние highlight и немедленно восстанавливаем стиль
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        // #region agent log
        if let cell = collectionView.cellForItem(at: indexPath) {
            let subRadii = (cell.layer.sublayers ?? []).map { Double($0.cornerRadius) }
            debugLog("didHighlightItemAt entry", data: ["row": indexPath.row, "cellCornerRadius": Double(cell.layer.cornerRadius), "sublayerCornerRadii": subRadii], hypothesisId: "H2")
        }
        // #endregion
        print("🔵 [CORNER_RADIUS] didHighlightItemAt indexPath.row=\(indexPath.row) - НАЧАЛО highlight")
        
        // Сохраняем indexPath для мониторинга
        highlightedIndexPath = indexPath
        
        // Запускаем мониторинг highlight состояния
        startHighlightMonitoring()
        
        if let cell = collectionView.cellForItem(at: indexPath) {
            let beforeCornerRadius = cell.layer.cornerRadius
            print("🔵 [CORNER_RADIUS] didHighlightItemAt indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
            
            if cell.backgroundView == nil {
                let transparentBackgroundView = UIView()
                transparentBackgroundView.backgroundColor = .clear
                cell.backgroundView = transparentBackgroundView
            }
            
            // Немедленно восстанавливаем стиль
            restoreCellStyle(for: cell, at: indexPath)
            
            // Исправляем cornerRadius всех sublayers ячейки
            // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
            if let sublayers = cell.layer.sublayers {
                for (index, sublayer) in sublayers.enumerated() {
                    if sublayer.cornerRadius != 0 {
                        if sublayer.cornerRadius != 20 {
                            print("⚠️ [CORNER_RADIUS] didHighlightItemAt indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                        }
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        sublayer.cornerRadius = 20
                        sublayer.masksToBounds = true
                        CATransaction.commit()
                    }
                }
            }
            
            let afterCornerRadius = cell.layer.cornerRadius
            print("✅ [CORNER_RADIUS] didHighlightItemAt indexPath.row=\(indexPath.row) - cornerRadius после восстановления=\(afterCornerRadius)")
            
            // Также восстанавливаем через очень короткую задержку
            DispatchQueue.main.async { [weak self] in
                if let cell = collectionView.cellForItem(at: indexPath) {
                    self?.restoreCellStyle(for: cell, at: indexPath)
                    // Исправляем sublayers - более агрессивный подход
                    if let sublayers = cell.layer.sublayers {
                        for sublayer in sublayers {
                            if sublayer.cornerRadius != 0 {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                sublayer.cornerRadius = 20
                                sublayer.masksToBounds = true
                                CATransaction.commit()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Контролируем состояние unhighlight и восстанавливаем стиль
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        print("🔵 [CORNER_RADIUS] didUnhighlightItemAt indexPath.row=\(indexPath.row) - НАЧАЛО unhighlight")
        
        // Останавливаем мониторинг highlight
        stopHighlightMonitoring()
        highlightedIndexPath = nil
        
        if let cell = collectionView.cellForItem(at: indexPath) {
            let beforeCornerRadius = cell.layer.cornerRadius
            print("🔵 [CORNER_RADIUS] didUnhighlightItemAt indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
            
            if cell.backgroundView == nil {
                let transparentBackgroundView = UIView()
                transparentBackgroundView.backgroundColor = .clear
                cell.backgroundView = transparentBackgroundView
            }
            cell.isSelected = false
            cell.isHighlighted = false
            
            // Немедленно восстанавливаем стиль
            restoreCellStyle(for: cell, at: indexPath)
            
            // Исправляем cornerRadius всех sublayers ячейки
            // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
            if let sublayers = cell.layer.sublayers {
                for (index, sublayer) in sublayers.enumerated() {
                    if sublayer.cornerRadius != 0 {
                        if sublayer.cornerRadius != 20 {
                            print("⚠️ [CORNER_RADIUS] didUnhighlightItemAt indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                        }
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        sublayer.cornerRadius = 20
                        sublayer.masksToBounds = true
                        CATransaction.commit()
                    }
                }
            }
            
            let afterCornerRadius = cell.layer.cornerRadius
            print("✅ [CORNER_RADIUS] didUnhighlightItemAt indexPath.row=\(indexPath.row) - cornerRadius после восстановления=\(afterCornerRadius)")
            
            // Восстанавливаем стиль с задержками для надежности
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) { [weak self] in
                if let cell = collectionView.cellForItem(at: indexPath) {
                    self?.restoreCellStyle(for: cell, at: indexPath)
                    // Исправляем sublayers - более агрессивный подход
                    if let sublayers = cell.layer.sublayers {
                        for sublayer in sublayers {
                            if sublayer.cornerRadius != 0 {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                sublayer.cornerRadius = 20
                                sublayer.masksToBounds = true
                                CATransaction.commit()
                            }
                        }
                    }
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let cell = collectionView.cellForItem(at: indexPath) {
                    self?.restoreCellStyle(for: cell, at: indexPath)
                    // Исправляем sublayers - более агрессивный подход
                    if let sublayers = cell.layer.sublayers {
                        for sublayer in sublayers {
                            if sublayer.cornerRadius != 0 {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                sublayer.cornerRadius = 20
                                sublayer.masksToBounds = true
                                CATransaction.commit()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Запускаем мониторинг highlight состояния
    private func startHighlightMonitoring() {
        stopHighlightMonitoring()
        
        print("🔵 [CORNER_RADIUS] startHighlightMonitoring - запускаем CADisplayLink")
        highlightDisplayLink = CADisplayLink(target: self, selector: #selector(monitorHighlightStyle))
        highlightDisplayLink?.add(to: .current, forMode: .common)
        print("✅ [CORNER_RADIUS] startHighlightMonitoring - CADisplayLink запущен")
    }
    
    // Останавливаем мониторинг highlight состояния
    private func stopHighlightMonitoring() {
        if highlightDisplayLink != nil {
            print("🔵 [CORNER_RADIUS] stopHighlightMonitoring - останавливаем CADisplayLink")
            highlightDisplayLink?.invalidate()
            highlightDisplayLink = nil
            print("✅ [CORNER_RADIUS] stopHighlightMonitoring - CADisplayLink остановлен")
        }
    }
    
    // Метод для мониторинга стиля при highlight
    @objc private func monitorHighlightStyle() {
        guard let indexPath = highlightedIndexPath,
              let cell = collection.cellForItem(at: indexPath) else {
            // Ячейка больше не видна или indexPath сброшен
            return
        }
        
        let cornerRadius = cell.layer.cornerRadius
        if cornerRadius != 20 {
            print("⚠️ [CORNER_RADIUS] monitorHighlightStyle indexPath.row=\(indexPath.row) - обнаружено изменение cornerRadius на \(cornerRadius)!")
        }
        
        // Постоянно восстанавливаем стиль
        restoreCellStyle(for: cell, at: indexPath)
        
        // Также проверяем и исправляем все sublayers ячейки
        // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
        if let sublayers = cell.layer.sublayers {
            for (index, sublayer) in sublayers.enumerated() {
                if sublayer.cornerRadius != 0 {
                    if sublayer.cornerRadius != 20 {
                        print("⚠️ [CORNER_RADIUS] monitorHighlightStyle indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                    }
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    sublayer.cornerRadius = 20
                    sublayer.masksToBounds = true
                    CATransaction.commit()
                }
            }
        }
    }
    
    // Восстанавливаем стиль ячейки при её отображении
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let beforeCornerRadius = cell.layer.cornerRadius
        print("🔵 [CORNER_RADIUS] willDisplay indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
        
        if cell.backgroundView == nil {
            let transparentBackgroundView = UIView()
            transparentBackgroundView.backgroundColor = .clear
            cell.backgroundView = transparentBackgroundView
        }
        cell.isSelected = false
        cell.isHighlighted = false
        
        // Восстанавливаем правильный cornerRadius при каждом отображении ячейки
        restoreCellStyle(for: cell, at: indexPath)
        
        let afterCornerRadius = cell.layer.cornerRadius
        if beforeCornerRadius != afterCornerRadius {
            print("⚠️ [CORNER_RADIUS] willDisplay indexPath.row=\(indexPath.row) - cornerRadius изменился с \(beforeCornerRadius) на \(afterCornerRadius)")
        } else {
            print("✅ [CORNER_RADIUS] willDisplay indexPath.row=\(indexPath.row) - cornerRadius остался \(afterCornerRadius)")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("🔵 [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - НАЧАЛО")
        
        // Снимаем выделение сразу, чтобы избежать появления рамки
        collectionView.deselectItem(at: indexPath, animated: false)
        
        // Убираем визуальное выделение у ячейки
        if let cell = collectionView.cellForItem(at: indexPath) {
            cell.isSelected = false
            cell.isHighlighted = false
        }
        
        // Восстанавливаем стиль ячейки сразу после нажатия, чтобы предотвратить изменение cornerRadius
        if let cell = collectionView.cellForItem(at: indexPath) {
            let beforeCornerRadius = cell.layer.cornerRadius
            print("🔵 [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
            
            if cell.backgroundView == nil {
                let transparentBackgroundView = UIView()
                transparentBackgroundView.backgroundColor = .clear
                cell.backgroundView = transparentBackgroundView
            }
            cell.isSelected = false
            cell.isHighlighted = false
            
            restoreCellStyle(for: cell, at: indexPath)
            
            // Исправляем cornerRadius всех sublayers ячейки
            // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
            if let sublayers = cell.layer.sublayers {
                for (index, sublayer) in sublayers.enumerated() {
                    if sublayer.cornerRadius != 0 {
                        if sublayer.cornerRadius != 20 {
                            print("⚠️ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                        }
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        sublayer.cornerRadius = 20
                        sublayer.masksToBounds = true
                        CATransaction.commit()
                    }
                }
            }
            
            let afterCornerRadius = cell.layer.cornerRadius
            print("✅ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - cornerRadius после восстановления=\(afterCornerRadius)")
            
            // Также восстанавливаем стиль с небольшой задержкой, чтобы перехватить изменения,
            // которые могут произойти после обработки нажатия
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let cell = collectionView.cellForItem(at: indexPath) {
                    let cornerRadius = cell.layer.cornerRadius
                    print("🔵 [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - через 0.05 сек cornerRadius=\(cornerRadius)")
                    if cornerRadius != 20 {
                        print("⚠️ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - cornerRadius изменился на \(cornerRadius), восстанавливаем!")
                    }
                    self?.restoreCellStyle(for: cell, at: indexPath)
                    // Исправляем sublayers
                    if let sublayers = cell.layer.sublayers {
                        for sublayer in sublayers {
                            if sublayer.cornerRadius != 0 {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                sublayer.cornerRadius = 20
                                sublayer.masksToBounds = true
                                CATransaction.commit()
                            }
                        }
                    }
                    let afterCornerRadius = cell.layer.cornerRadius
                    print("✅ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - после восстановления через 0.05 сек cornerRadius=\(afterCornerRadius)")
                }
            }
            
            // Еще одна проверка через больший интервал для надежности
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                if let cell = collectionView.cellForItem(at: indexPath) {
                    let cornerRadius = cell.layer.cornerRadius
                    print("🔵 [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - через 0.2 сек cornerRadius=\(cornerRadius)")
                    if cornerRadius != 20 {
                        print("⚠️ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - cornerRadius изменился на \(cornerRadius), восстанавливаем!")
                    }
                    self?.restoreCellStyle(for: cell, at: indexPath)
                    // Исправляем sublayers
                    if let sublayers = cell.layer.sublayers {
                        for sublayer in sublayers {
                            if sublayer.cornerRadius != 0 {
                                CATransaction.begin()
                                CATransaction.setDisableActions(true)
                                sublayer.cornerRadius = 20
                                sublayer.masksToBounds = true
                                CATransaction.commit()
                            }
                        }
                    }
                    let afterCornerRadius = cell.layer.cornerRadius
                    print("✅ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - после восстановления через 0.2 сек cornerRadius=\(afterCornerRadius)")
                }
            }
        } else {
            print("❌ [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - ячейка не найдена!")
        }
        
        print("🔵 [CORNER_RADIUS] didSelectItemAt indexPath.row=\(indexPath.row) - КОНЕЦ")
        
        guard indexPath.row < filteredAktArray.count else {
            return
        }
        
        if filteredAktArray.count > 0 {
            // Добавляем вибрацию при нажатии
            triggerHapticFeedback()
            
            // Получаем выбранный акт из отфильтрованного массива
            let selectedAkt = filteredAktArray[indexPath.row]
            
            // ИСПРАВЛЕНИЕ: Загружаем актуальный акт из файла по ID, чтобы получить свежие данные
            // Это исправляет проблему, когда дата предоставления отчета не обновляется в форме
            let allAkts = DataFlowAKT.loadArr()
            let actualAkt = allAkts.first(where: { $0.id == selectedAkt.id }) ?? selectedAkt
            
            // Проверяем, является ли акт сокращенным
            if isShortAkt(actualAkt) {
                // Открываем форму редактирования сокращенного акта (та же форма, что и при создании)
                openShortAktForEditing(actualAkt)
            } else {
                // Открываем акт для редактирования в окне продолжения заполнения
                openAktForEditing(actualAkt)
            }
        }
    }
    
    // MARK: - Short Akt Editing
    
    private func openShortAktForEditing(_ akt: AKT) {
        // ИСПРАВЛЕНИЕ: Очищаем кэш перед загрузкой, чтобы получить актуальные данные из файла
        // Это исправляет проблему, когда дата предоставления отчета не обновляется в форме
        DataCache.shared.invalidate("aktArray")
        print("🗑️ [HISTORY] openShortAktForEditing: Кэш aktArray очищен перед загрузкой")
        
        // ИСПРАВЛЕНИЕ: Загружаем актуальный акт из файла по ID, чтобы получить свежие данные
        // Это исправляет проблему, когда дата предоставления отчета не обновляется в форме
        // ВАЖНО: Загружаем напрямую из файла, минуя кэш, чтобы получить актуальные данные
        // Принудительно очищаем кэш перед загрузкой, чтобы гарантировать актуальность данных
        DataCache.shared.invalidate("aktArray")
        let allAkts = DataFlowAKT.loadArr()
        
        guard let actualAkt = allAkts.first(where: { $0.id == akt.id }) else {
            print("❌ [HISTORY] openShortAktForEditing: Актуальный акт с ID \(akt.id) не найден, используем переданный акт")
            // Если акт не найден в файле, используем переданный акт
            let form = ShortAktFormViewController(viewModel: viewModel, editingAkt: akt)
            form.onSaveCompletion = { [weak self] in
                DispatchQueue.main.async {
                    self?.loadHistoryData()
                }
            }
            let nav = UINavigationController(rootViewController: form)
            nav.modalPresentationStyle = UIModalPresentationStyle.formSheet
            present(nav, animated: true)
            return
        }
        
        print("🔵 [HISTORY] openShortAktForEditing: Сохраняем акт №\(actualAkt.number) (ID: \(actualAkt.id)) как lastOpenedAkt")
        print("   📅 Дата предоставления отчета из файла: \(actualAkt.actPredostavlenDate)")
        print("   📅 Дата проверки из файла: \(actualAkt.date)")
        print("   📅 Дата предоставления отчета из переданного акта: \(akt.actPredostavlenDate)")
        viewModel.setLastOpenedAkt(actualAkt)
        
        let form = ShortAktFormViewController(viewModel: viewModel, editingAkt: actualAkt)
        form.onSaveCompletion = { [weak self] in
            // Обновляем историю после сохранения отредактированного акта
            DispatchQueue.main.async {
                self?.loadHistoryData()
            }
        }
        let nav = UINavigationController(rootViewController: form)
        nav.modalPresentationStyle = UIModalPresentationStyle.formSheet
        present(nav, animated: true)
    }
    
    @objc private func customBackAction() {
        navigationController?.popViewController(animated: true)
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // #region agent log
        debugLog("contextMenuConfigurationForItemAt entry", data: ["row": indexPath.row], hypothesisId: "H1")
        if let cell = collection.cellForItem(at: indexPath) {
            let subRadii = (cell.layer.sublayers ?? []).map { Double($0.cornerRadius) }
            debugLog("contextMenuConfig cell state", data: ["cellCornerRadius": Double(cell.layer.cornerRadius), "sublayerCornerRadii": subRadii], hypothesisId: "H1")
        }
        // #endregion
        guard indexPath.row < filteredAktArray.count else {
            return nil
        }
        let akt = self.filteredAktArray[indexPath.row]
        let isShort = self.isShortAkt(akt)
        let isFull = self.isFullAkt(akt)
        
        // Сохраняем стиль ячейки перед показом меню
        if let cell = collection.cellForItem(at: indexPath) {
            // Сохраняем текущий cornerRadius
            cell.layer.cornerRadius = 20
            cell.clipsToBounds = true
        }
        
        // Используем стандартный UIContextMenuConfiguration с правильным identifier
        // iOS автоматически применяет размытие фона при показе меню
        return UIContextMenuConfiguration(
            identifier: indexPath as NSCopying,
            previewProvider: {
                // Возвращаем nil для показа только меню без preview
                // iOS автоматически создаст размытие фона
                return nil
            }
        ) { [weak self] _ in
            guard let self = self else { return UIMenu() }
            
            var actions: [UIAction] = []
            
            // Редактировать - только для не-сокращенных и не-полных актов
            if !isShort && !isFull {
                let editAction = UIAction(
                    title: "Редактировать",
                    image: UIImage(systemName: "pencil")
                ) { _ in
                    self.editAkt(akt)
                }
                actions.append(editAction)
            }
            
            // Сформировать акт - для всех актов кроме сокращенных
            if !isShort {
                let generateAction = UIAction(
                    title: "Сформировать акт",
                    image: UIImage(systemName: "doc.text")
                ) { _ in
                    self.generateAkt(for: akt)
                }
                actions.append(generateAction)
            }
            
            // Удалить
            let deleteAction = UIAction(
                title: "Удалить",
                image: UIImage(systemName: "trash"),
                attributes: .destructive
            ) { _ in
                self.deleteAktSafely(akt: akt, at: indexPath)
            }
            actions.append(deleteAction)
            
            // Возвращаем меню - iOS автоматически применит размытие фона
            return UIMenu(title: "", children: actions)
        }
    }
    
    // Контролируем стиль ячейки при показе контекстного меню.
    // Возвращаем скруглённый snapshot вместо ячейки — убирает квадратную рамку с первого кадра.
    func collectionView(_ collectionView: UICollectionView, previewForHighlightingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collection.cellForItem(at: indexPath) else {
            return nil
        }
        // #region agent log
        let subRadii = (cell.layer.sublayers ?? []).map { Double($0.cornerRadius) }
        debugLog("previewForHighlightingContextMenu ENTRY", data: ["row": indexPath.row, "cellCornerRadius": Double(cell.layer.cornerRadius), "sublayerCornerRadii": subRadii], hypothesisId: "H4")
        // #endregion
        contextMenuIndexPath = indexPath
        restoreCellStyle(for: cell, at: indexPath)
        startStyleMonitoringTimer()
        
        // Snapshot ячейки в нативном масштабе — текст не уменьшается при открытии меню
        let size = cell.bounds.size
        let scale = cell.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let path = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 20)
            path.addClip()
            cell.drawHierarchy(in: cell.bounds, afterScreenUpdates: true)
        }
        let imageView = UIImageView(image: image)
        imageView.frame = cell.bounds
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        imageView.backgroundColor = cell.backgroundColor ?? .systemGray6
        // Компенсация системного уменьшения preview — текст остаётся того же размера
        imageView.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        
        let frameInCollection = collection.convert(cell.bounds, from: cell)
        imageView.frame = frameInCollection
        collection.addSubview(imageView)
        contextMenuPreviewSnapshotView = imageView
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: imageView.bounds, cornerRadius: 20)
        
        return UITargetedPreview(view: imageView, parameters: parameters)
    }
    
    // Восстанавливаем правильный стиль ячейки
    private func restoreCellStyle(for cell: UICollectionViewCell, at indexPath: IndexPath) {
        // ИСПРАВЛЕНИЕ: Проверяем, что индекс валиден перед обращением к массиву
        guard indexPath.row < filteredAktArray.count else {
            print("⚠️ [CORNER_RADIUS] restoreCellStyle - индекс \(indexPath.row) выходит за границы массива (размер: \(filteredAktArray.count))")
            return
        }
        
        let item = filteredAktArray[indexPath.row]
        let isShort = isShortAkt(item)
        let isFull = isFullAkt(item)
        
        let beforeCornerRadius = cell.layer.cornerRadius
        let stackTrace = Thread.callStackSymbols.prefix(3).joined(separator: " -> ")
        
        // Принудительно устанавливаем правильный стиль - ВСЕГДА, даже если кажется что он уже правильный
        // Это предотвращает проскальзывание квадратных углов
        // Используем CATransaction для отключения анимаций и принудительного применения изменений
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        
        // Принудительно устанавливаем cornerRadius = 20, чтобы предотвратить изменение на квадратные углы
        cell.layer.cornerRadius = 20
        cell.layer.masksToBounds = true
        cell.clipsToBounds = true
        
        // Убеждаемся, что cornerRadius действительно установлен
        if cell.layer.cornerRadius != 20 {
            print("⚠️ [CORNER_RADIUS] restoreCellStyle indexPath.row=\(indexPath.row) - cornerRadius был \(cell.layer.cornerRadius) после установки, исправляем!")
            cell.layer.cornerRadius = 20
        }
        
        // Исправляем cornerRadius всех sublayers ячейки
        // iOS может создавать внутренние sublayers с неправильным cornerRadius при highlight
        // Более агрессивный подход - устанавливаем cornerRadius=20 для всех sublayers, которые не равны 0
        if let sublayers = cell.layer.sublayers {
            for (index, sublayer) in sublayers.enumerated() {
                // Исправляем все sublayers, которые имеют cornerRadius отличный от 0 или 20
                // Устанавливаем 20 для всех sublayers, которые не равны 0 (0 означает, что sublayer не должен иметь скругления)
                if sublayer.cornerRadius != 0 {
                    if sublayer.cornerRadius != 20 {
                        print("⚠️ [CORNER_RADIUS] restoreCellStyle indexPath.row=\(indexPath.row) - исправляем sublayer[\(index)].cornerRadius с \(sublayer.cornerRadius) на 20")
                    }
                    sublayer.cornerRadius = 20
                    sublayer.masksToBounds = true
                }
            }
        }
        
        if isShort {
            cell.layer.borderWidth = 1
            cell.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.25).cgColor
        } else if isFull {
            cell.layer.borderWidth = 1
            cell.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.2).cgColor
        } else {
            cell.layer.borderWidth = 0
        }
        
        CATransaction.commit()
        
        // Дополнительно принудительно обновляем слой
        cell.layer.setNeedsDisplay()
        cell.layer.displayIfNeeded()
        
        let afterCornerRadius = cell.layer.cornerRadius
        if beforeCornerRadius != afterCornerRadius {
            print("🔄 [CORNER_RADIUS] restoreCellStyle indexPath.row=\(indexPath.row) - ИЗМЕНИЛ cornerRadius с \(beforeCornerRadius) на \(afterCornerRadius)")
            print("   📍 Вызвано из: \(stackTrace)")
        } else if afterCornerRadius != 20 {
            print("⚠️ [CORNER_RADIUS] restoreCellStyle indexPath.row=\(indexPath.row) - cornerRadius остался \(afterCornerRadius) вместо 20!")
        }
    }
    
    // Запускаем мониторинг стиля с помощью CADisplayLink для максимальной точности
    private func startStyleMonitoringTimer() {
        stopStyleMonitoringTimer()
        
        // Используем CADisplayLink для синхронизации с частотой обновления экрана
        styleDisplayLink = CADisplayLink(target: self, selector: #selector(monitorCellStyle))
        styleDisplayLink?.add(to: .current, forMode: .common)
        
        // Также создаем таймер как резервный вариант
        contextMenuStyleTimer = Timer(timeInterval: 0.008, repeats: true) { [weak self] _ in
            self?.checkAndRestoreCellStyle()
        }
        RunLoop.current.add(contextMenuStyleTimer!, forMode: .common)
    }
    
    // Метод для мониторинга стиля через CADisplayLink
    @objc private func monitorCellStyle() {
        checkAndRestoreCellStyle()
    }
    
    // Проверяем и восстанавливаем стиль ячейки
    private func checkAndRestoreCellStyle() {
        guard let indexPath = contextMenuIndexPath else {
            // Если indexPath не установлен, останавливаем таймер
            stopStyleMonitoringTimer()
            return
        }
        
        // ИСПРАВЛЕНИЕ: Проверяем, что индекс валиден и ячейка существует в массиве
        guard indexPath.row < viewModel.aktArray.count else {
            // Ячейка была удалена, останавливаем таймер
            print("⚠️ [CORNER_RADIUS] checkAndRestoreCellStyle - ячейка с indexPath.row=\(indexPath.row) была удалена, останавливаем таймер")
            stopStyleMonitoringTimer()
            contextMenuIndexPath = nil
            return
        }
        
        guard let cell = collection.cellForItem(at: indexPath) else {
            // Ячейка не найдена в коллекции, возможно была удалена
            return
        }
        
        let beforeCornerRadius = cell.layer.cornerRadius
        // #region agent log
        if beforeCornerRadius != 20 {
            let subRadii = (cell.layer.sublayers ?? []).map { Double($0.cornerRadius) }
            debugLog("checkAndRestoreCellStyle detected non-rounded", data: ["row": indexPath.row, "beforeCR": Double(beforeCornerRadius), "sublayerCornerRadii": subRadii], hypothesisId: "H3")
        }
        // #endregion
        if beforeCornerRadius != 20 {
            print("⚠️ [CORNER_RADIUS] checkAndRestoreCellStyle indexPath.row=\(indexPath.row) - обнаружено изменение cornerRadius на \(beforeCornerRadius)!")
        }
        
        // ВСЕГДА восстанавливаем стиль, даже если кажется что он правильный
        // Это предотвращает проскальзывание квадратных углов
        restoreCellStyle(for: cell, at: indexPath)
        
        let afterCornerRadius = cell.layer.cornerRadius
        if beforeCornerRadius != afterCornerRadius {
            print("✅ [CORNER_RADIUS] checkAndRestoreCellStyle indexPath.row=\(indexPath.row) - восстановлено с \(beforeCornerRadius) на \(afterCornerRadius)")
        }
    }
    
    // Останавливаем таймер мониторинга
    private func stopStyleMonitoringTimer() {
        styleDisplayLink?.invalidate()
        styleDisplayLink = nil
        contextMenuStyleTimer?.invalidate()
        contextMenuStyleTimer = nil
    }
    
    // Контролируем стиль ячейки при скрытии контекстного меню — возвращаем скруглённый snapshot, чтобы не было квадратной рамки при закрытии
    func collectionView(_ collectionView: UICollectionView, previewForDismissingContextMenuWithConfiguration configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let indexPath = configuration.identifier as? IndexPath,
              let cell = collection.cellForItem(at: indexPath) else {
            return nil
        }
        restoreCellStyle(for: cell, at: indexPath)
        
        let size = cell.bounds.size
        let scale = cell.window?.screen.scale ?? UIScreen.main.scale
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { _ in
            let path = UIBezierPath(roundedRect: cell.bounds, cornerRadius: 20)
            path.addClip()
            cell.drawHierarchy(in: cell.bounds, afterScreenUpdates: true)
        }
        let imageView = UIImageView(image: image)
        imageView.frame = cell.bounds
        imageView.layer.cornerRadius = 20
        imageView.clipsToBounds = true
        imageView.backgroundColor = cell.backgroundColor ?? .systemGray6
        imageView.transform = CGAffineTransform(scaleX: 1.03, y: 1.03)
        
        let frameInCollection = collection.convert(cell.bounds, from: cell)
        imageView.frame = frameInCollection
        collection.addSubview(imageView)
        contextMenuDismissSnapshotView = imageView
        
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        parameters.visiblePath = UIBezierPath(roundedRect: imageView.bounds, cornerRadius: 20)
        
        return UITargetedPreview(view: imageView, parameters: parameters)
    }
    
    // Восстанавливаем правильный стиль ячейки после закрытия контекстного меню
    func collectionView(_ collectionView: UICollectionView, willEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        // Получаем indexPath из configuration
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        
        print("🔵 [CORNER_RADIUS] willEndContextMenuInteraction indexPath.row=\(indexPath.row) - НАЧАЛО")
        
        // Снимаем выделение, если оно есть
        collectionView.deselectItem(at: indexPath, animated: false)
        
        // Продолжаем мониторинг до завершения анимации
        animator?.addCompletion { [weak self] in
            guard let self = self else { return }
            
            print("🔵 [CORNER_RADIUS] willEndContextMenuInteraction indexPath.row=\(indexPath.row) - анимация завершена")
            
            // Останавливаем таймер после завершения анимации
            self.stopStyleMonitoringTimer()
            self.contextMenuIndexPath = nil
            // Удаляем snapshot'ы preview из иерархии
            self.contextMenuPreviewSnapshotView?.removeFromSuperview()
            self.contextMenuPreviewSnapshotView = nil
            self.contextMenuDismissSnapshotView?.removeFromSuperview()
            self.contextMenuDismissSnapshotView = nil
            
            // Восстанавливаем стиль конкретной ячейки после завершения анимации
            // ИСПРАВЛЕНИЕ: Проверяем, что индекс валиден перед восстановлением стиля
            guard indexPath.row < self.viewModel.aktArray.count,
                  let cell = self.collection.cellForItem(at: indexPath) else {
                print("⚠️ [CORNER_RADIUS] willEndContextMenuInteraction - ячейка не найдена или индекс невалиден")
                return
            }
            
            let beforeCornerRadius = cell.layer.cornerRadius
            print("🔵 [CORNER_RADIUS] willEndContextMenuInteraction indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
            
            UIView.performWithoutAnimation {
                self.restoreCellStyle(for: cell, at: indexPath)
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
            }
            
            let afterCornerRadius = cell.layer.cornerRadius
            print("✅ [CORNER_RADIUS] willEndContextMenuInteraction indexPath.row=\(indexPath.row) - cornerRadius после восстановления=\(afterCornerRadius)")
            
            // Убеждаемся, что выделение снято
            self.collection.deselectItem(at: indexPath, animated: false)
            
            print("🔵 [CORNER_RADIUS] willEndContextMenuInteraction indexPath.row=\(indexPath.row) - КОНЕЦ")
        }
    }
    
    // Дополнительно восстанавливаем стиль после полного завершения
    func collectionView(_ collectionView: UICollectionView, didEndContextMenuInteraction configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        // Получаем indexPath из configuration
        guard let indexPath = configuration.identifier as? IndexPath else { return }
        
        print("🔵 [CORNER_RADIUS] didEndContextMenuInteraction indexPath.row=\(indexPath.row) - НАЧАЛО")
        
        // Снимаем выделение, если оно есть
        collectionView.deselectItem(at: indexPath, animated: false)
        
        // Останавливаем таймер
        self.stopStyleMonitoringTimer()
        contextMenuPreviewSnapshotView?.removeFromSuperview()
        contextMenuPreviewSnapshotView = nil
        contextMenuDismissSnapshotView?.removeFromSuperview()
        contextMenuDismissSnapshotView = nil
        
        // Восстанавливаем стиль конкретной ячейки
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Убеждаемся, что выделение снято
            self.collection.deselectItem(at: indexPath, animated: false)
            
            if let cell = self.collection.cellForItem(at: indexPath) {
                let beforeCornerRadius = cell.layer.cornerRadius
                print("🔵 [CORNER_RADIUS] didEndContextMenuInteraction indexPath.row=\(indexPath.row) - cornerRadius до восстановления=\(beforeCornerRadius)")
                
                self.restoreCellStyle(for: cell, at: indexPath)
                cell.setNeedsLayout()
                cell.layoutIfNeeded()
                
                let afterCornerRadius = cell.layer.cornerRadius
                print("✅ [CORNER_RADIUS] didEndContextMenuInteraction indexPath.row=\(indexPath.row) - cornerRadius после восстановления=\(afterCornerRadius)")
            }
            
            // Очищаем сохраненный indexPath
            self.contextMenuIndexPath = nil
            
            print("🔵 [CORNER_RADIUS] didEndContextMenuInteraction indexPath.row=\(indexPath.row) - КОНЕЦ")
        }
    }

}

// MARK: - UIGestureRecognizerDelegate
extension HistoryTabViewController {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // Разрешаем одновременную работу жестов для бейджей
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Жест должен работать только для кнопок бейджей
        return touch.view is UIButton && (touch.view?.tag == 1000 || touch.view?.tag == 1001)
    }
}

// MARK: - QLPreviewControllerDataSource
extension HistoryTabViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return documentURL == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return documentURL! as QLPreviewItem
    }
}

// MARK: - Inline ShortAktFormViewController (to avoid target linking issues)
final class ShortAktFormViewController: UIViewController, UIPickerViewDataSource, UIPickerViewDelegate {
    private let viewModel: MainAKTViewModel
    private let editingAkt: AKT?
    private var isEditingMode: Bool { editingAkt != nil }
    
    // Callback для обновления истории после сохранения
    var onSaveCompletion: (() -> Void)?
    
    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    
    private let numberField = UITextField()
    private let numberStatusLabel = UILabel()
    private let numberPicker = UIPickerView()
    private var numberOptions: [String] = []
    
    private lazy var inspectionDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ru_RU")
        picker.calendar = Calendar(identifier: .gregorian)
        return picker
    }()
    
    private lazy var reportDueDatePicker: UIDatePicker = {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .wheels
        picker.locale = Locale(identifier: "ru_RU")
        picker.calendar = Calendar(identifier: .gregorian)
        return picker
    }()
    
    private let organizationButton = UIButton(type: .system)
    private let objectButton = UIButton(type: .system)
    
    private var selectedOrganization: Organization?
    private var selectedObject: ObjectCheck?
    
    private var violationCounts: [String: Int] = [:]
    private let totalViolationsLabel = UILabel()
    private var violationSteppers: [String: (stepper: UIStepper, label: UILabel)] = [:]
    
    init(viewModel: MainAKTViewModel, editingAkt: AKT? = nil) {
        self.viewModel = viewModel
        self.editingAkt = editingAkt
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = isEditingMode ? "Редактирование сокращенного акта" : "Сокращенный акт"
        view.backgroundColor = .systemBackground
        setupData()
        setupUI()
        
        // ИСПРАВЛЕНИЕ: Загружаем данные из акта синхронно, чтобы дата предоставления отчета
        // загрузилась сразу и не перезаписывалась значениями по умолчанию
        if let akt = editingAkt {
            loadDataFromAkt(akt)
        }
    }
    
    private func setupData() {
        numberOptions = (1...9999).map { String($0) }
        
        // DatePicker уже настроены с русской локалью при создании (lazy properties)
        // Доступ к lazy properties инициализирует их, если еще не были созданы
        
        for t in ViolationType.allCases { violationCounts[t.displayName] = 0 }

        // ИСПРАВЛЕНИЕ: Дата предоставления отчета по умолчанию устанавливается только для новых актов
        // Для редактируемых актов дата загружается из акта в loadDataFromAkt
        if !isEditingMode {
            // Дата предоставления отчета по умолчанию = дата проверки + 1 месяц (только для новых актов)
            if let plusMonth = Calendar.current.date(byAdding: .month, value: 1, to: inspectionDatePicker.date) {
                reportDueDatePicker.date = plusMonth
            }
        }
        // Автообновление даты предоставления при изменении даты проверки
        inspectionDatePicker.addTarget(self, action: #selector(inspectionDateChanged), for: .valueChanged)
    }

    @objc private func inspectionDateChanged() {
        // ИСПРАВЛЕНИЕ: Автообновление даты предоставления отчета только для новых актов
        // Для редактируемых актов дата предоставления отчета не должна автоматически меняться
        // при изменении даты проверки, так как она уже установлена пользователем
        if !isEditingMode {
            if let plusMonth = Calendar.current.date(byAdding: .month, value: 1, to: inspectionDatePicker.date) {
                reportDueDatePicker.date = plusMonth
            }
        }
    }
    
    private func setupUI() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Закрыть", style: .plain, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(saveTapped))
        
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        // Тап по пустому месту — скрыть все всплывающие элементы ввода
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        scrollView.addGestureRecognizer(tap)
        
        contentStack.axis = .vertical
        contentStack.spacing = 16
        contentStack.alignment = .fill
        contentStack.distribution = .fill
        scrollView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(view.safeAreaLayoutGuide.snp.width).inset(16)
        }
        
        let numberContainer = UIView()
        let numberTitle = label("Номер акта")
        numberField.borderStyle = .roundedRect
        numberField.inputView = numberPicker
        numberField.placeholder = "Выберите номер"
        numberField.textAlignment = .center
        numberStatusLabel.font = .systemFont(ofSize: 12)
        numberStatusLabel.textColor = .secondaryLabel
        numberPicker.dataSource = self
        numberPicker.delegate = self
        numberContainer.addSubview(numberTitle)
        numberContainer.addSubview(numberField)
        numberContainer.addSubview(numberStatusLabel)
        numberTitle.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        numberField.snp.makeConstraints { make in
            make.top.equalTo(numberTitle.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.height.equalTo(44)
        }
        numberStatusLabel.snp.makeConstraints { make in
            make.top.equalTo(numberField.snp.bottom).offset(4)
            make.left.right.bottom.equalToSuperview()
        }
        contentStack.addArrangedSubview(numberContainer)
        
        let dateContainer = UIView()
        let dateTitle = label("Даты")
        let datesStack = UIStackView()
        datesStack.axis = .vertical
        datesStack.spacing = 8  // Уменьшено расстояние между элементами дат
        let inspectionLabel = label("Дата проверки")
        let reportLabel = label("Дата предоставления отчета")
        
        // Обертка для date picker проверки с пустым полем справа
        let inspectionPickerContainer = UIView()
        inspectionPickerContainer.backgroundColor = .systemBackground
        inspectionPickerContainer.addSubview(inspectionDatePicker)
        inspectionDatePicker.snp.makeConstraints { make in
            make.top.bottom.left.equalToSuperview()
            make.right.equalToSuperview().offset(-60)  // Пустое поле справа от года
        }
        
        // Обертка для date picker отчета с пустым полем справа
        let reportPickerContainer = UIView()
        reportPickerContainer.backgroundColor = .systemBackground
        reportPickerContainer.addSubview(reportDueDatePicker)
        reportDueDatePicker.snp.makeConstraints { make in
            make.top.bottom.left.equalToSuperview()
            make.right.equalToSuperview().offset(-60)  // Пустое поле справа от года
        }
        
        dateContainer.addSubview(dateTitle)
        dateContainer.addSubview(datesStack)
        datesStack.addArrangedSubview(inspectionLabel)
        datesStack.addArrangedSubview(inspectionPickerContainer)
        datesStack.addArrangedSubview(reportLabel)
        datesStack.addArrangedSubview(reportPickerContainer)
        dateTitle.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        datesStack.snp.makeConstraints { make in
            make.top.equalTo(dateTitle.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
        }
        contentStack.addArrangedSubview(dateContainer)
        
        let orgContainer = UIView()
        let orgTitle = label("Подрядчик (организация)")
        styleSelectorButton(organizationButton, title: "Выбрать организацию")
        organizationButton.addTarget(self, action: #selector(selectOrganization), for: .touchUpInside)
        orgContainer.addSubview(orgTitle)
        orgContainer.addSubview(organizationButton)
        orgTitle.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        organizationButton.snp.makeConstraints { make in
            make.top.equalTo(orgTitle.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        contentStack.addArrangedSubview(orgContainer)
        
        let objContainer = UIView()
        let objTitle = label("Объект")
        styleSelectorButton(objectButton, title: "Выбрать объект")
        objectButton.addTarget(self, action: #selector(selectObject), for: .touchUpInside)
        objContainer.addSubview(objTitle)
        objContainer.addSubview(objectButton)
        objTitle.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        objectButton.snp.makeConstraints { make in
            make.top.equalTo(objTitle.snp.bottom).offset(8)
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(44)
        }
        contentStack.addArrangedSubview(objContainer)
        
        let violContainer = UIView()
        let violTitle = label("Распределение нарушений по видам")
        let violStack = UIStackView()
        violStack.axis = .vertical
        violStack.spacing = 20
        for t in ViolationType.allCases {
            let row = violationRow(title: t.displayName)
            violStack.addArrangedSubview(row)
        }
        // Настраиваем итоговую строку
        totalViolationsLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        totalViolationsLabel.textColor = .label
        totalViolationsLabel.text = "Итого нарушений: 0"

        violContainer.addSubview(violTitle)
        violContainer.addSubview(violStack)
        violContainer.addSubview(totalViolationsLabel)
        violTitle.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
        }
        violStack.snp.makeConstraints { make in
            make.top.equalTo(violTitle.snp.bottom).offset(8)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(totalViolationsLabel.snp.top).offset(-12)
        }
        totalViolationsLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
        }
        contentStack.addArrangedSubview(violContainer)

        // Начальное обновление итога
        updateTotalViolations()
    }
    
    private func label(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = .systemFont(ofSize: 14, weight: .semibold)
        return l
    }
    private func styleSelectorButton(_ button: UIButton, title: String) {
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.title = title
            config.baseForegroundColor = .label
            config.baseBackgroundColor = .secondarySystemBackground
            config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            config.titleAlignment = .leading
            config.titleLineBreakMode = .byTruncatingTail
            button.configuration = config
            button.contentHorizontalAlignment = .leading
            button.layer.cornerRadius = 8
        } else {
            button.setTitle(title, for: .normal)
            button.setTitleColor(.label, for: .normal)
            button.contentHorizontalAlignment = .left
            button.backgroundColor = .secondarySystemBackground
            button.layer.cornerRadius = 8
            button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        }
        // Текст не уменьшаем, обрезаем с троеточием в конце
        button.titleLabel?.numberOfLines = 1
        button.titleLabel?.adjustsFontSizeToFitWidth = false
        button.titleLabel?.lineBreakMode = .byTruncatingTail
    }
    private func violationRow(title: String) -> UIView {
        let container = UIView()
        let name = UILabel()
        name.text = title
        name.font = .systemFont(ofSize: 14)
        name.numberOfLines = 2
        name.lineBreakMode = .byTruncatingTail
        let value = UILabel()
        value.text = "0"
        value.font = .systemFont(ofSize: 14, weight: .semibold)
        value.textAlignment = .right
        let stepper = UIStepper()
        stepper.minimumValue = 0
        stepper.maximumValue = 999
        stepper.addAction(UIAction { [weak self] _ in
            let count = Int(stepper.value)
            value.text = "\(count)"
            self?.violationCounts[title] = count
            self?.updateTotalViolations()
        }, for: .valueChanged)
        
        // Сохраняем ссылку на степпер и лейбл для последующего обновления
        violationSteppers[title] = (stepper: stepper, label: value)
        // Настройка приоритетов, чтобы текст не наезжал на число и степпер
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        name.setContentHuggingPriority(.defaultLow, for: .horizontal)
        value.setContentCompressionResistancePriority(.required, for: .horizontal)
        value.setContentHuggingPriority(.required, for: .horizontal)

        container.addSubview(name)
        container.addSubview(value)
        container.addSubview(stepper)
        name.snp.makeConstraints { make in
            make.left.top.equalToSuperview()
            make.bottom.equalToSuperview()
            make.right.lessThanOrEqualTo(value.snp.left).offset(-12)
        }
        stepper.snp.makeConstraints { make in
            make.right.equalToSuperview()
            make.centerY.equalTo(name)
        }
        value.snp.makeConstraints { make in
            make.right.equalTo(stepper.snp.left).offset(-12)
            make.centerY.equalTo(name)
            make.width.equalTo(40)
        }
        return container
    }

    private func updateTotalViolations() {
        let total = violationCounts.values.reduce(0, +)
        totalViolationsLabel.text = "Итого нарушений: \(total)"
    }
    
    // MARK: - Load Data from Akt
    
    private func loadDataFromAkt(_ akt: AKT) {
        print("🔄 [SHORT_AKT_FORM] loadDataFromAkt вызван для акта №\(akt.number)")
        print("   📅 Дата предоставления отчета из акта: \(akt.actPredostavlenDate)")
        print("   📅 Дата проверки из акта: \(akt.date)")
        
        // Загружаем номер акта
        numberField.text = akt.number
        if let numberIndex = numberOptions.firstIndex(of: akt.number) {
            numberPicker.selectRow(numberIndex, inComponent: 0, animated: false)
        }
        numberStatusLabel.text = "Номер акта загружен"
        numberStatusLabel.textColor = .systemGreen
        
        // ИСПРАВЛЕНИЕ: Временно отключаем обработчик изменения даты проверки,
        // чтобы избежать перезаписи даты предоставления отчета при установке даты проверки
        inspectionDatePicker.removeTarget(self, action: #selector(inspectionDateChanged), for: .valueChanged)
        
        // Сначала загружаем дату предоставления отчета
        reportDueDatePicker.date = akt.actPredostavlenDate
        print("   ✅ Дата предоставления отчета установлена в date picker: \(reportDueDatePicker.date)")
        
        // Затем загружаем дату проверки (это не триггерит inspectionDateChanged, так как мы отключили обработчик)
        inspectionDatePicker.date = akt.date
        print("   ✅ Дата проверки установлена в date picker: \(inspectionDatePicker.date)")
        
        // Включаем обработчик обратно после загрузки данных
        inspectionDatePicker.addTarget(self, action: #selector(inspectionDateChanged), for: .valueChanged)
        
        // Загружаем организацию
        selectedOrganization = akt.organization
        if #available(iOS 15.0, *) {
            organizationButton.configuration?.title = akt.organization.title
        } else {
            organizationButton.setTitle(akt.organization.title, for: .normal)
        }
        
        // Загружаем объект (берем первый если есть)
        if let firstObject = akt.objectsCheck.first {
            selectedObject = firstObject
            if #available(iOS 15.0, *) {
                objectButton.configuration?.title = firstObject.title
            } else {
                objectButton.setTitle(firstObject.title, for: .normal)
            }
        }
        
        // Загружаем нарушения - подсчитываем по типам
        violationCounts.removeAll()
        for t in ViolationType.allCases {
            violationCounts[t.displayName] = 0
        }
        
        // Подсчитываем нарушения по типам (используем поле vid)
        for violation in akt.violations {
            if let typeName = violation.vid.isEmpty ? nil : violation.vid,
               violationCounts.keys.contains(typeName) {
                violationCounts[typeName] = (violationCounts[typeName] ?? 0) + 1
            }
        }
        
        // Обновляем UI для степперов
        updateViolationSteppers()
        updateTotalViolations()
    }
    
    private func updateViolationSteppers() {
        // Обновляем значения степперов через сохраненные ссылки
        for (typeName, count) in violationCounts {
            if let stepperData = violationSteppers[typeName] {
                stepperData.stepper.value = Double(count)
                stepperData.label.text = "\(count)"
            }
        }
    }
    
    @objc private func closeTapped() { dismiss(animated: true) }
    
    @objc private func handleBackgroundTap() {
        // Скрыть клавиатуры/пикеры (inputView)
        view.endEditing(true)
        // Если открыт action sheet выбора организации/объекта — закрыть
        if let presented = presentedViewController as? UIAlertController, presented.preferredStyle == .actionSheet {
            presented.dismiss(animated: true)
        }
    }
    @objc private func saveTapped() {
        guard let number = numberField.text, !number.isEmpty else { showError("Выберите номер акта"); return }
        
        // Проверка номера в разрезе года: в одном году номер должен быть уникальным
        let year = Calendar.current.component(.year, from: inspectionDatePicker.date)
        let excludingId = editingAkt?.id
        
        if !isEditingMode {
            if !viewModel.isAktNumberAvailable(number, forYear: year, excludingAktId: excludingId) {
                showError("Номер уже занят в этом году. Выберите другой.")
                return
            }
        } else {
            if let akt = editingAkt, akt.number != number {
                if !viewModel.isAktNumberAvailable(number, forYear: year, excludingAktId: excludingId) {
                    showError("Номер уже занят в этом году. Выберите другой.")
                    return
                }
            }
        }
        
        guard let organization = selectedOrganization else { showError("Выберите организацию"); return }
		guard let object = selectedObject else { showError("Выберите объект"); return }

        var violations: [Violations] = []
        for (type, count) in violationCounts where count > 0 {
            for _ in 0..<count {
                let v = Violations(title: "Сокращенный: \(type)", mesto: "", urlToPravilo: "", photo: [], vid: type, formulaFromRules: nil)
                violations.append(v)
            }
        }
        // ИСПРАВЛЕНИЕ: Для коротких актов дата устранения должна быть равна дате предоставления отчета
        // Для обычных актов рассчитываем как дата проверки + 1 месяц
        let isShortFormat = violations.contains { $0.title.hasPrefix("Сокращенный:") || $0.title.hasPrefix("Сокращённый:") || $0.title.hasPrefix("Внешний:") }
        let eliminationDate: Date
        if isShortFormat {
            // Для коротких актов используем дату предоставления отчета
            eliminationDate = reportDueDatePicker.date
        } else {
            // Для обычных актов: дата проверки + 1 месяц
            eliminationDate = Calendar.current.date(byAdding: .month, value: 1, to: inspectionDatePicker.date) ?? inspectionDatePicker.date
        }
        
        if isEditingMode, let akt = editingAkt {
            print("💾 [SHORT_AKT_FORM] saveTapped: Сохранение отредактированного акта №\(akt.number)")
            print("   📅 Дата предоставления отчета из date picker: \(reportDueDatePicker.date)")
            print("   📅 Дата проверки из date picker: \(inspectionDatePicker.date)")
            print("   📅 Старая дата предоставления отчета в акте: \(akt.actPredostavlenDate)")
            
			// Обновляем существующий акт
            let updatedAkt = AKT(
                id: akt.id, // Сохраняем оригинальный ID
                number: number,
                date: inspectionDatePicker.date,
                comission: akt.comission, // Сохраняем комиссию
                organization: organization,
                objectsCheck: [object],
                predstavitelyComission: akt.predstavitelyComission, // Сохраняем представителей
                violations: violations,
                description: akt.description, // Сохраняем описание
                actustranenDate: eliminationDate,
                actPredostavlenDate: reportDueDatePicker.date,
                actUtverzdenDate: inspectionDatePicker.date,
                urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: akt.realDateCreate // Сохраняем оригинальную дату создания
            )
            
            print("   ✅ Создан updatedAkt с датой предоставления отчета: \(updatedAkt.actPredostavlenDate)")
            
            // Обновляем записи устранения нарушений
            ViolationEliminationManager.createEliminationsForAkt(updatedAkt)
            
            // ИСПРАВЛЕНИЕ: Обновляем даты устранения в разделе устранения при изменении даты предоставления отчета
            // Для коротких актов используем дату предоставления отчета как дату устранения
            let eliminationDateForUpdate = isShortFormat ? reportDueDatePicker.date : eliminationDate
            AKT.updateEliminationDatesFromAkt(updatedAkt.id, newEliminationDate: eliminationDateForUpdate, forceUpdate: true)
            
            // Отправляем уведомление для обновления UI в разделе устранения
            NotificationCenter.default.post(
                name: NSNotification.Name("ViolationEliminationDatesUpdated"),
                object: nil,
                userInfo: ["aktId": updatedAkt.id]
            )
            
            // ИСПРАВЛЕНИЕ: Обновляем акт в массиве с completion handler, чтобы дождаться завершения сохранения
            viewModel.updateAktInArray(updatedAkt) {
                // ИСПРАВЛЕНИЕ: Очищаем кэш после сохранения, чтобы при следующем открытии
                // загружались актуальные данные из файла, а не из кэша
                DataCache.shared.invalidate("aktArray")
                print("   🗑️ [SHORT_AKT_FORM] Кэш aktArray очищен после сохранения")
                
                // ИСПРАВЛЕНИЕ: Обновляем редактируемый акт через SimpleRealtimeAKTManager, чтобы изменения сохранялись правильно
                // Это исправляет проблему с рассинхроном при открытии через историю
                print("   🔄 [SHORT_AKT_FORM] Обновляем нарушения через SimpleRealtimeAKTManager...")
                SimpleRealtimeAKTManager.shared.updateViolations(updatedAkt.violations)
                print("   ✅ [SHORT_AKT_FORM] Нарушения обновлены через SimpleRealtimeAKTManager")
                
                // Также обновляем редактируемый акт напрямую для совместимости
                DataFlowAKT.updateEditableAKT(updatedAkt)
                print("   🔄 [SHORT_AKT_FORM] Редактируемый акт обновлен после сохранения")
                
                // Сохранение завершено, вызываем callback для обновления истории
                DispatchQueue.main.async {
                    self.onSaveCompletion?()
                }
            }
        } else {
            // Создаем новый акт
            let newAkt = AKT(
                number: number,
                date: inspectionDatePicker.date,
                comission: [],
                organization: organization,
                objectsCheck: [object],
                predstavitelyComission: [],
                violations: violations,
                description: "",
                actustranenDate: eliminationDate, // Уже рассчитана выше с учетом короткого формата
                actPredostavlenDate: reportDueDatePicker.date,
                actUtverzdenDate: inspectionDatePicker.date,
                urlAct: URL(fileURLWithPath: ""),
                realDateCreate: Date()
            )
            self.viewModel.addNewAktToArray(newAkt)
            ViolationEliminationManager.createEliminationsForAkt(newAkt)
            
            // ИСПРАВЛЕНИЕ: Обновляем даты устранения в разделе устранения для нового акта
            // Для коротких актов используем дату предоставления отчета как дату устранения
            let eliminationDateForUpdate = isShortFormat ? reportDueDatePicker.date : eliminationDate
            AKT.updateEliminationDatesFromAkt(newAkt.id, newEliminationDate: eliminationDateForUpdate, forceUpdate: true)
            
            // Отправляем уведомление для обновления UI в разделе устранения
            NotificationCenter.default.post(
                name: NSNotification.Name("ViolationEliminationDatesUpdated"),
                object: nil,
                userInfo: ["aktId": newAkt.id]
            )
            
            // Для нового акта вызываем callback сразу (addNewAktToArray работает синхронно)
            onSaveCompletion?()
        }
        
        dismiss(animated: true)
    }
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Ошибка", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Хорошо", style: .default))
        present(alert, animated: true)
    }
    @objc private func selectOrganization() {
        let sheet = UIAlertController(title: "Выберите организацию", message: nil, preferredStyle: .actionSheet)
        for org in viewModel.organizationsArray {
            sheet.addAction(UIAlertAction(title: org.title, style: .default, handler: { [weak self] _ in
                self?.selectedOrganization = org
                self?.organizationButton.setTitle(org.title, for: .normal)
            }))
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = organizationButton; pop.sourceRect = organizationButton.bounds }
        present(sheet, animated: true)
    }
    @objc private func selectObject() {
        let sheet = UIAlertController(title: "Выберите объект", message: nil, preferredStyle: .actionSheet)
        for obj in viewModel.objectCheckArray {
            sheet.addAction(UIAlertAction(title: obj.title, style: .default, handler: { [weak self] _ in
                guard let self = self else { return }
                self.selectedObject = obj
                if #available(iOS 15.0, *) {
                    self.objectButton.configuration?.title = obj.title
                    self.objectButton.configuration?.titleAlignment = .leading
                    self.objectButton.configuration?.titleLineBreakMode = .byTruncatingTail
                } else {
                    self.objectButton.setTitle(obj.title, for: .normal)
                }
                // Гарантируем отсутствие авто-уменьшения и троеточие в конце после установки заголовка
                self.objectButton.titleLabel?.numberOfLines = 1
                self.objectButton.titleLabel?.adjustsFontSizeToFitWidth = false
                self.objectButton.titleLabel?.lineBreakMode = .byTruncatingTail
            }))
        }
        // Добавляем кнопку "Добавить новый объект"
        sheet.addAction(UIAlertAction(title: "Добавить новый объект", style: .default, handler: { [weak self] _ in
            self?.addNewObject()
        }))
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let pop = sheet.popoverPresentationController { pop.sourceView = objectButton; pop.sourceRect = objectButton.bounds }
        present(sheet, animated: true)
    }
    
    private func addNewObject() {
        let editType = EditType.doubleField(
            title1: "Название",
            placeholder1: "Введите название объекта",
            currentValue1: "",
            title2: "Описание",
            placeholder2: "Введите описание объекта",
            currentValue2: ""
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, newSubtitle, _ in
            guard let self = self else { return }
            let subtitle = newSubtitle ?? ""
            let newObj = ObjectCheck(title: newTitle, subTitle: subtitle)
            
            // Проверяем, нет ли объекта с таким названием
            if self.viewModel.objectCheckArray.contains(where: { $0.title == newTitle }) {
                let errorAlert = UIAlertController(title: "Ошибка!", message: "Объект с таким названием уже существует", preferredStyle: .alert)
                let ok = UIAlertAction(title: "Хорошо", style: .cancel)
                errorAlert.addAction(ok)
                self.present(errorAlert, animated: true)
                return
            }
            
            // Добавляем объект в библиотеку
            self.viewModel.objectCheckArray.append(newObj)
            DataFlowObjectsReview.saveArr(arr: self.viewModel.objectCheckArray)
            
            // Автоматически выбираем новый объект
            self.selectedObject = newObj
            if #available(iOS 15.0, *) {
                self.objectButton.configuration?.title = newObj.title
                self.objectButton.configuration?.titleAlignment = .leading
                self.objectButton.configuration?.titleLineBreakMode = .byTruncatingTail
            } else {
                self.objectButton.setTitle(newObj.title, for: .normal)
            }
            // Гарантируем отсутствие авто-уменьшения и троеточие в конце после установки заголовка
            self.objectButton.titleLabel?.numberOfLines = 1
            self.objectButton.titleLabel?.adjustsFontSizeToFitWidth = false
            self.objectButton.titleLabel?.lineBreakMode = .byTruncatingTail
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int { numberOptions.count }
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? { numberOptions[row] }
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let value = numberOptions[row]
        numberField.text = value
        let year = Calendar.current.component(.year, from: inspectionDatePicker.date)
        let available = viewModel.isAktNumberAvailable(value, forYear: year, excludingAktId: editingAkt?.id)
        numberStatusLabel.text = available ? "Номер свободен" : "Номер занят в этом году"
        numberStatusLabel.textColor = available ? .systemGreen : .systemRed
    }
}
