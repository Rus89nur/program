//
//  DateAndNumberAktViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class DateAndNumberAktViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    var akt: AKT?
    var isEditingMode: Bool = false // Флаг для различения создания нового акта и редактирования существующего
    
    lazy var comissionPeoples:  [ComissionPeople] = []
    
    private var dateLabel: UILabel!
    private var countLabel: UILabel!
    private var comissionLabel: UILabel!
    
    private let datePicker: UIDatePicker = {
        let view = UIDatePicker()
        view.date = .now
        view.datePickerMode = .date
        // Принудительно устанавливаем русскую локаль и календарь
        let russianLocale = Locale(identifier: "ru_RU")
        view.locale = russianLocale
        // Создаем календарь с русской локалью
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = russianLocale
        view.calendar = calendar
        view.preferredDatePickerStyle = .compact
        return view
    }()

    
    private let collection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.showsVerticalScrollIndicator = false
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.layer.cornerRadius = 16
        layout.scrollDirection = .vertical
        return collection
    }()
    
    private let numberPicker: UIPickerView = {
        let view = UIPickerView()
        return view
    }()
    
    // Занятые номера актов
    private var occupiedNumbers: Set<String> = []

    init(viewModel: MainAKTViewModel, akt: AKT? = nil, isEditingMode: Bool = false) {
        self.viewModel = viewModel
        self.akt = akt
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func checkOld() {
        if let a = akt {
            print("🔄 [DATE_AND_NUMBER] Загружаем данные из существующего акта №\(a.number)")
            
            // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
            // Если редактируемый акт существует, используем его данные вместо данных из истории
            var aktToUse = a
            if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == a.number {
                print("   ✅ Найден редактируемый акт с номером \(a.number), используем его данные")
                print("      👥 Количество членов комиссии в редактируемом акте: \(editableAkt.akt.comission.count)")
                print("      👥 Количество членов комиссии в акте из истории: \(a.comission.count)")
                aktToUse = editableAkt.akt
                // Обновляем ссылку на акт для последующих операций
                self.akt = aktToUse
            } else {
                print("   ℹ️ Редактируемый акт не найден, используем данные из истории")
            }
            
            // Устанавливаем дату из акта
            datePicker.date = aktToUse.date
            print("   📅 Дата установлена: \(aktToUse.date)")
            
            // Устанавливаем номер из акта
            if let number = Int(aktToUse.number), number > 0 && number <= 100 {
                numberPicker.selectRow(number - 1, inComponent: 0, animated: false)
                print("   🔢 Номер установлен: \(aktToUse.number)")
            }
            
            // Устанавливаем комиссию из акта (используем актуальные данные)
            comissionPeoples = aktToUse.comission
            print("   👥 Комиссия загружена: \(aktToUse.comission.count) членов")
            print("   📋 Список членов комиссии:")
            for (idx, member) in aktToUse.comission.enumerated() {
                print("      \(idx + 1). \(member.fio) - \(member.jobTitle)")
            }
            
            // Инициализируем SimpleRealtimeAKTManager только если он еще не активен
            if SimpleRealtimeAKTManager.shared.currentAkt == nil {
                print("   🔄 Инициализируем SimpleRealtimeAKTManager...")
                SimpleRealtimeAKTManager.shared.startEditing(aktToUse)
                print("   ✅ SimpleRealtimeAKTManager инициализирован")
            } else {
                print("   ℹ️ SimpleRealtimeAKTManager уже активен, пропускаем инициализацию")
            }
            
            collection.reloadData()
        } else {
            print("ℹ️ [DATE_AND_NUMBER] Новый акт, данные не загружаются")
        }
    }
    
    private func loadOccupiedNumbers() {
        // Используем год из datePicker для определения занятых номеров
        let year = Calendar.current.component(.year, from: datePicker.date)
        occupiedNumbers = viewModel.getOccupiedAktNumbers(forYear: year)
        numberPicker.reloadAllComponents()
        
        // Обновляем информационный лейбл
        updateInfoLabel()
        
        // Если это новый акт (не редактирование), устанавливаем следующий доступный номер для выбранного года
        if akt == nil {
            let nextAvailable = viewModel.getNextAvailableAktNumber(forYear: year)
            if let nextRow = Int(nextAvailable), nextRow <= 100 {
                numberPicker.selectRow(nextRow - 1, inComponent: 0, animated: false)
            }
        }
    }
    
    private func updateInfoLabel() {
        guard let infoLabel = view.viewWithTag(999) as? UILabel else { return }
        
        let occupiedCount = occupiedNumbers.count
        let totalCount = 100
        
        if occupiedCount > 0 {
            infoLabel.text = "Занято номеров: \(occupiedCount) из \(totalCount)"
        } else {
            infoLabel.text = "Все номера доступны"
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.title = "Основные данные"
        
        // ВАЖНО: Принудительно устанавливаем русскую локаль для DatePicker при каждом появлении экрана
        setupDatePickerLocale()
        
        // Ищем StartTabViewController в стеке навигации и устанавливаем backBarButtonItem из него
        if let navController = navigationController {
            // Проходим по всем контроллерам в стеке, начиная с конца (предыдущие)
            let viewControllers = navController.viewControllers
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let startVC = viewControllers[i] as? StartTabViewController {
                    // Нашли StartTabViewController в стеке, используем его backBarButtonItem
                    let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
                    startVC.navigationItem.backBarButtonItem = backButton
                    startVC.navigationItem.backButtonTitle = "Главная"
                    break
                }
            }
            
            // Также устанавливаем напрямую в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Главная"
            }
        }
        
        setupViewModel()
        setupNav()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Дополнительная установка русской локали после полного появления view на экране
        // Это гарантирует, что DatePicker будет на русском языке даже если система
        // пытается изменить локаль после viewWillAppear
        setupDatePickerLocale()
    }
    
    /// Принудительно устанавливает русскую локаль для DatePicker
    /// Этот метод должен вызываться при каждом появлении экрана для гарантии
    /// что DatePicker всегда будет отображаться на русском языке
    private func setupDatePickerLocale() {
        let russianLocale = Locale(identifier: "ru_RU")
        datePicker.locale = russianLocale
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = russianLocale
        datePicker.calendar = calendar
    }
    
    private func setupNav() {
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        let item = UIBarButtonItem(customView: goBackButton)
        goBackButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        goBackButton.alpha = 0.5
        self.navigationItem.rightBarButtonItem = item
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
    }
    
    @objc private func goHome() {
        print("🏠 [DATE_AND_NUMBER] Нажата кнопка 'Домой', сохраняем изменения...")
        
        // Принудительно обновляем акт с текущими данными
        if akt != nil {
            print("   🔄 Принудительно обновляем акт с текущими данными...")
            updateAktWithNewData()
            print("   ✅ Акт принудительно обновлен")
        }
        
        // Завершаем редактирование в SimpleRealtimeAKTManager
        print("   🔄 Завершаем редактирование в SimpleRealtimeAKTManager...")
        SimpleRealtimeAKTManager.shared.finishEditing()
        print("   ✅ Редактирование завершено")
        
        navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("🔄 [DATE_AND_NUMBER] Экран даты и номера закрывается")
        print("   📅 Текущая дата: \(datePicker.date)")
        print("   🔢 Текущий номер: \(numberPicker.selectedRow(inComponent: 0) + 1)")
        print("   👥 Количество членов комиссии: \(comissionPeoples.count)")
        
        // Проверяем, что это не переход к следующему экрану (кнопка "Далее")
        if let navigationController = navigationController,
           let topViewController = navigationController.topViewController,
           topViewController != self {
            print("   🔄 Переход к следующему экрану, сохраняем изменения...")
            
            // Принудительно обновляем акт с текущими данными
            if akt != nil {
                print("   🔄 Принудительно обновляем акт с текущими данными...")
                updateAktWithNewData()
                print("   ✅ Акт принудительно обновлен")
            }
            
            // ВАЖНО: НЕ завершаем редактирование при переходе к следующему экрану,
            // так как мы все еще редактируем акт. finishEditing() удалит редактируемый акт,
            // что приведет к потере изменений при следующем открытии акта из истории.
            print("   ℹ️ Редактирование продолжается, редактируемый акт сохранен для дальнейшей работы")
        } else {
            print("   ℹ️ Возврат назад, изменения не сохраняются автоматически")
        }
    }
    
    private func updateAktWithNewData() {
        print("═══════════════════════════════════════════════════════════")
        print("🔄 [DATE_AND_NUMBER] ОБНОВЛЕНИЕ АКТА С НОВЫМИ ДАННЫМИ")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔑 UniqueID акта: \(akt?.uniqueID ?? "нет")")
        print("   🔢 Старый номер: \(akt?.number ?? "нет")")
        
        guard let existingAkt = akt else {
            print("   ❌ Существующий акт не найден")
            print("═══════════════════════════════════════════════════════════")
            return
        }
        
        let selectedDate = datePicker.date
        
        // ВАЖНО: При редактировании существующего акта проверяем, изменился ли номер
        // Если номер в picker'е совпадает с оригинальным номером акта, используем оригинальный
        // Если номер изменился и доступен, используем новый номер
        let pickerNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        let selectedNumber: String
        if pickerNumber == existingAkt.number {
            // Номер не изменился - используем оригинальный номер
            selectedNumber = existingAkt.number
        } else {
            // Номер изменился - проверяем доступность и используем новый номер
            let excludingId = existingAkt.id
            // Используем год из даты проверки для проверки номера
            let year = Calendar.current.component(.year, from: selectedDate)
            if viewModel.isAktNumberAvailable(pickerNumber, forYear: year, excludingAktId: excludingId) {
                selectedNumber = pickerNumber
            } else {
                // Новый номер занят - используем оригинальный номер
                selectedNumber = existingAkt.number
            }
        }
        
        print("   🔢 Номер акта: \(existingAkt.number) -> \(selectedNumber)")
        print("   📅 Дата проверки: \(existingAkt.date) -> \(selectedDate)")
        print("   👥 Комиссия: \(existingAkt.comission.count) -> \(comissionPeoples.count) членов")
        print("   ⚠️ Количество нарушений в существующем акте: \(existingAkt.violations.count)")
        
        // ВАЖНО: Получаем актуальные нарушения из редактируемого акта, если он существует
        // Это гарантирует, что мы не потеряем нарушения при обновлении
        var actualViolations = existingAkt.violations
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.id == existingAkt.id {
            print("   🔄 Найден редактируемый акт, используем нарушения из него")
            print("      📋 Количество нарушений в редактируемом акте: \(editableAkt.akt.violations.count)")
            actualViolations = editableAkt.akt.violations
        }
        
        // Автоматически пересчитываем даты на основе новой даты проверки
        let newUstranenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newPredostavlenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newUtverzdenDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate // +7 дней от даты проверки
        
        print("   📊 Рассчитанные даты:")
        print("      📅 Дата проверки: \(selectedDate)")
        print("      📅 Дата устранения нарушения (+1 месяц): \(newUstranenDate)")
        print("      📅 Дата предоставления отчета (+1 месяц): \(newPredostavlenDate)")
        print("      📅 Дата утверждения (+7 дней): \(newUtverzdenDate)")
        
        // Создаем обновленный акт с новыми данными
        let updatedAkt = AKT(
            id: existingAkt.id, // Сохраняем оригинальный ID
            number: selectedNumber,
            date: selectedDate,
            comission: comissionPeoples,
            organization: existingAkt.organization, // Сохраняем существующую организацию
            objectsCheck: existingAkt.objectsCheck, // Сохраняем существующие объекты
            predstavitelyComission: existingAkt.predstavitelyComission, // Сохраняем существующих представителей
            violations: actualViolations, // ВАЖНО: Используем актуальные нарушения
            description: existingAkt.description, // Сохраняем существующее описание
            actustranenDate: newUstranenDate, // Автоматически пересчитанная дата устранения
            actPredostavlenDate: newPredostavlenDate, // Автоматически пересчитанная дата предоставления
            actUtverzdenDate: newUtverzdenDate, // Автоматически пересчитанная дата утверждения
            urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""), // Сохраняем существующий URL
            realDateCreate: existingAkt.realDateCreate // Сохраняем оригинальную дату создания
        )
        
        print("   📋 Номер акта: \(updatedAkt.number)")
        print("   👥 Количество членов комиссии: \(updatedAkt.comission.count)")
        print("   📋 Список членов комиссии в обновленном акте:")
        for (idx, member) in updatedAkt.comission.enumerated() {
            print("      \(idx + 1). \(member.fio) - \(member.jobTitle) (ID: \(member.id))")
        }
        print("   ⚠️ Количество нарушений в обновленном акте: \(updatedAkt.violations.count)")
        print("   🆔 ID акта: \(updatedAkt.id)")
        
        // ВАЖНО: Сначала обновляем редактируемый акт, чтобы сохранить нарушения
        print("   💾 Обновляем редактируемый акт (ПРИОРИТЕТ)...")
        print("   📋 Данные для сохранения в редактируемый акт:")
        print("      👥 Количество членов комиссии: \(updatedAkt.comission.count)")
        viewModel.updateEditableAKT(updatedAkt)
        print("   ✅ Редактируемый акт обновлен")
        
        // ПРОВЕРКА: Проверяем, что данные сохранились
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("   🔍 ПРОВЕРКА: Данные в редактируемом акте после обновления:")
            print("      👥 Количество членов комиссии: \(editableAkt.akt.comission.count)")
            print("      📋 Список членов комиссии:")
            for (idx, member) in editableAkt.akt.comission.enumerated() {
                print("         \(idx + 1). \(member.fio) - \(member.jobTitle) (ID: \(member.id))")
            }
            if editableAkt.akt.comission.count == updatedAkt.comission.count {
                print("      ✅ Количество совпадает с ожидаемым")
            } else {
                print("      ❌ ОШИБКА: Количество не совпадает! Ожидалось: \(updatedAkt.comission.count), получено: \(editableAkt.akt.comission.count)")
            }
        } else {
            print("   ⚠️ ПРЕДУПРЕЖДЕНИЕ: Редактируемый акт не найден после обновления")
        }
        
        // Обновляем SimpleRealtimeAKTManager если он активен
        if SimpleRealtimeAKTManager.shared.currentAkt != nil {
            print("   🔄 Обновляем SimpleRealtimeAKTManager с новыми данными...")
            SimpleRealtimeAKTManager.shared.updateCommission(comissionPeoples)
            SimpleRealtimeAKTManager.shared.updateNumber(selectedNumber)
            // Обновляем дату через создание нового акта с обновленной датой
            let realtimeAkt = SimpleRealtimeAKTManager.shared.currentAkt!
            let updatedRealtimeAkt = AKT(
                id: realtimeAkt.id,
                number: selectedNumber, // ВАЖНО: Используем selectedNumber вместо realtimeAkt.number
                date: selectedDate,
                comission: comissionPeoples,
                organization: realtimeAkt.organization,
                objectsCheck: realtimeAkt.objectsCheck,
                predstavitelyComission: realtimeAkt.predstavitelyComission,
                violations: realtimeAkt.violations, // Сохраняем нарушения из realtime акта
                description: realtimeAkt.description,
                actustranenDate: newUstranenDate,
                actPredostavlenDate: newPredostavlenDate,
                actUtverzdenDate: newUtverzdenDate,
                urlAct: realtimeAkt.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: realtimeAkt.realDateCreate
            )
            SimpleRealtimeAKTManager.shared.currentAkt = updatedRealtimeAkt
            print("   ✅ SimpleRealtimeAKTManager обновлен")
        }
        
        // Обновляем акт в истории (после обновления редактируемого акта)
        print("   💾 Сохраняем акт в историю...")
        viewModel.updateAktInArray(updatedAkt)
        print("   ✅ Акт №\(updatedAkt.number) обновлен в истории")
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = updatedAkt
        
        // ВАЖНО: Обновляем даты устранения нарушений при изменении даты проверки
        print("   🔄 Обновляем даты устранения нарушений...")
        print("      📋 Количество нарушений в акте: \(updatedAkt.violations.count)")
        updateViolationEliminationDates(for: updatedAkt)
        print("   ✅ Даты устранения нарушений обновлены")
        
        print("✅ [DATE_AND_NUMBER] ОБНОВЛЕНИЕ АКТА ЗАВЕРШЕНО")
        print("═══════════════════════════════════════════════════════════")
    }
    
    @objc private func dateChanged() {
        // При изменении даты проверки обновляем pickerView, чтобы пересчитать занятые номера с учетом нового года
        let newYear = Calendar.current.component(.year, from: datePicker.date)
        print("🔍 [DATE_CHANGED] Дата проверки изменена на: \(datePicker.date), год: \(newYear)")
        numberPicker.reloadAllComponents()
        
        // Если это новый акт (не редактирование), автоматически выбираем первый свободный номер для нового года
        if akt == nil {
            let firstAvailableNumber = viewModel.getNextAvailableAktNumber(forYear: newYear)
            if let number = Int(firstAvailableNumber), number > 0 && number <= 100 {
                numberPicker.selectRow(number - 1, inComponent: 0, animated: true)
                print("🔍 [DATE_CHANGED] Автоматически выбран первый свободный номер для года \(newYear): \(firstAvailableNumber)")
            }
        }
        
        // Автоматически сохраняем изменения при изменении даты
        if akt != nil {
            print("🔄 [DATE_AND_NUMBER] Дата изменена")
            print("   📅 Новая дата проверки: \(datePicker.date)")
            print("   📅 Старая дата проверки: \(akt?.date.description ?? "nil")")
            
            // Обновляем акт с новыми данными (включая пересчет дат)
            updateAktWithNewData()
            print("   ✅ Акт автоматически обновлен с новой датой")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        
        // ВАЖНО: Устанавливаем русскую локаль для DatePicker сразу после загрузки view
        setupDatePickerLocale()
        
        setupUI()
        checkOld()
        loadOccupiedNumbers()
        
        // Настройка темной темы после создания всех элементов
        setupDarkTheme()
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
            collection.reloadData()
        }
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            collection.backgroundColor = .clear
            
            // Устанавливаем белый цвет для лейблов в темной теме
            dateLabel?.textColor = .white
            countLabel?.textColor = .white
            comissionLabel?.textColor = .white
            
            // Обновляем цвет информационного лейбла
            if let infoLabel = view.viewWithTag(999) as? UILabel {
                infoLabel.textColor = .systemGray2
            }
            
            // Настройка datePicker для темной темы
            datePicker.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            datePicker.overrideUserInterfaceStyle = .dark
            
            // Настройка numberPicker для темной темы
            numberPicker.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            numberPicker.overrideUserInterfaceStyle = .dark
            
            print("🌙 Темная тема: установлен белый цвет для лейблов и пикеров")
        } else {
            view.backgroundColor = .systemBackground
            collection.backgroundColor = .clear
            
            // Стандартные цвета для светлой темы
            dateLabel?.textColor = .label
            countLabel?.textColor = .label
            comissionLabel?.textColor = .label
            
            // Обновляем цвет информационного лейбла
            if let infoLabel = view.viewWithTag(999) as? UILabel {
                infoLabel.textColor = .systemGray
            }
            
            // Настройка datePicker для светлой темы
            datePicker.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            datePicker.overrideUserInterfaceStyle = .light
            
            // Настройка numberPicker для светлой темы
            numberPicker.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
            numberPicker.overrideUserInterfaceStyle = .light
            
            print("☀️ Светлая тема: установлен стандартный цвет для лейблов и пикеров")
        }
    }
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.collection.reloadData()
        }
    }

    private func setupUI() {
        dateLabel = UIFactory.createlabel(title: "Укажите дату проверки:")
        view.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
        }
        
        view.addSubview(datePicker)
        datePicker.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(dateLabel.snp.right).inset(-24)
            make.centerY.equalTo(dateLabel)
        }
        
        // Добавляем обработчик изменения даты
        datePicker.addTarget(self, action: #selector(dateChanged), for: .valueChanged)
        
        countLabel = UIFactory.createlabel(title: "Укажите номер Акта:")
        view.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(datePicker.snp.bottom).offset(24)
        }
        
        // Добавляем информационный лейбл о занятых номерах
        let infoLabel = UIFactory.createlabel(title: "")
        infoLabel.font = .systemFont(ofSize: 12, weight: .regular)
        infoLabel.textColor = .systemGray
        infoLabel.tag = 999 // Для последующего обновления
        view.addSubview(infoLabel)
        infoLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(countLabel.snp.bottom).offset(4)
        }
        
        numberPicker.delegate = self
        numberPicker.dataSource = self
        view.addSubview(numberPicker)
        numberPicker.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(countLabel.snp.bottom).offset(16)
            make.height.equalTo(100)
        }
        
        // В режиме редактирования показываем "Сохранить", иначе "Далее"
        let buttonTitle = isEditingMode ? "Сохранить" : "Далее"
        print("🔘 [DATE_AND_NUMBER] Создание кнопки: '\(buttonTitle)' (isEditingMode: \(isEditingMode), akt: \(akt != nil ? "есть №\(akt!.number)" : "нет"))")
        let nextButton = UIFactory.createButton(title: buttonTitle, color: .systemBlue)
        view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        if isEditingMode {
            nextButton.addTarget(self, action: #selector(saveAndReturn), for: .touchUpInside)
            print("   ✅ Кнопка настроена на сохранение и возврат")
        } else {
            nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
            print("   ✅ Кнопка настроена на переход к следующему шагу")
        }
        
        comissionLabel = UIFactory.createlabel(title: "Члены комиссии:")
        view.addSubview(comissionLabel)
        comissionLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(numberPicker.snp.bottom).offset(16)
        }
        
        collection.delegate = self
        collection.dataSource = self
        view.addSubview(collection)
        collection.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(nextButton.snp.top).inset(-16)
            make.top.equalTo(comissionLabel.snp.bottom).inset(-16)
        }
        
        // Применяем настройки темы после создания всех элементов
        setupDarkTheme()
    }

    @objc private func saveAndReturn() {
        print("═══════════════════════════════════════════════════════════")
        print("💾 [DATE_AND_NUMBER] НАЧАЛО СОХРАНЕНИЯ И ВОЗВРАТА")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔑 UniqueID акта: \(akt?.uniqueID ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        print("   📅 Дата проверки: \(datePicker.date)")
        print("   👥 Количество членов комиссии: \(comissionPeoples.count)")
        print("   📋 Список членов комиссии перед сохранением:")
        for (idx, member) in comissionPeoples.enumerated() {
            print("      \(idx + 1). \(member.fio) - \(member.jobTitle) (ID: \(member.id))")
        }
        
        // Проверяем текущее состояние редактируемого акта
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("   🔍 ТЕКУЩЕЕ СОСТОЯНИЕ редактируемого акта:")
            print("      👥 Количество членов комиссии: \(editableAkt.akt.comission.count)")
            print("      🔢 Номер: \(editableAkt.akt.number)")
        } else {
            print("   ⚠️ Редактируемый акт не найден перед сохранением")
        }
        
        let selectedNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        print("   🔢 Выбранный номер: \(selectedNumber)")
        
        // ВАЖНО: Проверяем номер только если он изменился
        // Если номер не изменился, пропускаем проверку, чтобы избежать ложных ошибок
        if let existingAkt = akt, selectedNumber != existingAkt.number {
            // Номер изменился - проверяем доступность
            let excludingId = existingAkt.id
            // Используем год из даты проверки для проверки номера
            let year = Calendar.current.component(.year, from: datePicker.date)
            if !viewModel.isAktNumberAvailable(selectedNumber, forYear: year, excludingAktId: excludingId) {
                print("   ❌ Номер занят, показываем предупреждение")
                showOccupiedNumberAlert(selectedNumber: selectedNumber)
                return
            }
        } else {
            // Номер не изменился - используем оригинальный номер без проверки
            print("   ℹ️ Номер не изменился, пропускаем проверку")
        }
        
        // Обновляем акт с новыми данными
        if akt != nil {
            print("   🔄 Обновляем акт с новыми данными...")
            updateAktWithNewData()
            print("   ✅ Акт обновлен")
            
            // ПРОВЕРКА: Проверяем, что изменения сохранились в редактируемом акте
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                print("   🔍 ПРОВЕРКА ПОСЛЕ updateAktWithNewData():")
                print("      👥 Количество членов комиссии в редактируемом акте: \(editableAkt.akt.comission.count)")
                print("      📋 Список членов комиссии в редактируемом акте:")
                for (idx, member) in editableAkt.akt.comission.enumerated() {
                    print("         \(idx + 1). \(member.fio) - \(member.jobTitle) (ID: \(member.id))")
                }
                if editableAkt.akt.comission.count == comissionPeoples.count {
                    print("      ✅ Количество совпадает с ожидаемым")
                } else {
                    print("      ❌ ОШИБКА: Количество не совпадает! Ожидалось: \(comissionPeoples.count), получено: \(editableAkt.akt.comission.count)")
                }
            } else {
                print("   ⚠️ ПРЕДУПРЕЖДЕНИЕ: Редактируемый акт не найден после updateAktWithNewData()")
            }
            
            // Сохраняем изменения моментально
            print("   💾 Вызываем моментальное сохранение...")
            SimpleRealtimeAKTManager.shared.saveChangesImmediately()
            print("   ✅ Моментальное сохранение выполнено")
            
            // ПРОВЕРКА: Проверяем состояние после моментального сохранения
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                print("   🔍 ПРОВЕРКА ПОСЛЕ saveChangesImmediately():")
                print("      👥 Количество членов комиссии: \(editableAkt.akt.comission.count)")
            }
            
            // ВАЖНО: НЕ завершаем редактирование, чтобы редактируемый акт оставался доступным
            // для продолжения работы. finishEditing() удалит редактируемый акт, что приведет
            // к потере изменений при следующем открытии акта из истории.
            print("   ℹ️ Редактирование продолжается, редактируемый акт сохранен для дальнейшей работы")
            
            // Возвращаемся в раздел нарушений
            print("   🔙 Возвращаемся в раздел нарушений...")
            if let navController = navigationController {
                // Ищем NewViolationViewController в стеке навигации
                for vc in navController.viewControllers.reversed() {
                    if let violationsVC = vc as? NewViolationViewController {
                        print("   ✅ Найден NewViolationViewController, возвращаемся")
                        print("   📋 Состояние перед возвратом:")
                        if let editableAkt = DataFlowAKT.getEditableAKT() {
                            print("      👥 Количество членов комиссии в редактируемом акте: \(editableAkt.akt.comission.count)")
                        }
                        navController.popToViewController(violationsVC, animated: true)
                        print("═══════════════════════════════════════════════════════════")
                        return
                    }
                }
                // Если не нашли, возвращаемся на главный экран
                print("   ⚠️ NewViolationViewController не найден, возвращаемся на главный экран")
                navController.popToRootViewController(animated: true)
            }
            print("═══════════════════════════════════════════════════════════")
        } else {
            print("   ❌ Акт не найден, сохранение невозможно")
            print("═══════════════════════════════════════════════════════════")
        }
    }
    
    @objc private func goNext() {
        print("═══════════════════════════════════════════════════════════")
        print("➡️ [DATE_AND_NUMBER] ПЕРЕХОД К СЛЕДУЮЩЕМУ ШАГУ")
        print("   📋 Режим: \(akt == nil ? "СОЗДАНИЕ НОВОГО АКТА" : "ПРОДОЛЖЕНИЕ ЗАПОЛНЕНИЯ")")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "новый")")
        
        let selectedNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        print("   🔢 Выбранный номер: \(selectedNumber)")
        print("   📅 Дата проверки: \(datePicker.date)")
        print("   👥 Количество членов комиссии: \(comissionPeoples.count)")
        
        // ВАЖНО: Проверяем номер только если он изменился
        // Если номер не изменился, пропускаем проверку, чтобы избежать ложных ошибок
        if let existingAkt = akt, selectedNumber != existingAkt.number {
            // Номер изменился - проверяем доступность
            let excludingId = existingAkt.id
            // Используем год из даты проверки для проверки номера
            let year = Calendar.current.component(.year, from: datePicker.date)
            if !viewModel.isAktNumberAvailable(selectedNumber, forYear: year, excludingAktId: excludingId) {
                print("   ❌ Номер занят, показываем предупреждение")
                showOccupiedNumberAlert(selectedNumber: selectedNumber)
                return
            }
        } else {
            // Номер не изменился или это новый акт - пропускаем проверку
            print("   ℹ️ Номер не изменился или это новый акт, пропускаем проверку")
        }
        
        // Обновляем templateModel
        print("   🔄 Обновляем templateModel...")
        viewModel.templateModel.comissionPeople = comissionPeoples
        viewModel.templateModel.date = datePicker.date
        viewModel.templateModel.aktNumber = selectedNumber
        print("   ✅ templateModel обновлен")
        
        // ВСЕГДА создаем или обновляем акт и сохраняем в историю
        if akt == nil {
            // Новый акт - создаем и сохраняем в историю
            print("   🆕 Создаем новый акт...")
            createAndSaveNewAkt()
        } else {
            // Существующий акт - обновляем и сохраняем в историю
            print("   🔄 Обновляем существующий акт...")
            updateAndSaveExistingAkt()
        }
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButton = UIBarButtonItem(title: "Основные данные", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Основные данные"
        
        print("   ➡️ Переходим к экрану организаций (isEditingMode: \(isEditingMode))")
        let vc = OrganizationsViewController(viewModel: viewModel, comissionPeople: comissionPeoples, date: datePicker.date, aktNumber: selectedNumber, act: akt, isEditingMode: isEditingMode)
        navigationController?.pushViewController(vc, animated: true)
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func createAndSaveNewAkt() {
        // #region agent log
        let logPath = "/Users/ruslan/Desktop/Рабочие версии/13.12.2025 раб/Gazprom.xcodeproj/.cursor/debug.log"
        let selectedNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        let selectedDate = datePicker.date
        let logDict: [String: Any] = ["location": "DateAndNumberAktViewController.swift:createAndSaveNewAkt", "message": "СОЗДАНИЕ НОВОГО АКТА", "data": ["number": selectedNumber, "date": selectedDate.timeIntervalSince1970, "comission_count": comissionPeoples.count], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "A"]
        if let logData = try? JSONSerialization.data(withJSONObject: logDict) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logData)
                fileHandle.write("\n".data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                let fileURL = URL(fileURLWithPath: logPath)
                if let newlineData = "\n".data(using: .utf8) {
                    try? (logData + newlineData).write(to: fileURL)
                } else {
                    try? logData.write(to: fileURL)
                }
            }
        }
        // #endregion
        print("═══════════════════════════════════════════════════════════")
        print("🚀 [DATE_AND_NUMBER] СОЗДАНИЕ НОВОГО АКТА")
        print("   📋 Режим: СОЗДАНИЕ НОВОГО АКТА")
        
        print("   🔢 Номер акта: \(selectedNumber)")
        print("   📅 Дата проверки: \(selectedDate)")
        print("   👥 Количество членов комиссии: \(comissionPeoples.count)")
        
        // Автоматически пересчитываем даты на основе даты проверки
        let newUstranenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newPredostavlenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newUtverzdenDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate // +7 дней от даты проверки
        
        print("   📅 Дата проверки: \(selectedDate)")
        print("   📅 Дата устранения нарушения: \(newUstranenDate)")
        print("   📅 Дата предоставления отчета: \(newPredostavlenDate)")
        print("   📅 Дата утверждения: \(newUtverzdenDate)")
        
        // Получаем существующие uniqueID для проверки дубликатов
        let existingAkts = DataFlowAKT.loadArr()
        let existingUniqueIDs = existingAkts.compactMap { $0.uniqueID }
        
        // Создаем новый акт с минимальными данными
        // ВАЖНО: Используем дату из datePicker для realDateCreate, чтобы проверка дублирования номеров работала по году из даты проверки
        let newAkt = AKT(
            number: selectedNumber,
            date: selectedDate,
            comission: comissionPeoples,
            organization: Organization(title: "Организация не указана"), // Заглушка
            objectsCheck: [], // Пустой массив
            predstavitelyComission: [], // Пустой массив
            violations: [], // Пустой массив
            description: "", // Пустое описание
            actustranenDate: newUstranenDate, // Автоматически пересчитанная дата устранения
            actPredostavlenDate: newPredostavlenDate, // Автоматически пересчитанная дата предоставления
            actUtverzdenDate: newUtverzdenDate, // Автоматически пересчитанная дата утверждения
            urlAct: URL(fileURLWithPath: ""), // Пустой URL
            realDateCreate: selectedDate, // Используем дату проверки для realDateCreate
            existingUniqueIDs: existingUniqueIDs // Передаем существующие uniqueID для проверки дубликатов
        )
        
        print("   📋 Номер акта: \(newAkt.number)")
        print("   👥 Количество членов комиссии: \(newAkt.comission.count)")
        print("   🆔 ID акта: \(newAkt.id)")
        print("   🔑 UniqueID акта: \(newAkt.uniqueID ?? "нет")")
        
        // СРАЗУ ДОБАВЛЯЕМ АКТ В ИСТОРИЮ (без создания редактируемого акта)
        print("   💾 Добавляем акт в историю...")
        // #region agent log
        let logPath2 = "/Users/ruslan/Desktop/Рабочие версии/13.12.2025 раб/Gazprom.xcodeproj/.cursor/debug.log"
        let logDict2: [String: Any] = ["location": "DateAndNumberAktViewController.swift:createAndSaveNewAkt:before_add", "message": "ПЕРЕД ДОБАВЛЕНИЕМ В ИСТОРИЮ", "data": ["akt_id": newAkt.id.uuidString, "akt_number": newAkt.number], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "A"]
        if let logData2 = try? JSONSerialization.data(withJSONObject: logDict2) {
            if let fileHandle = FileHandle(forWritingAtPath: logPath2) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(logData2)
                fileHandle.write("\n".data(using: .utf8)!)
                fileHandle.closeFile()
            } else {
                let fileURL = URL(fileURLWithPath: logPath2)
                if let newlineData = "\n".data(using: .utf8) {
                    try? (logData2 + newlineData).write(to: fileURL)
                } else {
                    try? logData2.write(to: fileURL)
                }
            }
        }
        // #endregion
        viewModel.addNewAktToArray(newAkt)
        print("   ✅ Акт №\(newAkt.number) добавлен в историю")
        
        // Создаем редактируемый акт для продолжения редактирования
        print("   💾 Создаем редактируемый акт...")
        viewModel.createNewAktAndMakeEditable(newAkt)
        print("   ✅ Акт создан и сделан редактируемым для продолжения")
        
        // ВАЖНО: Обновляем даты устранения нарушений при изменении даты проверки
        print("   🔄 Обновляем даты устранения нарушений...")
        print("      📋 Количество нарушений в акте: \(newAkt.violations.count)")
        updateViolationEliminationDates(for: newAkt)
        print("   ✅ Даты устранения нарушений обновлены")
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = newAkt
        print("   🔗 Ссылка на акт обновлена для последующих экранов")
        
        print("✅ [DATE_AND_NUMBER] СОЗДАНИЕ НОВОГО АКТА ЗАВЕРШЕНО")
        print("   🆔 ID созданного акта: \(newAkt.id.uuidString)")
        print("   🔑 UniqueID созданного акта: \(newAkt.uniqueID ?? "нет")")
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func updateAndSaveExistingAkt() {
        print("🔄 ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО АКТА И СОХРАНЕНИЕ В ИСТОРИЮ")
        
        guard let existingAkt = akt else {
            print("   ❌ Существующий акт не найден")
            return
        }
        
        let selectedNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        let selectedDate = datePicker.date
        
        // Автоматически пересчитываем даты на основе новой даты проверки
        let newUstranenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newPredostavlenDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate // +1 месяц от даты проверки
        let newUtverzdenDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate // +7 дней от даты проверки
        
        print("   📅 Дата проверки: \(selectedDate)")
        print("   📅 Дата устранения нарушения: \(newUstranenDate)")
        print("   📅 Дата предоставления отчета: \(newPredostavlenDate)")
        print("   📅 Дата утверждения: \(newUtverzdenDate)")
        
        // Создаем обновленный акт с новыми данными
        // ВАЖНО: Сохраняем оригинальный uniqueID для предотвращения дубликатов
        let updatedAkt = AKT(
            id: existingAkt.id, // Сохраняем оригинальный ID
            number: selectedNumber,
            date: selectedDate,
            comission: comissionPeoples,
            organization: existingAkt.organization, // Сохраняем существующую организацию
            objectsCheck: existingAkt.objectsCheck, // Сохраняем существующие объекты
            predstavitelyComission: existingAkt.predstavitelyComission, // Сохраняем существующих представителей
            violations: existingAkt.violations, // Сохраняем существующие нарушения
            description: existingAkt.description, // Сохраняем существующее описание
            actustranenDate: newUstranenDate, // Автоматически пересчитанная дата устранения
            actPredostavlenDate: newPredostavlenDate, // Автоматически пересчитанная дата предоставления
            actUtverzdenDate: newUtverzdenDate, // Автоматически пересчитанная дата утверждения
            urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""), // Сохраняем существующий URL
            realDateCreate: existingAkt.realDateCreate, // Сохраняем оригинальную дату создания
            uniqueID: existingAkt.uniqueID // Сохраняем оригинальный uniqueID для предотвращения дубликатов
        )
        
        print("   📋 Номер акта: \(updatedAkt.number)")
        print("   👥 Количество членов комиссии: \(updatedAkt.comission.count)")
        print("   🆔 ID акта: \(updatedAkt.id)")
        print("   🔑 UniqueID акта: \(updatedAkt.uniqueID ?? "нет")")
        
        // Обновляем акт в истории
        viewModel.updateAktInArray(updatedAkt)
        print("   ✅ Акт №\(updatedAkt.number) обновлен в истории")
        
        // ВАЖНО: Обновляем даты устранения нарушений при изменении даты проверки
        print("   🔄 Обновляем даты устранения нарушений...")
        print("      📋 Количество нарушений в акте: \(updatedAkt.violations.count)")
        updateViolationEliminationDates(for: updatedAkt)
        print("   ✅ Даты устранения нарушений обновлены")
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = updatedAkt
        
        print("✅ ОБНОВЛЕНИЕ И СОХРАНЕНИЕ СУЩЕСТВУЮЩЕГО АКТА ЗАВЕРШЕНО")
    }
    
    @objc private func addNewComissionPeople() {
        let editType = EditType.doubleField(
            title1: "ФИО",
            placeholder1: "Введите ФИО члена комиссии",
            currentValue1: "",
            title2: "Должность",
            placeholder2: "Введите должность члена комиссии",
            currentValue2: ""
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newFio, newJobTitle, _ in
            guard let self = self else { return }
            let jobTitle = newJobTitle ?? ""
            let newObj = ComissionPeople(fio: newFio, jobTitle: jobTitle)
            self.viewModel.comissionArray.append(newObj)
            DataFlowComission.saveArr(arr: self.viewModel.comissionArray)
            self.collection.reloadData()
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
    
    
}

extension DateAndNumberAktViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return 100
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let number = "\(row + 1)"
        // Проверяем номер с учетом года из даты проверки
        let year = Calendar.current.component(.year, from: datePicker.date)
        let excludingId = akt?.id
        let isOccupied = !viewModel.isAktNumberAvailable(number, forYear: year, excludingAktId: excludingId)
        
        if isOccupied {
            return "№\(number) (занят)"
        } else {
            return "№\(number)"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let number = "\(row + 1)"
        // Проверяем номер с учетом года из даты проверки
        let year = Calendar.current.component(.year, from: datePicker.date)
        let excludingId = akt?.id
        let isOccupied = !viewModel.isAktNumberAvailable(number, forYear: year, excludingAktId: excludingId)
        
        let title: String
        if isOccupied {
            title = "№\(number) (занят)"
        } else {
            title = "№\(number)"
        }
        
        let color: UIColor
        if traitCollection.userInterfaceStyle == .dark {
            color = isOccupied ? .systemRed : .white
        } else {
            color = isOccupied ? .systemRed : .black
        }
        
        return NSAttributedString(string: title, attributes: [.foregroundColor: color])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        let selectedNumber = "\(row + 1)"
        // Проверяем номер с учетом года из даты проверки
        let year = Calendar.current.component(.year, from: datePicker.date)
        let excludingId = akt?.id
        let isOccupied = !viewModel.isAktNumberAvailable(selectedNumber, forYear: year, excludingAktId: excludingId)
        
        // ВАЖНО: При редактировании существующего акта не показываем предупреждение,
        // если выбранный номер совпадает с номером текущего акта
        let isCurrentAktNumber = akt != nil && akt!.number == selectedNumber
        
        if isOccupied && !isCurrentAktNumber {
            showOccupiedNumberAlert(selectedNumber: selectedNumber)
        } else {
            // Автоматически сохраняем изменения при выборе номера
            if akt != nil {
                print("🔄 [DATE_AND_NUMBER] Номер изменен на \(selectedNumber), обновляем акт...")
                
                // Обновляем акт с новыми данными (включая пересчет дат)
                // ВАЖНО: При редактировании используем оригинальный номер акта
                updateAktWithNewData()
                print("   ✅ Акт автоматически обновлен с новым номером")
            }
        }
    }
    
    private func showOccupiedNumberAlert(selectedNumber: String) {
        let alert = UIAlertController(
            title: "Номер занят",
            message: "Номер акта №\(selectedNumber) уже используется. Пожалуйста, выберите другой номер.",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "Понятно", style: .default) { [weak self] _ in
            // Предлагаем следующий доступный номер
            if let nextAvailable = self?.viewModel.getNextAvailableAktNumber(),
               let nextRow = Int(nextAvailable), nextRow <= 100 {
                self?.numberPicker.selectRow(nextRow - 1, inComponent: 0, animated: true)
            }
        }
        
        alert.addAction(okAction)
        present(alert, animated: true)
    }
}

