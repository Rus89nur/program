//
//  NewComissionViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import Combine

class NewComissionViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    let viewModel: MainAKTViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let fullNameTextField = UIFactory.createTextField(placeholder: "ФИО")
    private let jobTextField = UIFactory.createTextField(placeholder: "Должность")
    
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
        setupRealtimeIntegration()
    }
    
    deinit {
        cleanupRealtimeIntegration()
    }
    
    private func setupUI() {
        let topLabel = UIFactory.createlabel(title: "Новый член комиссии")
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
            make.top.equalTo(fullNameTextField.snp.bottom).inset(-16)
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
        
        print("🔄 [COMMISSION] Сохраняем нового члена комиссии")
        print("   👤 ФИО: \(fullNameTextField.text ?? "")")
        print("   💼 Должность: \(jobTextField.text ?? "")")
        
        viewModel.createNewEmployer(fio: fullNameTextField.text ?? "", jobTitle: jobTextField.text ?? "") { isOk in
            if isOk {
                print("   ✅ Новый член комиссии сохранен")
                
                // Обновляем комиссию в реальном времени
                print("   🔄 Обновляем комиссию в реальном времени...")
                SimpleRealtimeAKTManager.shared.updateCommission(self.viewModel.comissionArray)
                print("   ✅ Комиссия обновлена в реальном времени")
                
                self.viewModel.collectionReloadBinding?()
                self.dismiss(animated: true)
            } else {
                print("   ❌ Ошибка: такой работник уже есть в системе")
                UIFactory.showAlert(vc: self, title: "Ошибка", description: "Такой работник есть в системе!")
            }
        }
        
    }
}

// MARK: - SimpleRealtimeAKTObserver Methods
extension NewComissionViewController {
    
    func aktDidChange(_ change: String) {
        print("📝 [COMMISSION] Получено изменение: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            // Можно добавить обновление UI если нужно
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [COMMISSION] Акт сохранен")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            // Можно добавить обновление UI если нужно
        }
    }
    
    // MARK: - Realtime Integration Methods
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        
        print("🔗 [COMMISSION] Интеграция с системой реального времени настроена")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        
        print("🔗 [COMMISSION] Интеграция с системой реального времени очищена")
    }
}