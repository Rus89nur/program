//
//  SettingsTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import UniformTypeIdentifiers

class SettingsTabViewController: UIViewController {
    
    let model: MainAKTViewModel
    private var templateStatusLabel: UILabel!
    
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
        updateTemplateStatus()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateTemplateStatus()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        
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
        
        // Кнопка загрузки шаблона
        let templateButton = UIFactory.createButton(title: "Загрузить шаблон", color: .systemBlue)
        view.addSubview(templateButton)
        templateButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(comSelectButton.snp.bottom).inset(-12)
            make.height.equalTo(54)
        }
        templateButton.addTarget(self, action: #selector(loadTemplate), for: .touchUpInside)
        
        // Надпись о статусе шаблона
        let templateStatusLabel = UILabel()
        templateStatusLabel.text = "Шаблон не загружен"
        templateStatusLabel.textColor = .label
        templateStatusLabel.font = .systemFont(ofSize: 12, weight: .regular)
        templateStatusLabel.textAlignment = .center
        view.addSubview(templateStatusLabel)
        templateStatusLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(templateButton.snp.bottom).offset(4)
        }
        
        // Сохраняем ссылку на label для обновления статуса
        self.templateStatusLabel = templateStatusLabel
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
    
    // MARK: - Template Methods
    
    private func updateTemplateStatus() {
        if let filePath = UserDefaults.standard.string(forKey: "ShabPath") {
            let url = URL(fileURLWithPath: filePath)
            if FileManager.default.fileExists(atPath: url.path) {
                templateStatusLabel.text = "Шаблон загружен"
                templateStatusLabel.textColor = .systemGreen
            } else {
                templateStatusLabel.text = "Шаблон не загружен"
                templateStatusLabel.textColor = .label
            }
        } else {
            templateStatusLabel.text = "Шаблон не загружен"
            templateStatusLabel.textColor = .label
        }
    }
    
    @objc private func loadTemplate() {
        let docxType = UTType(filenameExtension: "docx") ?? .item
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docxType], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        
        present(documentPicker, animated: true, completion: nil)
    }
}

// MARK: - UIDocumentPickerDelegate

extension SettingsTabViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }

        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(sourceURL.lastPathComponent)

        var success = false

        if sourceURL.startAccessingSecurityScopedResource() {
            success = true
        }

        defer {
            if success {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Файл шаблона скопирован в: \(destinationURL.path)")

            // Сохраняем путь только после успешного копирования
            UserDefaults.standard.set(destinationURL.path, forKey: "ShabPath")
            
            // Обновляем статус
            updateTemplateStatus()

        } catch {
            print("❌ Ошибка при копировании файла шаблона: \(error.localizedDescription)")
            // Удаляем старое значение, если копирование не удалось
            UserDefaults.standard.removeObject(forKey: "ShabPath")
            updateTemplateStatus()
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Отмена выбора документа шаблона")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
