//
//  SettingsObjectsViewController.swift
//  Gazprom
//
//  Created by Владимир on 01.08.2025.
//

import UIKit

class SettingsObjectsViewController: UIViewController {
    
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
        title = "Обьекты"
        
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
        let alert = UIAlertController(title: "Добавление нового объекта проверки", message: "Введите название и описание", preferredStyle: .alert)
        alert.addTextField()
        alert.addTextField()
        
        alert.textFields?.first?.placeholder = "Название"
        alert.textFields?[1].placeholder = "Описание"
        
        let cancel = UIAlertAction(title: "Отмена", style: .cancel)
        alert.addAction(cancel)
        
        let save = UIAlertAction(title: "Добавить", style: .default) { [weak self] _ in
            guard let self = self else { return }
            if let text = alert.textFields?.first?.text, let subTitle = alert.textFields?[1].text {
                let newObj = ObjectCheck(title: text, subTitle: subTitle)
                model.objectCheckArray.append(newObj)
                DataFlowObjectsReview.saveArr(arr:  model.objectCheckArray)
                tableView.reloadData()
            }
        }
        alert.addAction(save)
        
        self.present(alert, animated: true)
    }
    

}


extension SettingsObjectsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.objectCheckArray.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "1") ?? UITableViewCell()
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear
        
        let item = model.objectCheckArray[indexPath.row]
        
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
            make.top.equalToSuperview().inset(12)
            make.left.right.equalToSuperview().inset(16)
        }
        
        let subTitle = UILabel()
        subTitle.text = item.subTitle
        subTitle.textAlignment = .left
        subTitle.textColor = .systemGray
        subTitle.font = .systemFont(ofSize: 14, weight: .regular)
        cell.addSubview(subTitle)

        subTitle.snp.makeConstraints { make in
            make.bottom.equalToSuperview().inset(12)
            make.left.right.equalToSuperview().inset(16)
        }
        return cell
    }
    
    
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            model.objectCheckArray.remove(at: indexPath.row)
            DataFlowObjectsReview.saveArr(arr: model.objectCheckArray)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let deleteAction = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] (action, view, completionHandler) in
            guard let self = self else { return }
            self.model.objectCheckArray.remove(at: indexPath.row)
            DataFlowObjectsReview.saveArr(arr: self.model.objectCheckArray)
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
        let object = model.objectCheckArray[indexPath.row]
        let editType = EditType.doubleField(
            title1: "Название",
            placeholder1: "Введите название объекта",
            currentValue1: object.title,
            title2: "Описание",
            placeholder2: "Введите описание объекта",
            currentValue2: object.subTitle
        )
        
        let editVC = UniversalEditViewController(editType: editType) { [weak self] newTitle, newSubtitle in
            guard let self = self else { return }
            let subtitle = newSubtitle ?? ""
            self.model.updateObjectCheck(at: indexPath.row, newTitle: newTitle, newSubtitle: subtitle) { success in
                DispatchQueue.main.async {
                    if success {
                        self.tableView.reloadRows(at: [indexPath], with: .automatic)
                    } else {
                        let errorAlert = UIAlertController(title: "Ошибка!", message: "Объект с таким названием уже существует", preferredStyle: .alert)
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
