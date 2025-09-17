//
//  SettingsTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class SettingsTabViewController: UIViewController {
    
    let model: MainAKTViewModel
    
    init(model: MainAKTViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.title = "Настройки"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        
        let violationsSelectButton = UIFactory.createButton(title: "Нарушения", color: .systemBlue)
        view.addSubview(violationsSelectButton)
        violationsSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(24)
            make.height.equalTo(54)
        }
        violationsSelectButton.addTarget(self, action: #selector(openViolations), for: .touchUpInside)
        
        let orgSelectButton = UIFactory.createButton(title: "Организации", color: .systemBlue)
        view.addSubview(orgSelectButton)
        orgSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(violationsSelectButton.snp.bottom).inset(-12)
            make.height.equalTo(54)
        }
        orgSelectButton.addTarget(self, action: #selector(openOrganizations), for: .touchUpInside)
        
        let objSelectButton = UIFactory.createButton(title: "Обьекты проверки", color: .systemBlue)
        view.addSubview(objSelectButton)
        objSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(orgSelectButton.snp.bottom).inset(-12)
            make.height.equalTo(54)
        }
        objSelectButton.addTarget(self, action: #selector(openObjects), for: .touchUpInside)
        
        let predSelectButton = UIFactory.createButton(title: "Представители", color: .systemBlue)
        view.addSubview(predSelectButton)
        predSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(objSelectButton.snp.bottom).inset(-12)
            make.height.equalTo(54)
        }
        predSelectButton.addTarget(self, action: #selector(openPredstav), for: .touchUpInside)
        
        
        let comSelectButton = UIFactory.createButton(title: "Члены комиссии", color: .systemBlue)
        view.addSubview(comSelectButton)
        comSelectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(predSelectButton.snp.bottom).inset(-12)
            make.height.equalTo(54)
        }
        comSelectButton.addTarget(self, action: #selector(openComissionPeople), for: .touchUpInside)
        
    }
    
    @objc private func openOrganizations() {
        let vc = SettingsOrganizationsViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func openViolations() {
        let vc = SettingsViolationsViewController()
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openObjects() {
        let vc = SettingsObjectsViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openPredstav() {
        let vc = SettingsPredstavViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    
    @objc private func openComissionPeople() {
        let vc = SettingsComissionPeopleViewController(model: model)
        navigationController?.pushViewController(vc, animated: true)
    }
    

}
