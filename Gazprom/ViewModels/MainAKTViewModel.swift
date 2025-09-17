//
//  MainAKTViewModel.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation
import UIKit

// MARK: - Draft Types
enum AKTCreationStep: String, Codable, CaseIterable {
    case dateAndNumber = "dateAndNumber"
    case organizations = "organizations"
    case objectCheck = "objectCheck"
    case violations = "violations"
    case userDescription = "userDescription"
    case predstavitely = "predstavitely"
    case generate = "generate"
    
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

class DraftManager {
    static let shared = DraftManager()
    
    private let userDefaults = UserDefaults.standard
    private let draftKey = "DraftAKT"
    
    private init() {}
    
    // MARK: - Save Draft
    func saveDraft(_ draft: DraftAKT) {
        do {
            let data = try JSONEncoder().encode(draft)
            userDefaults.set(data, forKey: draftKey)
            print("✅ Черновик АКТ сохранен: \(draft.currentStep.displayName)")
        } catch {
            print("❌ Ошибка сохранения черновика: \(error)")
        }
    }
    
    // MARK: - Load Draft
    func loadDraft() -> DraftAKT? {
        guard let data = userDefaults.data(forKey: draftKey) else {
            print("⚠️ Черновик не найден")
            return nil
        }
        
        do {
            let draft = try JSONDecoder().decode(DraftAKT.self, from: data)
            print("✅ Черновик АКТ загружен: \(draft.currentStep.displayName)")
            return draft
        } catch {
            print("❌ Ошибка загрузки черновика: \(error)")
            return nil
        }
    }
    
    // MARK: - Delete Draft
    func deleteDraft() {
        userDefaults.removeObject(forKey: draftKey)
        print("✅ Черновик АКТ удален")
    }
    
    // MARK: - Check if Draft Exists
    func hasDraft() -> Bool {
        return userDefaults.data(forKey: draftKey) != nil
    }
    
    // MARK: - Get Draft Info
    func getDraftInfo() -> (step: AKTCreationStep, violationsCount: Int)? {
        guard let draft = loadDraft() else { return nil }
        return (draft.currentStep, draft.violations.count)
    }
    
    // MARK: - Update Draft Step
    func updateDraftStep(_ step: AKTCreationStep) {
        guard let draft = loadDraft() else { return }
        
        // Создаем новый черновик с обновленным шагом
        let updatedDraft = DraftAKT(
            date: draft.date,
            aktNumber: draft.aktNumber,
            comissionPeople: draft.comissionPeople,
            organizations: draft.organizations,
            objectCheck: draft.objectCheck,
            violations: draft.violations,
            descripUser: draft.descripUser,
            predstavitely: draft.predstavitely,
            ustranenDatePicker: draft.ustranenDatePicker,
            predostavlenDatePicker: draft.predostavlenDatePicker,
            utverzdenDatePicker: draft.utverzdenDatePicker,
            currentStep: step
        )
        
        saveDraft(updatedDraft)
    }
    
    // MARK: - Create Draft from Template
    func createDraftFromTemplate(_ template: TemplateModel, currentStep: AKTCreationStep) -> DraftAKT? {
        // Минимальные требования для создания черновика
        guard let date = template.date,
              let aktNumber = template.aktNumber else {
            print("❌ Недостаточно данных для создания черновика: отсутствуют дата или номер АКТ")
            return nil
        }
        
        // Создаем черновик с доступными данными
        let draft = DraftAKT(
            date: date,
            aktNumber: aktNumber,
            comissionPeople: template.comissionPeople ?? [],
            organizations: template.organizations ?? [],
            objectCheck: template.objectCheck ?? [],
            violations: template.violations ?? [],
            descripUser: template.descripUser ?? "",
            predstavitely: template.predstavitely ?? [],
            ustranenDatePicker: template.ustranenDatePicker,
            predostavlenDatePicker: template.predostavlenDatePicker,
            utverzdenDatePicker: template.utverzdenDatePicker,
            currentStep: currentStep
        )
        
        print("✅ Черновик создан для шага: \(currentStep.displayName)")
        return draft
    }
    
    // MARK: - Load Template from Draft
    func loadTemplateFromDraft(_ draft: DraftAKT) -> TemplateModel {
        let template = TemplateModel()
        template.date = draft.date
        template.aktNumber = draft.aktNumber
        template.comissionPeople = draft.comissionPeople
        template.organizations = draft.organizations
        template.objectCheck = draft.objectCheck
        template.violations = draft.violations
        template.descripUser = draft.descripUser
        template.predstavitely = draft.predstavitely
        template.ustranenDatePicker = draft.ustranenDatePicker
        template.predostavlenDatePicker = draft.predostavlenDatePicker
        template.utverzdenDatePicker = draft.utverzdenDatePicker
        
        return template
    }
}

class MainAKTViewModel {
    
    var collectionReloadBinding: (()->())?
    
