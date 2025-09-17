//
//  SettingsOrganizationsViewController.swift
//  Gazprom
//
//  Created by Владимир on 01.08.2025.
//

import UIKit

class SettingsOrganizationsViewController: UIViewController {
    
    let model: MainAKTViewModel
    
    let tableView: UITableView = {
        let view = UITableView(frame: .zero, style: .plain)
        view.showsVerticalScrollIndicator = false
        view.register(UITableViewCell.self, forCellReuseIdentifier: "1")
        view.contentInset = .init(top: 0, left: 0, bottom: 100, right: 0)
        view.backgroundColor = .clear
        return view
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
        view.backgroundColor = .white
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
                tableView.reloadData()
            }
        }
        alert.addAction(save)
        
        self.present(alert, animated: true)
    }
    

}

extension SettingsOrganizationsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.organizationsArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "1") ?? UITableViewCell()
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        let item = model.organizationsArray[indexPath.row]
        
        let separator = UIView()
        separator.backgroundColor = .separator
        cell.addSubview(separator)
        separator.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.height.equalTo(1)
        }
        
        let topLabel = UILabel()
        topLabel.text = item.title
        topLabel.textAlignment = .left
        topLabel.textColor = .black
        topLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(topLabel)
        topLabel.snp.makeConstraints { make in
            make.centerY.equalToSuperview()
            make.left.right.equalToSuperview().inset(16)
        }
        
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            model.organizationsArray.remove(at: indexPath.row)
            DataFlowOrganizations.saveArr(arr: model.organizationsArray)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (action, view, completionHandler) in
            guard let self = self else { return }
            self.model.organizationsArray.remove(at: indexPath.row)
            DataFlowOrganizations.saveArr(arr: self.model.organizationsArray)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completionHandler(true)
        }
        deleteAction.backgroundColor = .systemRed
        deleteAction.image = UIImage(systemName: "trash")
        
        let editAction = UIContextualAction(style: .normal, title: "Редактировать") { [weak self] (action, view, completionHandler) in
            guard let self = self else { return }
            self.showEditAlert(for: indexPath)
            completionHandler(true)
        }
        editAction.backgroundColor = .systemBlue
        editAction.image = UIImage(systemName: "pencil")
        
        let configuration = UISwipeActionsConfiguration(actions: [deleteAction, editAction])
        return configuration
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
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
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
