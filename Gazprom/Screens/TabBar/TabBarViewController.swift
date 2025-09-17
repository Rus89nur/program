//
//  TabBarViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class TabBarViewController: UITabBarController {
    
    private let viewModel = MainAKTViewModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        config()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.templateModel.reset()
        navigationItem.rightBarButtonItem = .none
    }
    
    private func setupUI() {
        let startItem = UITabBarItem(title: "Главная", image: UIImage(systemName: "paperplane.fill"), tag: 0)
        let historyItem = UITabBarItem(title: "История", image: UIImage(systemName: "clock.fill"), tag: 1)
        let settingsItem = UITabBarItem(title: "Настройки", image: UIImage(systemName: "gear"), tag: 1)
        
        let vc1 = StartTabViewController(viewModel: viewModel)
        vc1.tabBarItem = startItem
        
        let vc2 = HistoryTabViewController()
        vc2.tabBarItem = historyItem
        
        let vc3 = SettingsTabViewController(model: viewModel)
        vc3.tabBarItem = settingsItem
        
        viewControllers = [vc1, vc2, vc3]
    }
    
    private func config() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .white
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.black,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = .black
        navBar.prefersLargeTitles = true
    }
}
