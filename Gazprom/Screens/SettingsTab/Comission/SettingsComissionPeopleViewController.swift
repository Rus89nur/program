//
//  ComissionPeopleViewController.swift
//  Gazprom
//
//  Created by Владимир on 01.08.2025.
//

import UIKit
import SnapKit

class SettingsComissionPeopleViewController: UIViewController {
    let model: MainAKTViewModel
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ComissionCell")
        tableView.contentInset = .init(top: 16, left: 0, bottom: 100, right: 0)
        return tableView
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
        title = "Члены комиссии"
        
        // Устанавливаем кнопку "назад" только со стрелочкой без текста
        if let navController = navigationController, navController.viewControllers.count > 1 {
            let previousVC = navController.viewControllers[navController.viewControllers.count - 2]
            let backButton = UIBarButtonItem(title: "", style: .plain, target: nil, action: nil)
            previousVC.navigationItem.backBarButtonItem = backButton
            previousVC.navigationItem.backButtonTitle = ""
            previousVC.navigationItem.backButtonDisplayMode = .minimal
        }
        
        // Создаем стильную кнопку добавления
        let plusButton = UIButton(type: .system)
        let plusImage = UIImage(systemName: "plus.circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium))
        plusButton.setImage(plusImage, for: .normal)
        plusButton.tintColor = .systemBlue
        plusButton.backgroundColor = .clear
        
        // Добавляем тень для глубины
        plusButton.layer.shadowColor = UIColor.systemBlue.cgColor
        plusButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        plusButton.layer.shadowOpacity = 0.3
        plusButton.layer.shadowRadius = 4
        
        // Анимация при нажатии
        plusButton.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        plusButton.addTarget(self, action: #selector(plusButtonPressed(_:)), for: .touchDown)
        plusButton.addTarget(self, action: #selector(plusButtonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        
        plusButton.snp.makeConstraints { make in
            make.height.width.equalTo(32)
        }
        
        let item = UIBarButtonItem(customView: plusButton)
        self.navigationItem.setRightBarButton(item, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
    }
    
    private func setupUI() {
        tableView.delegate = self
        tableView.dataSource = self
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
    }
    
    @objc private func plusButtonPressed(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    @objc private func plusButtonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            sender.transform = .identity
        })
    }
    
    @objc private func addNew() {
        let editType = EditType.doubleField(
            title1: "ФИО",
            placeholder1: "Введите ФИО члена комиссии",
            currentValue1: "",
            title2: "Должность",
            placeholder2: "Введите должность члена комиссии",
            currentValue2: ""
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newFio, newJobTitle, _ in
            guard let self = self else { return }
            let jobTitle = newJobTitle ?? ""
            let newObj = ComissionPeople(fio: newFio, jobTitle: jobTitle)
            self.model.comissionArray.append(newObj)
            DataFlowComission.saveArr(arr: self.model.comissionArray)
            self.tableView.reloadData()
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
    
    private func showDeleteConfirmation(for indexPath: IndexPath) {
        let alert = UIAlertController(title: "Удаление", message: "Вы уверены, что хотите удалить эту запись?", preferredStyle: .alert)
        
        let deleteAction = UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.model.comissionArray.remove(at: indexPath.row)
            DataFlowComission.saveArr(arr: self.model.comissionArray)
            self.tableView.deleteRows(at: [indexPath], with: .fade)
        }
        
        let cancelAction = UIAlertAction(title: "Отмена", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showEditAlert(for indexPath: IndexPath) {
        let comission = model.comissionArray[indexPath.row]
        let editType = EditType.doubleField(
            title1: "ФИО",
            placeholder1: "Введите ФИО члена комиссии",
            currentValue1: comission.fio,
            title2: "Должность",
            placeholder2: "Введите должность члена комиссии",
            currentValue2: comission.jobTitle
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newFio, newJobTitle, _ in
            guard let self = self else { return }
            let jobTitle = newJobTitle ?? ""
            self.model.updateComission(at: indexPath.row, newFio: newFio, newJobTitle: jobTitle) { success in
                DispatchQueue.main.async {
                    if success {
                        self.tableView.reloadData()
                    } else {
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Член комиссии с таким ФИО уже существует", preferredStyle: .alert)
                        let ok = UIAlertAction(title: "OK", style: .cancel)
                        errorAlert.addAction(ok)
                        self.present(errorAlert, animated: true)
                    }
                }
            }
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        navController.modalPresentationStyle = UIModalPresentationStyle.pageSheet
        
        if let sheet = navController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        
        present(navController, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsComissionPeopleViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.comissionArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ComissionCell", for: indexPath)
        
        // Очищаем содержимое ячейки
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        // Настройка внешнего вида ячейки
        cell.layer.cornerRadius = 16
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 2)
        cell.layer.shadowOpacity = 0.1
        cell.layer.shadowRadius = 4
        
        // Создаем контейнер для содержимого ячейки
        let containerView = UIView()
        
        // Настройка для темной темы
        if traitCollection.userInterfaceStyle == .dark {
            containerView.backgroundColor = .systemGray6
            containerView.layer.cornerRadius = 16
            containerView.layer.masksToBounds = true
        } else {
            containerView.backgroundColor = .systemGray6
            containerView.layer.cornerRadius = 16
            containerView.layer.masksToBounds = true
        }
        
        cell.contentView.addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        
        let item = model.comissionArray[indexPath.row]
        
        // ФИО
        let fioLabel = UILabel()
        fioLabel.text = item.fio
        fioLabel.textAlignment = .left
        if traitCollection.userInterfaceStyle == .dark {
            fioLabel.textColor = .white
        } else {
            fioLabel.textColor = .label
        }
        fioLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        containerView.addSubview(fioLabel)
        fioLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(16)
        }
        
        // Должность
        let jobTitleLabel = UILabel()
        jobTitleLabel.text = item.jobTitle
        jobTitleLabel.textAlignment = .left
        if traitCollection.userInterfaceStyle == .dark {
            jobTitleLabel.textColor = .white.withAlphaComponent(0.7)
        } else {
            jobTitleLabel.textColor = .secondaryLabel
        }
        jobTitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        containerView.addSubview(jobTitleLabel)
        jobTitleLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(fioLabel.snp.bottom).offset(8)
            make.bottom.equalToSuperview().inset(16)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SettingsComissionPeopleViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Редактирование теперь доступно только через свайп
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 96
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard indexPath.row >= 0 && indexPath.row < model.comissionArray.count else {
            return UISwipeActionsConfiguration(actions: [])
        }
        
        let editAction = UIContextualAction(style: .normal, title: "Редактировать") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.showEditAlert(for: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            self.showDeleteConfirmation(for: indexPath)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        configuration.performsFirstActionWithFullSwipe = false
        
        return configuration
    }
}
