//
//  EditViolationViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit
import PhotosUI

class EditViolationViewController: UIViewController {
    
    private let violation: Violations
    private let onSave: (Violations) -> Void
    private var photos: [UIImage] = []
    private var violations: [ViolationsModel.Violation] = ViolationsModel.returnAvialableViolation()
    private var filteredViolations: [ViolationsModel.Violation] = []
    private var selectedViolation: ViolationsModel.Violation?
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    
    private let violationTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "Формулировка нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let textView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        return textView
    }()
    
    private let characterCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // Поле для места нарушения
    private let mestoLabel: UILabel = {
        let label = UILabel()
        label.text = "Место нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let mestoTextField: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textColor = .label
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        return textView
    }()
    
    // Поле для выбора пункта нарушения
    private let violationPointLabel: UILabel = {
        let label = UILabel()
        label.text = "Пункт нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let violationPointTextField: UITextView = {
        let textView = UITextView()
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textColor = .label
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.isUserInteractionEnabled = true
        return textView
    }()
    
    private let violationPointButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Выбрать пункт", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 8
        return button
    }()
    
    // Коллекция фотографий
    private let photosLabel: UILabel = {
        let label = UILabel()
        label.text = "Фотографии:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let photoCollection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.layer.cornerRadius = 12
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        collection.showsHorizontalScrollIndicator = false
        layout.scrollDirection = .horizontal
        return collection
    }()
    
    // Строка поиска для выбора пункта нарушения
    private let searchTextField: UISearchTextField = {
        let textField = UISearchTextField()
        textField.placeholder = "Поиск по формулировке, документу, примечанию..."
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.isHidden = true
        return textField
    }()
    
    // Таблица для выбора пункта нарушения
    private let tableView: UITableView = {
        let tableView = UITableView()
        tableView.backgroundColor = .systemBackground
        tableView.layer.cornerRadius = 12
        tableView.layer.borderWidth = 1
        tableView.layer.borderColor = UIColor.systemGray4.cgColor
        tableView.isHidden = true
        return tableView
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Сохранить", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 12
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Отмена", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 12
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        return button
    }()
    
    init(violation: Violations, onSave: @escaping (Violations) -> Void) {
        self.violation = violation
        self.onSave = onSave
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        configureContent()
        setupKeyboardObservers()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Настройка навигации
        navigationItem.title = "Редактирование нарушения"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Настройка клавиатуры с кнопкой "Готово"
        setupKeyboardToolbar()
        
        // Добавление scroll view
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.leading.trailing.bottom.equalToSuperview()
            make.width.equalTo(scrollView.snp.width)
        }
        
        // Добавление элементов
        contentView.addSubview(mestoLabel)
        contentView.addSubview(mestoTextField)
        contentView.addSubview(violationTitleLabel)
        contentView.addSubview(textView)
        contentView.addSubview(characterCountLabel)
        contentView.addSubview(violationPointLabel)
        contentView.addSubview(violationPointTextField)
        contentView.addSubview(violationPointButton)
        contentView.addSubview(photosLabel)
        contentView.addSubview(photoCollection)
        contentView.addSubview(searchTextField)
        contentView.addSubview(tableView)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        
        setupConstraints()
        setupActions()
        setupDelegates()
    }
    
    private func setupConstraints() {
        // Место нарушения
        mestoLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        mestoTextField.snp.makeConstraints { make in
            make.top.equalTo(mestoLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        // Формулировка нарушения
        violationTitleLabel.snp.makeConstraints { make in
            make.top.equalTo(mestoTextField.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        textView.snp.makeConstraints { make in
            make.top.equalTo(violationTitleLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        characterCountLabel.snp.makeConstraints { make in
            make.top.equalTo(textView.snp.bottom).offset(8)
            make.right.equalToSuperview().inset(20)
        }
        
        // Пункт нарушения
        violationPointLabel.snp.makeConstraints { make in
            make.top.equalTo(characterCountLabel.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        violationPointTextField.snp.makeConstraints { make in
            make.top.equalTo(violationPointLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        violationPointButton.snp.makeConstraints { make in
            make.top.equalTo(violationPointTextField.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(36)
        }
        
        // Фотографии
        photosLabel.snp.makeConstraints { make in
            make.top.equalTo(violationPointButton.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        photoCollection.snp.makeConstraints { make in
            make.top.equalTo(photosLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(120)
        }
        
        // Строка поиска для выбора пункта нарушения
        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(violationPointButton.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(44)
        }
        
        // Таблица выбора пункта нарушения
        tableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(200)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(photoCollection.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        
        cancelButton.snp.makeConstraints { make in
            make.top.equalTo(saveButton.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func setupActions() {
        saveButton.addTarget(self, action: #selector(saveButtonTapped), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        violationPointButton.addTarget(self, action: #selector(violationPointButtonTapped), for: .touchUpInside)
        
        // Добавляем обработчик изменения текста
        textView.delegate = self
    }
    
    private func setupDelegates() {
        photoCollection.delegate = self
        photoCollection.dataSource = self
        tableView.delegate = self
        tableView.dataSource = self
        mestoTextField.delegate = self
        violationPointTextField.delegate = self
        searchTextField.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
    }
    
    private func configureContent() {
        mestoTextField.text = violation.mesto
        textView.text = violation.title
        violationPointTextField.text = violation.urlToPravilo
        
        // Загружаем фотографии
        photos = violation.photo.compactMap { UIImage(data: $0) }
        photoCollection.reloadData()
        
        // Инициализируем список нарушений
        filteredViolations = violations
        
        updateCharacterCount()
    }
    
    private func setupKeyboardToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let doneButton = UIBarButtonItem(
            title: "Готово",
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        
        // Настройка цвета кнопки "Готово" для ночного режима
        doneButton.setTitleTextAttributes([
            .foregroundColor: UIColor.systemBlue
        ], for: .normal)
        
        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )
        
        toolbar.items = [flexibleSpace, doneButton]
        
        // Применяем toolbar ко всем текстовым полям
        textView.inputAccessoryView = toolbar
        mestoTextField.inputAccessoryView = toolbar
        violationPointTextField.inputAccessoryView = toolbar
        searchTextField.inputAccessoryView = toolbar
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }
    
    private func updateCharacterCount() {
        let count = textView.text.count
        characterCountLabel.text = "\(count) символов"
    }
    
    @objc private func saveButtonTapped() {
        let newMesto = mestoTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTitle = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let newUrlToPravilo = violationPointTextField.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if newMesto.isEmpty {
            showAlert(title: "Ошибка", message: "Место нарушения не может быть пустым")
            return
        }
        
        if newTitle.isEmpty {
            showAlert(title: "Ошибка", message: "Название нарушения не может быть пустым")
            return
        }
        
        if newUrlToPravilo.isEmpty {
            showAlert(title: "Ошибка", message: "Пункт нарушения не может быть пустым")
            return
        }
        
        // Создаем обновленное нарушение
        let updatedViolation = Violations(
            title: newTitle,
            mesto: newMesto,
            urlToPravilo: newUrlToPravilo,
            photo: photos.map { $0.jpegData(compressionQuality: 0.5) ?? Data() }
        )
        
        onSave(updatedViolation)
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func violationPointButtonTapped() {
        let isHidden = tableView.isHidden
        tableView.isHidden = !isHidden
        searchTextField.isHidden = !isHidden
        
        if !isHidden {
            // Скрываем элементы
            searchTextField.text = ""
            filteredViolations = violations
        } else {
            // Показываем элементы
            tableView.reloadData()
            searchTextField.becomeFirstResponder()
        }
    }
    
    @objc private func addPhotoTapped() {
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
        
        present(alert, animated: true)
    }
    
    @objc private func deletePhotoTapped(_ sender: UIButton) {
        photos.remove(at: sender.tag)
        photoCollection.reloadData()
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
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension EditViolationViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCount()
    }
}

// MARK: - UITextFieldDelegate
extension EditViolationViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - PHPickerViewControllerDelegate
extension EditViolationViewController: PHPickerViewControllerDelegate {
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
}

// MARK: - UIImagePickerControllerDelegate
extension EditViolationViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
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

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension EditViolationViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 12
        cell.backgroundColor = .white
        
        if indexPath.row == photos.count {
            let buttonAdd = UIButton(type: .system)
            buttonAdd.setTitle("+", for: .normal)
            buttonAdd.titleLabel?.font = .systemFont(ofSize: 24, weight: .bold)
            buttonAdd.setTitleColor(.systemBlue, for: .normal)
            buttonAdd.backgroundColor = .systemGray6
            buttonAdd.layer.cornerRadius = 12
            cell.addSubview(buttonAdd)
            buttonAdd.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            buttonAdd.addTarget(self, action: #selector(addPhotoTapped), for: .touchUpInside)
        } else {
            let item = photos[indexPath.row]
            let imageView = UIImageView(image: item)
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.layer.cornerRadius = 12
            cell.addSubview(imageView)
            imageView.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            
            let delButton = UIButton(type: .system)
            delButton.tag = indexPath.row
            delButton.setBackgroundImage(UIImage(systemName: "trash.fill")?.withTintColor(.red), for: .normal)
            cell.addSubview(delButton)
            delButton.snp.makeConstraints { make in
                make.height.width.equalTo(24)
                make.right.top.equalToSuperview().inset(8)
            }
            delButton.addTarget(self, action: #selector(deletePhotoTapped(_:)), for: .touchUpInside)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}

// MARK: - UITableViewDataSource, UITableViewDelegate
extension EditViolationViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredViolations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "ViolationCell")
        let violation = filteredViolations[indexPath.row]
        
        cell.textLabel?.text = violation.titie
        cell.detailTextLabel?.text = violation.subTitle
        cell.backgroundColor = .systemBackground
        cell.textLabel?.textColor = .label
        cell.detailTextLabel?.textColor = .secondaryLabel
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let violation = filteredViolations[indexPath.row]
        selectedViolation = violation
        violationPointTextField.text = violation.subTitle
        tableView.isHidden = true
        searchTextField.isHidden = true
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
}
