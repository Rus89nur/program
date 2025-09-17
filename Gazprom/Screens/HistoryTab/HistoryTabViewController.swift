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
    
    // MARK: - Edit Akt Methods
    
    private func editAkt(_ akt: AKT) {
        // Загружаем данные акта в TemplateModel для редактирования
        loadAktToTemplate(akt)
        
        // Определяем шаг, с которого начинать редактирование
        let startStep = determineStartStep(for: akt)
        
        // Переходим к соответствующему экрану редактирования
        navigateToEditStep(startStep, akt: akt)
    }
    
    private func loadAktToTemplate(_ akt: AKT) {
        // Очищаем текущий template
        viewModel.templateModel.reset()
        
        // Загружаем данные из акта
        viewModel.templateModel.date = akt.date
        viewModel.templateModel.aktNumber = akt.number
        viewModel.templateModel.comissionPeople = akt.comission
        viewModel.templateModel.organizations = [akt.organization]
        viewModel.templateModel.objectCheck = akt.objectsCheck
        viewModel.templateModel.violations = akt.violations
        viewModel.templateModel.descripUser = akt.description
        viewModel.templateModel.predstavitely = akt.predstavitelyComission
        viewModel.templateModel.ustranenDatePicker = akt.actustranenDate
        viewModel.templateModel.predostavlenDatePicker = akt.actPredostavlenDate
        viewModel.templateModel.utverzdenDatePicker = akt.actUtverzdenDate
    }
    
    private func determineStartStep(for akt: AKT) -> AKTCreationStep {
        // Определяем с какого шага начинать редактирование
        // Начинаем с первого шага, чтобы пользователь мог изменить любые данные
        return .dateAndNumber
    }
    
    private func navigateToEditStep(_ step: AKTCreationStep, akt: AKT) {
        let targetVC = createEditViewControllerForStep(step, akt: akt)
        
        if let navigationController = navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func createEditViewControllerForStep(_ step: AKTCreationStep, akt: AKT) -> UIViewController {
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: viewModel, akt: akt)
        case .organizations:
            return OrganizationsViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                act: akt
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                akt: akt
            )
        case .violations:
            return NewViolationViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt
            )
        case .userDescription:
            return UserDescriptionViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                akt: akt
            )
        case .predstavitely:
            return PredstavViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt
            )
        case .generate:
            return GenerateAktViewController(
                viewModel: viewModel,
                comissionPeople: akt.comission,
                date: akt.date,
                aktNumber: akt.number,
                organizations: [akt.organization],
                objectCheck: akt.objectsCheck,
                violations: akt.violations,
                descripUser: akt.description,
                predstavitely: akt.predstavitelyComission,
                akt: akt
            )
        }
    }
    
    private func createWordDocument(for akt: AKT) {
        // Создаем Word документ из шаблона для выбранного акта
        let generateVC = GenerateAktViewController(
            viewModel: viewModel,
            comissionPeople: akt.comission,
            date: akt.date,
            aktNumber: akt.number,
            organizations: [akt.organization],
            objectCheck: akt.objectsCheck,
            violations: akt.violations,
            descripUser: akt.description,
            predstavitely: akt.predstavitelyComission,
            akt: akt
        )
        
        // Переходим к экрану генерации для создания документа
        navigationController?.pushViewController(generateVC, animated: true)
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
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width - 32, height: 96)
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
            let deleteAction = UIAction(title: "Удалить", image: UIImage(systemName: "trash"), attributes: .destructive) { _ in
                if let index = self.viewModel.aktArray.firstIndex(where: {$0.id == self.viewModel.aktArray.reversed()[indexPath.row].id}) {
                    self.viewModel.aktArray.remove(at: index)
                    DataFlowAKT.saveArr(arr:  self.viewModel.aktArray)
                }
                
                collectionView.deleteItems(at: [indexPath])
            }
            
            return UIMenu(title: "", children: [deleteAction])
        }
    }

}
