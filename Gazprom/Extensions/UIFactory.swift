//
//  UIFactory.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation
import UIKit
import SnapKit

class UIFactory {
    
    static func createButton(title: String, color: UIColor) -> UIButton {
        let button = UIButton(type: .system)
        button.layer.cornerRadius = 16
        button.backgroundColor = color
        button.setTitleColor(.white, for: .normal)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 22, weight: .bold)
        return button
    }
    
    static func createlabel(title: String) -> UILabel {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .black
        return label
    }
    
    static func createTextField(placeholder: String) -> UITextField {
        let view = UITextField()
        view.backgroundColor = .black.withAlphaComponent(0.05)
        view.layer.cornerRadius = 14
        view.textColor = .black
        view.font = .systemFont(ofSize: 16, weight: .regular)
    
        view.leftView =  UIView(frame: .init(x: 0, y: 0, width: 10, height: 10))
        view.leftViewMode = .always
        
        view.rightView =  UIView(frame: .init(x: 0, y: 0, width: 10, height: 10))
        view.rightViewMode = .always
        
        view.attributedPlaceholder = NSAttributedString(
               string: placeholder,
               attributes: [
                   .foregroundColor: UIColor.systemBlue,
                   .font: UIFont.systemFont(ofSize: 16, weight: .regular)
               ]
           )
        
        return view
    }
    
    static func showAlert(vc: UIViewController, title: String, description: String) {
        let alert = UIAlertController(title: title, message: description, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "Хорошо", style: .cancel)
        alert.addAction(okAction)
        vc.present(alert, animated: true)
    }
    
}
