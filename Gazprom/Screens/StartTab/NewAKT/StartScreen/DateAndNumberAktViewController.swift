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
    
    
    
    lazy var comissionPeoples:  [ComissionPeople] = []
    
    private var dateLabel: UILabel!
    private var countLabel: UILabel!
    private var comissionLabel: UILabel!
    
    private let datePicker: UIDatePicker = {
        let view = UIDatePicker()
        view.date = .now
        view.datePickerMode = .date
        view.locale = .init(identifier: "ru_RU")
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

    init(viewModel: MainAKTViewModel, akt: AKT? = nil) {
        self.viewModel = viewModel
        self.akt = akt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func checkOld() {
        if let a = akt {
            datePicker.date = a.date
            comissionPeoples = a.comission
            collection.reloadData()
            
            // Устанавливаем номер акта в picker
            if let aktNumber = Int(a.number), aktNumber > 0 && aktNumber <= 100 {
                numberPicker.selectRow(aktNumber - 1, inComponent: 0, animated: false)
            }
        }
    }
    
    private func loadOccupiedNumbers() {
        occupiedNumbers = viewModel.getOccupiedAktNumbers()
        numberPicker.reloadAllComponents()
        
        // Обновляем информационный лейбл
        updateInfoLabel()
        
        // Если это новый акт (не редактирование), устанавливаем следующий доступный номер
        if akt == nil {
            let nextAvailable = viewModel.getNextAvailableAktNumber()
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
        setupViewModel()
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
        navigationController?.popToRootViewController(animated: true)
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
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
        
        let nextButton = UIFactory.createButton(title: "Далее", color: .systemBlue)
        view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
        
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

    @objc private func goNext() {
        let selectedNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
        
        // Проверяем, не занят ли номер (исключая текущий акт при редактировании)
        let excludingId = akt?.id
        if !viewModel.isAktNumberAvailable(selectedNumber, excludingAktId: excludingId) {
            showOccupiedNumberAlert(selectedNumber: selectedNumber)
            return
        }
        
        let vc = OrganizationsViewController(viewModel: viewModel, comissionPeople: comissionPeoples, date: datePicker.date, aktNumber: selectedNumber, act: akt)
        navigationController?.pushViewController(vc, animated: true)
        
        viewModel.templateModel.comissionPeople = comissionPeoples
        viewModel.templateModel.date = datePicker.date
        viewModel.templateModel.aktNumber = selectedNumber
    }
    
    @objc private func addNewComissionPeople() {
        let vc = NewComissionViewController(viewModel: viewModel)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.custom(resolver: { _ in 710 })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        self.present(vc, animated: true)
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
        let isOccupied = occupiedNumbers.contains(number)
        
        if isOccupied {
            return "№\(number) (занят)"
        } else {
            return "№\(number)"
        }
    }
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let number = "\(row + 1)"
        let isOccupied = occupiedNumbers.contains(number)
        
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
        let isOccupied = occupiedNumbers.contains(selectedNumber)
        
        if isOccupied {
            showOccupiedNumberAlert(selectedNumber: selectedNumber)
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
            if let index = comissionPeoples.firstIndex(where: {$0.id == viewModel.comissionArray.reversed()[indexPath.row].id}) {
                comissionPeoples.remove(at: index)
                collectionView.reloadData()
            } else {
                comissionPeoples.append(viewModel.comissionArray.reversed()[indexPath.row])
                collectionView.reloadData()
            }
        }
    }
}
