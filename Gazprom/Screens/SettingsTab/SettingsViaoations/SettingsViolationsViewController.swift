//
//  SettingsViolationsViewController.swift
//  Gazprom
//
//  Created by Владимир on 08.07.2025.
//

import UIKit
import UniformTypeIdentifiers

class SettingsViolationsViewController: UIViewController, UIDocumentPickerDelegate {
    
    var items = ViolationsModel.returnAvialableViolation()
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.register(UITableViewCell.self, forCellReuseIdentifier: "1")
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .clear
        return view
    }()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Просмотр нарушений"
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
       
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
        
        let loadButton = UIFactory.createButton(title: "Импорт", color: .systemBlue)
        let exportButton = UIFactory.createButton(title: "Экспорт", color: .systemBlue)
        loadButton.addTarget(self, action: #selector(importData), for: .touchUpInside)
        exportButton.addTarget(self, action: #selector(exportData), for: .touchUpInside)
        
        view.addSubview(loadButton)
        loadButton.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.left.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.right.equalTo(view.safeAreaLayoutGuide.snp.centerX).offset(-4)
        }
        
        view.addSubview(exportButton)
        exportButton.snp.makeConstraints { make in
            make.height.equalTo(54)
            make.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.left.equalTo(view.safeAreaLayoutGuide.snp.centerX).offset(4)
        }
        
        checkitems()
    }
    
    @objc private func importData() {
        let types: [UTType] = [UTType(filenameExtension: "xlsx")!, UTType(filenameExtension: "xls")!]

        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    @objc private func exportData() {
        guard let path = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("❌ Файл не найден")
            return
        }
        
        let fileURL = URL(fileURLWithPath: path)
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("❌ Файл не существует по пути: \(fileURL.path)")
            return
        }
        
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        self.present(activityVC, animated: true, completion: nil)
    }

    
    // MARK: - UIDocumentPickerDelegate
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }

        // Начинаем доступ к security-scoped ресурсу
        guard url.startAccessingSecurityScopedResource() else {
            print("🚫 Не удалось получить доступ к файлу")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() }

        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destinationURL = documentsDirectory.appendingPathComponent(url.lastPathComponent)

        if fileManager.fileExists(atPath: destinationURL.path) {
            try? fileManager.removeItem(at: destinationURL)
        }

        do {
            try fileManager.copyItem(at: url, to: destinationURL)
            print("✅ Файл скопирован в: \(destinationURL.path)")

            UserDefaults.standard.set(destinationURL.path, forKey: "ImportedExcelFilePath")
            print("✅ Путь сохранен в UserDefaults: \(destinationURL.path)")

            print("🔍 Загружаем нарушения из файла...")
            items = ViolationsModel.returnAvialableViolation()
            print("📊 Загружено нарушений в UI: \(items.count)")
            
            tableView.reloadData()
            print("✅ Таблица обновлена")
        } catch {
            print("❌ Ошибка копирования файла: \(error.localizedDescription)")
        }
    }


    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("🚫 Выбор файла отменен")
    }
    
    
    func checkitems() {
        if items.count > 0 {
            let plusButton = UIButton(type: .system)
            plusButton.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
            plusButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
            }
            plusButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
            let item = UIBarButtonItem(customView: plusButton)
            self.navigationItem.setRightBarButton(item, animated: true)
        } else {
            self.navigationItem.rightBarButtonItem = nil
        }
    }
    
    @objc private func addNew() {
        let alert = UIAlertController(title: "Добавление нарушения", message: "Заполните все поля", preferredStyle: .alert)
        
        alert.addTextField() //0
        alert.addTextField() //1
        alert.addTextField() //2
        alert.addTextField() //3
        alert.addTextField() //4
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        alert.textFields?[0].placeholder = "Номер"
        alert.textFields?[1].placeholder = "Формулировка"
        alert.textFields?[2].placeholder = "Ссылка на норм. документ"
        alert.textFields?[3].placeholder = "Примечание"
        alert.textFields?[4].placeholder = "Вид нарушения"
        
        let save = UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            guard let self = self else { return }
            
            let number: Int =  Int(alert.textFields?[0].text ?? "0") ?? 0
            let form: String =  alert.textFields?[1].text ?? "-"
            let url: String =  alert.textFields?[2].text ?? "-"
            let desc: String =  alert.textFields?[3].text ?? "-"
            let vid: String =  alert.textFields?[4].text ?? "-"
            
            let violataion = ViolationsModel.Violation(number: number, titie: form, subTitle: url, description: desc, vid: vid)
            ViolationsModel.addNewViolation(violation: violataion)
            
            items = ViolationsModel.returnAvialableViolation()
            tableView.reloadData()
            
        }
        alert.addAction(save)
        
        present(alert, animated: true)
    }
    
    private func showViolationInfo(for violation: ViolationsModel.Violation) {
        let previewVC = ViolationPreviewViewController(violation: violation)
        previewVC.modalPresentationStyle = .pageSheet
        
        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(previewVC, animated: true)
    }
    
    private func openEditAlert(for violation: ViolationsModel.Violation, at indexPath: IndexPath) {
        let editVC = SettingsEditViolationViewController(violation: violation) { [weak self] updatedViolation in
            guard let self = self else { return }
            
            print("🔄 Обновляем нарушение в настройках:")
            print("   Старое: \(violation.titie)")
            print("   Новое: \(updatedViolation.titie)")
            
            // Используем новый метод для обновления нарушения
            ViolationsModel.updateViolation(oldViolation: violation, newViolation: updatedViolation)
            
            // Обновляем локальный массив
            self.items = ViolationsModel.returnAvialableViolation()
            print("📊 Количество нарушений после обновления: \(self.items.count)")
            self.tableView.reloadData()
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = .pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
}

extension SettingsViolationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "1") ?? UITableViewCell()
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        let item = items[indexPath.row]
        
        let numbLabel = UILabel()
        numbLabel.text = item.titie
        numbLabel.textAlignment = .left
        numbLabel.textColor = .black
        numbLabel.font = .systemFont(ofSize: 20, weight: .medium)
        cell.addSubview(numbLabel)
        numbLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().inset(16)
            make.left.equalToSuperview().inset(8)
            make.right.equalToSuperview().inset(16)
          //  make.width.equalTo(50)
        }
        
        
        let urlLabel = UILabel()
        urlLabel.text = "Ссылка на норм. документ"
        urlLabel.textColor = .black
        urlLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(urlLabel)
        urlLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(numbLabel.snp.bottom).inset(-8)
        }
        
        let normLabel = UILabel()
        normLabel.text = item.subTitle
        normLabel.textAlignment = .left
        normLabel.textColor = .black
        normLabel.font = .systemFont(ofSize: 16, weight: .regular)
        cell.addSubview(normLabel)
        normLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(urlLabel.snp.bottom).inset(-2)
        }
        
        let separator = UIView()
        separator.backgroundColor = .separator
        cell.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        
        let primLabel = UILabel()
        primLabel.text = "Примечание"
        primLabel.textColor = .black
        primLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(primLabel)
        primLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(normLabel.snp.bottom).inset(-8)
        }
        
        let mainPrimLabel = UILabel()
        mainPrimLabel.text = item.description == nil ? "---" :  item.description
        mainPrimLabel.textAlignment = .left
        mainPrimLabel.textColor = .black
        mainPrimLabel.font = .systemFont(ofSize: 16, weight: .regular)
        cell.addSubview(mainPrimLabel)
        mainPrimLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(primLabel.snp.bottom).inset(-2)
        }
        
        let narushLabel = UILabel()
        narushLabel.text = "Вид нарушения"
        narushLabel.textColor = .black
        narushLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(narushLabel)
        narushLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(24)
            make.top.equalTo(mainPrimLabel.snp.bottom).inset(-8)
        }
        
        let mainVidLabel = UILabel()
        mainVidLabel.text = item.vid
        mainVidLabel.textAlignment = .left
        mainVidLabel.textColor = .black
        mainVidLabel.font = .systemFont(ofSize: 16, weight: .regular)
        cell.addSubview(mainVidLabel)
        mainVidLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(24)
            make.top.equalTo(narushLabel.snp.bottom).inset(-2)
        }
        
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 200
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let violation = items[indexPath.row]
        showViolationInfo(for: violation)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let itemToDelete = items[indexPath.row]
            items.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            ViolationsModel.delete(item: itemToDelete)
            checkitems()
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            let itemToDelete = self.items[indexPath.row]
            self.items.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            ViolationsModel.delete(item: itemToDelete)
            self.checkitems()
            completionHandler(true)
        }
        
        let editAction = UIContextualAction(style: .normal, title: "Изменить") { [weak self] (_, _, completionHandler) in
            guard let self = self else { return }
            let violation = self.items[indexPath.row]
            self.openEditAlert(for: violation, at: indexPath)
            completionHandler(true)
        }
        
        deleteAction.backgroundColor = .systemRed
        editAction.backgroundColor = .systemOrange
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }


    
}
