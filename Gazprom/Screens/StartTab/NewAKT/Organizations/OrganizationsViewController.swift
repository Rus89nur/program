//
//  OrganizationsViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import Combine

class OrganizationsViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    let viewModel: MainAKTViewModel
    var akt: AKT?
    var isEditingMode: Bool = false
    
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    private var organizations: [Organization] = []
    private var cancellables = Set<AnyCancellable>()
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, act: AKT?, isEditingMode: Bool = false) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.akt = act
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
    
    private func checkOld() {
        if let a = akt {
            print("🔄 [ORGANIZATIONS] Загружаем данные из существующего акта №\(a.number)")
            
            // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
            // Если редактируемый акт существует, используем его данные вместо данных из истории
            var aktToUse = a
            if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == a.number {
                print("   ✅ Найден редактируемый акт с номером \(a.number), используем его данные")
                print("      🏢 Организация в редактируемом акте: \(editableAkt.akt.organization.title)")
                print("      🏢 Организация в акте из истории: \(a.organization.title)")
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
            
            // Ищем актуальную версию организации в массиве организаций
            let currentOrganization: Organization
            print("   🔍 Организация в акте: \(aktToUse.organization.title)")
            print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
            
            if let updatedOrg = viewModel.organizationsArray.first(where: { $0.title == aktToUse.organization.title }) {
                currentOrganization = updatedOrg
                print("   🔄 Найдена актуальная версия организации: \(updatedOrg.title)")
            } else {
                currentOrganization = aktToUse.organization
                print("   ⚠️ Актуальная версия организации не найдена, используем из акта: \(aktToUse.organization.title)")
            }
            
            organizations = [currentOrganization]
            print("   ✅ Данные загружены:")
            print("      Организация: \(organizations.first?.title ?? "нет")")
            collection.reloadData()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Организации"
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        if let navController = navigationController {
            let viewControllers = navController.viewControllers
            // Ищем DateAndNumberAktViewController в стеке
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let dateVC = viewControllers[i] as? DateAndNumberAktViewController {
                    let backButton = UIBarButtonItem(title: "Основные данные", style: .plain, target: nil, action: nil)
                    dateVC.navigationItem.backBarButtonItem = backButton
                    dateVC.navigationItem.backButtonTitle = "Основные данные"
                    break
                }
            }
            // Также устанавливаем в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Основные данные", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Основные данные"
            }
        }
        
        setupViewModel()
        setupNav()
        
        print("🔄 [ORGANIZATIONS] Экран организаций открыт")
        print("   📊 Текущие организации: \(organizations.count) шт.")
        print("   📋 Список организаций: \(organizations.map { $0.title })")
        print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("🔄 [ORGANIZATIONS] Экран организаций закрывается")
        print("   📊 Финальные организации: \(organizations.count) шт.")
        print("   📋 Список организаций: \(organizations.map { $0.title })")
        print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
        
        // ВАЖНО: НЕ завершаем редактирование при переходе к следующему экрану,
        // так как мы все еще редактируем акт. finishEditing() удалит редактируемый акт,
        // что приведет к потере изменений при следующем открытии акта из истории.
        print("   ℹ️ Редактирование продолжается, редактируемый акт сохранен для дальнейшей работы")
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
        setupRealtimeIntegration()
        
        print("🔄 [VIEW_DID_LOAD] Загружен экран организаций")
        print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
        
        checkOld()
        
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
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.collection.reloadData()
        }
        
        if let a =  viewModel.templateModel.organizations {
            print("🔄 [SETUP_VIEWMODEL] Загружаем организации из templateModel")
            print("   📋 Организации в templateModel: \(a.map { $0.title })")
            self.organizations = a
            collection.reloadData()
        } else {
            print("🔄 [SETUP_VIEWMODEL] Нет организаций в templateModel")
        }
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
        print("🔘 [ORGANIZATIONS] Создание кнопки: '\(buttonTitle)' (isEditingMode: \(isEditingMode), akt: \(akt != nil ? "есть №\(akt!.number)" : "нет"))")
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
    
    @objc private func addNewOrganization() {
        let vc = NewOrganizationViewController(viewModel: viewModel)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.custom(resolver: { _ in 710 })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        self.present(vc, animated: true)
    }
    
    @objc private func saveAndReturn() {
        print("═══════════════════════════════════════════════════════════")
        print("💾 [ORGANIZATIONS] НАЧАЛО СОХРАНЕНИЯ И ВОЗВРАТА")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        print("   🏢 Выбранные организации: \(organizations.map { $0.title })")
        
        // Обновляем акт с новой организацией
        if akt != nil {
            print("   🔄 Обновляем акт с новой организацией...")
            updateAktWithNewOrganization()
            print("   ✅ Акт обновлен")
            
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
        print("➡️ [ORGANIZATIONS] ПЕРЕХОД К СЛЕДУЮЩЕМУ ШАГУ")
        print("   📋 Режим: \(akt == nil ? "СОЗДАНИЕ НОВОГО АКТА" : "ПРОДОЛЖЕНИЕ ЗАПОЛНЕНИЯ")")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "новый")")
        print("   📊 Текущие организации: \(organizations.count) шт.")
        print("   📋 Список организаций: \(organizations.map { $0.title })")
        
        // Обновляем templateModel
        print("   🔄 Обновляем templateModel...")
        viewModel.templateModel.organizations = organizations
        print("   ✅ templateModel обновлен")
        
        // Акт уже обновлен автоматически при выборе организации, поэтому здесь ничего не делаем
        if akt != nil {
            print("   ℹ️ Акт уже обновлен автоматически при выборе организации")
        }
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButton = UIBarButtonItem(title: "Организации", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Организации"
        
        print("   ➡️ Переходим к экрану объектов проверки (isEditingMode: \(isEditingMode))")
        let vc = ObjectReviewViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, akt: akt, isEditingMode: isEditingMode)
        navigationController?.pushViewController(vc, animated: true)
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func updateAktWithNewOrganization() {
        print("═══════════════════════════════════════════════════════════")
        print("🔄 [ORGANIZATIONS] ОБНОВЛЕНИЕ АКТА С НОВОЙ ОРГАНИЗАЦИЕЙ")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        
        guard let existingAkt = akt else {
            print("   ❌ Существующий акт не найден")
            print("═══════════════════════════════════════════════════════════")
            return
        }
        
        // Находим актуальную организацию из обновленного массива организаций
        let currentOrganization: Organization
        if let selectedOrg = organizations.first {
            print("   🔍 Выбранная организация: \(selectedOrg.title)")
            print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
            
            // Если есть выбранная организация, ищем её актуальную версию в массиве
            if let updatedOrg = viewModel.organizationsArray.first(where: { $0.title == selectedOrg.title }) {
                currentOrganization = updatedOrg
                print("   🔄 Найдена актуальная версия организации: \(updatedOrg.title)")
            } else {
                currentOrganization = selectedOrg
                print("   ⚠️ Актуальная версия организации не найдена, используем выбранную: \(selectedOrg.title)")
            }
        } else {
            // Если нет выбранной организации, используем организацию из акта
            currentOrganization = existingAkt.organization
            print("   ⚠️ Нет выбранной организации, используем организацию из акта: \(existingAkt.organization.title)")
        }
        
        // Создаем обновленный акт с актуальной организацией
        let updatedAkt = AKT(
            id: existingAkt.id, // Сохраняем оригинальный ID
            number: existingAkt.number,
            date: existingAkt.date,
            comission: existingAkt.comission,
            organization: currentOrganization, // Используем актуальную организацию
            objectsCheck: existingAkt.objectsCheck, // Сохраняем существующие объекты
            predstavitelyComission: existingAkt.predstavitelyComission, // Сохраняем существующих представителей
            violations: existingAkt.violations, // Сохраняем существующие нарушения
            description: existingAkt.description, // Сохраняем существующее описание
            actustranenDate: existingAkt.actustranenDate, // Сохраняем существующие даты
            actPredostavlenDate: existingAkt.actPredostavlenDate,
            actUtverzdenDate: existingAkt.actUtverzdenDate,
            urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""), // Сохраняем существующий URL
            realDateCreate: existingAkt.realDateCreate // Сохраняем оригинальную дату создания
        )
        
        print("   📋 Номер акта: \(updatedAkt.number)")
        print("   🏢 Организация: \(updatedAkt.organization.title)")
        print("   🆔 ID акта: \(updatedAkt.id)")
        
        // Обновляем акт в истории
        print("   💾 Сохраняем акт в историю...")
        viewModel.updateAktInArray(updatedAkt)
        print("   ✅ Акт №\(updatedAkt.number) обновлен в истории с новой организацией")
        
        // Обновляем редактируемый акт
        print("   💾 Обновляем редактируемый акт...")
        viewModel.updateEditableAKT(updatedAkt)
        print("   ✅ Редактируемый акт обновлен с новой организацией")
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = updatedAkt
        print("   🔗 Ссылка на акт обновлена")
        
        print("✅ [ORGANIZATIONS] ОБНОВЛЕНИЕ АКТА ЗАВЕРШЕНО")
        print("═══════════════════════════════════════════════════════════")
    }

}

