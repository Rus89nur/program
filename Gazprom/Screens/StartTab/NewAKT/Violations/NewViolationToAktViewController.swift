//
//  NewViolationToAktViewController.swift
//  Gazprom
//
//  Created by Владимир on 11.07.2025.
//

import UIKit
import PhotosUI

class NewViolationToAktViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let vc: NewViolationViewController
    let model: MainAKTViewModel
    
    var photos: [UIImage] = []
    var violations: [ViolationsModel.Violation] = ViolationsModel.returnAvialableViolation()
    private var filteredViolations: [ViolationsModel.Violation] = []
    
    var selectedViolation: ViolationsModel.Violation?
    var updatedViolatation: Violations?
    
    // Генератор вибрации
    private let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    
    init(vc: NewViolationViewController, model: MainAKTViewModel) {
        self.vc = vc
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    let searchTextField = UISearchTextField()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.isEditing = false
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .white
        return view
    }()
    
    let photoCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.layer.cornerRadius = 24
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.showsHorizontalScrollIndicator = false
        layout.scrollDirection = .horizontal
        return collection
    }()
    
    let mextoTextField: UITextField = {
        let view = UITextField()
        view.backgroundColor = UIColor(red: 242/255, green: 242/255, blue: 242/255, alpha: 1) 
        view.layer.cornerRadius = 12
        view.textColor = .black
        view.placeholder = "Место нарушения"
        let left = UIView(frame: .init(x: 0, y: 0, width: 16, height: 16))
        view.leftView = left
        view.leftViewMode = .always
        
        let right = UIView(frame: .init(x: 0, y: 0, width: 16, height: 16))
        view.rightView = left
        view.rightViewMode = .always
        
        return view
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        // Настройка навигации
        navigationItem.title = "Новое нарушение в акте"
        
        setupUI()
        checkEdit()
        setupLongPressGesture()
    }
    
    private func setupUI() {
        if  ViolationsModel.returnAvialableViolation().count > 0 {
            let plusButton = UIButton(type: .system)
            plusButton.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
            view.addSubview(plusButton)
            plusButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
                make.top.equalTo(view.safeAreaLayoutGuide).inset(16)
                make.right.equalToSuperview().inset(16)
            }
            plusButton.addTarget(self, action: #selector(addNewViol), for: .touchUpInside)
        }
        
        mextoTextField.delegate = self
        view.addSubview(mextoTextField)
        mextoTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide).inset(16)
            make.height.equalTo(42)
        }
        
        view.addSubview(searchTextField)
        searchTextField.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(mextoTextField.snp.bottom).inset(-8)
            make.height.equalTo(42)
        }
        searchTextField.placeholder = "Поиск по формулировке, документу, примечанию..."
        searchTextField.returnKeyType = .done
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
        searchTextField.delegate = self
        
        let doneButton = UIFactory.createButton(title: "Добавить", color: .systemBlue)
        view.addSubview(doneButton)
        doneButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(54)
        }
        doneButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        
        photoCollection.delegate = self
        photoCollection.dataSource = self
        view.addSubview(photoCollection)
        photoCollection.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(doneButton.snp.top).inset(-16)
            make.height.equalTo(200)
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(16)
            make.left.right.equalToSuperview()
            make.bottom.equalTo(photoCollection.snp.top).inset(-16)
        }
        
        filteredViolations = violations

    }
    
    @objc private func addNewViol() {
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
            self.violations = ViolationsModel.returnAvialableViolation()
            self.filteredViolations = self.violations
            searchTextField.text = ""
            tableView.reloadData()
            
        }
        alert.addAction(save)
        
        present(alert, animated: true)
    }
    
    
    @objc private func addNew() {
        
        if let unvItem = updatedViolatation {
            if let index = vc.violations.firstIndex(where: {$0.title == unvItem.title}) {
                selectedViolation = filteredViolations.first(where: {$0.titie ==  vc.violations[index].title})
            }
        }
        
        
        if let item = selectedViolation {
            
            if let updateditem = updatedViolatation {
                if let index = vc.violations.firstIndex(where: {$0.title == updateditem.title}) {
                    selectedViolation = filteredViolations.first(where: {$0.titie ==  vc.violations[index].title})
                    vc.violations[index] =  Violations(title: item.titie, mesto:  mextoTextField.text ?? "Неизвестно", urlToPravilo: item.subTitle, photo: photos.map({$0.jpegData(compressionQuality: 0.5) ?? Data()}))
                }
            } else {
                let violation = Violations(title: item.titie, mesto:  mextoTextField.text ?? "Неизвестно", urlToPravilo: item.subTitle, photo: photos.map({$0.jpegData(compressionQuality: 0.5) ?? Data()}))
                vc.violations.append(violation)
            }
            
            vc.tableView.reloadData()
            
            // Сохраняем черновик после добавления нарушения
            vc.viewModel.templateModel.violations = vc.violations
            vc.viewModel.saveDraft(currentStep: .violations)
            
            self.dismiss(animated: true)
        } else {
            let alert = UIAlertController(title: "Ошибка!", message: "Выберите нарушение", preferredStyle: .alert)
            let ok = UIAlertAction(title: "Хорошо", style: .cancel)
            alert.addAction(ok)
            self.present(alert, animated: true)
        }
    }
    
    func openedMain(violation: Violations) {
        mextoTextField.text = violation.mesto
        self.photos = violation.photo.map({UIImage(data: $0) ?? UIImage()})
        searchTextField.text = violation.title
        photoCollection.reloadData()
    }
    
    func checkEdit() {
        if let item = updatedViolatation {
            openedMain(violation: item)
        }
    }
    
    private func setupLongPressGesture() {
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        tableView.addGestureRecognizer(longPressGesture)
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let location = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: location) else { return }
        
        // Добавляем вибрацию при удержании пальца
        impactFeedback.impactOccurred()
        
        let violation = filteredViolations[indexPath.row]
        showViolationPreview(for: violation)
    }
    
    private func showViolationPreview(for violation: ViolationsModel.Violation) {
        let previewVC = ViolationPreviewViewController(violation: violation)
        previewVC.modalPresentationStyle = .pageSheet
        
        if let sheet = previewVC.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(previewVC, animated: true)
    }
    
    
}

