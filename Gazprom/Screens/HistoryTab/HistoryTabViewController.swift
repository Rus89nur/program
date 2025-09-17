//
//  HistoryTabViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class HistoryTabViewController: UIViewController {
    
    let viewModel: MainAKTViewModel = MainAKTViewModel()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tabBarController?.title = "История"
        viewModel.aktArray = DataFlowAKT.loadArr()
        colelction.reloadData()
    }
    
    let colelction: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 16, left: 0, bottom: 16, right: 0)
        layout.scrollDirection = .vertical
        return collection
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    private func setupUI() {
        view.backgroundColor = .white
        view.addSubview(colelction)
        colelction.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
        }
        colelction.delegate = self
        colelction.dataSource = self
    }
    
    private func formatter(date: Date) -> String {
        let form = DateFormatter()
        form.dateFormat = "dd.MM.yyyy | HH:mm"
        form.locale = .current
        return form.string(from: date)
    }
    
    // MARK: - Version Display Methods
    
    private func getAktVersion(_ akt: AKT) -> String {
        // Получаем версию акта на основе даты создания
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let dateString = formatter.string(from: akt.realDateCreate)
        
        // Создаем версию на основе даты и номера акта
        let version = "v\(akt.number).\(dateString.replacingOccurrences(of: ".", with: ""))"
        return version
    }
    
    private func getAktVersionInfo(_ akt: AKT) -> String {
        let version = getAktVersion(akt)
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        let dateString = formatter.string(from: akt.realDateCreate)
        
        return "\(version)\nСоздан: \(dateString)"
    }

}

extension HistoryTabViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.aktArray.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .black.withAlphaComponent(0.03)
        cell.clipsToBounds = true
        cell.layer.cornerRadius  = 20
        
        let item = viewModel.aktArray.reversed()[indexPath.row]
        
        let dateLabel = UILabel()
        dateLabel.text = formatter(date: item.realDateCreate)
        dateLabel.textColor = .black
        dateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        cell.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
        }
        
        let numbLabel = UILabel()
        numbLabel.textColor = .black
        numbLabel.text = "Aкт №\(item.number)"
        numbLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        cell.addSubview(numbLabel)
        numbLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalToSuperview().inset(8)
        }
        
        let objectLabel = UILabel()
        objectLabel.text = item.objectsCheck.first?.title ?? ""
        objectLabel.textAlignment = .left
        objectLabel.textColor = .black.withAlphaComponent(0.6)
        objectLabel.font = .systemFont(ofSize: 14, weight: .regular)
        cell.addSubview(objectLabel)
        objectLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.right.equalToSuperview().inset(16)
            make.top.equalTo(numbLabel.snp.bottom).inset(-12)
        }
        
        let organizationLabel = UILabel()
        organizationLabel.textAlignment = .left
        organizationLabel.text = item.organization.title
        organizationLabel.textColor = .black.withAlphaComponent(0.6)
        organizationLabel.font = .systemFont(ofSize: 14, weight: .regular)
        cell.addSubview(organizationLabel)
        organizationLabel.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(objectLabel.snp.bottom).inset(-6)
        }
        
        // Добавляем отображение версии акта
        let versionLabel = UILabel()
        versionLabel.textAlignment = .right
        versionLabel.text = getAktVersion(item)
        versionLabel.textColor = .systemBlue
        versionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        cell.addSubview(versionLabel)
        versionLabel.snp.makeConstraints { make in
            make.right.equalToSuperview().inset(16)
            make.bottom.equalToSuperview().inset(8)
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 32, height: 120)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if viewModel.aktArray.count > 0 {
            if let url = viewModel.aktArray.reversed()[indexPath.row].urlToFllACT {
                let activ = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                self.present(activ, animated: true)
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, contextMenuConfigurationForItemAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let akt = self.viewModel.aktArray.reversed()[indexPath.row]
            let versionInfo = self.getAktVersionInfo(akt)
            
            let versionAction = UIAction(title: "Информация о версии", image: UIImage(systemName: "info.circle")) { _ in
                let alert = UIAlertController(title: "Версия акта", message: versionInfo, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                if let index = self.viewModel.aktArray.firstIndex(where: {$0.id == self.viewModel.aktArray.reversed()[indexPath.row].id}) {
                    self.viewModel.aktArray.remove(at: index)
                    DataFlowAKT.saveArr(arr:  self.viewModel.aktArray)
                }
                
                collectionView.deleteItems(at: [indexPath])
            }
            
            return UIMenu(title: "", children: [versionAction, deleteAction])
        }
    }

}
