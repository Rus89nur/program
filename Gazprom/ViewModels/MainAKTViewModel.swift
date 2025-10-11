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
    var continueButtonUpdateBinding: (()->())?
    
    lazy var aktArray: [AKT] = DataFlowAKT.loadArr()
    
    // MARK: - Refresh Data
    func refreshAktArray() {
        aktArray = DataFlowAKT.loadArr()
    }
    lazy var comissionArray: [ComissionPeople] = DataFlowComission.loadArr()
    lazy var organizationsArray: [Organization] = DataFlowOrganizations.loadArr()
    lazy var objectCheckArray: [ObjectCheck] = DataFlowObjectsReview.loadArr()
    lazy var predstavitelyArray: [PredstavitelyComission] = DataFlowPredstavitely.loadArr()
    let templateModel = TemplateModel()
    
    // Последний открытый АКТ для кнопки "Продолжить заполнение"
    private var lastOpenedAkt: AKT?
    
    // Ключ для сохранения последнего открытого акта в UserDefaults
    private let lastOpenedAktKey = "LastOpenedAktId"
    
    // MARK: - Draft Management
    func saveDraft(currentStep: AKTCreationStep) {
        if let draft = DraftManager.shared.createDraftFromTemplate(templateModel, currentStep: currentStep) {
            DraftManager.shared.saveDraft(draft)
            
            // Уведомляем о необходимости обновления кнопки "Продолжить"
            DispatchQueue.main.async {
                self.continueButtonUpdateBinding?()
            }
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
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    // MARK: - Last Opened AKT Management
    func setLastOpenedAkt(_ akt: AKT?) {
        lastOpenedAkt = akt
        if let akt = akt {
            // Сохраняем ID последнего открытого акта в UserDefaults
            UserDefaults.standard.set(akt.id.uuidString, forKey: lastOpenedAktKey)
        } else {
            // Очищаем сохраненный ID
            UserDefaults.standard.removeObject(forKey: lastOpenedAktKey)
        }
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    func getLastOpenedAkt() -> AKT? {
        // Всегда проверяем UserDefaults, чтобы получить актуальный ID
        if let lastOpenedAktIdString = UserDefaults.standard.string(forKey: lastOpenedAktKey) {
            if let lastOpenedAktId = UUID(uuidString: lastOpenedAktIdString) {
                // Ищем акт в обновленном массиве актов
                lastOpenedAkt = aktArray.first { $0.id == lastOpenedAktId }
                return lastOpenedAkt
            }
        } else {
            lastOpenedAkt = nil
        }
        
        return nil
    }
    
    func clearLastOpenedAkt() {
        lastOpenedAkt = nil
        UserDefaults.standard.removeObject(forKey: lastOpenedAktKey)
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    // MARK: - Get Last Akt for Continue
    func getLastAktForContinue() -> AKT? {
        // Обновляем массив актов перед поиском
        refreshAktArray()
        
        // Новая логика: приоритет редактируемому акту
        
        // 1. Если есть черновик - значит последним делали новый акт
        if hasDraft() {
            return nil // Черновик обрабатывается отдельно
        }
        
        // 2. Если есть редактируемый акт - значит последним редактировали акт
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            return editableAkt.akt
        }
        
        // 3. Если есть последний открытый акт - значит последним открывали из истории
        if let lastOpened = getLastOpenedAkt() {
            return lastOpened
        }
        
        // 4. Если ничего не найдено - показываем пустую кнопку
        return nil
    }
    
    // MARK: - Editable AKT Management
    func getEditableAktInfo() -> (akt: AKT, violationsCount: Int)? {
        guard let editableAkt = DataFlowAKT.getEditableAKT() else { return nil }
        return (editableAkt.akt, editableAkt.akt.violations.count)
    }
    
    func createEditableAKT(from akt: AKT) {
        _ = DataFlowAKT.createEditableAKT(from: akt)
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    func updateEditableAKT(_ updatedAkt: AKT) {
        DataFlowAKT.updateEditableAKT(updatedAkt)
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    func finalizeEditableAKT() -> AKT? {
        guard let finalAkt = DataFlowAKT.finalizeEditableAKT() else { return nil }
        
        // Добавляем финальный акт в историю
        addNewAktToArray(finalAkt)
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
        
        return finalAkt
    }
    
    func moveEditableToHistory() {
        DataFlowAKT.moveEditableToHistory()
        
        // Обновляем массив актов
        refreshAktArray()
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
    }
    
    func replaceEditableAKT(with newAkt: AKT) {
        DataFlowAKT.replaceEditableAKT(with: newAkt)
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            self.continueButtonUpdateBinding?()
        }
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
    
    // MARK: - AKT Array Management
    func updateAktInArray(_ updatedAkt: AKT) {
        // Находим индекс акта в массиве по ID
        if let index = aktArray.firstIndex(where: { $0.id == updatedAkt.id }) {
            // Обновляем акт в массиве
            aktArray[index] = updatedAkt
            // Сохраняем обновленный массив
            DataFlowAKT.saveArr(arr: aktArray)
            print("✅ АКТ обновлен в массиве: №\(updatedAkt.number)")
        } else {
            print("❌ Акт с ID \(updatedAkt.id) не найден в массиве для обновления!")
            print("   Доступные ID в массиве: \(aktArray.map { $0.id })")
        }
        
        // Уведомляем о необходимости обновления коллекции
        DispatchQueue.main.async {
            self.collectionReloadBinding?()
        }
    }
    
    func addNewAktToArray(_ newAkt: AKT) {
        // Добавляем новый акт в массив
        aktArray.append(newAkt)
        DataFlowAKT.saveArr(arr: aktArray)
        print("✅ Новый АКТ добавлен в массив: №\(newAkt.number)")
        
        // Уведомляем о необходимости обновления коллекции
        DispatchQueue.main.async {
            self.collectionReloadBinding?()
        }
    }
    
    // MARK: - Number Validation
    func isAktNumberAvailable(_ number: String, excludingAktId: UUID? = nil) -> Bool {
        // Обновляем массив актов
        refreshAktArray()
        
        // Проверяем, есть ли акт с таким номером (исключая текущий акт при редактировании)
        let existingAkt = aktArray.first { akt in
            akt.number == number && (excludingAktId == nil || akt.id != excludingAktId)
        }
        
        return existingAkt == nil
    }
    
    func getOccupiedAktNumbers() -> Set<String> {
        // Обновляем массив актов
        refreshAktArray()
        
        // Возвращаем множество занятых номеров
        return Set(aktArray.map { $0.number })
    }
    
    func getNextAvailableAktNumber() -> String {
        let occupiedNumbers = getOccupiedAktNumbers()
        var number = 1
        
        while occupiedNumbers.contains("\(number)") {
            number += 1
        }
        
        return "\(number)"
    }

    // MARK: - New AKT Creation with Editable System
    func createNewAktAndMakeEditable(_ newAkt: AKT) {
        // Создаем редактируемый акт
        createEditableAKT(from: newAkt)
        
        // Очищаем черновик при создании нового акта
        deleteDraft()
        
        print("✅ Новый АКТ №\(newAkt.number) создан и сделан редактируемым")
    }
    
    // MARK: - Edit Existing AKT
    func editExistingAkt(_ akt: AKT) {
        // Создаем редактируемый акт из существующего
        createEditableAKT(from: akt)
        
        // Очищаем черновик при редактировании акта
        deleteDraft()
        
        // Сохраняем акт как последний открытый
        setLastOpenedAkt(akt)
        
        print("✅ АКТ №\(akt.number) сделан редактируемым для продолжения")
    }
    
    // MARK: - Save Changes to Editable AKT
    func saveChangesToEditableAkt(_ updatedAkt: AKT) {
        // Обновляем редактируемый акт
        updateEditableAKT(updatedAkt)
        
        print("✅ Изменения сохранены в редактируемый АКТ №\(updatedAkt.number)")
    }
    
    // MARK: - Finalize Editable AKT (move to history)
    func finalizeEditableAktToHistory() {
        // Перемещаем редактируемый акт в историю
        moveEditableToHistory()
        
        // Очищаем последний открытый акт
        clearLastOpenedAkt()
        
        print("✅ Редактируемый АКТ финализирован и перемещен в историю")
    }
    
    
}
