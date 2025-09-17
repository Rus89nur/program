//
//  PredstavViewController.swift
//  Gazprom
//
//  Created by Владимир on 24.07.2025.
//

import UIKit

class PredstavViewController: UIViewController {
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    let date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    let descripUser: String
    
    var predstavitely: [PredstavitelyComission] = []
    
    var akt: AKT?
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstavitely: [PredstavitelyComission], akt: AKT?) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.descripUser = descripUser
        self.predstavitely = predstavitely
        self.akt = akt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let collection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.contentInset = .init(top: 16, left: 0, bottom: 16, right: 0)
        collection.showsVerticalScrollIndicator = false
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collection.layer.cornerRadius = 16
        layout.scrollDirection = .vertical
        return collection
    }()
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewModel.templateModel.predstavitely = predstavitely
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Представители"
        setupViewModel()
        setupNav()
    }
    
    private func setupNav() {
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        let item = UIBarButtonItem(customView: goBackButton)
        goBackButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        goBackButton.alpha = 0.5
        self.navigationItem.rightBarButtonItem = item
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
    }
    
    @objc private func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
       setupUI()
        checkOld()
    }
    
    private func checkOld() {
        if let a = akt {
            predstavitely = a.predstavitelyComission
            collection.reloadData()
        }
    }
    
    private func setupViewModel() {
        viewModel.collectionReloadBinding = { [weak self] in
            self?.collection.reloadData()
        }
        
        if let a = viewModel.templateModel.predstavitely {
            self.predstavitely = a
            collection.reloadData()
        }
    }
    
    private func setupUI() {
        collection.delegate = self
        collection.dataSource = self
        view.addSubview(collection)
        collection.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.bottom.equalToSuperview().inset(100)
        }
        
        let nextButton = UIFactory.createButton(title: "Далее", color: .systemBlue)
        view.addSubview(nextButton)
        nextButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.height.equalTo(54)
        }
        nextButton.addTarget(self, action: #selector(goNext), for: .touchUpInside)
    }
    
    @objc private func addNew() {
        let vc = NewPredstavitelyViewController(viewModel: viewModel)
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.custom(resolver: { _ in 710 })]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 20
        }
        self.present(vc, animated: true)
    }
    
    @objc private func goNext() {
        let vc = GenerateAktViewController(viewModel: viewModel, comissionPeople: comissionPeople, date: date, aktNumber: aktNumber, organizations: organizations, objectCheck: objectCheck, violations: violations, descripUser: descripUser, predstavitely: predstavitely, akt: akt)
        navigationController?.pushViewController(vc, animated: true)
    }
    

}

extension PredstavViewController: UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.predstavitelyArray.count + 1
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "1", for: indexPath)
        cell.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .black.withAlphaComponent(0.05)
        cell.layer.cornerRadius = 16
        
        if indexPath.row == viewModel.predstavitelyArray.count {
            let button = UIFactory.createButton(title: "Добавить", color: .clear)
            button.setTitleColor(.systemBlue, for: .normal)
            cell.addSubview(button)
            button.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
            button.addTarget(self, action: #selector(addNew), for: .touchUpInside)
        } else {
            
            let item =  viewModel.predstavitelyArray.reversed()[indexPath.row]
            
            let rightImageView = UIImageView()
            rightImageView.contentMode = .scaleAspectFit
            cell.addSubview(rightImageView)
            rightImageView.snp.makeConstraints { make in
                make.height.width.equalTo(32)
                make.centerY.equalToSuperview()
                make.right.equalToSuperview().inset(16)
            }
            
            if predstavitely.contains(where: {$0.fio == item.fio}) {
                rightImageView.image = UIImage(systemName: "checkmark.circle.fill")
                rightImageView.tintColor = .systemGreen
            } else {
                rightImageView.image = UIImage(systemName: "circlebadge")
                rightImageView.tintColor = .systemGray
            }
            
            let title = UIFactory.createlabel(title: item.fio)
            title.numberOfLines = 1
            title.font = .systemFont(ofSize: 16, weight: .medium)
            cell.addSubview(title)
            title.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.top.equalToSuperview().inset(10)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
            
            let sublabel = UIFactory.createlabel(title: item.jobTitle)
            sublabel.numberOfLines = 1
            sublabel.textColor = .black.withAlphaComponent(0.6)
            sublabel.font = .systemFont(ofSize: 12, weight: .regular)
            cell.addSubview(sublabel)
            sublabel.snp.makeConstraints { make in
                make.left.equalToSuperview().inset(16)
                make.bottom.equalToSuperview().inset(10)
                make.right.equalTo(rightImageView.snp.left).inset(-16)
            }
            
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if indexPath.row != viewModel.predstavitelyArray.count {
            if let index = predstavitely.firstIndex(where: {$0.id == viewModel.predstavitelyArray.reversed()[indexPath.row].id}) {
                predstavitely.remove(at: index)
                collectionView.reloadData()
            } else {
                predstavitely.append(viewModel.predstavitelyArray.reversed()[indexPath.row])
                collectionView.reloadData()
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.width, height: 54)
    }
}
