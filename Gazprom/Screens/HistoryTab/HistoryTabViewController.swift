//
//  HistoryTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit
import AudioToolbox
import QuickLook

class HistoryTabViewController: UIViewController, QLPreviewControllerDelegate {
    
    let viewModel: MainAKTViewModel = MainAKTViewModel()
    var documentURL: URL?
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.title = "История"
        // Обновляем массив актов из сохраненных данных
        viewModel.refreshAktArray()
        colelction.reloadData()
    }
    
    let colelction: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 16, left: 0, bottom: 16, right: 0)
        layout.scrollDirection = .vertical
        return collection
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .systemBackground
        view.addSubview(colelction)
        colelction.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
        colelction.delegate = self
        colelction.dataSource = self
        
        // Добавляем длинное нажатие с вибрацией
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        colelction.addGestureRecognizer(longPressGesture)
    }
    
    private func formatter(date: Date) -> String {
        let form = DateFormatter()
        form.dateFormat = "dd.MM.yyyy"
        form.locale = .current
        return form.string(from: date)
    }
    
    // MARK: - Generate Akt Method
    
    private func generateAkt(for akt: AKT) {
        // Создаем акт напрямую
        createAktDirectly(for: akt) { [weak self] generatedURL in
            DispatchQueue.main.async {
                if let url = generatedURL {
                    self?.showSaveOrShareOptions(for: url, originalAkt: akt)
                } else {
                    self?.showErrorAlert()
                }
            }
        }
    }
    
    private func createAktDirectly(for akt: AKT, completion: @escaping (URL?) -> Void) {
        guard let filePath = UserDefaults.standard.string(forKey: "ShabPath") else {
            completion(nil)
            return
        }
        
        let url = URL(fileURLWithPath: filePath)
        
        if FileManager.default.fileExists(atPath: url.path) {
            let generateViewModel = GenerateViewModel()
            
            generateViewModel.generate(
                url: url,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstav: akt.predstavitelyComission,
                datePredostavlen: akt.actPredostavlenDate,
                dateUstranen: akt.actustranenDate,
                utverzdenDate: akt.actUtverzdenDate,
                escaping: completion
            )
        } else {
            completion(nil)
        }
    }
    
    private func showSaveOrShareOptions(for url: URL, originalAkt: AKT) {
        // Сразу сохраняем акт в историю
        saveAktToHistory(url: url, originalAkt: originalAkt)
        
        // И сразу открываем для просмотра
        openDocumentPreview(url: url)
    }
    
    private func openDocumentPreview(url: URL) {
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Файл не существует: \(url.path)")
            showAlert(title: "Ошибка", message: "Файл не найден или недоступен")
            return
        }
        
        // Проверяем размер файла
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? NSNumber ?? 0
            if fileSize.intValue == 0 {
                print("❌ Файл пустой: \(url.path)")
                showAlert(title: "Ошибка", message: "Файл пустой или поврежден")
                return
            }
        } catch {
            print("❌ Ошибка при проверке файла: \(error)")
            showAlert(title: "Ошибка", message: "Не удалось проверить файл")
            return
        }
        
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        self.documentURL = url
        present(previewController, animated: true)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func saveAktToHistory(url: URL, originalAkt: AKT) {
        print("🔄 Обновляем акт №\(originalAkt.number) с ID: \(originalAkt.id)")
        print("   Оригинальная дата создания: \(originalAkt.realDateCreate)")
        print("   Текущий размер массива актов: \(viewModel.aktArray.count)")
        print("   Доступные ID в массиве: \(viewModel.aktArray.map { $0.id })")
        
        // Обновляем существующий акт с новым URL, сохраняя ID и дату создания
        let updatedAkt = originalAkt.updated(with: url)
        
        print("   Обновленный акт с ID: \(updatedAkt.id)")
        print("   Обновленная дата создания: \(updatedAkt.realDateCreate)")
        
        // Используем правильный метод для обновления акта в массиве
        viewModel.updateAktInArray(updatedAkt)
        colelction.reloadData()
        print("   ✅ Акт успешно обновлен через updateAktInArray")
        print("   Новый размер массива актов: \(viewModel.aktArray.count)")
    }
    
    private func shareAkt(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        // Настройка для iPad
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityVC, animated: true)
    }
    
    private func showErrorAlert() {
        let alert = UIAlertController(title: "Ошибка", message: "Не удалось создать акт. Проверьте наличие шаблона.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Haptic Feedback
    
    private func triggerHapticFeedback() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
    
    // MARK: - Open Akt for Editing
    
    private func openAktForEditing(_ akt: AKT) {
        // Очищаем черновик при открытии акта из истории
        viewModel.deleteDraft()
        
        // Создаем редактируемый акт из выбранного акта
        viewModel.editExistingAkt(akt)
        
        // Загружаем данные акта в template model
        loadAktToTemplate(akt)
        
        // Создаем контроллер для редактирования нарушений с возможностью добавления
        let violationsVC = NewViolationViewController(
            viewModel: viewModel,
            comissionPeople: akt.comission,
            date: akt.date,
            aktNumber: akt.number,
            organizations: [akt.organization],
            objectCheck: akt.objectsCheck,
            violations: akt.violations,
            akt: akt
        )
        
        // Переходим к редактированию
        navigationController?.pushViewController(violationsVC, animated: true)
    }
    
    private func loadAktToTemplate(_ akt: AKT) {
        // Очищаем текущий template
        viewModel.templateModel.reset()
        
        // Загружаем данные из акта
        viewModel.templateModel.date = akt.date
        viewModel.templateModel.aktNumber = akt.number
        viewModel.templateModel.comissionPeople = akt.comission
        viewModel.templateModel.organizations = [akt.organization]
        viewModel.templateModel.objectCheck = akt.objectsCheck
        viewModel.templateModel.violations = akt.violations
        viewModel.templateModel.descripUser = akt.description
        viewModel.templateModel.predstavitely = akt.predstavitelyComission
        viewModel.templateModel.ustranenDatePicker = akt.actustranenDate
        viewModel.templateModel.predostavlenDatePicker = akt.actPredostavlenDate
        viewModel.templateModel.utverzdenDatePicker = akt.actUtverzdenDate
    }
    
    // MARK: - Long Press Handler
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: colelction)
        guard let indexPath = colelction.indexPathForItem(at: point) else { return }
        
        // Включаем вибрацию
        triggerHapticFeedback()
        
        // Показываем контекстное меню
        let akt = viewModel.aktArray.reversed()[indexPath.row]
        showContextMenu(for: akt, at: indexPath)
    }
    
    private func showContextMenu(for akt: AKT, at indexPath: IndexPath) {
        // Показываем меню через Alert Controller для лучшей совместимости
        let alert = UIAlertController(title: "Действия с актом №\(akt.number)", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Сформировать акт", style: .default) { _ in
            self.generateAkt(for: akt)
        })
        
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { _ in
            if let index = self.viewModel.aktArray.firstIndex(where: {$0.id == akt.id}) {
                self.viewModel.aktArray.remove(at: index)
                DataFlowAKT.saveArr(arr: self.viewModel.aktArray)
            }
            self.colelction.deleteItems(at: [indexPath])
        })
        
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        
        // Настройка для iPad
        if let popover = alert.popoverPresentationController {
            if let cell = colelction.cellForItem(at: indexPath) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alert, animated: true)
    }
    

}

