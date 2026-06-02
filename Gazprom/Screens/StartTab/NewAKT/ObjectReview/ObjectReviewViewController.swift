//
//  ObjectReviewViewController.swift
//  Gazprom
//
//  Created by Владимир on 07.07.2025.
//

import UIKit
import Combine

class ObjectReviewViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    private var objectCheck: [ObjectCheck] = []
    private var cancellables = Set<AnyCancellable>()
    
    var akt: AKT?
    var isEditingMode: Bool = false
    
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
    
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], akt: AKT?, isEditingMode: Bool = false) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.akt = akt
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func checkOld() {
        if let a = akt {
            print("🔄 [OBJECTS] Загружаем данные из существующего акта №\(a.number)")
            
            // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
            // Если редактируемый акт существует, используем его данные вместо данных из истории
            var aktToUse = a
            if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == a.number {
                print("   ✅ Найден редактируемый акт с номером \(a.number), используем его данные")
                print("      🏗️ Количество объектов в редактируемом акте: \(editableAkt.akt.objectsCheck.count)")
                print("      🏗️ Количество объектов в акте из истории: \(a.objectsCheck.count)")
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
            
            objectCheck = aktToUse.objectsCheck
            print("   ✅ Данные загружены:")
            print("      Количество объектов: \(objectCheck.count)")
            print("      Список объектов: \(objectCheck.map { $0.title })")
            collection.reloadData()
        }
    }
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Обьект проверки"
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        if let navController = navigationController {
            let viewControllers = navController.viewControllers
            // Ищем OrganizationsViewController в стеке
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let orgVC = viewControllers[i] as? OrganizationsViewController {
                    let backButton = UIBarButtonItem(title: "Организации", style: .plain, target: nil, action: nil)
                    orgVC.navigationItem.backBarButtonItem = backButton
                    orgVC.navigationItem.backButtonTitle = "Организации"
                    break
                }
            }
            // Также устанавливаем в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Организации", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Организации"
            }
        }
        
        setupViewModel()
        setupNav()
        
        print("🔄 [OBJECTS] Экран объектов проверки открыт")
        print("   📊 Текущие объекты: \(objectCheck.count) шт.")
        print("   📋 Список объектов: \(objectCheck.map { $0.title })")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        print("🔄 [OBJECTS] Экран объектов проверки закрывается")
        print("   📊 Финальные объекты: \(objectCheck.count) шт.")
        print("   📋 Список объектов: \(objectCheck.map { $0.title })")
        
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
        
        if let a = viewModel.templateModel.objectCheck {
            self.objectCheck = a
            collection.reloadData()
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
        print("🔘 [OBJECTS] Создание кнопки: '\(buttonTitle)' (isEditingMode: \(isEditingMode), akt: \(akt != nil ? "есть №\(akt!.number)" : "нет"))")
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
            self.viewModel.objectCheckArray.append(newObj)
            DataFlowObjectsReview.saveArr(arr: self.viewModel.objectCheckArray)
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
    
    @objc private func saveAndReturn() {
        print("═══════════════════════════════════════════════════════════")
        print("💾 [OBJECTS] НАЧАЛО СОХРАНЕНИЯ И ВОЗВРАТА")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        print("   🏗️ Выбранные объекты: \(objectCheck.map { $0.title })")
        
        // Обновляем акт с новыми объектами
        if akt != nil {
            print("   🔄 Обновляем акт с новыми объектами...")
            updateAktWithNewObjects()
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
        print("➡️ [OBJECTS] ПЕРЕХОД К СЛЕДУЮЩЕМУ ШАГУ")
        print("   📋 Режим: \(akt == nil ? "СОЗДАНИЕ НОВОГО АКТА" : "ПРОДОЛЖЕНИЕ ЗАПОЛНЕНИЯ")")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "новый")")
        print("   📊 Текущие объекты: \(objectCheck.count) шт.")
        print("   📋 Список объектов: \(objectCheck.map { $0.title })")
        
        // Обновляем templateModel
        print("   🔄 Обновляем templateModel...")
        viewModel.templateModel.objectCheck = objectCheck
        print("   ✅ templateModel обновлен")
        
        // Акт уже обновлен автоматически при выборе объекта, поэтому здесь ничего не делаем
        if akt != nil {
            print("   ℹ️ Акт уже обновлен автоматически при выборе объекта")
        }
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButton = UIBarButtonItem(title: "Объекты проверки", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Объекты проверки"
        
        print("   ➡️ Переходим к экрану нарушений (isEditingMode: \(isEditingMode))")
        let vc = NewViolationViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: [], akt: akt, isEditingMode: isEditingMode)
        navigationController?.pushViewController(vc, animated: true)
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func updateAktWithNewObjects() {
        print("═══════════════════════════════════════════════════════════")
        print("🔄 [OBJECTS] ОБНОВЛЕНИЕ АКТА С НОВЫМИ ОБЪЕКТАМИ")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        
        guard let existingAkt = akt else {
            print("   ❌ Существующий акт не найден")
            print("═══════════════════════════════════════════════════════════")
            return
        }
        
        // Создаем обновленный акт с новыми объектами
        let updatedAkt = AKT(
            id: existingAkt.id, // Сохраняем оригинальный ID
            number: existingAkt.number,
            date: existingAkt.date,
            comission: existingAkt.comission,
            organization: existingAkt.organization, // Сохраняем существующую организацию
            objectsCheck: objectCheck, // Обновляем объекты проверки
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
        print("   🏗️ Объекты проверки: \(updatedAkt.objectsCheck.map { $0.title })")
        print("   🆔 ID акта: \(updatedAkt.id)")
        
        // Обновляем акт в истории
        print("   💾 Сохраняем акт в историю...")
        viewModel.updateAktInArray(updatedAkt)
        print("   ✅ Акт №\(updatedAkt.number) обновлен в истории с новыми объектами")
        
        // Обновляем редактируемый акт
        print("   💾 Обновляем редактируемый акт...")
        viewModel.updateEditableAKT(updatedAkt)
        print("   ✅ Редактируемый акт обновлен с новыми объектами")
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = updatedAkt
        print("   🔗 Ссылка на акт обновлена")
        
        print("✅ [OBJECTS] ОБНОВЛЕНИЕ АКТА ЗАВЕРШЕНО")
        print("═══════════════════════════════════════════════════════════")
    }
    
}


extension ObjectReviewViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.objectCheckArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        // Настройка внешнего вида ячейки в стиле настроек
        cell.backgroundColor = .systemGray6
        cell.layer.cornerRadius = 20
        cell.clipsToBounds = true
        
        if indexPath.row == viewModel.objectCheckArray.count {
            let button = UIFactory.createButton(title: "Добавить", color: .clear)
            button.setTitleColor(.systemBlue, for: .normal)
            cell.addSubview(button)
            button.snp.makeConstraints { make in
                make.centerX.equalToSuperview()
                make.centerY.equalToSuperview()
                make.height.equalToSuperview()
                make.left.greaterThanOrEqualToSuperview().offset(4)
                make.right.lessThanOrEqualToSuperview().offset(-4)
            }
            button.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        } else {
            let item =  viewModel.objectCheckArray.reversed()[indexPath.row]
            
            let rightImageView = UIImageView()
            rightImageView.contentMode = .scaleAspectFit
            cell.addSubview(rightImageView)
            rightImageView.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
            }
            
            if objectCheck.contains(where: {$0.title == item.title}) {
                rightImageView.image = UIImage(systemName: "checkmark.circle.fill")
                rightImageView.tintColor = .systemGreen
            } else {
                rightImageView.image = UIImage(systemName: "circlebadge")
                rightImageView.tintColor = .systemGray
            }
            
            let title = UIFactory.createlabel(title: item.title)
            title.numberOfLines = 3
            title.adjustsFontSizeToFitWidth = false
            title.lineBreakMode = .byWordWrapping
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
            
            let sublabel = UIFactory.createlabel(title: item.subTitle)
            sublabel.numberOfLines = 1
            sublabel.adjustsFontSizeToFitWidth = false
            sublabel.lineBreakMode = .byTruncatingTail
            // Улучшенный контраст для темной темы
            if traitCollection.userInterfaceStyle == .dark {
                sublabel.textColor = .white.withAlphaComponent(0.7)
            } else {
                sublabel.textColor = .black.withAlphaComponent(0.6)
            }
            sublabel.font = .italicSystemFont(ofSize: 12)
            cell.addSubview(sublabel)
            sublabel.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().inset(10)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row != viewModel.objectCheckArray.count {
            let selectedObject = viewModel.objectCheckArray.reversed()[indexPath.row]
            objectCheck = [selectedObject]
            viewModel.templateModel.objectCheck = [selectedObject]
            
            print("🔄 [OBJECTS] Выбран объект проверки: \(selectedObject.title)")
            print("   📊 Текущие объекты: \(objectCheck.count) шт.")
            print("   📋 Список объектов: \(objectCheck.map { $0.title })")
            
            // Сохраняем изменения в реальном времени
            print("   🔄 Сохраняем выбранный объект в реальном времени...")
            SimpleRealtimeAKTManager.shared.updateObjectsCheck(objectCheck)
            print("   ✅ Объект проверки сохранен в реальном времени")
            
            // Автоматически обновляем акт с новыми объектами
            if akt != nil {
                print("   🔄 Автоматически обновляем акт с новыми объектами...")
                updateAktWithNewObjects()
                print("   ✅ Акт автоматически обновлен с новыми объектами")
            }
            
            collectionView.reloadData()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 90)
    }
    
    // MARK: - Context Menu for Editing Objects
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        // Показываем контекстное меню только для существующих объектов (не для кнопки "Добавить")
        guard indexPath.row < viewModel.objectCheckArray.count else { return nil }
        
        let object = viewModel.objectCheckArray.reversed()[indexPath.row]
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let editAction = UIAction(title: "Редактировать", image: UIImage(systemName: "pencil")) { _ in
                self.showEditObjectAlert(for: indexPath, object: object)
            }
            
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.showDeleteObjectAlert(for: indexPath, object: object)
            }
            
            return UIMenu(title: object.title, children: [editAction, deleteAction])
        }
    }
    
    private func showEditObjectAlert(for indexPath: IndexPath, object: ObjectCheck) {
        print("🔄 [OBJECTS] Начало редактирования объекта")
        print("   📊 Индекс: \(indexPath.row)")
        print("   🏗️ Старое название: \(object.title)")
        
        let editType = EditType.doubleField(
            title1: "Название объекта",
            placeholder1: "Введите название объекта",
            currentValue1: object.title,
            title2: "Описание",
            placeholder2: "Введите описание объекта",
            currentValue2: object.subTitle
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, newSubTitle, _ in
            guard let self = self else { return }
            
            print("   🏗️ Новое название: \(newTitle)")
            print("   📝 Новое описание: \(newSubTitle ?? "")")
            
            // Проверяем, что название не пустое
            if newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let errorAlert = UIAlertController(title: "Ошибка!", message: "Название объекта не может быть пустым", preferredStyle: .alert)
                let ok = UIAlertAction(title: "Хорошо", style: .cancel)
                errorAlert.addAction(ok)
                self.present(errorAlert, animated: true)
                return
            }
            
            // Обновляем объект через viewModel
            let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedSubTitle = newSubTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            self.viewModel.updateObjectCheck(at: indexPath.row, newTitle: trimmedTitle, newSubtitle: trimmedSubTitle) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ [OBJECTS] Объект успешно обновлен")
                        self.collection.reloadData()
                        self.dismiss(animated: true)
                    } else {
                        print("❌ [OBJECTS] Ошибка обновления объекта")
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Объект с таким названием уже существует", preferredStyle: .alert)
                        let ok = UIAlertAction(title: "Хорошо", style: .cancel)
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
    
    private func showDeleteObjectAlert(for indexPath: IndexPath, object: ObjectCheck) {
        let alert = UIAlertController(title: "Удалить объект", message: "Вы уверены, что хотите удалить объект '\(object.title)'?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            
            print("🗑️ [OBJECTS] Удаление объекта: \(object.title)")
            
            // Удаляем объект из массива
            self.viewModel.objectCheckArray.remove(at: indexPath.row)
            DataFlowObjectsReview.saveArr(arr: self.viewModel.objectCheckArray)
            
            // Обновляем UI
            self.collection.reloadData()
            
            print("✅ [OBJECTS] Объект удален")
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}

// MARK: - SimpleRealtimeAKTObserver Methods
extension ObjectReviewViewController {
    
    func aktDidChange(_ change: String) {
        print("📝 [OBJECTS] Получено изменение: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [OBJECTS] Акт сохранен")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            self.collection.reloadData()
        }
    }
    
    // MARK: - Realtime Integration Methods
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        
        print("🔗 [OBJECTS] Интеграция с системой реального времени настроена")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        
        print("🔗 [OBJECTS] Интеграция с системой реального времени очищена")
    }
}
