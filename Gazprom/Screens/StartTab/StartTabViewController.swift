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
        label.textColor = .black
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        return label
    }()
    
    private var continueButton: UIButton?
    
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
        
        // Обновляем кнопку "Продолжить заполнение" при возврате на экран
        updateContinueButton()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
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
        
        // Добавляем информацию о версии приложения
        let versionLabel = UILabel()
        versionLabel.text = VersionManager.shared.getDisplayVersion()
        versionLabel.textAlignment = .center
        versionLabel.textColor = .systemBlue
        versionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        versionLabel.numberOfLines = 0
        view.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(fioLabel.snp.top).offset(-8)
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
    
    private func updateContinueButton() {
        guard let button = continueButton else { return }
        
        if let draftInfo = viewModel.getDraftInfo() {
            let violationsText = draftInfo.violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(draftInfo.violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
        } else if let lastOpenedAkt = viewModel.getLastOpenedAkt() {
            let violationsCount = lastOpenedAkt.violations.count
            let violationsText = violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
        } else if let lastAkt = viewModel.aktArray.last {
            let violationsCount = lastAkt.violations.count
            let violationsText = violationsCount == 1 ? "нарушение" : "нарушений"
            button.setTitle("Продолжить заполнение\n(\(violationsCount) \(violationsText))", for: .normal)
            button.titleLabel?.numberOfLines = 2
            button.titleLabel?.textAlignment = .center
        } else {
            button.setTitle("Продолжить заполнение", for: .normal)
            button.titleLabel?.numberOfLines = 1
            button.titleLabel?.textAlignment = .center
        }
    }
    
    @objc private func createNew() {
        // Очищаем последний открытый АКТ при создании нового
        viewModel.clearLastOpenedAkt()
        let vc = DateAndNumberAktViewController(viewModel: viewModel)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func nextAct() {
        if let draft = viewModel.loadDraft() {
            // Продолжаем с черновика - переходим к соответствующему шагу редактирования
            continueFromDraft(draft)
        } else if let lastOpenedAkt = viewModel.getLastOpenedAkt() {
            // Продолжаем с последнего открытого АКТ - переходим к редактированию нарушений
            editAkt(lastOpenedAkt)
        } else if let act = viewModel.aktArray.last {
            // Если нет последнего открытого АКТ, используем последний в массиве
            editAkt(act)
        } else {
            let alert = UIAlertController(title: "Ошибка!", message: "Нет сохраненного прогресса для продолжения", preferredStyle: .alert)
            let ok = UIAlertAction(title: "OK", style: .cancel)
            alert.addAction(ok)
            self.present(alert, animated: true)
        }
    }
    
    private func editAkt(_ akt: AKT) {
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
        
        // Переходим к соответствующему шагу
        switch draft.currentStep {
        case .dateAndNumber:
            let vc = DateAndNumberAktViewController(viewModel: viewModel)
            navigationController?.pushViewController(vc, animated: true)
        case .organizations:
            let vc = OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                act: nil
            )
            navigationController?.pushViewController(vc, animated: true)
        case .objectCheck:
            let vc = ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                akt: nil
            )
            navigationController?.pushViewController(vc, animated: true)
        case .violations:
            let vc = NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                akt: nil
            )
            navigationController?.pushViewController(vc, animated: true)
        case .userDescription:
            let vc = UserDescriptionViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                akt: nil
            )
            navigationController?.pushViewController(vc, animated: true)
        case .predstavitely:
            let vc = PredstavViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                descripUser: draft.descripUser,
                predstavitely: [],
                akt: nil
            )
            navigationController?.pushViewController(vc, animated: true)
        case .generate:
            let vc = GenerateAktViewController(
                viewModel: viewModel,
                comissionPeople: draft.comissionPeople,
                date: draft.date,
                aktNumber: draft.aktNumber,
                organizations: draft.organizations,
                objectCheck: draft.objectCheck,
                violations: draft.violations,
                descripUser: draft.descripUser,
                predstavitely: draft.predstavitely,
                akt: nil
            )
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

}
