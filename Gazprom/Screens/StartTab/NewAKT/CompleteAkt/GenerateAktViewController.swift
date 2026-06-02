//
//  GenerateAktViewController.swift
//  Gazprom
//
//  Created by Владимир on 17.07.2025.
//

import UIKit
import UniformTypeIdentifiers
import WebKit

class GenerateAktViewController: UIViewController {
    
    private let generateViewModel = GenerateViewModel()
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    var date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    let descripUser: String
    let predstavitely: [PredstavitelyComission]
    
    var akt: AKT?
    var documentURL: URL?
    private let fileSizeLabel = UILabel()
    
    private let ustranenDatePicker = UIDatePicker() //дата устранения - ustranenDate
    private let predostavlenDatePicker = UIDatePicker() //дата предоставления - predostavlenDate
    private let utverzdenDatePicker = UIDatePicker() //дата утверждения - UtverzderDate
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstavitely: [PredstavitelyComission], akt: AKT?) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.descripUser = descripUser
        self.predstavitely = predstavitely
        self.akt = akt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        // Сохраняем изменённые даты в редактируемый акт при выходе с экрана (без генерации PDF)
        saveDatesToEditableAktIfNeeded()
        
        // Очищаем callback при уходе с экрана
        viewModel.templateModel.autoSaveCallback = nil
    }
    
    /// Сохраняет текущие даты из пикеров в редактируемый акт (без финализации в историю).
    /// Вызывается при выходе с экрана, чтобы правки сроков не терялись.
    private func saveDatesToEditableAktIfNeeded() {
        guard let editable = DataFlowAKT.getEditableAKT() else { return }
        let base = editable.akt
        let updatedAkt = AKT(
            id: base.id,
            number: base.number,
            date: base.date,
            comission: base.comission,
            organization: base.organization,
            objectsCheck: base.objectsCheck,
            predstavitelyComission: base.predstavitelyComission,
            violations: base.violations,
            description: base.description,
            actustranenDate: ustranenDatePicker.date,
            actPredostavlenDate: predostavlenDatePicker.date,
            actUtverzdenDate: utverzdenDatePicker.date,
            urlAct: base.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: base.realDateCreate
        )
        viewModel.saveChangesToEditableAkt(updatedAkt)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Генерация"
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        if let navController = navigationController {
            let viewControllers = navController.viewControllers
            // Ищем PredstavViewController в стеке
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let predstavVC = viewControllers[i] as? PredstavViewController {
                    let backButton = UIBarButtonItem(title: "Представители", style: .plain, target: nil, action: nil)
                    predstavVC.navigationItem.backBarButtonItem = backButton
                    predstavVC.navigationItem.backButtonTitle = "Представители"
                    break
                }
            }
            // Также устанавливаем в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Представители", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Представители"
            }
        }
        
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // ИСПРАВЛЕНИЕ: Приоритет загрузки дат из акта (редактируемого или в истории), затем из templateModel
        // Это гарантирует, что сохраненные даты не будут перезаписаны
        var datesLoaded = false
        
        // 1. Проверяем редактируемый акт (высший приоритет)
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            ustranenDatePicker.date = editableAkt.akt.actustranenDate
            predostavlenDatePicker.date = editableAkt.akt.actPredostavlenDate
            utverzdenDatePicker.date = editableAkt.akt.actUtverzdenDate
            datesLoaded = true
            print("📅 [VIEW_WILL_APPEAR] Даты загружены из редактируемого акта №\(editableAkt.akt.number)")
        }
        // 2. Проверяем обычный акт
        else if let existingAkt = akt {
            ustranenDatePicker.date = existingAkt.actustranenDate
            predostavlenDatePicker.date = existingAkt.actPredostavlenDate
            utverzdenDatePicker.date = existingAkt.actUtverzdenDate
            datesLoaded = true
            print("📅 [VIEW_WILL_APPEAR] Даты загружены из акта №\(existingAkt.number)")
        }
        // 3. Проверяем templateModel
        else if let ustran = viewModel.templateModel.ustranenDatePicker,
                let predos = viewModel.templateModel.predostavlenDatePicker,
                let utverzd = viewModel.templateModel.utverzdenDatePicker {
            ustranenDatePicker.date = ustran
            predostavlenDatePicker.date = predos
            utverzdenDatePicker.date = utverzd
            datesLoaded = true
            print("📅 [VIEW_WILL_APPEAR] Даты загружены из templateModel")
        }
        
        // 4. Если даты не были загружены ни откуда, пересчитываем по умолчанию
        if !datesLoaded {
            print("📅 [VIEW_WILL_APPEAR] Даты не найдены, пересчитываем по умолчанию")
            ustranenDateChanged()
        }
        setupNav()

        // Предварительная оценка размера файла до генерации
        estimateFileSizeAsync()
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
        navigationController?.popToRootViewController(animated: true)
    }
    
    // Удаляем старый индикатор, заменим на новый универсальный
    private var loadingIndicator: UIView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        checkOld()
        
        // Добавляем observer для автоматического пересчета дат при изменении даты проверки
        viewModel.templateModel.autoSaveCallback = { [weak self] in
            DispatchQueue.main.async {
                self?.updateDatesFromTemplate()
            }
        }
    }
    
    private func checkOld() {
        // ИСПРАВЛЕНИЕ: Приоритет загрузки дат из редактируемого акта, затем из обычного акта
        // Это гарантирует, что сохраненные даты будут отображаться правильно
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            // Загружаем даты из редактируемого акта (приоритет)
            ustranenDatePicker.date = editableAkt.akt.actustranenDate
            predostavlenDatePicker.date = editableAkt.akt.actPredostavlenDate
            utverzdenDatePicker.date = editableAkt.akt.actUtverzdenDate
            print("📅 [CHECK_OLD] Даты загружены из редактируемого акта №\(editableAkt.akt.number)")
        } else if let a = akt {
            // Если редактируемого акта нет, загружаем из обычного акта
            ustranenDatePicker.date = a.actustranenDate
            predostavlenDatePicker.date = a.actPredostavlenDate
            utverzdenDatePicker.date = a.actUtverzdenDate
            print("📅 [CHECK_OLD] Даты загружены из акта №\(a.number)")
        } else if let templateUstranen = viewModel.templateModel.ustranenDatePicker,
                  let templatePredostavlen = viewModel.templateModel.predostavlenDatePicker,
                  let templateUtverzden = viewModel.templateModel.utverzdenDatePicker {
            // Если акта нет, но есть даты в templateModel - используем их
            ustranenDatePicker.date = templateUstranen
            predostavlenDatePicker.date = templatePredostavlen
            utverzdenDatePicker.date = templateUtverzden
            print("📅 [CHECK_OLD] Даты загружены из templateModel")
        }
    }

    private func setupUI() {
        let genButton = UIFactory.createButton(title: "Создать акт", color: .systemGreen)
        view.addSubview(genButton)
        genButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.snp.centerY).offset(-8)
        }
        genButton.addTarget(self, action: #selector(openAlert), for: .touchUpInside)
        
        let selectButton = UIFactory.createButton(title: "Выбрать шаблон", color: .systemOrange)
        view.addSubview(selectButton)
        selectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(view.snp.centerY).offset(8)
        }
        selectButton.addTarget(self, action: #selector(selectShab), for: .touchUpInside)
        
        // Метка размера сгенерированного файла
        view.addSubview(fileSizeLabel)
        fileSizeLabel.text = "Размер файла (оценка): —"
        fileSizeLabel.textColor = .secondaryLabel
        fileSizeLabel.font = .systemFont(ofSize: 14, weight: .regular)
        fileSizeLabel.textAlignment = .center
        fileSizeLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(selectButton.snp.bottom).offset(12)
        }
        
        
        let ustranenDateLabel = UILabel()
        ustranenDateLabel.text = "Дата устранения нарушений:"
        ustranenDateLabel.textColor = .label
        ustranenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(ustranenDateLabel)
        ustranenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
        }
        ustranenDatePicker.datePickerMode = .date
        ustranenDatePicker.locale = .init(identifier: "ru_RU")
   //     ustranenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        view.addSubview(ustranenDatePicker)
        ustranenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(ustranenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
        
        let predostavlenDateLabel = UILabel()
        predostavlenDateLabel.text = "Дата предоставления:"
        predostavlenDateLabel.textColor = .label
        predostavlenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(predostavlenDateLabel)
        predostavlenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(ustranenDatePicker.snp.bottom).offset(12)
        }
        
        
        view.addSubview(predostavlenDatePicker)
        predostavlenDatePicker.datePickerMode = .date
        predostavlenDatePicker.locale = .init(identifier: "ru_RU")
        predostavlenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(predostavlenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
     //   predostavlenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        
        let utverzdenDateLabel = UILabel()
        utverzdenDateLabel.text = "Дата утверждения:"
        utverzdenDateLabel.textColor = .label
        utverzdenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(utverzdenDateLabel)
        utverzdenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(predostavlenDatePicker.snp.bottom).offset(12)
        }
        
        utverzdenDatePicker.datePickerMode = .date
        utverzdenDatePicker.locale = .init(identifier: "ru_RU")
        view.addSubview(utverzdenDatePicker)
        utverzdenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(utverzdenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
       // utverzdenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        
        // Кнопка для сохранения акта
        let saveButton = UIFactory.createButton(title: "Сохранить акт", color: .systemBlue)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(16)
        }
        saveButton.addTarget(self, action: #selector(saveAkt), for: .touchUpInside)
        
        // Убираем старый индикатор из setupUI, будем создавать динамически
    }
    

    
    
    @objc private func ustranenDateChanged() {
        let proverkaDate = date
        
        // Дата устранения = +1 месяц от даты проверки
        if let ustranenDate = Calendar.current.date(byAdding: .month, value: 1, to: proverkaDate) {
            ustranenDatePicker.date = ustranenDate
            
            // Дата предоставления отчета = дата устранения (тоже +1 месяц от даты проверки)
            predostavlenDatePicker.date = ustranenDate
        }
        
        // Дата утверждения = +7 дней от даты проверки
        if let utverzdenDate = Calendar.current.date(byAdding: .day, value: 7, to: proverkaDate) {
            utverzdenDatePicker.date = utverzdenDate
        }
        
        // Сохраняем рассчитанные даты в модель
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        print("📅 Даты пересчитаны:")
        print("   Дата проверки: \(proverkaDate)")
        print("   Дата устранения: \(ustranenDatePicker.date)")
        print("   Дата предоставления: \(predostavlenDatePicker.date)")
        print("   Дата утверждения: \(utverzdenDatePicker.date)")
        
        // Проверяем правильность расчета
        let oneMonthFromProverka = Calendar.current.date(byAdding: .month, value: 1, to: proverkaDate)
        print("   Проверка: дата проверки + 1 месяц = \(oneMonthFromProverka ?? Date())")
        print("   Совпадает с датой устранения: \(ustranenDatePicker.date == oneMonthFromProverka)")
    }
    
    @objc private func recalculateDates() {
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // Пересчитываем даты
        ustranenDateChanged()
        
        // Показываем уведомление пользователю
        let alert = UIAlertController(title: "Даты пересчитаны", message: "Даты обновлены согласно текущей дате проверки", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Сохраняет акт: даты, все данные, финализирует в историю и возвращает на главный экран
    @objc private func saveAkt() {
        print("💾 [SAVE_AKT] НАЧАЛО СОХРАНЕНИЯ АКТА")
        print("   📅 Дата устранения: \(ustranenDatePicker.date)")
        print("   📅 Дата предоставления: \(predostavlenDatePicker.date)")
        print("   📅 Дата утверждения: \(utverzdenDatePicker.date)")
        
        // Сохраняем даты в templateModel (для черновика и следующих шагов)
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        var aktId: UUID?
        
        // ИСПРАВЛЕНИЕ: Приоритет работы с редактируемым актом, чтобы избежать дубликатов
        if let editable = DataFlowAKT.getEditableAKT() {
            print("   ✅ Найден редактируемый акт №\(editable.akt.number)")
            let base = editable.akt
            aktId = base.id
            
            // Создаем обновленный акт с новыми датами из пикеров
            let updatedAkt = AKT(
                id: base.id,
                number: base.number,
                date: base.date,
                comission: base.comission,
                organization: base.organization,
                objectsCheck: base.objectsCheck,
                predstavitelyComission: base.predstavitelyComission,
                violations: base.violations,
                description: base.description,
                actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                urlAct: base.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: base.realDateCreate
            )
            
            print("   🔄 Сохраняем изменения в редактируемый акт...")
            viewModel.saveChangesToEditableAkt(updatedAkt)
            print("   ✅ Изменения сохранены в редактируемый акт")
            
        } else if let existingAkt = akt {
            print("   ✅ Найден обычный акт №\(existingAkt.number)")
            aktId = existingAkt.id
            
            // ИСПРАВЛЕНИЕ: Проверяем, есть ли акт уже в истории перед созданием редактируемого
            // Если акт уже в истории - обновляем его напрямую, чтобы избежать дубликатов
            let allAkts = DataFlowAKT.loadArr()
            if let aktInHistory = allAkts.first(where: { $0.id == existingAkt.id || $0.number == existingAkt.number }) {
                print("   ✅ Акт найден в истории, обновляем напрямую...")
                
                // Обновляем акт в истории с новыми датами
                let updatedAkt = AKT(
                    id: aktInHistory.id, // Используем ID из истории
                    number: aktInHistory.number,
                    date: aktInHistory.date,
                    comission: aktInHistory.comission,
                    organization: aktInHistory.organization,
                    objectsCheck: aktInHistory.objectsCheck,
                    predstavitelyComission: aktInHistory.predstavitelyComission,
                    violations: aktInHistory.violations,
                    description: aktInHistory.description,
                    actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                    actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                    actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                    urlAct: aktInHistory.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: aktInHistory.realDateCreate
                )
                
                // Обновляем акт в истории напрямую
                viewModel.updateAktInArray(updatedAkt)
                print("   ✅ Акт обновлен в истории")
                
                // Также обновляем локальную переменную
                self.akt = updatedAkt
            } else {
                print("   ✅ Акт не найден в истории, создаем редактируемый акт...")
                // Если акт не найден в истории, создаём редактируемый с новыми датами
                let updatedAkt = AKT(
                    id: existingAkt.id,
                    number: existingAkt.number,
                    date: existingAkt.date,
                    comission: existingAkt.comission,
                    organization: existingAkt.organization,
                    objectsCheck: existingAkt.objectsCheck,
                    predstavitelyComission: existingAkt.predstavitelyComission,
                    violations: existingAkt.violations,
                    description: existingAkt.description,
                    actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                    actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                    actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                    urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: existingAkt.realDateCreate
                )
                viewModel.createEditableAKT(from: updatedAkt)
                self.akt = updatedAkt
                print("   ✅ Редактируемый акт создан")
            }
        } else {
            print("   ⚠️ Акт не найден, создаем новый акт...")
            // Создаем новый акт с текущими данными
            let newAkt = AKT(
                number: aktNumber,
                date: date,
                comission: comissionPeople,
                organization: organizations.first ?? Organization(title: "-"),
                objectsCheck: objectCheck,
                predstavitelyComission: predstavitely,
                violations: violations,
                description: descripUser,
                actustranenDate: ustranenDatePicker.date,
                actPredostavlenDate: predostavlenDatePicker.date,
                actUtverzdenDate: utverzdenDatePicker.date,
                urlAct: URL(fileURLWithPath: ""),
                realDateCreate: Date.now
            )
            viewModel.createEditableAKT(from: newAkt)
            self.akt = newAkt
            aktId = newAkt.id
            print("   ✅ Новый акт создан")
        }
        
        // Обновляем даты устранения в разделе устранения с учётом продлённых сроков
        if let aktId = aktId {
            print("   🔄 Обновляем даты устранения в разделе устранения...")
            print("   📅 [DEBUG] Дата устранения (ustranenDatePicker): \(ustranenDatePicker.date)")
            print("   📅 [DEBUG] Дата предоставления (predostavlenDatePicker): \(predostavlenDatePicker.date)")
            // ИСПРАВЛЕНИЕ: Используем дату устранения (ustranenDatePicker), а не дату предоставления
            AKT.updateEliminationDatesFromAkt(aktId, newEliminationDate: ustranenDatePicker.date, forceUpdate: true)
            print("   ✅ Даты устранения обновлены")
        }
        
        // Финализируем акт в историю
        print("🏁 [SAVE_AKT] ФИНАЛИЗАЦИЯ АКТА В ИСТОРИЮ")
        viewModel.finalizeEditableAktToHistory()
        print("   ✅ Акт финализирован и добавлен в историю")
        
        print("✅ [SAVE_AKT] Сохранение акта завершено")
        
        // Возвращаемся на главный экран
        navigationController?.popToRootViewController(animated: true)
    }
    
    /// Сохраняет изменённые даты в templateModel и в АКТ без обязательной генерации нового файла
    @objc private func saveDatesOnly() {
        print("💾 [SAVE_DATES] НАЧАЛО СОХРАНЕНИЯ ДАТ")
        print("   📅 Дата устранения: \(ustranenDatePicker.date)")
        print("   📅 Дата предоставления: \(predostavlenDatePicker.date)")
        print("   📅 Дата утверждения: \(utverzdenDatePicker.date)")
        
        // Сохраняем даты в templateModel (для черновика и следующих шагов)
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        var aktId: UUID?
        
        // ИСПРАВЛЕНИЕ: Приоритет работы с редактируемым актом, чтобы избежать дубликатов
        if let editable = DataFlowAKT.getEditableAKT() {
            print("   ✅ Найден редактируемый акт №\(editable.akt.number)")
            let base = editable.akt
            aktId = base.id
            
            // Создаем обновленный акт с новыми датами из пикеров
            let updatedAkt = AKT(
                id: base.id,
                number: base.number,
                date: base.date,
                comission: base.comission,
                organization: base.organization,
                objectsCheck: base.objectsCheck,
                predstavitelyComission: base.predstavitelyComission,
                violations: base.violations,
                description: base.description,
                actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                urlAct: base.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: base.realDateCreate
            )
            
            print("   🔄 Сохраняем изменения в редактируемый акт...")
            viewModel.saveChangesToEditableAkt(updatedAkt)
            print("   ✅ Изменения сохранены в редактируемый акт")
            
            // ИСПРАВЛЕНИЕ: Если акт уже есть в истории, обновляем его там тоже
            // Это гарантирует, что даты будут сохранены даже если акт был финализирован ранее
            let allAkts = DataFlowAKT.loadArr()
            if allAkts.contains(where: { $0.id == base.id || $0.number == base.number }) {
                print("   🔄 Акт найден в истории, обновляем его тоже...")
                viewModel.updateAktInArray(updatedAkt)
                print("   ✅ Акт обновлен в истории")
            }
            
            // ВАЖНО: НЕ финализируем акт в историю здесь, чтобы избежать дубликатов
            // Пользователь может сохранить даты несколько раз, и это не должно создавать дубликаты
            
        } else if let existingAkt = akt {
            print("   ✅ Найден обычный акт №\(existingAkt.number)")
            aktId = existingAkt.id
            
            // ИСПРАВЛЕНИЕ: Проверяем, есть ли акт уже в истории перед созданием редактируемого
            // Если акт уже в истории - обновляем его напрямую, чтобы избежать дубликатов
            let allAkts = DataFlowAKT.loadArr()
            if let aktInHistory = allAkts.first(where: { $0.id == existingAkt.id || $0.number == existingAkt.number }) {
                print("   ✅ Акт найден в истории, обновляем напрямую...")
                
                // Обновляем акт в истории с новыми датами
                let updatedAkt = AKT(
                    id: aktInHistory.id, // Используем ID из истории
                    number: aktInHistory.number,
                    date: aktInHistory.date,
                    comission: aktInHistory.comission,
                    organization: aktInHistory.organization,
                    objectsCheck: aktInHistory.objectsCheck,
                    predstavitelyComission: aktInHistory.predstavitelyComission,
                    violations: aktInHistory.violations,
                    description: aktInHistory.description,
                    actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                    actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                    actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                    urlAct: aktInHistory.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: aktInHistory.realDateCreate
                )
                
                // Обновляем акт в истории напрямую
                viewModel.updateAktInArray(updatedAkt)
                print("   ✅ Акт обновлен в истории")
                
                // Также обновляем локальную переменную
                self.akt = updatedAkt
            } else {
                print("   ✅ Акт не найден в истории, создаем редактируемый акт...")
                // Если акт не найден в истории, создаём редактируемый с новыми датами
                let updatedAkt = AKT(
                    id: existingAkt.id,
                    number: existingAkt.number,
                    date: existingAkt.date,
                    comission: existingAkt.comission,
                    organization: existingAkt.organization,
                    objectsCheck: existingAkt.objectsCheck,
                    predstavitelyComission: existingAkt.predstavitelyComission,
                    violations: existingAkt.violations,
                    description: existingAkt.description,
                    actustranenDate: ustranenDatePicker.date, // Используем дату из пикера
                    actPredostavlenDate: predostavlenDatePicker.date, // Используем дату из пикера
                    actUtverzdenDate: utverzdenDatePicker.date, // Используем дату из пикера
                    urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: existingAkt.realDateCreate
                )
                viewModel.createEditableAKT(from: updatedAkt)
                self.akt = updatedAkt
                print("   ✅ Редактируемый акт создан")
            }
        } else {
            print("   ⚠️ Акт не найден, сохраняем только в templateModel")
        }
        
        // Обновляем даты устранения в разделе устранения с учётом продлённых сроков
        if let aktId = aktId {
            print("   🔄 Обновляем даты устранения в разделе устранения...")
            print("   📅 [DEBUG] Дата устранения (ustranenDatePicker): \(ustranenDatePicker.date)")
            print("   📅 [DEBUG] Дата предоставления (predostavlenDatePicker): \(predostavlenDatePicker.date)")
            // ИСПРАВЛЕНИЕ: Используем дату устранения (ustranenDatePicker), а не дату предоставления
            AKT.updateEliminationDatesFromAkt(aktId, newEliminationDate: ustranenDatePicker.date, forceUpdate: true)
            print("   ✅ Даты устранения обновлены")
        }
        
        print("✅ [SAVE_DATES] Сохранение дат завершено")
        
        let alert = UIAlertController(
            title: "Даты сохранены",
            message: "Новые даты сохранены в акте и в разделе устранения. При необходимости вы можете позже переформировать файл акта.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateDatesFromTemplate() {
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // Пересчитываем даты только если они не были установлены вручную
        if viewModel.templateModel.ustranenDatePicker == nil || 
           viewModel.templateModel.predostavlenDatePicker == nil || 
           viewModel.templateModel.utverzdenDatePicker == nil {
            ustranenDateChanged()
        }
    }
    
    @objc private func openAlert() {
        // Убираем лишний alert и сразу создаем акт
        create()
    }
    
    @objc private func create() {
        // Показываем улучшенный индикатор загрузки
        showLoadingIndicator(message: "Создание акта...")
        
        // Логируем начало процесса генерации акта
        print("🚀 НАЧАЛО ГЕНЕРАЦИИ АКТА")
        print("   📋 Номер акта: \(aktNumber)")
        print("   📅 Дата проверки: \(date)")
        print("   👥 Количество членов комиссии: \(comissionPeople.count)")
        print("   🏢 Количество организаций: \(organizations.count)")
        print("   🏗️ Количество объектов проверки: \(objectCheck.count)")
        print("   ⚠️ Количество нарушений: \(violations.count)")
        print("   👤 Количество представителей: \(predstavitely.count)")
        print("   📝 Длина описания: \(descripUser.count) символов")
        
        // Получаем значения дат в главном потоке перед переходом в фоновый
        let predostavlenDate = predostavlenDatePicker.date
        let ustranenDate = ustranenDatePicker.date
        let utverzdenDate = utverzdenDatePicker.date
        
        // Выполняем генерацию в фоновом потоке
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Проверяем наличие шаблона
            print("🔍 ПРОВЕРКА ШАБЛОНА")
            guard let filePath = UserDefaults.standard.string(forKey: "ShabPath") else {
                print("   ❌ Путь к шаблону не найден в UserDefaults")
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.selectShab()
                }
                return
            }
            print("   ✅ Путь к шаблону найден: \(filePath)")
            
            let url = URL(fileURLWithPath: filePath)
            
            // Проверяем существование файла
            print("📁 ПРОВЕРКА СУЩЕСТВОВАНИЯ ФАЙЛА")
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("   ❌ Файл шаблона не существует по пути: \(url.path)")
                DispatchQueue.main.async {
                    self.hideLoadingIndicator()
                    self.selectShab()
                }
                return
            }
            print("   ✅ Файл шаблона существует")
            
            // Получаем информацию о файле
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let fileSize = attributes[.size] as? Int ?? 0
                let fileSizeKB = fileSize / 1024
                print("   📊 Размер файла шаблона: \(fileSizeKB) KB")
            } catch {
                print("   ⚠️ Не удалось получить информацию о файле: \(error)")
            }
            
            // Отладочная информация о датах перед генерацией
            print("🔍 Отладочная информация перед генерацией:")
            print("   Дата проверки (date): \(self.date)")
            print("   Дата предоставления: \(predostavlenDate)")
            print("   Дата устранения: \(ustranenDate)")
            print("   Дата утверждения: \(utverzdenDate)")
            
            // ВАЖНО: Синхронизируем представителей с актуальными данными из viewModel
            // чтобы использовать обновленные ФИО представителей
            let actualPredstavitely = self.predstavitely.map { rep in
                // Ищем актуального представителя по ID в viewModel.predstavitelyArray
                if let updatedRep = self.viewModel.predstavitelyArray.first(where: { $0.id == rep.id }) {
                    return updatedRep // Используем актуальные данные (включая обновленное ФИО)
                }
                return rep // Если не найден, используем оригинальные данные
            }
            
            // Генерируем акт
            self.generateViewModel.generate(
                url: url,
                comissionPeople: self.comissionPeople,
                date: self.date,
                aktNumber: self.aktNumber,
                organizations: self.organizations,
                objectCheck: self.objectCheck,
                violations: self.violations,
                descripUser: self.descripUser,
                predstav: actualPredstavitely,
                datePredostavlen: predostavlenDate,
                dateUstranen: ustranenDate,
                utverzdenDate: utverzdenDate,
                escaping: { [weak self] url in
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        self.hideLoadingIndicator()
                        
                        if let unwURL = url {
                            print("⚠️ [ERROR_LOG] GenerateAktViewController: Акт успешно сгенерирован, URL: \(unwURL.path)")
                            self.handleGeneratedAkt(url: unwURL)
                        } else {
                            print("⚠️ [ERROR_LOG] GenerateAktViewController: Генерация вернула nil - акт не был создан")
                            self.showAlert(title: "Ошибка генерации", message: "Не удалось создать акт. Проверьте шаблон и попробуйте снова.")
                        }
                    }
                }
            )
        }
    }
    
    private func handleGeneratedAkt(url: URL) {
        // Получаем размер файла акта
        let fileSize = getFileSize(url)
        let fileSizeFormatted = formatFileSize(fileSize)
        
        print("📄 Размер итогового акта: \(fileSizeFormatted)")
        // Обновляем метку размера на экране (фактический размер)
        fileSizeLabel.text = "Размер файла (факт): \(fileSizeFormatted)"
        
        // Если это редактирование существующего акта, обновляем его
        print("🔍 [DEBUG] Проверяем self.akt:")
        print("   self.akt = \(self.akt?.number ?? "nil")")
        print("   self.akt?.id = \(self.akt?.id.uuidString ?? "nil")")
        
        if let existingAkt = self.akt {
            print("🔄 [GENERATE] РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
            print("   📋 Детали существующего акта:")
            print("      Номер: \(existingAkt.number)")
            print("      ID: \(existingAkt.id)")
            print("      Дата: \(existingAkt.date)")
            print("      Организация: \(existingAkt.organization.title)")
            print("      URL документа: \(existingAkt.urlToFllACT?.path ?? "нет")")
            
            // ПОЛУЧАЕМ АКТУАЛЬНЫЕ ДАННЫЕ ИЗ СИСТЕМЫ РЕАЛЬНОГО ВРЕМЕНИ
            print("   🔄 Получаем актуальные данные из системы реального времени...")
            let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt ?? existingAkt
            
            // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: Если в системе реального времени нет актуальных данных,
            // используем данные из редактируемого акта
            let finalAkt: AKT
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                print("   🔄 Используем данные из редактируемого акта...")
                finalAkt = editableAkt.akt
            } else {
                print("   🔄 Используем данные из системы реального времени...")
                finalAkt = currentAkt
            }
            
            print("   ✅ Актуальные данные получены:")
            print("      Количество представителей: \(finalAkt.predstavitelyComission.count)")
            print("      Список представителей: \(finalAkt.predstavitelyComission.map { $0.fio })")
            
            // Берем актуальные даты из пикеров (те же, что ушли в документ)
            let updatedUstranenDate = ustranenDatePicker.date
            let updatedPredostavlenDate = predostavlenDatePicker.date
            let updatedUtverzdenDate = utverzdenDatePicker.date
            
            print("   🔄 Обновляем даты акта:")
            print("      Новая дата устранения: \(updatedUstranenDate)")
            print("      Новая дата предоставления: \(updatedPredostavlenDate)")
            print("      Новая дата утверждения: \(updatedUtverzdenDate)")
            
            print("   🔄 Создаем обновленный акт с новым URL, датами и актуальными данными...")
            let updatedAkt = AKT(
                id: finalAkt.id,
                number: finalAkt.number,
                date: finalAkt.date,
                comission: finalAkt.comission,
                organization: finalAkt.organization,
                objectsCheck: finalAkt.objectsCheck,
                predstavitelyComission: finalAkt.predstavitelyComission,
                violations: finalAkt.violations,
                description: finalAkt.description,
                actustranenDate: updatedUstranenDate,
                actPredostavlenDate: updatedPredostavlenDate,
                actUtverzdenDate: updatedUtverzdenDate,
                urlAct: url,
                realDateCreate: finalAkt.realDateCreate
            )
            print("   ✅ Обновленный акт создан:")
            print("      Номер: \(updatedAkt.number)")
            print("      ID: \(updatedAkt.id)")
            print("      Новый URL: \(updatedAkt.urlToFllACT?.path ?? "нет")")
            print("      Количество представителей: \(updatedAkt.predstavitelyComission.count)")
            print("      Список представителей: \(updatedAkt.predstavitelyComission.map { $0.fio })")
            
            // Сохраняем изменения в редактируемый акт
            print("   🔄 Сохраняем изменения в редактируемый акт...")
            viewModel.saveChangesToEditableAkt(updatedAkt)
            print("   ✅ Изменения сохранены в редактируемый акт")
            
            // ФИНАЛИЗИРУЕМ АКТ В ИСТОРИЮ СРАЗУ ПОСЛЕ СОЗДАНИЯ
            print("🏁 [GENERATE] ФИНАЛИЗАЦИЯ АКТА В ИСТОРИЮ")
            viewModel.finalizeEditableAktToHistory()
            print("   ✅ Акт №\(updatedAkt.number) финализирован и добавлен в историю")
            
            // Обновляем даты устранения в разделе устранения с учётом продлённых сроков
            print("🔄 [GENERATE] Обновление дат устранения в разделе устранения...")
            // ИСПРАВЛЕНИЕ: Используем метод из AKT с принудительным обновлением
            AKT.updateEliminationDatesFromAkt(updatedAkt.id, newEliminationDate: updatedUstranenDate, forceUpdate: true)
            print("   ✅ Даты устранения обновлены")
            
        } else {
            print("🔄 [GENERATE] СОЗДАНИЕ НОВОГО АКТА (self.akt = nil)")
            print("   📋 Причина: self.akt равен nil, поэтому создаем новый акт")
            print("   📋 Детали для создания акта:")
            print("      Номер: \(aktNumber)")
            print("      Дата: \(date)")
            print("      Количество членов комиссии: \(comissionPeople.count)")
            print("      Организация: \(organizations.first?.title ?? "-")")
            print("      Количество объектов проверки: \(objectCheck.count)")
            print("      Количество нарушений: \(violations.count)")
            print("      URL документа: \(url.path)")
            
            // ПОЛУЧАЕМ АКТУАЛЬНЫЕ ДАННЫЕ ИЗ СИСТЕМЫ РЕАЛЬНОГО ВРЕМЕНИ
            print("   🔄 Получаем актуальные данные из системы реального времени...")
            let currentPredstavitely = SimpleRealtimeAKTManager.shared.currentAkt?.predstavitelyComission ?? predstavitely
            
            // ДОПОЛНИТЕЛЬНАЯ ПРОВЕРКА: Если в системе реального времени нет актуальных данных,
            // используем данные из редактируемого акта
            // ВАЖНО: Синхронизируем данные с актуальными из viewModel.predstavitelyArray
            // чтобы использовать обновленные ФИО представителей
            let finalPredstavitely: [PredstavitelyComission]
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                print("   🔄 Используем данные из редактируемого акта...")
                // Синхронизируем с актуальными данными из viewModel.predstavitelyArray
                let syncedPredstavitely = editableAkt.akt.predstavitelyComission.map { rep in
                    // Ищем актуального представителя по ID в viewModel.predstavitelyArray
                    if let updatedRep = viewModel.predstavitelyArray.first(where: { $0.id == rep.id }) {
                        return updatedRep // Используем актуальные данные (включая обновленное ФИО)
                    }
                    return rep // Если не найден, используем оригинальные данные
                }
                finalPredstavitely = syncedPredstavitely
            } else {
                print("   🔄 Используем данные из системы реального времени...")
                // Синхронизируем с актуальными данными из viewModel.predstavitelyArray
                let syncedPredstavitely = currentPredstavitely.map { rep in
                    // Ищем актуального представителя по ID в viewModel.predstavitelyArray
                    if let updatedRep = viewModel.predstavitelyArray.first(where: { $0.id == rep.id }) {
                        return updatedRep // Используем актуальные данные (включая обновленное ФИО)
                    }
                    return rep // Если не найден, используем оригинальные данные
                }
                finalPredstavitely = syncedPredstavitely
            }
            
            print("   ✅ Актуальные данные получены:")
            print("      Количество представителей: \(finalPredstavitely.count)")
            print("      Список представителей: \(finalPredstavitely.map { $0.fio })")
            
            // Если это существующий акт, обновляем его
            print("   🔄 Создаем новый акт с актуальными данными...")
            let updatedAkt = AKT(
                number: aktNumber,
                date: date,
                comission: comissionPeople,
                organization: organizations.first ?? Organization(title: "-"),
                objectsCheck: objectCheck,
                predstavitelyComission: finalPredstavitely,
                violations: violations,
                description: descripUser,
                actustranenDate: ustranenDatePicker.date,
                actPredostavlenDate: predostavlenDatePicker.date,
                actUtverzdenDate: utverzdenDatePicker.date,
                urlAct: url, 
                realDateCreate: Date.now
            )
            print("   ✅ Новый акт создан:")
            print("      Номер: \(updatedAkt.number)")
            print("      ID: \(updatedAkt.id)")
            print("      Дата создания: \(updatedAkt.realDateCreate)")
            print("      Количество представителей: \(updatedAkt.predstavitelyComission.count)")
            print("      Список представителей: \(updatedAkt.predstavitelyComission.map { $0.fio })")
            
            // ИСПРАВЛЕНИЕ: Проверяем, есть ли редактируемый акт с таким же номером или ID
            // Если есть - используем finalizeEditableAktToHistory() для предотвращения дубликатов
            if let editableAkt = DataFlowAKT.getEditableAKT(),
               (editableAkt.akt.number == updatedAkt.number || editableAkt.akt.id == updatedAkt.id) {
                print("   🔄 Найден редактируемый акт с таким же номером/ID, используем финализацию...")
                // Сохраняем изменения в редактируемый акт
                viewModel.saveChangesToEditableAkt(updatedAkt)
                // Финализируем редактируемый акт в историю (это предотвратит дубликаты)
                viewModel.finalizeEditableAktToHistory()
                print("   ✅ Акт №\(updatedAkt.number) финализирован через редактируемый акт")
            } else {
                // Если редактируемого акта нет или он отличается - обновляем напрямую
                print("   🔄 Редактируемого акта нет, обновляем напрямую в массиве...")
                viewModel.updateAktInArray(updatedAkt)
                print("   ✅ Акт №\(updatedAkt.number) обновлен в истории")
            }
            
            // Обновляем даты устранения в разделе устранения с учётом продлённых сроков
            print("   🔄 Обновление дат устранения в разделе устранения...")
            // ИСПРАВЛЕНИЕ: Используем метод из AKT с принудительным обновлением
            AKT.updateEliminationDatesFromAkt(updatedAkt.id, newEliminationDate: ustranenDatePicker.date, forceUpdate: true)
            print("   ✅ Даты устранения обновлены")
        }
        
        // Сначала открываем документ, а потом показываем информацию
        openDoc(url: url)
        
        // Показываем информацию о размере файла пользователю с небольшой задержкой
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showFileSizeInfo(fileSize: fileSizeFormatted)
        }
    }
    
    private func showFileSizeInfo(fileSize: String) {
        // Показываем алерт только если нет представленного контроллера
        guard presentedViewController == nil else {
            // Если документ уже открыт, не показываем алерт
            return
        }
        
        let alert = UIAlertController(
            title: "Акт создан успешно!",
            message: "Размер файла: \(fileSize)\n\nИзображения автоматически оптимизированы для уменьшения размера акта. Файл гарантированно не превышает 5 МБ.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - File Size Utilities
    private func getFileSize(_ url: URL) -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int
        } catch {
            print("❌ Ошибка получения размера файла: \(error)")
            return nil
        }
    }
    
    private func formatFileSize(_ bytes: Int?) -> String {
        guard let bytes = bytes else {
            return "Неизвестно"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    
    private func openDoc(url: URL) {
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Файл не существует: \(url.path)")
            // Проверяем альтернативный путь в Documents
            let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = url.lastPathComponent
            let alternativeURL = documentsURL.appendingPathComponent(fileName)
            
            if FileManager.default.fileExists(atPath: alternativeURL.path) {
                print("✅ Файл найден по альтернативному пути: \(alternativeURL.path)")
                openDoc(url: alternativeURL)
                return
            }
            
            // Показываем ошибку только если файл не найден нигде
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlert(title: "Ошибка", message: "Файл не найден или был удален. Попробуйте сгенерировать акт снова.")
            }
            return
        }
        
        // Проверяем размер файла
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? NSNumber ?? 0
            if fileSize.intValue == 0 {
                print("❌ Файл пустой: \(url.path)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.showAlert(title: "Ошибка", message: "Файл пустой или поврежден")
                }
                return
            }
        } catch {
            print("❌ Ошибка при проверке файла: \(error)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlert(title: "Ошибка", message: "Не удалось проверить файл")
            }
            return
        }
        
        // Определяем, находится ли файл уже в Documents
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let isInDocuments = url.path.hasPrefix(documentsURL.path)
        
        let fileToUse: URL
        
        if isInDocuments {
            // Файл уже в Documents - используем его напрямую
            fileToUse = url
        } else {
            // Файл в tmp - копируем в Documents
            let fileName = url.lastPathComponent
            let destinationURL = documentsURL.appendingPathComponent(fileName)
            
            do {
                // Удаляем старый файл если существует
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                // Копируем файл в Documents
                try FileManager.default.copyItem(at: url, to: destinationURL)
                print("✅ Файл скопирован в Documents: \(destinationURL.path)")
                
                // Проверяем, что файл действительно существует после копирования
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    fileToUse = destinationURL
                } else {
                    print("❌ Файл не существует после копирования: \(destinationURL.path)")
                    // Пробуем использовать оригинальный файл
                    if FileManager.default.fileExists(atPath: url.path) {
                        fileToUse = url
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.showAlert(title: "Ошибка", message: "Не удалось скопировать файл. Попробуйте сгенерировать акт снова.")
                        }
                        return
                    }
                }
            } catch {
                print("❌ Ошибка при копировании файла: \(error)")
                // Пробуем использовать оригинальный файл
                if FileManager.default.fileExists(atPath: url.path) {
                    fileToUse = url
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.showAlert(title: "Ошибка", message: "Файл не найден. Попробуйте сгенерировать акт снова.")
                    }
                    return
                }
            }
        }
        
        // Финальная проверка существования файла перед открытием
        guard FileManager.default.fileExists(atPath: fileToUse.path) else {
            print("❌ Файл не существует перед открытием: \(fileToUse.path)")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlert(title: "Ошибка", message: "Файл не найден. Попробуйте сгенерировать акт снова.")
            }
            return
        }
        
        // Открываем документ
        let documentViewController = DocumentViewController(documentURL: fileToUse)
        let navigationController = UINavigationController(rootViewController: documentViewController)
        
        // Проверяем, что нет уже представленного контроллера
        if presentedViewController == nil {
            self.present(navigationController, animated: true, completion: nil)
        } else {
            // Если уже есть представленный контроллер, показываем ошибку
            print("⚠️ Не удалось открыть документ: уже представлен другой контроллер")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showAlert(title: "Ошибка", message: "Не удалось открыть документ. Закройте текущее окно и попробуйте снова.")
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Loading Indicator Methods
    
    private func showLoadingIndicator(message: String = "Загрузка...") {
        hideLoadingIndicator() // Убираем предыдущий индикатор если есть
        loadingIndicator = UIFactory.showLoadingIndicator(on: view, message: message)
    }
    
    private func hideLoadingIndicator() {
        UIFactory.hideLoadingIndicator(from: view)
        loadingIndicator = nil
    }
    
    
    
    @objc private func selectShab() {
        // Показываем индикатор загрузки
        showLoadingIndicator(message: "Открытие файлового менеджера...")
        
        let docxType = UTType(filenameExtension: "docx") ?? .item
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docxType], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        
        // Скрываем индикатор загрузки перед показом файлового менеджера
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.hideLoadingIndicator()
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let topVC = windowScene.windows.first?.rootViewController {
                topVC.present(documentPicker, animated: true, completion: nil)
            }
        }
    }

}


