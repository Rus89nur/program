//
//  DraftAKT.swift
//  Gazprom
//
//  Created by Assistant on 15.01.2025.
//

import Foundation

/// Модель черновика АКТ для сохранения промежуточного состояния
struct DraftAKT: Codable {
    let id: UUID
    let date: Date
    let aktNumber: String
    let comissionPeople: [ComissionPeople]
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    let descripUser: String
    let predstavitely: [PredstavitelyComission]
    let ustranenDatePicker: Date?
    let predostavlenDatePicker: Date?
    let utverzdenDatePicker: Date?
    let currentStep: AKTCreationStep
    let createdAt: Date
    let updatedAt: Date
    
    /// Создает новый черновик АКТ
    /// - Parameters:
    ///   - date: Дата АКТ
    ///   - aktNumber: Номер АКТ
    ///   - comissionPeople: Члены комиссии
    ///   - organizations: Организации
    ///   - objectCheck: Объекты проверки
    ///   - violations: Нарушения
    ///   - descripUser: Описание пользователя
    ///   - predstavitely: Представители
    ///   - ustranenDatePicker: Дата устранения
    ///   - predostavlenDatePicker: Дата предоставления
    ///   - utverzdenDatePicker: Дата утверждения
    ///   - currentStep: Текущий шаг создания
    init(date: Date, aktNumber: String, comissionPeople: [ComissionPeople], organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstavitely: [PredstavitelyComission], ustranenDatePicker: Date?, predostavlenDatePicker: Date?, utverzdenDatePicker: Date?, currentStep: AKTCreationStep) {
        self.id = UUID()
        self.date = date
        self.aktNumber = aktNumber
        self.comissionPeople = comissionPeople
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.descripUser = descripUser
        self.predstavitely = predstavitely
        self.ustranenDatePicker = ustranenDatePicker
        self.predostavlenDatePicker = predostavlenDatePicker
        self.utverzdenDatePicker = utverzdenDatePicker
        self.currentStep = currentStep
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