extension HistoryTabViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.aktArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .systemGray6
        cell.clipsToBounds = true
        cell.layer.cornerRadius  = 20
        
        let item = viewModel.aktArray.reversed()[indexPath.row]
        
        // Дата проверки (синим цветом)
        let checkDateLabel = UILabel()
        checkDateLabel.text = "Проверка: \(formatter(date: item.date))"
        checkDateLabel.textColor = .systemBlue
        checkDateLabel.font = .systemFont(ofSize: 14, weight: .medium)
        cell.addSubview(checkDateLabel)
        checkDateLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
        }
        
        // Дата создания
        let createDateLabel = UILabel()
        createDateLabel.text = "Создан: \(formatter(date: item.realDateCreate))"
        createDateLabel.textColor = .secondaryLabel
        createDateLabel.font = .systemFont(ofSize: 12, weight: .regular)
        cell.addSubview(createDateLabel)
        createDateLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
        
        let numbLabel = UILabel()
        numbLabel.textColor = .label
        numbLabel.text = "Aкт №\(item.number)"
        numbLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(numbLabel)
        numbLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
        }
        
        let objectLabel = UILabel()
        objectLabel.text = item.objectsCheck.first?.title ?? ""
        objectLabel.textAlignment = .left
        objectLabel.textColor = .secondaryLabel
        objectLabel.font = .systemFont(ofSize: 14, weight: .regular)
        cell.addSubview(objectLabel)
        objectLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(numbLabel.snp.bottom).inset(-12)
        }
        
        let organizationLabel = UILabel()
        organizationLabel.textAlignment = .left
        organizationLabel.text = item.organization.title
        organizationLabel.textColor = .secondaryLabel
        organizationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        cell.addSubview(organizationLabel)
        organizationLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(objectLabel.snp.bottom).inset(-6)
        }
        
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 32, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.aktArray.count > 0 {
            // Добавляем вибрацию при нажатии
            triggerHapticFeedback()
            
            // Получаем выбранный акт
            let selectedAkt = viewModel.aktArray.reversed()[indexPath.row]
            
            // Открываем акт для редактирования в окне продолжения заполнения
            openAktForEditing(selectedAkt)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let akt = self.viewModel.aktArray.reversed()[indexPath.row]
            
            let generateAction = UIAction(title: "Сформировать акт", image: UIImage(systemName: "doc.text")) { _ in
                self.generateAkt(for: akt)
            }
            
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                if let index = self.viewModel.aktArray.firstIndex(where: {$0.id == self.viewModel.aktArray.reversed()[indexPath.row].id}) {
                    self.viewModel.aktArray.remove(at: index)
                    DataFlowAKT.saveArr(arr:  self.viewModel.aktArray)
                }
                
                collectionView.deleteItems(at: [indexPath])
            }
            
            return UIMenu(title: "", children: [generateAction, deleteAction])
        }
    }

}

// MARK: - QLPreviewControllerDataSource
extension HistoryTabViewController: QLPreviewControllerDataSource {
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return documentURL == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return documentURL! as QLPreviewItem
    }
}