extension DateAndNumberAktViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.comissionArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        // Настройка внешнего вида ячейки в стиле настроек
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 20
        cell.clipsToBounds = true
        
        if indexPath.row == viewModel.comissionArray.count {
            let button = UIFactory.createButton(title: "Добавить", color: .clear)
            button.setTitleColor(.systemBlue, for: .normal)
            cell.addSubview(button)
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            button.addTarget(self, action: #selector(addNewComissionPeople), for: .touchUpInside)
        } else {
            let item = viewModel.comissionArray.reversed()[indexPath.row]
            
            let rightImageView = UIImageView()
            rightImageView.contentMode = .scaleAspectFit
            cell.addSubview(rightImageView)
            rightImageView.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
            }
            
            if comissionPeoples.contains(where: {$0.id == item.id}) {
                rightImageView.image = UIImage(systemName: "checkmark.circle.fill")
                rightImageView.tintColor = .systemGreen
            } else {
                rightImageView.image = UIImage(systemName: "circlebadge")
                rightImageView.tintColor = .systemGray
            }
            
            let mainLabel = UIFactory.createlabel(title: item.fio)
            // Улучшенный контраст для темной темы
            if traitCollection.userInterfaceStyle == .dark {
                mainLabel.textColor = .white
            } else {
                mainLabel.textColor = .black
            }
            mainLabel.numberOfLines = 1
            mainLabel.font = .systemFont(ofSize: 16, weight: .medium)
            cell.addSubview(mainLabel)
            mainLabel.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
                make.top.equalToSuperview().inset(10)
            }
            
            let sublabel = UIFactory.createlabel(title: item.jobTitle)
            sublabel.numberOfLines = 1
            // Улучшенный контраст для темной темы
            if traitCollection.userInterfaceStyle == .dark {
                sublabel.textColor = .white.withAlphaComponent(0.7)
            } else {
                sublabel.textColor = .black.withAlphaComponent(0.6)
            }
            sublabel.font = .systemFont(ofSize: 12, weight: .regular)
            cell.addSubview(sublabel)
            sublabel.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().inset(10)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 54)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row != viewModel.comissionArray.count {
            let selectedItem = viewModel.comissionArray.reversed()[indexPath.row]
            let oldCount = comissionPeoples.count
            let wasSelected = comissionPeoples.contains(where: {$0.id == selectedItem.id})
            
            print("═══════════════════════════════════════════════════════════")
            print("👆 [DATE_AND_NUMBER] ВЫБРАН ЧЛЕН КОМИССИИ")
            print("   📋 Выбранный член: \(selectedItem.fio) (\(selectedItem.jobTitle))")
            print("   🆔 ID: \(selectedItem.id)")
            print("   📊 Текущее количество: \(oldCount)")
            print("   ✅ Уже выбран: \(wasSelected)")
            
            if let index = comissionPeoples.firstIndex(where: {$0.id == selectedItem.id}) {
                let removed = comissionPeoples.remove(at: index)
                print("   ➖ УДАЛЕН из комиссии: \(removed.fio)")
                collectionView.reloadData()
            } else {
                comissionPeoples.append(selectedItem)
                print("   ➕ ДОБАВЛЕН в комиссию: \(selectedItem.fio)")
                collectionView.reloadData()
            }
            
            let newCount = comissionPeoples.count
            print("   📊 Новое количество: \(newCount)")
            print("   📋 Список членов комиссии:")
            for (idx, member) in comissionPeoples.enumerated() {
                print("      \(idx + 1). \(member.fio) - \(member.jobTitle)")
            }
            
            // Автоматически сохраняем изменения при изменении состава комиссии
            if akt != nil {
                print("   🔄 Начинаем обновление акта с новым составом комиссии...")
                print("   🆔 ID акта: \(akt!.id.uuidString)")
                print("   🔢 Номер акта: \(akt!.number)")
                
                // Обновляем акт с новыми данными (включая пересчет дат)
                updateAktWithNewData()
                print("   ✅ Акт автоматически обновлен с новым составом комиссии")
                
                // Проверяем, что изменения сохранились
                if let editableAkt = DataFlowAKT.getEditableAKT() {
                    print("   🔍 ПРОВЕРКА: Количество членов в редактируемом акте: \(editableAkt.akt.comission.count)")
                    if editableAkt.akt.comission.count == newCount {
                        print("   ✅ ПОДТВЕРЖДЕНО: Изменения сохранены корректно")
                    } else {
                        print("   ❌ ОШИБКА: Количество не совпадает! Ожидалось: \(newCount), получено: \(editableAkt.akt.comission.count)")
                    }
                } else {
                    print("   ⚠️ ПРЕДУПРЕЖДЕНИЕ: Редактируемый акт не найден после обновления")
                }
            } else {
                print("   ⚠️ Акт не найден, обновление не выполняется")
            }
            print("═══════════════════════════════════════════════════════════")
        }
    }
    
    // MARK: - Обновление дат устранения нарушений
    /// Обновляет даты устранения нарушений при изменении даты проверки акта
    private func updateViolationEliminationDates(for akt: AKT) {
        print("🔄 [DATE_AND_NUMBER] Начинаем обновление дат устранения для акта №\(akt.number)")
        print("   📅 Дата проверки: \(akt.date)")
        
        // Рассчитываем правильную дату устранения для логирования
        if let calculatedDate = Calendar.current.date(byAdding: .month, value: 1, to: akt.date) {
            print("   ✅ Правильная дата устранения (дата проверки + 1 месяц): \(calculatedDate)")
        } else {
            print("   ⚠️ Не удалось рассчитать дату устранения")
        }

        // Получаем все записи устранения для данного акта
        let eliminations = ViolationEliminationManager.getEliminationsForAkt(akt.id)
        print("   📊 Найдено записей устранения: \(eliminations.count)")

        if eliminations.isEmpty {
            print("   ℹ️ Записи устранения не найдены, создаем их...")
            // Создаем записи устранения для всех нарушений акта
            ViolationEliminationManager.createEliminationsForAkt(akt)
            print("   ✅ Записи устранения созданы")
            return
        }

        // Используем новый метод для обновления дат устранения
        print("   🔄 Вызываем ViolationEliminationManager.updateEliminationDatesForAkt...")
        ViolationEliminationManager.updateEliminationDatesForAkt(akt.id)
        
        // Уведомляем о необходимости обновления раздела устранения
        print("   📢 Отправляем уведомление об обновлении дат устранения...")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: NSNotification.Name("ViolationEliminationDatesUpdated"), object: nil, userInfo: ["aktId": akt.id])
        }
        print("   ✅ Уведомление отправлено")
        
        print("✅ [DATE_AND_NUMBER] Обновление дат устранения завершено для акта №\(akt.number)")
    }
}
