//
//  NewObjectCheckViewController.swift
//  Gazprom
//
//  Created by Владимир on 07.07.2025.
//

import UIKit

class NewObjectCheckViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    
    
    private let fullNameTextField = UIFactory.createTextField(placeholder: "Краткое название")
    private let jobTextField = UIFactory.createTextField(placeholder: "Полное название")
    
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
        let topLabel = UIFactory.createlabel(title: "Новый обьект проверки")
        view.addSubview(topLabel)
        topLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().inset(30)
        }
        
        view.addSubview(fullNameTextField)
        fullNameTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.top.equalTo(topLabel.snp.bottom).inset(-16)
        }
        
        view.addSubview(jobTextField)
        jobTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(44)
            make.top.equalTo(fullNameTextField.snp.bottom).inset(-8)
        }
        
        let saveButton = UIFactory.createButton(title: "Сохранить", color: .systemBlue)
        view.addSubview(saveButton)
        saveButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(jobTextField.snp.bottom).inset(-16)
        }
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
    }
    
    @objc private func saveTapped() {
        view.endEditing(true)
        if fullNameTextField.text?.count ?? 0 <= 0 || jobTextField.text?.count ?? 0 <= 0 {
            UIFactory.showAlert(vc: self, title: "Ошибка", description: "Заполните все поля")
            return
        }
        
        viewModel.createNewCheckObject(title: fullNameTextField.text ?? "", subtitle: jobTextField.text ?? "") { isOk in
            if isOk {
                self.viewModel.collectionReloadBinding?()
                self.dismiss(animated: true)
            } else {
                UIFactory.showAlert(vc: self, title: "Ошибка", description: "Такой обьект есть в системе!")
            }
        }
        
    }
    
    
  

}
