//
//  SettingsEditViolationViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit

class SettingsEditViolationViewController: UIViewController {
    
    private let violation: ViolationsModel.Violation
    private let onSave: (ViolationsModel.Violation) -> Void
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    
    // Номер нарушения
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.text = "Номер нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let numberTextField: UITextField = {
        let textField = UITextField()
        textField.backgroundColor = .systemGray6
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1
        textField.layer.borderColor = UIColor.systemGray4.cgColor
        textField.textColor = .label
        textField.font = .systemFont(ofSize: 16, weight: .regular)
        textField.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        textField.rightViewMode = .always
        textField.keyboardType = .numberPad
        return textField
    }()
    
    // Формулировка нарушения
    private let formulationLabel: UILabel = {
        let label = UILabel()
        label.text = "Формулировка нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let formulationTextView: UITextView = {
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
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
    }()
    
    // Ссылка на нормативный документ
    private let referenceLabel: UILabel = {
        let label = UILabel()
        label.text = "Ссылка на нормативный документ:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let referenceTextView: UITextView = {
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
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
    }()
    
    // Примечание
    private let noteLabel: UILabel = {
        let label = UILabel()
        label.text = "Примечание:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let noteTextView: UITextView = {
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
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
    }()
    
    // Вид нарушения
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.text = "Вид нарушения:"
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let typeTextView: UITextView = {
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
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
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
    
    init(violation: ViolationsModel.Violation, onSave: @escaping (ViolationsModel.Violation) -> Void) {
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
        
        // Настройка темной темы
        setupDarkTheme()
        
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
        
        // Добавление обработчика нажатия вне поля ввода
        setupTapGesture()
        
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
        contentView.addSubview(numberLabel)
        contentView.addSubview(numberTextField)
        contentView.addSubview(formulationLabel)
        contentView.addSubview(formulationTextView)
        contentView.addSubview(referenceLabel)
        contentView.addSubview(referenceTextView)
        contentView.addSubview(noteLabel)
        contentView.addSubview(noteTextView)
        contentView.addSubview(typeLabel)
        contentView.addSubview(typeTextView)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        
        setupConstraints()
        setupActions()
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .systemBackground
            scrollView.backgroundColor = .systemBackground
            contentView.backgroundColor = .systemBackground
        }
    }
    
    private func setupConstraints() {
        // Номер нарушения
        numberLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        numberTextField.snp.makeConstraints { make in
            make.top.equalTo(numberLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        
        // Формулировка нарушения
        formulationLabel.snp.makeConstraints { make in
            make.top.equalTo(numberTextField.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        formulationTextView.snp.makeConstraints { make in
            make.top.equalTo(formulationLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        // Ссылка на нормативный документ
        referenceLabel.snp.makeConstraints { make in
            make.top.equalTo(formulationTextView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        referenceTextView.snp.makeConstraints { make in
            make.top.equalTo(referenceLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        // Примечание
        noteLabel.snp.makeConstraints { make in
            make.top.equalTo(referenceTextView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        noteTextView.snp.makeConstraints { make in
            make.top.equalTo(noteLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        // Вид нарушения
        typeLabel.snp.makeConstraints { make in
            make.top.equalTo(noteTextView.snp.bottom).offset(30)
            make.left.right.equalToSuperview().inset(20)
        }
        
        typeTextView.snp.makeConstraints { make in
            make.top.equalTo(typeLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(typeTextView.snp.bottom).offset(30)
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
        
        // Настраиваем делегаты для текстовых полей
        numberTextField.delegate = self
        formulationTextView.delegate = self
        referenceTextView.delegate = self
        noteTextView.delegate = self
        typeTextView.delegate = self
    }
    
    private func configureContent() {
        numberTextField.text = violation.number?.description ?? ""
        formulationTextView.text = violation.titie
        referenceTextView.text = violation.subTitle
        noteTextView.text = violation.description
        typeTextView.text = violation.vid
    }
    
    private func setupKeyboardToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let doneButton = UIBarButtonItem(
            title: "Готово",
            style: .done,
            target: self,
            action: #selector(dismissKeyboard)
        )
        
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
        formulationTextView.inputAccessoryView = toolbar
        referenceTextView.inputAccessoryView = toolbar
        noteTextView.inputAccessoryView = toolbar
        typeTextView.inputAccessoryView = toolbar
        numberTextField.inputAccessoryView = toolbar
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
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
    
    @objc private func saveButtonTapped() {
        let number: Int = Int(numberTextField.text ?? "0") ?? 0
        let formulation = formulationTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let reference = referenceTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = noteTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let type = typeTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if formulation.isEmpty {
            showAlert(title: "Ошибка", message: "Формулировка нарушения не может быть пустой")
            return
        }
        
        if reference.isEmpty {
            showAlert(title: "Ошибка", message: "Ссылка на нормативный документ не может быть пустой")
            return
        }
        
        // Создаем обновленное нарушение
        let updatedViolation = ViolationsModel.Violation(
            number: number,
            titie: formulation,
            subTitle: reference,
            description: note.isEmpty ? nil : note,
            vid: type.isEmpty ? nil : type
        )
        
        print("🔍 Сохраняем нарушение:")
        print("   Номер: \(number)")
        print("   Формулировка: \(formulation)")
        print("   Ссылка: \(reference)")
        print("   Примечание: \(note.isEmpty ? "nil" : note)")
        print("   Вид: \(type.isEmpty ? "nil" : type)")
        
        onSave(updatedViolation)
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        
        // Прокручиваем к активному текстовому полю
        DispatchQueue.main.async {
            self.scrollToActiveField()
        }
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
    
    private func scrollToActiveField() {
        var activeField: UIView?
        
        if numberTextField.isFirstResponder {
            activeField = numberTextField
        } else if formulationTextView.isFirstResponder {
            activeField = formulationTextView
        } else if referenceTextView.isFirstResponder {
            activeField = referenceTextView
        } else if noteTextView.isFirstResponder {
            activeField = noteTextView
        } else if typeTextView.isFirstResponder {
            activeField = typeTextView
        }
        
        guard let field = activeField else { return }
        scrollToView(field)
    }
    
    private func scrollToView(_ view: UIView) {
        // Получаем frame поля в координатах scrollView
        let viewFrame = view.convert(view.bounds, to: scrollView)
        
        // Вычисляем отступ сверху, чтобы поле было видно над клавиатурой
        let targetY = viewFrame.minY - 20 // 20pt отступ сверху
        
        // Прокручиваем к нужной позиции
        let contentOffset = CGPoint(x: 0, y: max(0, targetY))
        scrollView.setContentOffset(contentOffset, animated: true)
    }
}

// MARK: - UITextFieldDelegate
extension SettingsEditViolationViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Прокручиваем к текстовому полю при начале редактирования
        DispatchQueue.main.async {
            self.scrollToView(textField)
        }
    }
}

// MARK: - UITextViewDelegate
extension SettingsEditViolationViewController: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Прокручиваем к текстовому полю при начале редактирования
        DispatchQueue.main.async {
            self.scrollToView(textView)
        }
    }
}
