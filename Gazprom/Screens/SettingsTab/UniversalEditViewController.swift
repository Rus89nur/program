//
//  UniversalEditViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit

enum EditType {
    case singleField(title: String, placeholder: String, currentValue: String)
    case doubleField(title1: String, placeholder1: String, currentValue1: String,
                     title2: String, placeholder2: String, currentValue2: String)
}

class UniversalEditViewController: UIViewController {
    
    private let editType: EditType
    private let onSave: (String, String?) -> Void
    
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
    
    
    // Первое поле
    private let firstFieldLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let firstTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
    }()
    
    private let firstCharacterCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    // Второе поле (для двойных записей)
    private let secondFieldLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        return label
    }()
    
    private let secondTextView: UITextView = {
        let textView = UITextView()
        textView.font = .systemFont(ofSize: 16, weight: .regular)
        textView.textColor = .label
        textView.backgroundColor = .systemGray6
        textView.layer.cornerRadius = 12
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.systemGray4.cgColor
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.isScrollEnabled = true
        textView.showsVerticalScrollIndicator = true
        textView.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой курсор
        return textView
    }()
    
    private let secondCharacterCountLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()
    
    private let saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Сохранить", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 16
        button.layer.shadowColor = UIColor.systemBlue.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 4
        return button
    }()
    
    private let cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Отмена", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.setTitleColor(.systemBlue, for: .normal)
        button.backgroundColor = .systemGray6
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.systemGray4.cgColor
        return button
    }()
    
    init(editType: EditType, onSave: @escaping (String, String?) -> Void) {
        self.editType = editType
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
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Настройка навигации
        navigationItem.title = "Редактирование"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Отмена",
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        
        // Добавление scroll view
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalTo(view.safeAreaLayoutGuide)
        }
        
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalToSuperview()
        }
        
        // Добавление элементов
        contentView.addSubview(firstFieldLabel)
        contentView.addSubview(firstTextView)
        contentView.addSubview(firstCharacterCountLabel)
        contentView.addSubview(secondFieldLabel)
        contentView.addSubview(secondTextView)
        contentView.addSubview(secondCharacterCountLabel)
        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        
        setupConstraints()
        setupActions()
        setupKeyboardHandling()
    }
    
    private func setupKeyboardHandling() {
        // Добавляем обработчик появления/скрытия клавиатуры
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
        
        // Настраиваем toolbar для клавиатуры
        setupKeyboardToolbar()
        
        // Добавляем обработчик нажатия вне поля ввода
        setupTapGesture()
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
        firstTextView.inputAccessoryView = toolbar
        secondTextView.inputAccessoryView = toolbar
    }
    
    private func setupTapGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tapGesture.cancelsTouchesInView = false
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue else { return }
        let keyboardHeight = keyboardFrame.cgRectValue.height
        
        // Обновляем contentInset для scrollView
        scrollView.contentInset.bottom = keyboardHeight
        scrollView.verticalScrollIndicatorInsets.bottom = keyboardHeight
        
        // Прокручиваем к активному текстовому полю
        DispatchQueue.main.async {
            if self.firstTextView.isFirstResponder {
                self.scrollToTextView(self.firstTextView)
            } else if self.secondTextView.isFirstResponder {
                self.scrollToTextView(self.secondTextView)
            }
        }
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        // Сбрасываем contentInset при скрытии клавиатуры
        scrollView.contentInset.bottom = 0
        scrollView.verticalScrollIndicatorInsets.bottom = 0
    }
    
    private func scrollToTextView(_ textView: UITextView) {
        // Получаем frame текстового поля в координатах scrollView
        let textViewFrame = textView.convert(textView.bounds, to: scrollView)
        
        // Вычисляем отступ сверху, чтобы поле было видно над клавиатурой
        let targetY = textViewFrame.minY - 20 // 20pt отступ сверху
        
        // Прокручиваем к нужной позиции
        let contentOffset = CGPoint(x: 0, y: max(0, targetY))
        scrollView.setContentOffset(contentOffset, animated: true)
    }
    
    private func setupConstraints() {
        firstFieldLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        firstTextView.snp.makeConstraints { make in
            make.top.equalTo(firstFieldLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        firstCharacterCountLabel.snp.makeConstraints { make in
            make.top.equalTo(firstTextView.snp.bottom).offset(8)
            make.right.equalToSuperview().inset(20)
        }
        
        // Устанавливаем constraints для второго поля, но они будут пересозданы в configureContent
        secondFieldLabel.snp.makeConstraints { make in
            make.top.equalTo(firstCharacterCountLabel.snp.bottom).offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        secondTextView.snp.makeConstraints { make in
            make.top.equalTo(secondFieldLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
            make.height.greaterThanOrEqualTo(120)
        }
        
        secondCharacterCountLabel.snp.makeConstraints { make in
            make.top.equalTo(secondTextView.snp.bottom).offset(8)
            make.right.equalToSuperview().inset(20)
        }
        
        saveButton.snp.makeConstraints { make in
            make.top.equalTo(secondCharacterCountLabel.snp.bottom).offset(30)
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
        
        // Добавляем обработчики изменения текста
        firstTextView.delegate = self
        secondTextView.delegate = self
    }
    
    private func configureContent() {
        switch editType {
        case .singleField(let title, let placeholder, let currentValue):
            firstFieldLabel.text = "\(title):"
            firstTextView.text = currentValue
            setupPlaceholder(for: firstTextView, placeholder: placeholder)
            
            // Скрываем второе поле
            secondFieldLabel.isHidden = true
            secondTextView.isHidden = true
            secondCharacterCountLabel.isHidden = true
            
            // Обновляем констрейнты для одного поля
            saveButton.snp.remakeConstraints { make in
                make.top.equalTo(firstCharacterCountLabel.snp.bottom).offset(30)
                make.left.right.equalToSuperview().inset(20)
                make.height.equalTo(50)
            }
            
            cancelButton.snp.remakeConstraints { make in
                make.top.equalTo(saveButton.snp.bottom).offset(12)
                make.left.right.equalToSuperview().inset(20)
                make.height.equalTo(50)
                make.bottom.equalToSuperview().offset(-20)
            }
            
        case .doubleField(let title1, let placeholder1, let currentValue1,
                          let title2, let placeholder2, let currentValue2):
            firstFieldLabel.text = "\(title1):"
            firstTextView.text = currentValue1
            setupPlaceholder(for: firstTextView, placeholder: placeholder1)
            
            secondFieldLabel.text = "\(title2):"
            secondTextView.text = currentValue2
            setupPlaceholder(for: secondTextView, placeholder: placeholder2)
            
            // Показываем второе поле
            secondFieldLabel.isHidden = false
            secondTextView.isHidden = false
            secondCharacterCountLabel.isHidden = false
            
            // Обновляем констрейнты для двух полей
            saveButton.snp.remakeConstraints { make in
                make.top.equalTo(secondCharacterCountLabel.snp.bottom).offset(30)
                make.left.right.equalToSuperview().inset(20)
                make.height.equalTo(50)
            }
            
            cancelButton.snp.remakeConstraints { make in
                make.top.equalTo(saveButton.snp.bottom).offset(12)
                make.left.right.equalToSuperview().inset(20)
                make.height.equalTo(50)
                make.bottom.equalToSuperview().offset(-20)
            }
        }
        
        updateCharacterCounts()
        
        // Устанавливаем курсор в конец первого текста, но не вызываем клавиатуру автоматически
        DispatchQueue.main.async {
            let endPosition = self.firstTextView.endOfDocument
            self.firstTextView.selectedTextRange = self.firstTextView.textRange(from: endPosition, to: endPosition)
        }
    }
    
    private func setupPlaceholder(for textView: UITextView, placeholder: String) {
        let placeholderLabel = UILabel()
        placeholderLabel.text = placeholder
        placeholderLabel.font = textView.font
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.tag = 100
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        textView.addSubview(placeholderLabel)
        
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: textView.topAnchor, constant: 16),
            placeholderLabel.leadingAnchor.constraint(equalTo: textView.leadingAnchor, constant: 16),
            placeholderLabel.trailingAnchor.constraint(equalTo: textView.trailingAnchor, constant: -16)
        ])
        
        // Скрываем placeholder если есть текст
        placeholderLabel.isHidden = !textView.text.isEmpty
        
        // Добавляем наблюдатель за изменением текста
        NotificationCenter.default.addObserver(
            forName: UITextView.textDidChangeNotification,
            object: textView,
            queue: .main
        ) { _ in
            placeholderLabel.isHidden = !textView.text.isEmpty
        }
    }
    
    
    private func updateCharacterCounts() {
        let firstCount = firstTextView.text.count
        firstCharacterCountLabel.text = "\(firstCount) символов"
        
        if !secondTextView.isHidden {
            let secondCount = secondTextView.text.count
            secondCharacterCountLabel.text = "\(secondCount) символов"
        }
    }
    
    @objc private func saveButtonTapped() {
        let firstValue = firstTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if firstValue.isEmpty {
            showAlert(title: "Ошибка", message: "Первое поле не может быть пустым")
            return
        }
        
        let secondValue: String?
        if !secondTextView.isHidden {
            let second = secondTextView.text.trimmingCharacters(in: .whitespacesAndNewlines)
            secondValue = second.isEmpty ? nil : second
        } else {
            secondValue = nil
        }
        
        onSave(firstValue, secondValue)
        dismiss(animated: true)
    }
    
    @objc private func cancelButtonTapped() {
        dismiss(animated: true)
    }
    
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITextViewDelegate
extension UniversalEditViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        updateCharacterCounts()
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        // Прокручиваем к текстовому полю при начале редактирования
        DispatchQueue.main.async {
            self.scrollToTextView(textView)
        }
    }
}

