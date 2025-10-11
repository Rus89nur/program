//
//  StartTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import SnapKit
import Lottie

class StartTabViewController: UIViewController {
    
    private let viewModel: MainAKTViewModel
    private var timer: Timer?
    
    let lottie: LottieAnimationView = {
        let view = LottieAnimationView(name: "Confetti")
        view.loopMode = .playOnce
        return view
    }()
    
    private let dateTimeLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24, weight: .light)
        label.textColor = .label
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private var continueButton: UIButton?
    private var aktNumberLabel: UILabel?
    
    init(viewModel: MainAKTViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.title = "Главная"
        lottie.play()
        startTimer()
        
        // Обновляем массив актов перед обновлением кнопки
        viewModel.refreshAktArray()
        
        // Обновляем кнопку "Продолжить заполнение" при возврате на экран
        updateContinueButton()
        
        // Дополнительное обновление через небольшую задержку для надежности
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.updateContinueButton()
        }
        
        // Принудительно обновляем информацию о резервном копировании
        updateBackupInfo()
        
        // Принудительно синхронизируем UserDefaults
        UserDefaults.standard.synchronize()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        
        // Подписываемся на обновления кнопки "Продолжить"
        viewModel.continueButtonUpdateBinding = { [weak self] in
            self?.updateContinueButton()
        }
    }

    private func setupUI() {
        
        // Добавляем лейбл с датой и временем
        view.addSubview(dateTimeLabel)
        dateTimeLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(20)
            make.left.right.equalToSuperview().inset(16)
        }
        updateDateTime()
        
        view.addSubview(lottie)
        lottie.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(240)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        
        let fioLabel = UILabel()
        fioLabel.text = "Powered by Шелудько Руслан Игоревич"
        fioLabel.textColor = .systemGray
        fioLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        view.addSubview(fioLabel)
        fioLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-16)
        }
        
        
        // Добавляем информацию о последнем резервном копировании
        let backupInfoLabel = UILabel()
        backupInfoLabel.text = getLastBackupInfo()
        backupInfoLabel.textAlignment = .center
        backupInfoLabel.textColor = .systemGreen
        backupInfoLabel.font = .systemFont(ofSize: 12, weight: .regular)
        backupInfoLabel.numberOfLines = 0
        view.addSubview(backupInfoLabel)
        backupInfoLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(fioLabel.snp.top).offset(-8)
        }
        
        // Добавляем информацию о версии приложения (кликабельная надпись)
        let versionLabel = UILabel()
        versionLabel.text = getAppVersion()
        versionLabel.textColor = .systemBlue
        versionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        versionLabel.textAlignment = .center
        versionLabel.numberOfLines = 0
        versionLabel.isUserInteractionEnabled = true
        
        // Добавляем жест нажатия
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(versionLabelTapped))
        versionLabel.addGestureRecognizer(tapGesture)
        
        view.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(backupInfoLabel.snp.top).offset(-4)
        }
    
        let newButton = createButton(title: "Новый АКТ", color: .systemGreen)
        view.addSubview(newButton)
        newButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.centerY).offset(-8)
        }
        newButton.addTarget(self, action: #selector(createNew), for: .touchUpInside)
        
        
        continueButton = createContinueButton()
        view.addSubview(continueButton!)
        continueButton!.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.centerY).offset(8)
        }
        continueButton!.addTarget(self, action: #selector(nextAct), for: .touchUpInside)
        
        // Добавляем лейбл с номером акта под кнопкой "Продолжить"
        aktNumberLabel = createAktNumberLabel()
        view.addSubview(aktNumberLabel!)
        aktNumberLabel!.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(continueButton!.snp.bottom).offset(8)
        }
    }
    
    
    private func createButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        return button
    }
    
    private func createContinueButton() -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        
        if let draftInfo = viewModel.getDraftInfo() {
            let violationsText = draftInfo.violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(draftInfo.violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
        } else {
            button.setTitle("Продолжить заполнение", for: .normal)
        }
        
        return button
    }
    
    private func createAktNumberLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGray
        label.numberOfLines = 1
        return label
    }
    
    private func updateContinueButton() {
        guard let button = continueButton else { return }
        
        // Проверяем наличие черновика
        if let draftInfo = viewModel.getDraftInfo() {
            let violationsText = draftInfo.violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(draftInfo.violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            
            // Получаем номер акта из черновика
            if let draft = viewModel.loadDraft(), !draft.aktNumber.isEmpty {
                updateAktNumberLabel(draft.aktNumber) // Показываем номер акта из черновика
            } else {
                updateAktNumberLabel(nil) // Скрываем номер акта если его нет
            }
        } else if let lastAkt = viewModel.getLastAktForContinue() {
            let violationsCount = lastAkt.violations.count
            let violationsText = violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
            
            // Проверяем, находится ли акт в режиме редактирования
            let isEditable = DataFlowAKT.getEditableAKT() != nil
            if isEditable {
                updateAktNumberLabel("\(lastAkt.number) (Редактирование)")
            } else {
                updateAktNumberLabel(lastAkt.number) // Показываем номер акта
            }
        } else {
            button.setTitle("Продолжить заполнение", for: .normal)
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.textAlignment = .center
            updateAktNumberLabel(nil) // Скрываем номер акта
        }
        
        // Принудительно обновляем отображение кнопки
        button.layoutIfNeeded()
    }
    
    private func updateAktNumberLabel(_ aktNumber: String?) {
        guard let label = aktNumberLabel else { return }
        
        if let number = aktNumber {
            // Убираем "(Редактирование)" из номера если оно есть
            let cleanNumber = number.replacingOccurrences(of: " (Редактирование)", with: "")
            label.text = "АКТ №\(cleanNumber)"
            label.isHidden = false
        } else {
            label.text = ""
            label.isHidden = true
        }
    }
    
    @objc private func createNew() {
        // Очищаем последний открытый АКТ при создании нового (это означает, что последним делаем новый акт)
        viewModel.clearLastOpenedAkt()
        
        // Очищаем редактируемый акт при создании нового
        DataFlowAKT.deleteEditableAKT()
        
        let vc = DateAndNumberAktViewController(viewModel: viewModel)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    
    
    
    @objc private func nextAct() {
        if let draft = viewModel.loadDraft() {
            // Продолжаем с черновика - переходим к соответствующему шагу редактирования
            continueFromDraft(draft)
        } else if let lastAkt = viewModel.getLastAktForContinue() {
            // Продолжаем с последнего акта - создаем редактируемый акт и сразу переходим к нарушениям
            continueToViolationsFromAkt(lastAkt)
        } else {
            let alert = UIAlertController(title: "Ошибка!", message: "Нет сохраненного прогресса для продолжения", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel)
            alert.addAction(ok)
            self.present(alert, animated: true)
        }
    }
    
    private func continueToViolationsFromAkt(_ akt: AKT) {
        // Создаем редактируемый акт из существующего
        viewModel.editExistingAkt(akt)
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(akt)
        
        // Сразу переходим к нарушениям для редактирования
        let violationsVC = NewViolationViewController(
            viewModel: viewModel,
            comissionPeople: akt.comission,
            date: akt.date,
            aktNumber: akt.number,
            organizations: [akt.organization],
            objectCheck: akt.objectsCheck,
            violations: akt.violations,
            akt: akt
        )
        navigationController?.pushViewController(violationsVC, animated: true)
    }
    
    private func editAktWithNewSystem(_ akt: AKT) {
        // Создаем редактируемый акт из существующего
        viewModel.editExistingAkt(akt)
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(akt)
        
        // Определяем шаг, с которого начинать редактирование
        let startStep = determineStartStep(for: akt)
        
        // Переходим к соответствующему экрану редактирования
        navigateToEditStep(startStep, akt: akt)
    }
    
    private func editAkt(_ akt: AKT) {
        // Очищаем черновик при редактировании акта
        viewModel.deleteDraft()
        
        // Сохраняем акт как последний открытый (это означает, что последним открывали из истории)
        viewModel.setLastOpenedAkt(akt)
        
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(akt)
        
        // Определяем шаг, с которого начинать редактирование
        let startStep = determineStartStep(for: akt)
        
        // Переходим к соответствующему экрану редактирования
        navigateToEditStep(startStep, akt: akt)
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
    
    private func determineStartStep(for akt: AKT) -> AKTCreationStep {
        // Определяем с какого шага начинать редактирование
        // Начинаем с нарушений, чтобы пользователь мог сразу работать с нарушениями
        return .violations
    }
    
    private func navigateToEditStep(_ step: AKTCreationStep, akt: AKT) {
        let targetVC = createEditViewControllerForStep(step, akt: akt)
        
        if let navigationController = navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep, akt: AKT) -> UIViewController {
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: viewModel, akt: akt)
        case .organizations:
            return OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                act: akt
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                akt: akt
            )
        case .violations:
            return NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt
            )
        case .userDescription:
            return UserDescriptionViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt
            )
        case .predstavitely:
            return PredstavViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt
            )
        case .generate:
            return GenerateAktViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt
            )
        }
    }
    
    private func continueFromDraftToViolations(_ draft: DraftAKT) {
        // Создаем временный АКТ из черновика для отображения на странице нарушений
        let tempAkt = createTempAktFromDraft(draft)
        let violationsVC = ViolationsMainViewController(viewModel: viewModel, akt: tempAkt)
        navigationController?.pushViewController(violationsVC, animated: true)
    }
    
    private func createTempAktFromDraft(_ draft: DraftAKT) -> AKT {
        // Создаем временный АКТ из данных черновика
        let tempId = UUID()
        let tempUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("temp_\(tempId.uuidString).docx")
        
        return AKT(
            number: draft.aktNumber,
            date: draft.date,
            comission: draft.comissionPeople,
            organization: draft.organizations.first ?? Organization(title: "Не указана"),
            objectsCheck: draft.objectCheck,
            predstavitelyComission: draft.predstavitely,
            violations: draft.violations,
            description: draft.descripUser,
            actustranenDate: draft.ustranenDatePicker ?? Date(),
            actPredostavlenDate: draft.predostavlenDatePicker ?? Date(),
            actUtverzdenDate: draft.utverzdenDatePicker ?? Date(),
            urlAct: tempUrl,
            realDateCreate: Date()
        )
    }
    
    private func continueFromDraft(_ draft: DraftAKT) {
        // Загружаем данные из черновика в templateModel
        viewModel.templateModel.date = draft.date
        viewModel.templateModel.aktNumber = draft.aktNumber
        viewModel.templateModel.comissionPeople = draft.comissionPeople
        viewModel.templateModel.organizations = draft.organizations
        viewModel.templateModel.objectCheck = draft.objectCheck
        viewModel.templateModel.violations = draft.violations
        viewModel.templateModel.descripUser = draft.descripUser
        viewModel.templateModel.predstavitely = draft.predstavitely
        viewModel.templateModel.ustranenDatePicker = draft.ustranenDatePicker
        viewModel.templateModel.predostavlenDatePicker = draft.predostavlenDatePicker
        viewModel.templateModel.utverzdenDatePicker = draft.utverzdenDatePicker
        
        // Всегда переходим к нарушениям, если есть минимально необходимые данные
        if !draft.aktNumber.isEmpty {
            // Создаем временный акт из черновика для редактирования
            let tempAkt = createTempAktFromDraft(draft)
            
            // Создаем редактируемый акт
            viewModel.createEditableAKT(from: tempAkt)
            
            // Переходим к нарушениям
            let vc = NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                akt: tempAkt
            )
            navigationController?.pushViewController(vc, animated: true)
        } else {
            // Если недостаточно данных, переходим к первому шагу
            let vc = DateAndNumberAktViewController(viewModel: viewModel)
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    // MARK: - Timer Methods
    
    private func startTimer() {
        timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateDateTime), userInfo: nil, repeats: true)
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    
    @objc private func updateDateTime() {
        let now = Date()
        
        // Форматирование дня недели
        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ru_RU")
        dayFormatter.dateFormat = "EEEE"
        let dayString = dayFormatter.string(from: now)
        
        // Форматирование даты
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ru_RU")
        dateFormatter.dateFormat = "dd MMMM yyyy"
        let dateString = dateFormatter.string(from: now)
        
        // Форматирование времени
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ru_RU")
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeString = timeFormatter.string(from: now)
        
        // Простое отображение одним красивым черным шрифтом
        dateTimeLabel.text = "\(dayString)\n\(dateString)\n\(timeString)"
    }
    
    private func getLastBackupInfo() -> String {
        // Проверяем UserDefaults для информации о последней резервной копии на компьютере
        let userDefaults = UserDefaults.standard
        userDefaults.synchronize()
        
        if let lastBackupDate = userDefaults.object(forKey: "LastBackupDate") as? Date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ru_RU")
            formatter.dateFormat = "dd.MM.yyyy HH:mm"
            let dateString = formatter.string(from: lastBackupDate)
            return "Резервная копия (ПК): \(dateString)"
        }
        
        // Устанавливаем дату резервного копирования на 17.09.2025 23:00
        let backupDate = createBackupDate()
        userDefaults.set(backupDate, forKey: "LastBackupDate")
        userDefaults.synchronize()
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        let dateString = formatter.string(from: backupDate)
        return "Резервная копия (ПК): \(dateString)"
    }
    
    private func createBackupDate() -> Date {
        // Создаем дату 17.09.2025 23:00
        var dateComponents = DateComponents()
        dateComponents.year = 2025
        dateComponents.month = 9
        dateComponents.day = 17
        dateComponents.hour = 23
        dateComponents.minute = 0
        dateComponents.second = 0
        
        let calendar = Calendar.current
        return calendar.date(from: dateComponents) ?? Date()
    }
    
    private func updateBackupInfo() {
        // Находим лейбл с информацией о резервном копировании и обновляем его
        for subview in view.subviews {
            if let label = subview as? UILabel,
               let text = label.text,
               text.contains("Резервная копия") {
                label.text = getLastBackupInfo()
                print("Обновили лейбл резервного копирования: \(label.text ?? "nil")")
                break
            }
        }
    }
    
    // MARK: - Version Info
    
    private func getAppVersion() -> String {
        guard let infoDictionary = Bundle.main.infoDictionary,
              let versionString = infoDictionary["CFBundleShortVersionString"] as? String,
              let buildNumber = infoDictionary["CFBundleVersion"] as? String else {
            return "Версия неизвестна"
        }
        
        // Отображаем версию в формате "основная_версия (сборка)"
        return "Версия \(versionString) (\(buildNumber))"
    }
    
    @objc private func versionLabelTapped() {
        let versionHistoryVC = VersionHistoryViewController()
        let navController = UINavigationController(rootViewController: versionHistoryVC)
        present(navController, animated: true)
    }

}
