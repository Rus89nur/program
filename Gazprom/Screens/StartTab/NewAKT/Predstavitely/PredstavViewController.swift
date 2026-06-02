//
//  PredstavViewController.swift
//  Gazprom
//
//  Created by Владимир on 24.07.2025.
//

import UIKit
import Combine

class PredstavViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    let descripUser: String
    
    var predstavitely: [PredstavitelyComission] = []
    
    var akt: AKT?
    var isEditingMode: Bool = false
    
    // Система реального времени
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstavitely: [PredstavitelyComission], akt: AKT?, isEditingMode: Bool = false) {
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
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let collection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 16, left: 0, bottom: 16, right: 0)
        collection.showsVerticalScrollIndicator = false
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.layer.cornerRadius = 16
        layout.scrollDirection = .vertical
        return collection
    }()
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.templateModel.predstavitely = predstavitely
        
        print("🔍 [PREDSTAV] Экран представителей закрывается")
        print("   📊 Финальные представители: \(predstavitely.count) шт.")
        print("   📋 Финальный список: \(predstavitely.map { $0.fio })")
        
        // ВАЖНО: Синхронизируем с актуальными данными из viewModel перед сохранением
        // чтобы использовать обновленные ФИО представителей
        let syncedPredstavitely = predstavitely.map { rep in
            // Ищем актуального представителя по ID в viewModel.predstavitelyArray
            if let updatedRep = viewModel.predstavitelyArray.first(where: { $0.id == rep.id }) {
                return updatedRep // Используем актуальные данные (включая обновленное ФИО)
            }
            return rep // Если не найден, используем оригинальные данные
        }
        
        // СОХРАНЯЕМ ИЗМЕНЕНИЯ ПРИ ЗАКРЫТИИ ЭКРАНА (ВСЕГДА, даже если список пустой)
        print("🔄 [PREDSTAV] Сохраняем изменения при закрытии экрана...")
        SimpleRealtimeAKTManager.shared.updatePredstavitely(syncedPredstavitely)
        print("✅ [PREDSTAV] Изменения сохранены при закрытии экрана")
        
        // ДОПОЛНИТЕЛЬНО: Принудительно сохраняем изменения в редактируемый акт
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            let updatedAkt = AKT(
                id: editableAkt.akt.id,
                number: editableAkt.akt.number,
                date: editableAkt.akt.date,
                comission: editableAkt.akt.comission,
                organization: editableAkt.akt.organization,
                objectsCheck: editableAkt.akt.objectsCheck,
                predstavitelyComission: syncedPredstavitely, // Используем синхронизированный список представителей
                violations: editableAkt.akt.violations,
                description: editableAkt.akt.description,
                actustranenDate: editableAkt.akt.actustranenDate,
                actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: editableAkt.akt.realDateCreate
            )
            DataFlowAKT.updateEditableAKT(updatedAkt)
            print("✅ [PREDSTAV] Редактируемый акт обновлен с актуальными представителями")
        }
        
        // Принудительно сохраняем изменения немедленно
        SimpleRealtimeAKTManager.shared.saveChangesImmediately()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Представители"
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        if let navController = navigationController {
            let viewControllers = navController.viewControllers
            // Ищем UserDescriptionViewController в стеке
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let descVC = viewControllers[i] as? UserDescriptionViewController {
                    let backButton = UIBarButtonItem(title: "Выводы", style: .plain, target: nil, action: nil)
                    descVC.navigationItem.backBarButtonItem = backButton
                    descVC.navigationItem.backButtonTitle = "Выводы"
                    break
                }
            }
            // Также устанавливаем в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Выводы", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Выводы"
            }
        }
        
        setupViewModel()
        setupNav()
        
        // ВАЖНО: Перезагружаем данные при каждом входе в раздел
        // чтобы отображать актуальные изменения
        reloadPredstavitelyData()
        
        print("🔍 [PREDSTAV] Экран представителей открыт")
        print("   📊 Текущие представители: \(predstavitely.count) шт.")
        print("   📋 Список представителей: \(predstavitely.map { $0.fio })")
    }
    
    private func reloadPredstavitelyData() {
        print("🔄 [PREDSTAV] Перезагрузка данных представителей...")
        
        // Сначала проверяем редактируемый акт
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("   ✅ Найден редактируемый акт, используем его данные")
            
            // Синхронизируем ID представителей из редактируемого акта с ID из viewModel.predstavitelyArray
            var syncedPredstavitely: [PredstavitelyComission] = []
            for predstavFromAkt in editableAkt.akt.predstavitelyComission {
                // Ищем соответствующего представителя в viewModel.predstavitelyArray по ID
                if let matchingPredstav = viewModel.predstavitelyArray.first(where: { $0.id == predstavFromAkt.id }) {
                    // Используем представителя из viewModel с правильным ID и актуальными данными
                    syncedPredstavitely.append(matchingPredstav)
                    print("   ✅ Синхронизирован представитель: \(matchingPredstav.fio) (ID: \(matchingPredstav.id.uuidString))")
                } else if let matchingPredstav = viewModel.predstavitelyArray.first(where: { predstav in
                    predstav.fio == predstavFromAkt.fio &&
                    predstav.jobTitle == predstavFromAkt.jobTitle &&
                    predstav.organization == predstavFromAkt.organization
                }) {
                    // Fallback: ищем по совпадению fio, jobTitle и organization
                    syncedPredstavitely.append(matchingPredstav)
                    print("   ✅ Синхронизирован представитель (fallback): \(matchingPredstav.fio)")
                } else {
                    // Если не нашли совпадение, используем представителя из акта как есть
                    syncedPredstavitely.append(predstavFromAkt)
                    print("   ⚠️ Представитель не найден в общей базе: \(predstavFromAkt.fio), используем из акта")
                }
            }
            
            predstavitely = syncedPredstavitely
            print("   ✅ Данные перезагружены из редактируемого акта:")
            print("      Количество представителей: \(predstavitely.count)")
            print("      Список представителей: \(predstavitely.map { $0.fio })")
            
            // Обновляем ссылку на акт
            if akt != nil {
                self.akt = editableAkt.akt
            }
        } else if let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt {
            print("   ✅ Используем данные из системы реального времени")
            
            // Синхронизируем ID представителей из системы реального времени с ID из viewModel.predstavitelyArray
            var syncedPredstavitely: [PredstavitelyComission] = []
            for predstavFromAkt in currentAkt.predstavitelyComission {
                // Ищем соответствующего представителя в viewModel.predstavitelyArray по ID
                if let matchingPredstav = viewModel.predstavitelyArray.first(where: { $0.id == predstavFromAkt.id }) {
                    // Используем представителя из viewModel с правильным ID и актуальными данными
                    syncedPredstavitely.append(matchingPredstav)
                    print("   ✅ Синхронизирован представитель: \(matchingPredstav.fio) (ID: \(matchingPredstav.id.uuidString))")
                } else if let matchingPredstav = viewModel.predstavitelyArray.first(where: { predstav in
                    predstav.fio == predstavFromAkt.fio &&
                    predstav.jobTitle == predstavFromAkt.jobTitle &&
                    predstav.organization == predstavFromAkt.organization
                }) {
                    // Fallback: ищем по совпадению fio, jobTitle и organization
                    syncedPredstavitely.append(matchingPredstav)
                    print("   ✅ Синхронизирован представитель (fallback): \(matchingPredstav.fio)")
                } else {
                    // Если не нашли совпадение, используем представителя из акта как есть
                    syncedPredstavitely.append(predstavFromAkt)
                    print("   ⚠️ Представитель не найден в общей базе: \(predstavFromAkt.fio), используем из акта")
                }
            }
            
            predstavitely = syncedPredstavitely
            print("   ✅ Данные перезагружены из системы реального времени:")
            print("      Количество представителей: \(predstavitely.count)")
            print("      Список представителей: \(predstavitely.map { $0.fio })")
        } else if let a = akt {
            print("   ℹ️ Используем данные из переданного акта")
            // Используем логику из checkOld для синхронизации
            var syncedPredstavitely: [PredstavitelyComission] = []
            for predstavFromAkt in a.predstavitelyComission {
                // Ищем соответствующего представителя в viewModel.predstavitelyArray по ID
                if let matchingPredstav = viewModel.predstavitelyArray.first(where: { $0.id == predstavFromAkt.id }) {
                    syncedPredstavitely.append(matchingPredstav)
                } else if let matchingPredstav = viewModel.predstavitelyArray.first(where: { predstav in
                    predstav.fio == predstavFromAkt.fio &&
                    predstav.jobTitle == predstavFromAkt.jobTitle &&
                    predstav.organization == predstavFromAkt.organization
                }) {
                    syncedPredstavitely.append(matchingPredstav)
                } else {
                    syncedPredstavitely.append(predstavFromAkt)
                }
            }
            predstavitely = syncedPredstavitely
        }
        
        // Обновляем UI
        collection.reloadData()
        print("✅ [PREDSTAV] Перезагрузка данных завершена")
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        checkOld()
        setupRealtimeIntegration()
        
        // Настройка темной темы
        setupDarkTheme()
    }
    
    deinit {
        cleanupRealtimeIntegration()
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
        } else {
            view.backgroundColor = .systemBackground
            collection.backgroundColor = .clear
        }
    }
    
    private func checkOld() {
        if let a = akt {
            print("🔄 [PREDSTAV] Загружаем данные из существующего акта №\(a.number)")
            
            // ВАЖНО: Проверяем, является ли это новым актом (созданным только что)
            // Новый акт определяется по пустым данным (организация "Организация не указана" и пустые массивы)
            let isNewAkt = a.organization.title == "Организация не указана" && 
                          a.objectsCheck.isEmpty && 
                          a.violations.isEmpty && 
                          a.description.isEmpty
            
            if isNewAkt {
                print("   🆕 Это новый акт, используем переданные данные (не загружаем из редактируемого акта)")
                // Для нового акта используем переданные данные (которые уже в predstavitely)
                // Не загружаем из редактируемого акта, чтобы избежать старых данных
                print("   ✅ Используем переданные данные:")
                print("      Количество представителей: \(predstavitely.count)")
                print("      Список представителей: \(predstavitely.map { $0.fio })")
                
                // Инициализируем SimpleRealtimeAKTManager только если он еще не активен
                if SimpleRealtimeAKTManager.shared.currentAkt == nil {
                    print("   🔄 Инициализируем SimpleRealtimeAKTManager...")
                    SimpleRealtimeAKTManager.shared.startEditing(a)
                    print("   ✅ SimpleRealtimeAKTManager инициализирован")
                }
                
                collection.reloadData()
                return
            }
            
            // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
            // Если редактируемый акт существует, используем его данные вместо данных из истории
            var aktToUse = a
            if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == a.number {
                print("   ✅ Найден редактируемый акт с номером \(a.number), используем его данные")
                print("      👤 Количество представителей в редактируемом акте: \(editableAkt.akt.predstavitelyComission.count)")
                print("      👤 Количество представителей в акте из истории: \(a.predstavitelyComission.count)")
                aktToUse = editableAkt.akt
                // Обновляем ссылку на акт для последующих операций
                self.akt = aktToUse
            } else {
                print("   ℹ️ Редактируемый акт не найден, используем данные из истории")
                // Инициализируем SimpleRealtimeAKTManager только если он еще не активен
                if SimpleRealtimeAKTManager.shared.currentAkt == nil {
                    print("   🔄 Инициализируем SimpleRealtimeAKTManager...")
                    SimpleRealtimeAKTManager.shared.startEditing(a)
                    print("   ✅ SimpleRealtimeAKTManager инициализирован")
                }
            }
            
            // ВАЖНО: Синхронизируем ID представителей из редактируемого акта с ID из viewModel.predstavitelyArray
            // Это необходимо для корректного отображения выбранных представителей в UI
            var syncedPredstavitely: [PredstavitelyComission] = []
            for predstavFromAkt in aktToUse.predstavitelyComission {
                // Ищем соответствующего представителя в viewModel.predstavitelyArray по совпадению fio, jobTitle и organization
                if let matchingPredstav = viewModel.predstavitelyArray.first(where: { predstav in
                    predstav.fio == predstavFromAkt.fio &&
                    predstav.jobTitle == predstavFromAkt.jobTitle &&
                    predstav.organization == predstavFromAkt.organization
                }) {
                    // Используем представителя из viewModel с правильным ID
                    syncedPredstavitely.append(matchingPredstav)
                    print("   ✅ Синхронизирован представитель: \(predstavFromAkt.fio) (ID обновлен)")
                } else {
                    // Если не нашли совпадение, используем представителя из акта как есть
                    // Это может произойти, если представитель был удален из общей базы
                    syncedPredstavitely.append(predstavFromAkt)
                    print("   ⚠️ Представитель не найден в общей базе: \(predstavFromAkt.fio), используем из акта")
                }
            }
            
            predstavitely = syncedPredstavitely
            print("   ✅ Данные загружены и синхронизированы:")
            print("      Количество представителей: \(predstavitely.count)")
            print("      Список представителей: \(predstavitely.map { $0.fio })")
            
            collection.reloadData()
        } else {
            print("ℹ️ [PREDSTAV] Акт не передан, используем переданные данные")
            print("   ✅ Используем переданные данные:")
            print("      Количество представителей: \(predstavitely.count)")
            print("      Список представителей: \(predstavitely.map { $0.fio })")
        }
    }
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.collection.reloadData()
        }
        
        // НЕ перезаписываем данные, если они уже загружены из системы реального времени
        // Данные будут загружены в checkOld() из системы реального времени
        print("🔄 [PREDSTAV] setupViewModel вызван, но НЕ перезаписываем данные")
        print("   📊 Текущие представители: \(predstavitely.count) шт.")
        print("   📋 Список представителей: \(predstavitely.map { $0.fio })")
    }
    
    private func setupUI() {
        collection.delegate = self
        collection.dataSource = self
        view.addSubview(collection)
        collection.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview().inset(100)
        }
        
        // В режиме редактирования показываем "Сохранить", иначе "Далее"
        let buttonTitle = isEditingMode ? "Сохранить" : "Далее"
        print("🔘 [PREDSTAV] Создание кнопки: '\(buttonTitle)' (isEditingMode: \(isEditingMode), akt: \(akt != nil ? "есть №\(akt!.number)" : "нет"))")
        let nextButton = UIFactory.createButton(title: buttonTitle, color: .systemBlue)
        view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(54)
        }
        if isEditingMode {
            nextButton.addTarget(self, action: #selector(saveAndReturn), for: .touchUpInside)
            print("   ✅ Кнопка настроена на сохранение и возврат")
        } else {
            nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
            print("   ✅ Кнопка настроена на переход к следующему шагу")
        }
    }
    
    @objc private func addNew() {
        let editType = EditType.tripleField(
            title1: "ФИО",
            placeholder1: "Введите ФИО представителя",
            currentValue1: "",
            title2: "Должность",
            placeholder2: "Введите должность представителя",
            currentValue2: "",
            title3: "Организация",
            placeholder3: "Введите организацию представителя",
            currentValue3: ""
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newFio, newJobTitle, newOrganization in
            guard let self = self else { return }
            let jobTitle = newJobTitle ?? ""
            let organization = newOrganization ?? ""
            let newObj = PredstavitelyComission(fio: newFio, jobTitle: jobTitle, organization: organization)
            
            // Добавляем в общую базу представителей
            self.viewModel.predstavitelyArray.append(newObj)
            DataFlowPredstavitely.saveArr(arr: self.viewModel.predstavitelyArray)
            
            // Автоматически выбираем добавленного представителя в текущем акте
            self.predstavitely.append(newObj)
            
            // ДОПОЛНИТЕЛЬНО: Принудительно сохраняем изменения в редактируемый акт
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: self.predstavitely, // Используем актуальный список представителей
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                DataFlowAKT.updateEditableAKT(updatedAkt)
                print("✅ [PREDSTAV] Редактируемый акт обновлен с новым представителем")
            }
            
            self.collection.reloadData()
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
    
    @objc private func saveAndReturn() {
        print("═══════════════════════════════════════════════════════════")
        print("💾 [PREDSTAV] НАЧАЛО СОХРАНЕНИЯ И ВОЗВРАТА")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        print("   👥 Количество представителей: \(predstavitely.count)")
        print("   📋 Список представителей: \(predstavitely.map { $0.fio })")
        
        // Обновляем акт с новыми представителями
        if akt != nil {
            // Обновляем через SimpleRealtimeAKTManager
            print("   🔄 Обновляем акт через SimpleRealtimeAKTManager...")
            SimpleRealtimeAKTManager.shared.updatePredstavitely(predstavitely)
            print("   ✅ Акт обновлен в SimpleRealtimeAKTManager")
            
            // Сохраняем изменения моментально
            print("   💾 Вызываем моментальное сохранение...")
            SimpleRealtimeAKTManager.shared.saveChangesImmediately()
            print("   ✅ Моментальное сохранение выполнено")
            
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
        print("➡️ [PREDSTAV] ПЕРЕХОД К СЛЕДУЮЩЕМУ ШАГУ")
        print("   📋 Режим: \(akt == nil ? "СОЗДАНИЕ НОВОГО АКТА" : "ПРОДОЛЖЕНИЕ ЗАПОЛНЕНИЯ")")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "новый")")
        print("   👥 Количество представителей: \(predstavitely.count)")
        print("   📋 Список представителей: \(predstavitely.map { $0.fio })")
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButton = UIBarButtonItem(title: "Представители", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Представители"
        
        print("   ➡️ Переходим к экрану генерации акта")
        let vc = GenerateAktViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, descripUser: descripUser, predstavitely: predstavitely, akt: akt)
        navigationController?.pushViewController(vc, animated: true)
        print("═══════════════════════════════════════════════════════════")
    }
    

}

