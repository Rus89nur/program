//
//  UITextView+RussianMenu.swift
//  Gazprom
//
//  Created by Assistant on 11.09.2025.
//

import UIKit

extension UITextView {
    
    override open func awakeFromNib() {
        super.awakeFromNib()
        setupRussianMenu()
    }
    
    func setupRussianMenu() {
        // Настройка русских контекстных меню
        // Настройка адаптивного цвета курсора
        setupAdaptiveCursorColor()
    }
    
    func setupAdaptiveCursorColor() {
        // Устанавливаем золотой курсор для всех текстовых полей
        self.tintColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Золотой цвет
    }
    
    @available(iOS 14.0, *)
    override open func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        
        // Удаляем стандартные действия редактирования
        builder.remove(menu: .standardEdit)
        
        // Добавляем русские действия
        let cutAction = UIAction(title: "Вырезать", image: UIImage(systemName: "scissors")) { _ in
            self.cut(self)
        }
        
        let copyAction = UIAction(title: "Копировать", image: UIImage(systemName: "doc.on.doc")) { _ in
            self.copy(self)
        }
        
        let pasteAction = UIAction(title: "Вставить", image: UIImage(systemName: "doc.on.clipboard")) { _ in
            self.paste(self)
        }
        
        let selectAction = UIAction(title: "Выделить", image: UIImage(systemName: "selection")) { _ in
            self.select(self)
        }
        
        let selectAllAction = UIAction(title: "Выделить все", image: UIImage(systemName: "selection.all")) { _ in
            self.selectAll(self)
        }
        
        // Создаем меню в зависимости от состояния выделения
        if selectedRange.length > 0 {
            // Есть выделение - показываем Cut, Copy, Select All
            let editMenu = UIMenu(title: "", children: [cutAction, copyAction, selectAllAction])
            builder.insertChild(editMenu, atStartOfMenu: .standardEdit)
        } else {
            // Нет выделения - показываем Select, Select All, Paste (если есть)
            var actions: [UIAction] = [selectAction, selectAllAction]
            if UIPasteboard.general.hasStrings {
                actions.append(pasteAction)
            }
            let editMenu = UIMenu(title: "", children: actions)
            builder.insertChild(editMenu, atStartOfMenu: .standardEdit)
        }
    }
}
