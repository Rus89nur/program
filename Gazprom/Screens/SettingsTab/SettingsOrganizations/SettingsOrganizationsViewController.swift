//
//  SettingsOrganizationsViewController.swift
//  Gazprom
//
//  Created by Владимир on 01.08.2025.
//

import UIKit

class SettingsOrganizationsViewController: UIViewController {
    
    let model: MainAKTViewModel
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 16, left: 0, bottom: 100, right: 0)
        layout.scrollDirection = .vertical
        return collection
    }()
    
    
    init(model: MainAKTViewModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Организации"
        
        let plusButton = UIButton(type: .system)
        plusButton.setBackgroundImage(UIImage(systemName: "plus"), for: .normal)
        plusButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        plusButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        let item = UIBarButtonItem(customView: plusButton)
        self.navigationItem.setRightBarButton(item, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        collectionView.delegate = self
        collectionView.dataSource = self
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
    }
    
    @objc private func addNew() {
        let alert = UIAlertController(title: "Добавление новой организации", message: "Введите название", preferredStyle: .alert)
        alert.addTextField()
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        let save = UIAlertAction(title: "Добавить", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let text = alert.textFields?.first?.text {
                let newOrg = Organization(title: text)
                model.organizationsArray.append(newOrg)
                DataFlowOrganizations.saveArr(arr: model.organizationsArray)
                collectionView.reloadData()
            }
        }
        alert.addAction(save)
        
        self.present(alert, animated: true)
    }
    

}

extension SettingsOrganizationsViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return model.organizationsArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .systemGray6
        cell.clipsToBounds = true
        cell.layer.cornerRadius = 20
        
        let item = model.organizationsArray[indexPath.row]
        
        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.textAlignment = .left
        titleLabel.textColor = .label
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview().inset(16)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 32, height: 60)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        showEditAlert(for: indexPath)
    }
    
    // MARK: - Long Press Actions
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                self.showDeleteConfirmation(for: indexPath)
            }
            
            return UIMenu(title: "", children: [deleteAction])
        }
    }
    
    private func showDeleteConfirmation(for indexPath: IndexPath) {
        let alert = UIAlertController(title: "Удаление", message: "Вы уверены, что хотите удалить эту запись?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.model.organizationsArray.remove(at: indexPath.row)
            DataFlowOrganizations.saveArr(arr: self.model.organizationsArray)
            self.collectionView.deleteItems(at: [indexPath])
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    
    private func showEditAlert(for indexPath: IndexPath) {
        let organization = model.organizationsArray[indexPath.row]
        let editType = EditType.singleField(
            title: "Организация",
            placeholder: "Введите название организации",
            currentValue: organization.title
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, _ in
            guard let self = self else { return }
            self.model.updateOrganization(at: indexPath.row, newTitle: newTitle) { success in
                DispatchQueue.main.async {
                    if success {
                        self.collectionView.reloadData()
                    } else {
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Организация с таким названием уже существует", preferredStyle: .alert)
                        let ok = UIAlertAction(title: "OK", style: .cancel)
                        errorAlert.addAction(ok)
                        self.present(errorAlert, animated: true)
                    }
                }
            }
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