    lazy var aktArray: [AKT] = DataFlowAKT.loadArr()
    lazy var comissionArray: [ComissionPeople] = DataFlowComission.loadArr()
    lazy var organizationsArray: [Organization] = DataFlowOrganizations.loadArr()
    lazy var objectCheckArray: [ObjectCheck] = DataFlowObjectsReview.loadArr()
    lazy var predstavitelyArray: [PredstavitelyComission] = DataFlowPredstavitely.loadArr()
    let templateModel = TemplateModel()
    
    // Последний открытый АКТ для кнопки "Продолжить заполнение"
    private var lastOpenedAkt: AKT?
    
    // MARK: - Draft Management
    func saveDraft(currentStep: AKTCreationStep) {
        if let draft = DraftManager.shared.createDraftFromTemplate(templateModel, currentStep: currentStep) {
            DraftManager.shared.saveDraft(draft)
        }
    }
    
    func loadDraft() -> DraftAKT? {
        return DraftManager.shared.loadDraft()
    }
    
    func hasDraft() -> Bool {
        return DraftManager.shared.hasDraft()
    }
    
    func deleteDraft() {
        DraftManager.shared.deleteDraft()
    }
    
    // MARK: - Last Opened AKT Management
    func setLastOpenedAkt(_ akt: AKT?) {
        lastOpenedAkt = akt
    }
    
    func getLastOpenedAkt() -> AKT? {
        return lastOpenedAkt
    }
    
    func clearLastOpenedAkt() {
        lastOpenedAkt = nil
    }
    
    func getDraftInfo() -> (step: AKTCreationStep, violationsCount: Int)? {
        return DraftManager.shared.getDraftInfo()
    }
    
    // MARK: - Navigation between steps
    func canGoToStep(_ step: AKTCreationStep) -> Bool {
        guard let currentStep = getDraftInfo()?.step else { return false }
        
        // Можно перейти к предыдущим шагам или текущему
        switch step {
        case .dateAndNumber:
            return true // Всегда можно перейти к первому шагу
        case .organizations:
            return currentStep != .dateAndNumber
        case .objectCheck:
            return currentStep != .dateAndNumber && currentStep != .organizations
        case .violations:
            return currentStep != .dateAndNumber && currentStep != .organizations && currentStep != .objectCheck
        case .userDescription:
            return currentStep != .dateAndNumber && currentStep != .organizations && currentStep != .objectCheck && currentStep != .violations
        case .predstavitely:
            return currentStep != .dateAndNumber && currentStep != .organizations && currentStep != .objectCheck && currentStep != .violations && currentStep != .userDescription
        case .generate:
            return currentStep == .generate
        }
    }
    
    func navigateToStep(_ step: AKTCreationStep, from viewController: UIViewController) {
        guard canGoToStep(step) else { return }
        
        // Обновляем текущий шаг в черновике
        DraftManager.shared.updateDraftStep(step)
        
        // Создаем соответствующий view controller
        let targetVC = createViewControllerForStep(step)
        
        
        // Переходим к нужному экрану
        if let navigationController = viewController.navigationController {
            navigationController.pushViewController(targetVC, animated: true)
        }
    }
    
    private func getPreviousStepTitle(from currentStep: AKTCreationStep, to targetStep: AKTCreationStep) -> String {
        switch targetStep {
        case .dateAndNumber:
            return "Главная"
        case .organizations:
            return "Дата и номер"
        case .objectCheck:
            return "Организации"
        case .violations:
            return "Объекты проверки"
        case .userDescription:
            return "Нарушения"
        case .predstavitely:
            return "Описание"
        case .generate:
            return "Представители"
        }
    }
    