extension GenerateAktViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }

        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(sourceURL.lastPathComponent)

        var success = false

        if sourceURL.startAccessingSecurityScopedResource() {
            success = true
        }

        defer {
            if success {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Файл скопирован в: \(destinationURL.path)")

            // ✅ Сохраняем путь только после успешного копирования
            UserDefaults.standard.set(destinationURL.path, forKey: "ShabPath")

            // Обновляем предварительную оценку размера
            DispatchQueue.main.async { [weak self] in
                self?.estimateFileSizeAsync()
            }

        } catch {
            print("❌ Ошибка при копировании файла: \(error.localizedDescription)")
            // 🔴 Удаляем старое значение, если копирование не удалось
            UserDefaults.standard.removeObject(forKey: "ShabPath")
        }

    }




    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }



    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Отмена выбора документа")
    }
}

// MARK: - Pre-generation size estimation
private extension GenerateAktViewController {
    func estimateFileSizeAsync() {
        fileSizeLabel.text = "Размер файла (оценка): расчёт..."

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var totalBytes = 0

            // Размер шаблона
            if let filePath = UserDefaults.standard.string(forKey: "ShabPath") {
                let url = URL(fileURLWithPath: filePath)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int {
                    totalBytes += size
                }
            }

            // Оценка суммарного размера изображений после сжатия
            var imagesBytes = 0
            for violation in self.violations {
                for photoData in violation.photo {
                    if let image = UIImage(data: photoData),
                       let compressed = self.generateViewModel.compressImageForAct(image, aggressive: false) {
                        imagesBytes += compressed.count
                    }
                }
            }
            totalBytes += imagesBytes

            // Небольшой запас на XML/rels (эвристика)
            totalBytes += 50_000

            let formatted = self.formatFileSize(totalBytes)

            DispatchQueue.main.async { [weak self] in
                self?.fileSizeLabel.text = "Размер файла (оценка): \(formatted)"
            }
        }
    }
}
