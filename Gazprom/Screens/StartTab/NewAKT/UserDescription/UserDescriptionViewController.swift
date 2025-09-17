//
//  UserDescriptionViewController.swift
//  Gazprom
//
//  Created by Владимир on 14.07.2025.
//

import UIKit

class UserDescriptionViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    
    var descripUser: String = ""
    
    var akt: AKT?
    
    private let oneBut  = UIFactory.createButton(title: "Шаблон 1", color: .systemBlue)
    private let twoBut  = UIFactory.createButton(title: "Шаблон 2", color: .systemBlue)
    private let threeBut  = UIFactory.createButton(title: "Шаблон 3", color: .systemBlue)
    
    let mainTextView: UITextView = {
        let view = UITextView()
        view.backgroundColor = .white.withAlphaComponent(0.9)
        view.font = .systemFont(ofSize: 16, weight: .regular)
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.systemGray.cgColor
        view.textContainerInset = .init(top: 16, left: 16, bottom: 16, right: 16)
        view.textColor = .black
        return view
    }()
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], akt: AKT?) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.akt  = akt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.templateModel.descripUser = mainTextView.text
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Рекомендации"
        
        if let a = viewModel.templateModel.descripUser {
            self.descripUser = a
            self.mainTextView.text = a
        }
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
        stupUI()
        checkOld()
    }
    
    private func checkOld() {
        if let a = akt {
            descripUser = a.description
            mainTextView.text = descripUser
        }
    }
    
    private func stupUI() {
        view.addSubview(mainTextView)
        mainTextView.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.height.equalTo(250)
        }
        
        let gestire = UITapGestureRecognizer(target: self, action: #selector(hideKB))
        view.addGestureRecognizer(gestire)
        
        let nextButton = UIFactory.createButton(title: "Далее", color: .systemBlue)
        view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(54)
        }
        nextButton.addTarget(self, action: #selector(nextVC), for: .touchUpInside)
        
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
    
    @objc private func nextVC() {
//        let vc = GenerateAktViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, descripUser: mainTextView.text)
//        navigationController?.pushViewController(vc, animated: true)
        
        let vc = PredstavViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, descripUser: mainTextView.text, predstavitely: [], akt: akt)
        navigationController?.pushViewController(vc, animated: true)
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
        let alert = UIAlertController(title: "Редактирование", message: "Номер текстового поля соответсвует номеру кнопки с шаблоном", preferredStyle: .alert)
        alert.addTextField()
        alert.addTextField()
        alert.addTextField()
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        let save = UIAlertAction(title: "Сохранить", style: .default) { _ in
            UserDefaults.standard.set(alert.textFields?[0].text ?? "Подготовить акт", forKey:  "oneB")
            UserDefaults.standard.set(alert.textFields?[1].text ?? "Провести проверку", forKey:  "twoB")
            UserDefaults.standard.set(alert.textFields?[2].text ?? "Проверить объекты повторно", forKey:  "threeB")
        }
        alert.addAction(save)
        
        
        alert.textFields?[0].text =  (UserDefaults.standard.object(forKey: "oneB") as? String) ?? "Подготовить акт"
        alert.textFields?[1].text =  (UserDefaults.standard.object(forKey: "twoB") as? String) ?? "Провести проверку"
        alert.textFields?[2].text =  (UserDefaults.standard.object(forKey: "threeB") as? String) ?? "Проверить объекты повторно"
        
        self.present(alert, animated: true)
    }

    private func tapped(index: Int) {
        let tag = index == 0 ? "oneB" : index == 1 ? "twoB" : "threeB"
        
        if let text = UserDefaults.standard.object(forKey: tag) as? String {
            mainTextView.text.append("\n" + text)
        } else {
            let text = index == 0 ? "Подготовить акт" : index == 1 ? "Провести проверку" : "Проверить объекты повторно"
            mainTextView.text.append("\n" + text)
        }
    }

    @objc private func hideKB() {
        view.endEditing(true)
    }

}