extension PredstavViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.predstavitelyArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        // Настройка внешнего вида ячейки в стиле настроек
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 20
        cell.clipsToBounds = true
        
        if indexPath.row == viewModel.predstavitelyArray.count {
            let button = UIFactory.createButton(title: "Добавить", color: .clear)
            button.setTitleColor(.systemBlue, for: .normal)
            cell.addSubview(button)
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            button.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        } else {
            
            let item =  viewModel.predstavitelyArray.reversed()[indexPath.row]
            
            let rightImageView = UIImageView()
            rightImageView.contentMode = .scaleAspectFit
            cell.addSubview(rightImageView)
            rightImageView.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
            }
            
            // Проверяем, выбран ли представитель (приоритет по ID)
            let isSelected = predstavitely.contains(where: { $0.id == item.id })
            
            if isSelected {
                rightImageView.image = UIImage(systemName: "checkmark.circle.fill")
                rightImageView.tintColor = .systemGreen
            } else {
                rightImageView.image = UIImage(systemName: "circlebadge")
                rightImageView.tintColor = .systemGray
            }
            
            let title = UIFactory.createlabel(title: item.fio)
            title.numberOfLines = 1
            title.font = .systemFont(ofSize: 16, weight: .medium)
            // Улучшенный контраст для темной темы
            if traitCollection.userInterfaceStyle == .dark {
                title.textColor = .white
            } else {
                title.textColor = .black
            }
            cell.addSubview(title)
            title.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.top.equalToSuperview().inset(10)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
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
                make.top.equalTo(title.snp.bottom).inset(-4)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
            // Добавляем отображение организации, если она есть
            if !item.organization.isEmpty {
                let organizationLabel = UIFactory.createlabel(title: item.organization)
                organizationLabel.numberOfLines = 1
                // Улучшенный контраст для темной темы
                if traitCollection.userInterfaceStyle == .dark {
                    organizationLabel.textColor = .white.withAlphaComponent(0.5)
                } else {
                    organizationLabel.textColor = .black.withAlphaComponent(0.4)
                }
                organizationLabel.font = .systemFont(ofSize: 10, weight: .regular)
                cell.addSubview(organizationLabel)
                organizationLabel.snp.makeConstraints { make in
                    make.left.equalToSuperview().inset(16)
                    make.bottom.equalToSuperview().inset(10)
                    make.right.equalTo(rightImageView.snp.left).inset(-16)
                }
            }
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("🔍 [PREDSTAV] Нажата ячейка: \(indexPath.row)")
        print("   📊 Общее количество представителей: \(viewModel.predstavitelyArray.count)")
        print("   📊 Текущий размер списка: \(predstavitely.count)")
        
        if indexPath.row != viewModel.predstavitelyArray.count {
            let selectedPredstav = viewModel.predstavitelyArray.reversed()[indexPath.row]
            print("   📋 Выбранный представитель: \(selectedPredstav.fio)")
            
            // ВАЖНО: Используем актуального представителя из viewModel.predstavitelyArray
            // чтобы использовать обновленные данные (включая ФИО)
            let actualPredstav = viewModel.predstavitelyArray.first(where: { $0.id == selectedPredstav.id }) ?? selectedPredstav
            
            if let index = predstavitely.firstIndex(where: {$0.id == actualPredstav.id}) {
                predstavitely.remove(at: index)
                print("🗑️ [PREDSTAV] Удален представитель из списка: \(actualPredstav.fio)")
            } else {
                predstavitely.append(actualPredstav)
                print("➕ [PREDSTAV] Добавлен представитель в список: \(actualPredstav.fio)")
            }
            
            print("   📊 Новый размер списка: \(predstavitely.count)")
            print("   📋 Новый список: \(predstavitely.map { $0.fio })")
            
            // ВАЖНО: Синхронизируем с актуальными данными из viewModel перед сохранением
            let syncedPredstavitely = predstavitely.map { rep in
                // Ищем актуального представителя по ID в viewModel.predstavitelyArray
                if let updatedRep = viewModel.predstavitelyArray.first(where: { $0.id == rep.id }) {
                    return updatedRep // Используем актуальные данные (включая обновленное ФИО)
                }
                return rep // Если не найден, используем оригинальные данные
            }
            
            // СОХРАНЯЕМ ИЗМЕНЕНИЯ В СИСТЕМУ РЕАЛЬНОГО ВРЕМЕНИ
            print("🔄 [PREDSTAV] Сохраняем изменения в систему реального времени...")
            SimpleRealtimeAKTManager.shared.updatePredstavitely(syncedPredstavitely)
            print("✅ [PREDSTAV] Изменения сохранены в систему реального времени")
            
            // ДОПОЛНИТЕЛЬНО: Принудительно сохраняем изменения в редактируемый акт
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: syncedPredstavitely, // Используем синхронизированный список представителей
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                DataFlowAKT.updateEditableAKT(updatedAkt)
                print("✅ [PREDSTAV] Редактируемый акт обновлен с актуальными представителями")
            }
            
            // ВАЖНО: Принудительно сохраняем изменения немедленно, без задержки
            print("💾 [PREDSTAV] Принудительно сохраняем изменения немедленно...")
            SimpleRealtimeAKTManager.shared.saveChangesImmediately()
            print("✅ [PREDSTAV] Изменения сохранены немедленно")
            
            // Обновляем локальный массив синхронизированными данными
            predstavitely = syncedPredstavitely
            
            collectionView.reloadData()
        } else {
            print("🔍 [PREDSTAV] Нажата кнопка 'Добавить'")
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 70)
    }
}

// MARK: - Realtime Integration
extension PredstavViewController {
    
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
    
    // MARK: - SimpleRealtimeAKTObserver Methods
    
    func aktDidChange(_ change: String) {
        print("📝 [REALTIME] Получено изменение в \(type(of: self)): \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [REALTIME] Акт сохранен в \(type(of: self))")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
}
