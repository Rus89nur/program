//
//  ViolationPreviewViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit

class ViolationPreviewViewController: UIViewController {
    
    private let violation: ViolationsModel.Violation
    
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.showsVerticalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let numberLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemBlue
        label.numberOfLines = 1
        return label
    }()
    
    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let referenceLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemGreen
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let typeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemOrange
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    init(violation: ViolationsModel.Violation) {
        self.violation = violation
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
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Настройка навигации
        navigationItem.title = "Предварительный просмотр"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeButtonTapped)
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
        
        // Добавление лейблов
        contentView.addSubview(numberLabel)
        contentView.addSubview(titleLabel)
        contentView.addSubview(descriptionLabel)
        contentView.addSubview(referenceLabel)
        contentView.addSubview(typeLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        numberLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(numberLabel.snp.bottom).offset(12)
            make.left.right.equalToSuperview().inset(20)
        }
        
        descriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        referenceLabel.snp.makeConstraints { make in
            make.top.equalTo(descriptionLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        typeLabel.snp.makeConstraints { make in
            make.top.equalTo(referenceLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureContent() {
        // Номер нарушения
        if let number = violation.number {
            numberLabel.text = "№ \(number)"
        } else {
            numberLabel.text = "№ не указан"
        }
        
        // Заголовок (формулировка)
        titleLabel.text = violation.titie
        
        // Примечание
        if let description = violation.description, !description.isEmpty && description != "-" {
            descriptionLabel.text = "Примечание:\n\(description)"
        } else {
            descriptionLabel.text = "Примечание не указано"
            descriptionLabel.textColor = .tertiaryLabel
        }
        
        // Ссылка на нормативный документ
        if !violation.subTitle.isEmpty && violation.subTitle != "-" {
            referenceLabel.text = "Ссылка на нормативный документ:\n\(violation.subTitle)"
        } else {
            referenceLabel.text = "Ссылка на нормативный документ не указана"
            referenceLabel.textColor = .tertiaryLabel
        }
        
        // Вид нарушения
        if let vid = violation.vid, !vid.isEmpty && vid != "-" {
            typeLabel.text = "Вид нарушения:\n\(vid)"
        } else {
            typeLabel.text = "Вид нарушения не указан"
            typeLabel.textColor = .tertiaryLabel
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}