extension NewViolationToAktViewController: UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredViolations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "1")
        let violation = filteredViolations[indexPath.row]
        
        // Подсвечиваем найденный текст в заголовке
        if let searchText = searchTextField.text, !searchText.isEmpty {
            cell.textLabel?.attributedText = highlightText(violation.titie, searchText: searchText)
        } else {
            cell.textLabel?.text = violation.titie
        }
        
        cell.backgroundColor = .white
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.textColor = .black
        
        // Показываем нормативный документ в качестве подзаголовка
        if !violation.subTitle.isEmpty && violation.subTitle != "---" {
            let subtitleText = "📄 \(violation.subTitle)"
            if let searchText = searchTextField.text, !searchText.isEmpty {
                cell.detailTextLabel?.attributedText = highlightText(subtitleText, searchText: searchText)
            } else {
                cell.detailTextLabel?.text = subtitleText
            }
        } else if let description = violation.description, !description.isEmpty && description != "---" {
            let descriptionText = "📝 \(description)"
            if let searchText = searchTextField.text, !searchText.isEmpty {
                cell.detailTextLabel?.attributedText = highlightText(descriptionText, searchText: searchText)
            } else {
                cell.detailTextLabel?.text = descriptionText
            }
        }
        
        return cell
    }
    
    private func highlightText(_ text: String, searchText: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        let _ = NSRange(location: 0, length: text.count)
        
        // Ищем все вхождения поискового текста (без учета регистра)
        let searchRange = text.range(of: searchText, options: .caseInsensitive)
        if let searchRange = searchRange {
            let nsRange = NSRange(searchRange, in: text)
            attributedString.addAttribute(.backgroundColor, value: UIColor.systemGray5, range: nsRange)
            attributedString.addAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), range: nsRange)
        }
        
        return attributedString
    }
    
    @objc private func searchTextChanged(_ textField: UITextField) {
        guard let query = textField.text?.lowercased(), !query.isEmpty else {
            filteredViolations = violations
            tableView.reloadData()
            return
        }
        
        filteredViolations = violations.filter { violation in
            // Поиск по формулировке нарушения
            let titleMatch = violation.titie.lowercased().contains(query)
            
            // Поиск по нормативному документу
            let documentMatch = violation.subTitle.lowercased().contains(query)
            
            // Поиск по примечанию
            let descriptionMatch = violation.description?.lowercased().contains(query) ?? false
            
            // Поиск по виду нарушения
            let typeMatch = violation.vid?.lowercased().contains(query) ?? false
            
            // Поиск по номеру нарушения
            let numberMatch = violation.number?.description.contains(query) ?? false
            
            // Возвращаем true если хотя бы одно поле содержит запрос
            return titleMatch || documentMatch || descriptionMatch || typeMatch || numberMatch
        }
        tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedViolation = filteredViolations[indexPath.row]
        searchTextField.text = selectedViolation?.titie
        view.endEditing(true)
    }
    