    private func createViewControllerForStep(_ step: AKTCreationStep) -> UIViewController {
        switch step {
        case .dateAndNumber:
            return DateAndNumberAktViewController(viewModel: self)
        case .organizations:
            return OrganizationsViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                act: nil
            )
        case .objectCheck:
            return ObjectReviewViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                organizations: templateModel.organizations ?? [],
                akt: nil
            )
        case .violations:
            return NewViolationViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                organizations: templateModel.organizations ?? [],
                objectCheck: templateModel.objectCheck ?? [],
                violations: templateModel.violations ?? [],
                akt: nil
            )
        case .userDescription:
            return UserDescriptionViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                organizations: templateModel.organizations ?? [],
                objectCheck: templateModel.objectCheck ?? [],
                violations: templateModel.violations ?? [],
                akt: nil
            )
        case .predstavitely:
            return PredstavViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                organizations: templateModel.organizations ?? [],
                objectCheck: templateModel.objectCheck ?? [],
                violations: templateModel.violations ?? [],
                descripUser: templateModel.descripUser ?? "",
                predstavitely: [],
                akt: nil
            )
        case .generate:
            return GenerateAktViewController(
                viewModel: self,
                comissionPeople: templateModel.comissionPeople ?? [],
                date: templateModel.date ?? Date(),
                aktNumber: templateModel.aktNumber ?? "",
                organizations: templateModel.organizations ?? [],
                objectCheck: templateModel.objectCheck ?? [],
                violations: templateModel.violations ?? [],
                descripUser: templateModel.descripUser ?? "",
                predstavitely: templateModel.predstavitely ?? [],
                akt: nil
            )
        }
    }
    
    func createNewEmployer(fio: String, jobTitle: String, escaping: @escaping(Bool) -> Void) {
        if comissionArray.contains(where: {$0.fio == fio}) {
            escaping(false)
        } else {
            let newUser = ComissionPeople(fio: fio, jobTitle: jobTitle)
            comissionArray.append(newUser)
            DataFlowComission.saveArr(arr: comissionArray)
            escaping(true)
        }
    }
    
    func createNewOrganization(title: String, escaping: @escaping(Bool) -> Void) {
        if organizationsArray.contains(where: {$0.title == title}) {
            escaping(false)
        } else {
            let newOrganization = Organization(title: title)
            organizationsArray.append(newOrganization)
            DataFlowOrganizations.saveArr(arr: organizationsArray)
            escaping(true)
        }
    }
    
    func createNewCheckObject(title: String, subtitle: String, escaping: @escaping(Bool) -> Void) {
        if objectCheckArray.contains(where: {$0.title == title}) {
            escaping(false)
        } else {
            let newOrganization = ObjectCheck(title: title, subTitle: subtitle)
            objectCheckArray.append(newOrganization)
            DataFlowObjectsReview.saveArr(arr: objectCheckArray)
            escaping(true)
        }
    }
    
    func createNewPredstavitel(title: String, subtitle: String, escaping: @escaping(Bool) -> Void) {
        if predstavitelyArray.contains(where: {$0.fio == title}) {
            escaping(false)
        } else {
            let newOrganization = PredstavitelyComission(fio: title, jobTitle: subtitle)
            predstavitelyArray.append(newOrganization)
            DataFlowPredstavitely.saveArr(arr: predstavitelyArray)
            escaping(true)
        }
    }
    
    func updateOrganization(at index: Int, newTitle: String, escaping: @escaping(Bool) -> Void) {
        guard index < organizationsArray.count else {
            escaping(false)
            return
        }
        
        // Проверяем, что новое название не совпадает с существующими (кроме текущего)
        let otherOrganizations = organizationsArray.enumerated().compactMap { idx, org in
            return idx != index ? org : nil
        }
        
        if otherOrganizations.contains(where: { $0.title == newTitle }) {
            escaping(false)
        } else {
            let updatedOrganization = Organization(title: newTitle)
            organizationsArray[index] = updatedOrganization
            DataFlowOrganizations.saveArr(arr: organizationsArray)
            escaping(true)
        }
    }
    
    func updateObjectCheck(at index: Int, newTitle: String, newSubtitle: String, escaping: @escaping(Bool) -> Void) {
        guard index < objectCheckArray.count else {
            escaping(false)
            return
        }
        
        // Проверяем, что новое название не совпадает с существующими (кроме текущего)
        let otherObjects = objectCheckArray.enumerated().compactMap { idx, obj in
            return idx != index ? obj : nil
        }
        
        if otherObjects.contains(where: { $0.title == newTitle }) {
            escaping(false)
        } else {
            let updatedObject = ObjectCheck(title: newTitle, subTitle: newSubtitle)
            objectCheckArray[index] = updatedObject
            DataFlowObjectsReview.saveArr(arr: objectCheckArray)
            escaping(true)
        }
    }
    
    func updatePredstavitely(at index: Int, newFio: String, newJobTitle: String, escaping: @escaping(Bool) -> Void) {
        guard index < predstavitelyArray.count else {
            escaping(false)
            return
        }
        
        // Проверяем, что новое ФИО не совпадает с существующими (кроме текущего)
        let otherPredstavitely = predstavitelyArray.enumerated().compactMap { idx, pred in
            return idx != index ? pred : nil
        }
        
        if otherPredstavitely.contains(where: { $0.fio == newFio }) {
            escaping(false)
        } else {
            let updatedPredstavitely = PredstavitelyComission(fio: newFio, jobTitle: newJobTitle)
            predstavitelyArray[index] = updatedPredstavitely
            DataFlowPredstavitely.saveArr(arr: predstavitelyArray)
            escaping(true)
        }
    }
    
    func updateComission(at index: Int, newFio: String, newJobTitle: String, escaping: @escaping(Bool) -> Void) {
        guard index < comissionArray.count else {
            escaping(false)
            return
        }
        
        // Проверяем, что новое ФИО не совпадает с существующими (кроме текущего)
        let otherComission = comissionArray.enumerated().compactMap { idx, com in
            return idx != index ? com : nil
        }
        
        if otherComission.contains(where: { $0.fio == newFio }) {
            escaping(false)
        } else {
            let updatedComission = ComissionPeople(fio: newFio, jobTitle: newJobTitle)
            comissionArray[index] = updatedComission
            DataFlowComission.saveArr(arr: comissionArray)
            escaping(true)
        }
    }
    
    
}
