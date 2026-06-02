//
//  UIFactory.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation
import UIKit
import SnapKit

class UIFactory {
    
    static func createButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        return button
    }
    
    /// Единая плавающая кнопка фильтра по году (История, Устранение, Отчёты, График): синяя, с тенью, 56×56.
    /// При «все годы» показывайте на кнопке иконку календаря; при выбранном годе — текст года.
    static func createYearFilterButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.backgroundColor = .systemBlue
        button.tintColor = .white
        button.layer.cornerRadius = 28
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowOffset = CGSize(width: 0, height: 2)
        button.layer.shadowRadius = 6
        return button
    }
    
    static func createlabel(title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .label
        return label
    }
    
    static func createTextField(placeholder: String) -> UITextField {
        let view = UITextField()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 14
        view.textColor = .label
        view.font = .systemFont(ofSize: 16, weight: .regular)
        
        // Настройка золотого курсора для всех текстовых полей
        view.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой цвет
    
        // Создаем UIView с безопасными размерами для предотвращения NaN ошибок
        let safeSize: CGFloat = 10.0
        let safeFrame = NumberValidation.safeCGRect(x: 0, y: 0, width: safeSize, height: safeSize)
        
        view.leftView = UIView(frame: safeFrame)
        view.leftViewMode = .always
        
        view.rightView = UIView(frame: safeFrame)
        view.rightViewMode = .always
        
        view.attributedPlaceholder = NSAttributedString(
               string: placeholder,
               attributes: [
                   .foregroundColor: UIColor.placeholderText,
                   .font: UIFont.systemFont(ofSize: 16, weight: .regular)
               ]
           )
        
        return view
    }
    
    static func showAlert(vc: UIViewController, title: String, description: String) {
        let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Хорошо", style: .cancel)
        alert.addAction(okAction)
        vc.present(alert, animated: true)
    }
    
    // MARK: - Loading Indicators
    
    /// Создает полноэкранный индикатор загрузки с полупрозрачным фоном
    static func createFullScreenLoadingIndicator(message: String = "Загрузка...") -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.8)
        containerView.tag = 1000 // Уникальный тег для идентификации
        
        // Создаем контейнер для индикатора и текста
        let contentView = UIView()
        contentView.backgroundColor = UIColor.systemGray6
        contentView.layer.cornerRadius = 16
        contentView.layer.shadowColor = UIColor.black.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 2)
        contentView.layer.shadowRadius = 8
        contentView.layer.shadowOpacity = 0.1
        containerView.addSubview(contentView)
        
        // Индикатор загрузки
        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .systemBlue
        activityIndicator.startAnimating()
        contentView.addSubview(activityIndicator)
        
        // Текст загрузки
        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = .systemFont(ofSize: 16, weight: .medium)
        messageLabel.textColor = .label
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        contentView.addSubview(messageLabel)
        
        // Настройка constraints
        contentView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.lessThanOrEqualTo(280)
            make.height.greaterThanOrEqualTo(120)
        }
        
        activityIndicator.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalToSuperview().offset(20)
        }
        
        messageLabel.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.top.equalTo(activityIndicator.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        return containerView
    }
    
    /// Создает компактный индикатор загрузки для кнопок
    static func createButtonLoadingIndicator() -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.color = .white
        activityIndicator.startAnimating()
        containerView.addSubview(activityIndicator)
        
        activityIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(20)
        }
        
        return containerView
    }
    
    /// Показывает индикатор загрузки на указанном view
    static func showLoadingIndicator(on view: UIView, message: String = "Загрузка...") -> UIView {
        let loadingView = createFullScreenLoadingIndicator(message: message)
        view.addSubview(loadingView)
        loadingView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return loadingView
    }
    
    /// Скрывает индикатор загрузки
    static func hideLoadingIndicator(from view: UIView) {
        view.subviews.forEach { subview in
            if subview.tag == 1000 {
                subview.removeFromSuperview()
            }
        }
    }
    
}