//    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        return 100
//    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    @objc private func addTapped() {
        let alert = UIAlertController(title: "Откуда загрузить фото?", message: "", preferredStyle: .alert)
        
        let galAction = UIAlertAction(title: "Из галереи", style: .default) { [weak self] _ in
            self?.presentPhotoPicker()
        }
        alert.addAction(galAction)
        
        let photoAction = UIAlertAction(title: "Сделать фото", style: .default) { [weak self] _ in
            self?.presentImagePicker(sourceType: .camera)
        }
        alert.addAction(photoAction)
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        self.present(alert, animated: true)
    }
    
    private func presentPhotoPicker() {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 0 // 0 = без ограничений
        configuration.filter = .images
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType) {
        guard UIImagePickerController.isSourceTypeAvailable(sourceType) else {
            print("Источник не доступен: \(sourceType)")
            return
        }
        
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = sourceType
        picker.allowsEditing = false
        present(picker, animated: true)
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        
        if let image = info[.originalImage] as? UIImage {
            photos.append(image)
            photoCollection.reloadData()
            print("✅ Фото добавлено")
        } else {
            print("❌ Не удалось получить изображение")
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }
}

// MARK: - PHPickerViewControllerDelegate
extension NewViolationToAktViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        guard !results.isEmpty else { return }
        
        let group = DispatchGroup()
        var newImages: [UIImage] = []
        
        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                defer { group.leave() }
                
                if let image = object as? UIImage {
                    newImages.append(image)
                } else if let error = error {
                    print("❌ Ошибка загрузки изображения: \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) {
            self.photos.append(contentsOf: newImages)
            self.photoCollection.reloadData()
            print("✅ Добавлено \(newImages.count) фотографий")
        }
    }
    
    @objc private func delPhoto(sender: UIButton) {
        photos.remove(at: sender.tag)
        photoCollection.reloadData()
    }
    
}


extension NewViolationToAktViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 24
        cell.backgroundColor = .white
        
        if indexPath.row == photos.count {
            let buttonAdd = UIFactory.createButton(title: "Новое фото", color: .systemBlue.withAlphaComponent(0.2))
            buttonAdd.setTitleColor(.black, for: .normal)
            cell.addSubview(buttonAdd)
            buttonAdd.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            buttonAdd.addTarget(self, action: #selector(addTapped), for: .touchUpInside)
        } else {
            let item = photos[indexPath.row]
            let imageView = UIImageView(image: item)
            imageView.contentMode = .scaleAspectFill
            cell.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let delButton = UIButton(type: .system)
            delButton.tag = indexPath.row
            delButton.setBackgroundImage(UIImage(systemName: "trash.fill")?.withTintColor(.red), for: .normal)
            cell.addSubview(delButton)
            delButton.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.right.top.equalToSuperview().inset(16)
            }
            delButton.addTarget(self, action: #selector(delPhoto(sender:)), for: .touchUpInside)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 200, height: 200)
    }
    
}
