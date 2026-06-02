//
//  NewOrganizationViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import Combine

// MARK: - Simple Realtime AKT System (Integrated)
// Типы определены в MainAKTViewModel.swift для избежания дублирования

class NewOrganizationViewController: UIViewController, SimpleRealtimeAKTObserver {
    
    let viewModel: MainAKTViewModel
    
    // Realtime AKT Integration
    var cancellables = Set<AnyCancellable>()
    
    init(viewModel: MainAKTViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupRealtimeIntegration()
    }
    
    deinit {
        cleanupRealtimeIntegration()
    }
    
    private func setupRealtimeIntegration() {
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        print("🔗 [REALTIME] Интеграция настроена для \(type(of: self))")
    }
    
    private func cleanupRealtimeIntegration() {
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        cancellables.removeAll()
        print("🔗 [REALTIME] Интеграция очищена для \(type(of: self))")
    }
    
    private func setupUI() {
        let editType = EditType.singleField(
            title: "Новая организация",
            placeholder: "Введите название организации",
            currentValue: ""
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, _, _ in
            guard let self = self else { return }
            
            // Проверяем, что название не пустое
            if newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let errorAlert = UIAlertController(title: "Ошибка!", message: "Название организации не может быть пустым", preferredStyle: .alert)
                let ok = UIAlertAction(title: "OK", style: .cancel)
                errorAlert.addAction(ok)
                self.present(errorAlert, animated: true)
                return
            }
            
            // Создаем новую организацию через viewModel
            let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            self.viewModel.createNewOrganization(title: trimmedTitle) { isOk in
                DispatchQueue.main.async {
                    if isOk {
                        // Обновляем в системе реального времени
                        let newOrganization = Organization(title: trimmedTitle)
                        SimpleRealtimeAKTManager.shared.updateOrganization(newOrganization)
                        
                        self.viewModel.collectionReloadBinding?()
                        self.dismiss(animated: true)
                    } else {
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Организация с таким названием уже существует", preferredStyle: .alert)
                        let ok = UIAlertAction(title: "OK", style: .cancel)
                        errorAlert.addAction(ok)
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
        
        // Добавляем editVC как дочерний контроллер
        addChild(editVC)
        view.addSubview(editVC.view)
        editVC.view.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        editVC.didMove(toParent: self)
    }
    
    // MARK: - SimpleRealtimeAKTObserver Methods
    
    func aktDidChange(_ change: String) {
        print("📝 [REALTIME] Получено изменение в NewOrganizationViewController: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            // Здесь можно добавить логику обновления UI
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [REALTIME] Акт сохранен в NewOrganizationViewController")
        
        // Обновляем локальное состояние при необходимости
        DispatchQueue.main.async {
            // Здесь можно добавить логику обновления UI после сохранения
        }
    }
}
