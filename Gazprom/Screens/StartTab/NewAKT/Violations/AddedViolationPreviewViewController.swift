//
//  AddedViolationPreviewViewController.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import UIKit
import SnapKit

class AddedViolationPreviewViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    
    private let violation: Violations
    
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
    
    private let locationLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemBlue
        label.numberOfLines = 0
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
    
    private let violationTypeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemPurple
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let photosLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .systemOrange
        label.numberOfLines = 1
        return label
    }()
    
    private let formulaFromRulesLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .systemRed
        label.numberOfLines = 0
        label.textAlignment = .left
        return label
    }()
    
    private let photosCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "PhotoCell")
        return collectionView
    }()
    
    init(violation: Violations) {
        self.violation = violation
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Принудительно устанавливаем темную тему для sheet presentation
        if traitCollection.userInterfaceStyle == .dark {
            overrideUserInterfaceStyle = .dark
        }
        
        setupUI()
        configureContent()
        
        // Настройка темной темы
        setupDarkTheme()
    }
    
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        // Устанавливаем черный фон перед закрытием
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            scrollView.backgroundColor = .black
            contentView.backgroundColor = .black
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Настраиваем delegate для presentation controller
        presentationController?.delegate = self
        
        // Устанавливаем черный фон для темной темы, чтобы он был одинаковым в свернутом и развернутом состоянии
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            scrollView.backgroundColor = .black
            contentView.backgroundColor = .black
            
            // Также устанавливаем фон для presentation controller
            if sheetPresentationController != nil {
                // Принудительно обновляем фон
                DispatchQueue.main.async { [weak self] in
                    self?.view.backgroundColor = .black
                    self?.scrollView.backgroundColor = .black
                    self?.contentView.backgroundColor = .black
                }
            }
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Дополнительно устанавливаем фон после появления, чтобы гарантировать правильный цвет в свернутом состоянии
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            scrollView.backgroundColor = .black
            contentView.backgroundColor = .black
        }
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        // Обновляем интерфейс при изменении темы
        if traitCollection.userInterfaceStyle != previousTraitCollection?.userInterfaceStyle {
            setupDarkTheme()
        }
    }
    
    private func setupDarkTheme() {
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            scrollView.backgroundColor = .black
            contentView.backgroundColor = .black
            
            // Обновляем цвета текста для темной темы
            titleLabel.textColor = .white
            locationLabel.textColor = .systemBlue
            referenceLabel.textColor = .systemGreen
            violationTypeLabel.textColor = .systemPurple
            photosLabel.textColor = .systemOrange
            formulaFromRulesLabel.textColor = .systemRed
        } else {
            // Светлая тема
            view.backgroundColor = .systemBackground
            scrollView.backgroundColor = .systemBackground
            contentView.backgroundColor = .systemBackground
            
            titleLabel.textColor = .label
            locationLabel.textColor = .systemBlue
            referenceLabel.textColor = .systemGreen
            violationTypeLabel.textColor = .systemPurple
            photosLabel.textColor = .systemOrange
            formulaFromRulesLabel.textColor = .systemRed
        }
    }
    
    private func setupUI() {
        // Устанавливаем черный фон для темной темы, чтобы он был одинаковым в свернутом и развернутом состоянии
        if traitCollection.userInterfaceStyle == .dark {
            view.backgroundColor = .black
            // Устанавливаем черный фон для всего view, включая область за safe area
            view.layer.backgroundColor = UIColor.black.cgColor
        } else {
            view.backgroundColor = .systemBackground
        }
        
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
        contentView.addSubview(titleLabel)
        contentView.addSubview(locationLabel)
        contentView.addSubview(referenceLabel)
        contentView.addSubview(violationTypeLabel)
        contentView.addSubview(formulaFromRulesLabel)
        contentView.addSubview(photosLabel)
        contentView.addSubview(photosCollectionView)
        
        // Настройка коллекции фотографий
        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.left.right.equalToSuperview().inset(20)
        }
        
        locationLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        referenceLabel.snp.makeConstraints { make in
            make.top.equalTo(locationLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        violationTypeLabel.snp.makeConstraints { make in
            make.top.equalTo(referenceLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        formulaFromRulesLabel.snp.makeConstraints { make in
            make.top.equalTo(violationTypeLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        photosLabel.snp.makeConstraints { make in
            make.top.equalTo(formulaFromRulesLabel.snp.bottom).offset(16)
            make.left.right.equalToSuperview().inset(20)
        }
        
        photosCollectionView.snp.makeConstraints { make in
            make.top.equalTo(photosLabel.snp.bottom).offset(8)
            make.left.right.equalToSuperview().inset(20)
            make.height.equalTo(120)
            make.bottom.equalToSuperview().offset(-20)
        }
    }
    
    private func configureContent() {
        // Заголовок (формулировка нарушения)
        titleLabel.text = violation.title
        
        // Место нарушения
        locationLabel.text = "Место нарушения:\n\(violation.mesto)"
        
        // Ссылка на нормативный документ
        if !violation.urlToPravilo.isEmpty && violation.urlToPravilo != "-" {
            referenceLabel.text = "Ссылка на нормативный документ:\n\(violation.urlToPravilo)"
        } else {
            referenceLabel.text = "Ссылка на нормативный документ не указана"
            referenceLabel.textColor = .tertiaryLabel
        }
        
        // Вид нарушения
        if !violation.vid.isEmpty {
            violationTypeLabel.text = "Вид нарушения:\n\(violation.vid)"
        } else {
            violationTypeLabel.text = "Вид нарушения не указан"
            violationTypeLabel.textColor = .tertiaryLabel
        }
        
        // Формулировка из правил
        if let formulaFromRules = violation.formulaFromRules, !formulaFromRules.isEmpty && formulaFromRules != "-" {
            formulaFromRulesLabel.text = "Формулировка из правил:\n\(formulaFromRules)"
        } else {
            formulaFromRulesLabel.text = "Формулировка из правил не указана"
            formulaFromRulesLabel.textColor = .tertiaryLabel
        }
        
        // Фотографии
        if !violation.photo.isEmpty {
            photosLabel.text = "Фотографии (\(violation.photo.count)):"
            photosCollectionView.isHidden = false
        } else {
            photosLabel.text = "Фотографии не добавлены"
            photosLabel.textColor = .tertiaryLabel
            photosCollectionView.isHidden = true
        }
    }
    
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate
extension AddedViolationPreviewViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return violation.photo.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath)
        
        // Очищаем предыдущие subviews
        cell.subviews.forEach { $0.removeFromSuperview() }
        
        // Создаем imageView
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 8
        imageView.backgroundColor = .systemGray5
        
        // Загружаем изображение из Data
        if let imageData = violation.photo[safe: indexPath.item],
           let image = UIImage(data: imageData) {
            imageView.image = image
        } else {
            imageView.image = UIImage(systemName: "photo")
            imageView.tintColor = .systemGray3
        }
        
        cell.addSubview(imageView)
        imageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: 100, height: 100)
    }
}

// MARK: - Array Extension for Safe Access
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
