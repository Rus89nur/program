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
    
    private let datePicker: UIDatePicker = {
        let view = UIDatePicker()
        view.date = .now
        view.datePickerMode = .date
        view.locale = .init(identifier: "ru_RU")
        view.preferredDatePickerStyle = .compact
        view.overrideUserInterfaceStyle = .light
        view.tintColor = .black
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
        view.overrideUserInterfaceStyle = .light
        view.tintColor = .black
        return view
    }()

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
        view.backgroundColor = .white
        setupUI()
        checkOld()
    }
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.collection.reloadData()
        }
    }

    private func setupUI() {
        let dateLabel = UIFactory.createlabel(title: "Укажите дату проверки:")
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
        
        let countLabel = UIFactory.createlabel(title: "Укажите номер Акта:")
        view.addSubview(countLabel)
        countLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(datePicker.snp.bottom).offset(24)
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
        
        let comissionLabel = UIFactory.createlabel(title: "Члены комиссии:")
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
    }

    @objc private func goNext() {
        let vc = OrganizationsViewController(viewModel: viewModel, comissionPeople: comissionPeoples, date: datePicker.date, aktNumber: "\(numberPicker.selectedRow(inComponent: 0) + 1)", act: akt)
        navigationController?.pushViewController(vc, animated: true)
        
        viewModel.templateModel.comissionPeople = comissionPeoples
        viewModel.templateModel.date = datePicker.date
        viewModel.templateModel.aktNumber = "\(numberPicker.selectedRow(inComponent: 0) + 1)"
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
        return "№\(row + 1)"
    }
}

extension DateAndNumberAktViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.comissionArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .black.withAlphaComponent(0.05)
        cell.layer.cornerRadius = 16
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
            mainLabel.textColor = .black
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
            sublabel.textColor = .black.withAlphaComponent(0.6)
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