extension OrganizationsViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.organizationsArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        // Настройка внешнего вида ячейки в стиле настроек
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 20
        cell.clipsToBounds = true
        
        if indexPath.row == viewModel.organizationsArray.count {
            let button = UIFactory.createButton(title: "Добавить", color: .clear)
            button.setTitleColor(.systemBlue, for: .normal)
            cell.addSubview(button)
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            button.addTarget(self, action: #selector(addNewOrganization), for: .touchUpInside)
        } else {
            
            let item =  viewModel.organizationsArray.reversed()[indexPath.row]
            
            let rightImageView = UIImageView()
            rightImageView.contentMode = .scaleAspectFit
            cell.addSubview(rightImageView)
            rightImageView.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
            }
            
            if organizations.contains(where: {$0.title == item.title}) {
                rightImageView.image = UIImage(systemName: "checkmark.circle.fill")
                rightImageView.tintColor = .systemGreen
            } else {
                rightImageView.image = UIImage(systemName: "circlebadge")
                rightImageView.tintColor = .systemGray
            }
            
            let title = UIFactory.createlabel(title: item.title)
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
                make.centerY.equalToSuperview()
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row != viewModel.organizationsArray.count {
            let selectedOrganization = viewModel.organizationsArray.reversed()[indexPath.row]
            organizations = [selectedOrganization]
            viewModel.templateModel.organizations = [selectedOrganization]
            
            print("🔄 [ORGANIZATIONS] Выбрана организация: \(selectedOrganization.title)")
            print("   📊 Текущие организации: \(organizations.count) шт.")
            print("   📋 Список организаций: \(organizations.map { $0.title })")
            print("   📋 Доступные организации в массиве: \(viewModel.organizationsArray.map { $0.title })")
            
            // Сохраняем изменения в реальном времени
            print("   🔄 Сохраняем выбранную организацию в реальном времени...")
            SimpleRealtimeAKTManager.shared.updateOrganization(selectedOrganization)
            print("   ✅ Организация сохранена в реальном времени")
            
            // Автоматически обновляем акт с новой организацией
            if akt != nil {
                print("   🔄 Автоматически обновляем акт с новой организацией...")
                updateAktWithNewOrganization()
                print("   ✅ Акт автоматически обновлен с новой организацией")
            }
            
            collectionView.reloadData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 54)
    }
    
    // MARK: - Context Menu for Editing Organizations
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // Показываем контекстное меню только для существующих организаций (не для кнопки "Добавить")
        guard indexPath.row < viewModel.organizationsArray.count else { return nil }
        
        let organization = viewModel.organizationsArray.reversed()[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let editAction = UIAction(title: "Редактировать", image: UIImage(systemName: "pencil")) { _ in
                self.showEditOrganizationAlert(for: indexPath, organization: organization)
            }
            
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.showDeleteOrganizationAlert(for: indexPath, organization: organization)
            }
            
            return UIMenu(title: organization.title, children: [editAction, deleteAction])
        }
    }
    
    private func showEditOrganizationAlert(for indexPath: IndexPath, organization: Organization) {
        print("🔄 [ORGANIZATIONS] Начало редактирования организации")
        print("   📊 Индекс: \(indexPath.row)")
        print("   🏢 Старое название: \(organization.title)")
        
        let editType = EditType.singleField(
            title: "Редактировать организацию",
            placeholder: "Введите название организации",
            currentValue: organization.title
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, _, _ in
            guard let self = self else { return }
            
            print("   🏢 Новое название: \(newTitle)")
            
            // Проверяем, что название не пустое
            if newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let errorAlert = UIAlertController(title: "Ошибка!", message: "Название организации не может быть пустым", preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .cancel)
                errorAlert.addAction(ok)
                self.present(errorAlert, animated: true)
                return
            }
            
            // Обновляем организацию через viewModel
            let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.viewModel.updateOrganization(at: indexPath.row, newTitle: trimmedTitle) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ [ORGANIZATIONS] Организация успешно обновлена")
                        self.collection.reloadData()
                        self.dismiss(animated: true)
                    } else {
                        print("❌ [ORGANIZATIONS] Ошибка обновления организации")
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Организация с таким названием уже существует", preferredStyle: .alert)
                        let ok = UIAlertAction(title: "OK", style: .cancel)
                        errorAlert.addAction(ok)
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.medium()]
            sheet.preferredCornerRadius = 20
        }
        self.present(navController, animated: true)
    }
    
    private func showDeleteOrganizationAlert(for indexPath: IndexPath, organization: Organization) {
        let alert = UIAlertController(title: "Удалить организацию", message: "Вы уверены, что хотите удалить организацию '\(organization.title)'?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            print("🗑️ [ORGANIZATIONS] Удаление организации: \(organization.title)")
            
            // Удаляем организацию из массива
            self.viewModel.organizationsArray.remove(at: indexPath.row)
            DataFlowOrganizations.saveArr(arr: self.viewModel.organizationsArray)
            
            // Обновляем UI
            self.collection.reloadData()
            
            print("✅ [ORGANIZATIONS] Организация удалена")
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}

// MARK: - SimpleRealtimeAKTObserver Methods
extension OrganizationsViewController {
    
    func aktDidChange(_ change: String) {
        print("📝 [ORGANIZATIONS] Получено изменение: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [ORGANIZATIONS] Акт сохранен")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
    
    // MARK: - Realtime Integration Methods
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        
        print("🔗 [ORGANIZATIONS] Интеграция с системой реального времени настроена")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        
        print("🔗 [ORGANIZATIONS] Интеграция с системой реального времени очищена")
    }
}
