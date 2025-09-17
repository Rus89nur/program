//
//  NewOrganizationViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class NewOrganizationViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    
    let nameTextField = UIFactory.createTextField(placeholder: "Название организации")
    
    init(viewModel: MainAKTViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
    }
    
    private func setupUI() {
        let topLabel = UIFactory.createlabel(title: "Новая организация")
        view.addSubview(topLabel)
        topLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(30)
        }
        
        view.addSubview(nameTextField)
        nameTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.top.equalTo(topLabel.snp.bottom).inset(-16)
        }
        
        let saveButton = UIFactory.createButton(title: "Сохранить", color: .systemBlue)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(nameTextField.snp.bottom).inset(-16)
        }
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }
    
    @objc private func saveTapped() {
        view.endEditing(true)
        if nameTextField.text?.count ?? 0 <= 0 {
            UIFactory.showAlert(vc: self, title: "Ошибка", description: "Заполните организацию")
            return
        }
        
        viewModel.createNewOrganization(title: nameTextField.text ?? "") { isOk in
            if isOk {
                self.viewModel.collectionReloadBinding?()
                self.dismiss(animated: true)
            } else {
                UIFactory.showAlert(vc: self, title: "Ошибка", description: "Такая организация уже есть в системе!")
            }
        }
        
    }


}
