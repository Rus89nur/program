//
//  UserDescriptionViewController.swift
//  Gazprom
//
//  Created by Владимир on 14.07.2025.
//

import UIKit
import Combine

class UserDescriptionViewController: UIViewController, SimpleRealtimeAKTObserver, UITextViewDelegate {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    
    var descripUser: String = ""
    private var cancellables = Set<AnyCancellable>()
    
    var akt: AKT?
    var isEditingMode: Bool = false
    
    // Таймер для задержки обновления акта при изменении текста
    private var updateTimer: Timer?
    
    private let oneBut  = UIFactory.createButton(title: "Шаблон 1", color: .systemBlue)
    private let twoBut  = UIFactory.createButton(title: "Шаблон 2", color: .systemBlue)
    private let threeBut  = UIFactory.createButton(title: "Шаблон 3", color: .systemBlue)
    
    let mainTextView: UITextView = {
        let view = UITextView()
        view.backgroundColor = .systemGray6
        view.font = .systemFont(ofSize: 16, weight: .regular)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray.cgColor
        view.textContainerInset = .init(top: 16, left: 16, bottom: 16, right: 16)
        view.textColor = .label
        view.tintColor = .white
        return view
    }()
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], akt: AKT?, isEditingMode: Bool = false) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.akt  = akt
        self.isEditingMode = isEditingMode
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.templateModel.descripUser = mainTextView.text
        
        print("🔄 [DESCRIPTION] Экран выводов закрывается")
        print("   📝 Текущие выводы: \(mainTextView.text.prefix(50))...")
        
        // Проверяем, что это не переход к следующему экрану (кнопка "Далее")
        if let navigationController = navigationController,
           let topViewController = navigationController.topViewController,
           topViewController != self {
            print("   🔄 Переход к следующему экрану, сохраняем изменения...")
            
            // Отменяем таймер, если он активен
            updateTimer?.invalidate()
            
            // Принудительно обновляем акт с текущими выводами
            if akt != nil {
                print("   🔄 Принудительно обновляем акт с текущими выводами...")
                updateAktWithNewDescription()
                print("   ✅ Акт принудительно обновлен с выводами")
            }
            
            // ВАЖНО: НЕ завершаем редактирование при переходе к следующему экрану,
            // так как мы все еще редактируем акт. finishEditing() удалит редактируемый акт,
            // что приведет к потере изменений при следующем открытии акта из истории.
            print("   ℹ️ Редактирование продолжается, редактируемый акт сохранен для дальнейшей работы")
        } else {
            print("   ℹ️ Возврат назад или закрытие экрана")
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Выводы"
        
        // Устанавливаем кнопку "назад" с названием предыдущего раздела
        if let navController = navigationController {
            let viewControllers = navController.viewControllers
            // Ищем NewViolationViewController в стеке
            for i in (0..<viewControllers.count).reversed() {
                if i < viewControllers.count - 1, let violationsVC = viewControllers[i] as? NewViolationViewController {
                    let backButton = UIBarButtonItem(title: "Нарушения", style: .plain, target: nil, action: nil)
                    violationsVC.navigationItem.backBarButtonItem = backButton
                    violationsVC.navigationItem.backButtonTitle = "Нарушения"
                    break
                }
            }
            // Также устанавливаем в предыдущем контроллере
            if let prevVC = viewControllers.dropLast().last {
                let backButton = UIBarButtonItem(title: "Нарушения", style: .plain, target: nil, action: nil)
                prevVC.navigationItem.backBarButtonItem = backButton
                prevVC.navigationItem.backButtonTitle = "Нарушения"
            }
        }
        
        print("🔄 [DESCRIPTION] Экран выводов открыт")
        
        // ВАЖНО: Загружаем данные из templateModel только если мы НЕ редактируем существующий акт
        // Если редактируем существующий акт, данные уже загружены в checkOld() из редактируемого акта
        if akt == nil, let a = viewModel.templateModel.descripUser {
            print("   📋 Загружаем данные из templateModel (новый акт)")
            self.descripUser = a
            self.mainTextView.text = a
        } else if akt != nil {
            print("   ℹ️ Редактируем существующий акт, данные уже загружены в checkOld()")
        }
        
        print("   📝 Текущие выводы: \(mainTextView.text.prefix(50))...")
        setupNav()
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
        print("🏠 [DESCRIPTION] Нажата кнопка 'Домой', сохраняем изменения...")
        
        // Отменяем таймер, если он активен
        updateTimer?.invalidate()
        
        // Принудительно обновляем акт с текущими выводами
        if akt != nil {
            print("   🔄 Принудительно обновляем акт с текущими выводами...")
            updateAktWithNewDescription()
            print("   ✅ Акт принудительно обновлен с выводами")
        }
        
        // Завершаем редактирование в SimpleRealtimeAKTManager
        print("   🔄 Завершаем редактирование в SimpleRealtimeAKTManager...")
        SimpleRealtimeAKTManager.shared.finishEditing()
        print("   ✅ Редактирование завершено")
        
        // Переходим на главный экран
        navigationController?.popToRootViewController(animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        ConclusionsTemplateKeys.registerDefaultsIfNeeded()
        stupUI()
        setupRealtimeIntegration()
        checkOld()
        
        // Настраиваем функциональность клавиатуры
        setupKeyboardHandling()
    }
    
    deinit {
        updateTimer?.invalidate()
        cleanupRealtimeIntegration()
    }
    
    private func checkOld() {
        if let a = akt {
            print("🔄 [DESCRIPTION] Загружаем данные из существующего акта №\(a.number)")
            
            // ВАЖНО: Сначала проверяем наличие редактируемого акта с тем же номером
            // Если редактируемый акт существует, используем его данные вместо данных из истории
            var aktToUse = a
            if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == a.number {
                print("   ✅ Найден редактируемый акт с номером \(a.number), используем его данные")
                print("      📝 Длина выводов в редактируемом акте: \(editableAkt.akt.description.count) символов")
                print("      📝 Длина выводов в акте из истории: \(a.description.count) символов")
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
            
            descripUser = aktToUse.description
            mainTextView.text = descripUser
            print("   ✅ Данные загружены:")
            print("      Выводы: \(descripUser.prefix(50))...")
        }
    }
    
    private func stupUI() {
        view.addSubview(mainTextView)
        mainTextView.delegate = self
        mainTextView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.height.equalTo(320)
        }
        
        // Обработчик тапа для сворачивания клавиатуры теперь настраивается в setupKeyboardHandling()
        
        // В режиме редактирования показываем "Сохранить", иначе "Далее"
        let buttonTitle = isEditingMode ? "Сохранить" : "Далее"
        print("🔘 [DESCRIPTION] Создание кнопки: '\(buttonTitle)' (isEditingMode: \(isEditingMode), akt: \(akt != nil ? "есть №\(akt!.number)" : "нет"))")
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
            nextButton.addTarget(self, action: #selector(nextVC), for: .touchUpInside)
            print("   ✅ Кнопка настроена на переход к следующему шагу")
        }
        
        oneBut.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        oneBut.tag = 0
        oneBut.addTarget(self, action: #selector(oneTap), for: .touchUpInside)
        twoBut.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        twoBut.tag = 1
        twoBut.addTarget(self, action: #selector(twoTap), for: .touchUpInside)
        threeBut.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        threeBut.tag = 2
        threeBut.addTarget(self, action: #selector(threeTap), for: .touchUpInside)

        
        
        
        let stackView = UIStackView(arrangedSubviews: [oneBut, twoBut, threeBut])
        stackView.axis = .horizontal
        stackView.distribution = .fillProportionally
        stackView.spacing = 8
        view.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(nextButton.snp.top).inset(-16)
        }
        
        let buttonEdit = UIButton(type: .system)
        buttonEdit.setTitle("Редактировать", for: .normal)
        buttonEdit.setTitleColor(.systemGray, for: .normal)
        view.addSubview(buttonEdit)
        buttonEdit.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.bottom.equalTo(stackView.snp.top).inset(-8)
        }
        buttonEdit.addTarget(self, action: #selector(editBut), for: .touchUpInside)
    }
    
    @objc private func saveAndReturn() {
        print("═══════════════════════════════════════════════════════════")
        print("💾 [DESCRIPTION] НАЧАЛО СОХРАНЕНИЯ И ВОЗВРАТА")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ СУЩЕСТВУЮЩЕГО АКТА")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        print("   📝 Длина выводов: \(mainTextView.text.count) символов")
        
        // Отменяем таймер, если он активен
        updateTimer?.invalidate()
        print("   ⏱️ Таймер обновления отменен")
        
        // Обновляем акт с новыми выводами
        if akt != nil {
            print("   🔄 Обновляем акт с новыми выводами...")
            updateAktWithNewDescription()
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
    
    @objc private func nextVC() {
        print("═══════════════════════════════════════════════════════════")
        print("➡️ [DESCRIPTION] ПЕРЕХОД К СЛЕДУЮЩЕМУ ШАГУ")
        print("   📋 Режим: \(akt == nil ? "СОЗДАНИЕ НОВОГО АКТА" : "ПРОДОЛЖЕНИЕ ЗАПОЛНЕНИЯ")")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "новый")")
        print("   📝 Длина выводов: \(mainTextView.text.count) символов")
        print("   📝 Превью выводов: \(mainTextView.text.prefix(50))...")
        
        // Обновляем templateModel
        print("   🔄 Обновляем templateModel...")
        viewModel.templateModel.descripUser = mainTextView.text
        print("   ✅ templateModel обновлен")
        
        // Акт уже обновлен автоматически при изменении выводов, поэтому здесь ничего не делаем
        if akt != nil {
            print("   ℹ️ Акт уже обновлен автоматически при изменении выводов")
        }
        
        // Устанавливаем кнопку "назад" с названием текущего раздела перед push
        let backButton = UIBarButtonItem(title: "Выводы", style: .plain, target: nil, action: nil)
        navigationItem.backBarButtonItem = backButton
        navigationItem.backButtonTitle = "Выводы"
        
        print("   ➡️ Переходим к экрану представителей (isEditingMode: \(isEditingMode))")
        let vc = PredstavViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, descripUser: mainTextView.text, predstavitely: [], akt: akt, isEditingMode: isEditingMode)
        navigationController?.pushViewController(vc, animated: true)
        print("═══════════════════════════════════════════════════════════")
    }
    
    private func updateAktWithNewDescription() {
        print("═══════════════════════════════════════════════════════════")
        print("🔄 [DESCRIPTION] ОБНОВЛЕНИЕ АКТА С НОВЫМИ ВЫВОДАМИ")
        print("   📋 Режим: РЕДАКТИРОВАНИЕ")
        print("   🆔 ID акта: \(akt?.id.uuidString ?? "нет")")
        print("   🔢 Номер акта: \(akt?.number ?? "нет")")
        
        guard let existingAkt = akt else {
            print("   ❌ Существующий акт не найден")
            print("═══════════════════════════════════════════════════════════")
            return
        }
        
        // Создаем обновленный акт с новыми выводами
        let updatedAkt = AKT(
            id: existingAkt.id, // Сохраняем оригинальный ID
            number: existingAkt.number,
            date: existingAkt.date,
            comission: existingAkt.comission,
            organization: existingAkt.organization, // Сохраняем существующую организацию
            objectsCheck: existingAkt.objectsCheck, // Сохраняем существующие объекты
            predstavitelyComission: existingAkt.predstavitelyComission, // Сохраняем существующих представителей
            violations: existingAkt.violations, // Сохраняем существующие нарушения
            description: mainTextView.text, // Обновляем выводы
            actustranenDate: existingAkt.actustranenDate, // Сохраняем существующие даты
            actPredostavlenDate: existingAkt.actPredostavlenDate,
            actUtverzdenDate: existingAkt.actUtverzdenDate,
            urlAct: existingAkt.urlToFllACT ?? URL(fileURLWithPath: ""), // Сохраняем существующий URL
            realDateCreate: existingAkt.realDateCreate // Сохраняем оригинальную дату создания
        )
        
        print("   📋 Номер акта: \(updatedAkt.number)")
        print("   🏢 Организация: \(updatedAkt.organization.title)")
        print("   📝 Выводы: \(updatedAkt.description.prefix(50))...")
        print("   🆔 ID акта: \(updatedAkt.id)")
        
        // Обновляем акт в истории
        print("   💾 Сохраняем акт в историю...")
        viewModel.updateAktInArray(updatedAkt)
        print("   ✅ Акт №\(updatedAkt.number) обновлен в истории с новыми выводами")
        
        // Обновляем редактируемый акт
        print("   💾 Обновляем редактируемый акт...")
        viewModel.updateEditableAKT(updatedAkt)
        print("   ✅ Редактируемый акт обновлен с новыми выводами")
        
        // Обновляем SimpleRealtimeAKTManager, если он активен
        if SimpleRealtimeAKTManager.shared.currentAkt != nil {
            print("   🔄 Обновляем SimpleRealtimeAKTManager с новыми выводами...")
            // Обновляем текущий акт в SimpleRealtimeAKTManager
            SimpleRealtimeAKTManager.shared.currentAkt = updatedAkt
            print("   ✅ SimpleRealtimeAKTManager обновлен с новыми выводами")
        }
        
        // Обновляем ссылку на акт для последующих экранов
        self.akt = updatedAkt
        print("   🔗 Ссылка на акт обновлена")
        
        print("✅ [DESCRIPTION] ОБНОВЛЕНИЕ АКТА ЗАВЕРШЕНО")
        print("═══════════════════════════════════════════════════════════")
    }
    
    @objc private func oneTap() {
        tapped(index: 0)
    }
    
    @objc private func twoTap() {
        tapped(index: 1)
    }
    
    @objc private func threeTap() {
        tapped(index: 2)
    }
    
    @objc private func editBut() {
        ConclusionsTemplateKeys.registerDefaultsIfNeeded()
        let editVC = EditConclusionsTemplatesViewController()
        navigationController?.pushViewController(editVC, animated: true)
    }

    private func tapped(index: Int) {
        ConclusionsTemplateKeys.registerDefaultsIfNeeded()
        let text: String
        switch index {
        case 0: text = ConclusionsTemplateKeys.loadOne()
        case 1: text = ConclusionsTemplateKeys.loadTwo()
        default: text = ConclusionsTemplateKeys.loadThree()
        }
        if !mainTextView.text.isEmpty { mainTextView.text += "\n" }
        mainTextView.text += text
    }

    // Метод hideKB удален - теперь используется dismissKeyboard из расширения
    
    private func setupKeyboardHandling() {
        // Создаем обработчик тапа для сворачивания клавиатуры
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - UITextViewDelegate
    
    func textViewDidChange(_ textView: UITextView) {
        // Отменяем предыдущий таймер
        updateTimer?.invalidate()
        
        // Автоматически обновляем акт при изменении текста с задержкой
        if akt != nil {
            print("🔄 [DESCRIPTION] Текст изменен, планируем обновление акта...")
            
            // Устанавливаем таймер на 1 секунду
            updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                
                print("🔄 [DESCRIPTION] Выполняем отложенное обновление акта...")
                self.updateAktWithNewDescription()
                print("   ✅ Акт автоматически обновлен с новыми выводами")
            }
        }
    }

}

// MARK: - SimpleRealtimeAKTObserver Methods
extension UserDescriptionViewController {
    
    func aktDidChange(_ change: String) {
        print("📝 [DESCRIPTION] Получено изменение: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            // Можно добавить обновление UI если нужно
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [DESCRIPTION] Акт сохранен")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            // Можно добавить обновление UI если нужно
        }
    }
    
    // MARK: - Realtime Integration Methods
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        
        print("🔗 [DESCRIPTION] Интеграция с системой реального времени настроена")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        
        print("🔗 [DESCRIPTION] Интеграция с системой реального времени очищена")
    }
}
