//
//  AKTCreationStep.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import Foundation

/// Шаги создания АКТ в приложении
enum AKTCreationStep: String, Codable, CaseIterable {
    case dateAndNumber = "dateAndNumber"
    case organizations = "organizations"
    case objectCheck = "objectCheck"
    case violations = "violations"
    case userDescription = "userDescription"
    case predstavitely = "predstavitely"
    case generate = "generate"
    
    /// Отображаемое название шага
    var displayName: String {
        switch self {
        case .dateAndNumber:
            return "Дата и номер АКТ"
        case .organizations:
            return "Организации"
        case .objectCheck:
            return "Объекты проверки"
        case .violations:
            return "Нарушения"
        case .userDescription:
            return "Описание пользователя"
        case .predstavitely:
            return "Представители"
        case .generate:
            return "Генерация АКТ"
        }
    }
    
    /// Следующий шаг в процессе создания АКТ
    var nextStep: AKTCreationStep? {
        switch self {
        case .dateAndNumber:
            return .organizations
        case .organizations:
            return .objectCheck
        case .objectCheck:
            return .violations
        case .violations:
            return .userDescription
        case .userDescription:
            return .predstavitely
        case .predstavitely:
            return .generate
        case .generate:
            return nil
        }
    }
}
