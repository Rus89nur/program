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
        view.backgroundColor = .systemBackground
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
        let reportsItem = UITabBarItem(title: "Отчеты", image: UIImage(systemName: "doc.text.fill"), tag: 2)
        let eliminationItem = UITabBarItem(title: "Устранение", image: UIImage(systemName: "checkmark.circle.fill"), tag: 3)
        let settingsItem = UITabBarItem(title: "Настройки", image: UIImage(systemName: "gear"), tag: 4)
        
        let vc1 = StartTabViewController(viewModel: viewModel)
        vc1.tabBarItem = startItem
        
        let vc2 = HistoryTabViewController()
        vc2.tabBarItem = historyItem
        
        let vc3 = ReportsTabViewController()
        vc3.tabBarItem = reportsItem
        
        let vc4 = EliminationTabViewController()
        vc4.tabBarItem = eliminationItem
        
        let vc5 = SettingsTabViewController(model: viewModel)
        vc5.tabBarItem = settingsItem
        
        viewControllers = [vc1, vc2, vc3, vc4, vc5]
    }
    
    private func config() {
        // Настройка NavigationBar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        navBar.tintColor = .label
        navBar.prefersLargeTitles = true
        
        // Настройка TabBar для темной темы
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .systemBackground
        
        // Настройка цветов для темной темы
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .systemGray
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray]
        
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        
        // Применяем настройки
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.tintColor = .systemBlue
    }
}
