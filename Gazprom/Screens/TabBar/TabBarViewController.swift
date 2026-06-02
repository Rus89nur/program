//
//  TabBarViewController.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import UIKit

class TabBarViewController: UITabBarController {
    
    private let viewModel = MainAKTViewModel()
    private var previousSelectedIndex: Int = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        config()
        delegate = self
        tabBar.delegate = self
        previousSelectedIndex = selectedIndex
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.templateModel.reset()
        navigationItem.rightBarButtonItem = .none
        
        // Гарантируем, что TabBar всегда видима и кнопки отображаются
        tabBar.isHidden = false
        tabBar.alpha = 1.0
        
        // Убеждаемся, что все элементы TabBar видимы
        if let items = tabBar.items {
            for item in items {
                item.isEnabled = true
            }
        }
        
        // Устанавливаем backBarButtonItem для всех дочерних экранов SettingsTab
        if let settingsVC = selectedViewController as? SettingsTabViewController {
            let backButton = UIBarButtonItem(title: "Настройки", style: .plain, target: nil, action: nil)
            settingsVC.navigationItem.backBarButtonItem = backButton
            settingsVC.navigationItem.backButtonTitle = "Настройки"
        }
        
        // Устанавливаем backBarButtonItem для всех дочерних экранов StartTab
        if let startVC = selectedViewController as? StartTabViewController {
            let backButton = UIBarButtonItem(title: "Главная", style: .plain, target: nil, action: nil)
            startVC.navigationItem.backBarButtonItem = backButton
            startVC.navigationItem.backButtonTitle = "Главная"
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Дополнительная проверка видимости TabBar после появления
        tabBar.isHidden = false
        tabBar.alpha = 1.0
        
        // Убеждаемся, что все элементы TabBar видимы
        if let items = tabBar.items {
            for item in items {
                item.isEnabled = true
            }
        }
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
        // Настройка NavigationBar - прозрачный фон (как в истории)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = .clear
        appearance.backgroundEffect = nil
        // Адаптивный цвет для заголовков: черный в светлой теме, белый в темной
        let adaptiveTitleColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? .black : .white
        }
        appearance.titleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 22, weight: .bold)
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: adaptiveTitleColor,
            .font: UIFont.systemFont(ofSize: 28, weight: .bold)
        ]

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
        // Адаптивный цвет для кнопок навигации
        navBar.tintColor = adaptiveTitleColor
        navBar.prefersLargeTitles = false
        navBar.isTranslucent = true
        navBar.setBackgroundImage(UIImage(), for: .default)
        navBar.shadowImage = UIImage()
        
        // ВАЖНО: Проверяем, что isTranslucent действительно true
        if !navBar.isTranslucent {
            navBar.isTranslucent = true
        }
        
        // Настройка TabBar для прозрачности (как в истории)
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        
        // Убираем blur эффект для полной прозрачности
        tabBarAppearance.backgroundEffect = nil
        
        // Настройка цветов с адаптацией к теме
        // Адаптивный цвет для текста: черный в светлой теме, серый в темной
        let adaptiveTextColor = UIColor { traitCollection in
            return traitCollection.userInterfaceStyle == .light ? .black : .systemGray
        }
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = .systemGray
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: adaptiveTextColor]
        
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = .systemBlue
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        
        // Применяем настройки
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance
        tabBar.tintColor = .systemBlue
        
        // Убеждаемся, что tab bar полностью прозрачный
        tabBar.isTranslucent = true
        // Устанавливаем nil вместо .clear, чтобы избежать черного цвета в grayscale color space
        tabBar.barTintColor = nil
        tabBar.backgroundColor = nil
        
        // Устанавливаем прозрачность через layer
        tabBar.layer.backgroundColor = nil
        
        // Удаляем UIVisualEffectView и обрабатываем subviews для полной прозрачности
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.makeTabBarTransparent()
        }
        
        // Гарантируем, что TabBar всегда видима и кнопки отображаются
        tabBar.isHidden = false
        tabBar.alpha = 1.0
        
        // Убеждаемся, что все элементы TabBar видимы
        if let items = tabBar.items {
            for item in items {
                item.isEnabled = true
            }
        }
    }
    
    // MARK: - TabBar Transparency
    
    /// Делает TabBar полностью прозрачным, удаляя все фоновые элементы
    private func makeTabBarTransparent() {
        for subview in tabBar.subviews {
            makeSubviewTransparent(subview)
            
            // Обрабатываем вложенные subviews
            for nestedSubview in subview.subviews {
                makeSubviewTransparent(nestedSubview)
                
                // Обрабатываем фоновые subviews внутри вложенных
                for backgroundSubview in nestedSubview.subviews {
                    makeBackgroundSubviewTransparent(backgroundSubview)
                }
            }
            
            // Обрабатываем фоновые subviews напрямую
            for backgroundSubview in subview.subviews {
                makeBackgroundSubviewTransparent(backgroundSubview)
            }
        }
        
        tabBar.layer.backgroundColor = nil
    }
    
    /// Делает subview прозрачным
    private func makeSubviewTransparent(_ subview: UIView) {
        let subviewType = String(describing: type(of: subview))
        
        if subview is UIVisualEffectView {
            subview.removeFromSuperview()
            return
        }
        
        if subviewType.contains("PlatterView") {
            subview.backgroundColor = .clear
            subview.alpha = 1.0
            subview.isOpaque = false
            subview.layer.backgroundColor = nil
        } else if subviewType.contains("Background") || subviewType.contains("BarBackground") {
            subview.backgroundColor = .clear
            subview.alpha = 1.0
            subview.layer.backgroundColor = nil
        }
    }
    
    /// Делает фоновый subview прозрачным
    private func makeBackgroundSubviewTransparent(_ subview: UIView) {
        let bgType = String(describing: type(of: subview))
        if bgType.contains("Background") || bgType.contains("BarBackground") || 
           bgType.contains("Platter") || bgType.contains("Material") || bgType.contains("Effect") {
            subview.backgroundColor = .clear
            subview.alpha = 0.0
            subview.isOpaque = false
            subview.layer.backgroundColor = nil
        } else {
            subview.alpha = 1.0
        }
    }
    
    // MARK: - Анимация иконок
    
    /// Анимирует иконку выбранного таба
    private func animateTabBarItem(at index: Int) {
        guard let tabBarItems = tabBar.items, index < tabBarItems.count else { return }
        
        // Небольшая задержка для гарантии, что TabBar полностью отрендерился
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            
            // Находим view иконки в TabBar
            guard let tabBarButton = self.findTabBarButton(at: index) else { return }
            
            // Находим imageView внутри кнопки
            guard let imageView = self.findImageView(in: tabBarButton) else { return }
            
            // Сбрасываем предыдущие анимации
            imageView.layer.removeAllAnimations()
            
            // Анимация масштабирования с пружинным эффектом для всех иконок
            UIView.animate(
                withDuration: 0.3,
                delay: 0,
                usingSpringWithDamping: 0.5,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    // Увеличиваем иконку
                    imageView.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
                },
                completion: { _ in
                    // Возвращаем к нормальному размеру
                    UIView.animate(
                        withDuration: 0.2,
                        delay: 0,
                        usingSpringWithDamping: 0.7,
                        initialSpringVelocity: 0.3,
                        options: [.curveEaseOut, .allowUserInteraction],
                        animations: {
                            imageView.transform = .identity
                        }
                    )
                }
            )
        }
    }
    
    /// Находит кнопку TabBar по индексу
    private func findTabBarButton(at index: Int) -> UIView? {
        guard let tabBarItems = tabBar.items, index < tabBarItems.count else { return nil }
        
        // Ищем все subviews в TabBar, которые являются кнопками
        var tabBarButtons: [UIView] = []
        
        for subview in tabBar.subviews {
            let subviewType = String(describing: type(of: subview))
            // Ищем кнопки TabBar (могут называться по-разному в разных версиях iOS)
            if subviewType.contains("Button") || subviewType.contains("UITabBarButton") {
                tabBarButtons.append(subview)
            }
        }
        
        // Если не нашли через тип, ищем через структуру
        if tabBarButtons.isEmpty {
            // Альтернативный способ: ищем все subviews, которые содержат imageView
            for subview in tabBar.subviews {
                if findImageView(in: subview) != nil {
                    tabBarButtons.append(subview)
                }
            }
        }
        
        // Сортируем кнопки по их позиции (слева направо)
        let sortedButtons = tabBarButtons.sorted { button1, button2 in
            button1.frame.origin.x < button2.frame.origin.x
        }
        
        guard index < sortedButtons.count else { return nil }
        return sortedButtons[index]
    }
    
    /// Находит UIImageView внутри view
    private func findImageView(in view: UIView) -> UIImageView? {
        if let imageView = view as? UIImageView {
            return imageView
        }
        
        for subview in view.subviews {
            if let imageView = subview as? UIImageView {
                return imageView
            }
            if let found = findImageView(in: subview) {
                return found
            }
        }
        
        return nil
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let selectedIndex = tabBarController.selectedIndex
        
        // Анимируем только если выбран другой таб
        if selectedIndex != previousSelectedIndex {
            animateTabBarItem(at: selectedIndex)
            previousSelectedIndex = selectedIndex
        }
    }
}

