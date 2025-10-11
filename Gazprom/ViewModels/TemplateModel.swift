//
//  TemplateModel.swift
//  Gazprom
//
//  Created by Владимир on 04.08.2025.
//

import Foundation

class TemplateModel {
    
    // MARK: - Properties
    var comissionPeople: [ComissionPeople]? {
        didSet {
            autoSave()
        }
    }
    var date: Date? {
        didSet {
            autoSave()
        }
    }
    var aktNumber: String? {
        didSet {
            autoSave()
        }
    }
    var organizations: [Organization]? {
        didSet {
            autoSave()
        }
    }
    var objectCheck: [ObjectCheck]? {
        didSet {
            autoSave()
        }
    }
    var violations: [Violations]? {
        didSet {
            autoSave()
        }
    }
    var descripUser: String? {
        didSet {
            autoSave()
        }
    }
    var predstavitely: [PredstavitelyComission]? {
        didSet {
            autoSave()
        }
    }
    var ustranenDatePicker: Date? {
        didSet {
            autoSave()
        }
    }
    var predostavlenDatePicker: Date? {
        didSet {
            autoSave()
        }
    }
    var utverzdenDatePicker: Date? {
        didSet {
            autoSave()
        }
    }
    
    // MARK: - Auto-save properties
    private var autoSaveEnabled: Bool = true
    private var lastSaveTime: Date = Date()
    private let saveDelay: TimeInterval = 1.0 // Задержка перед сохранением
    private var saveTimer: Timer?
    
    // MARK: - Callback for auto-save
    var autoSaveCallback: (() -> Void)?
    
    // MARK: - Initialization
    init() {
        // Загружаем существующий черновик при инициализации
        loadFromDraft()
    }
    
    // MARK: - Auto-save functionality
    private func autoSave() {
        guard autoSaveEnabled else { return }
        
        // Отменяем предыдущий таймер
        saveTimer?.invalidate()
        
        // Устанавливаем новый таймер
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDelay, repeats: false) { [weak self] _ in
            self?.performAutoSave()
        }
    }
    
    private func performAutoSave() {
        // Проверяем, есть ли минимальные данные для сохранения
        guard hasMinimumDataForDraft() else {
            print("⚠️ Недостаточно данных для автосохранения")
            return
        }
        
        // Создаем черновик из текущего состояния
        if let draft = createDraftFromCurrentState() {
            DraftManager.shared.saveDraft(draft)
            lastSaveTime = Date()
            print("✅ Автосохранение выполнено: \(draft.currentStep.displayName)")
            
            // Вызываем callback для обновления UI
            DispatchQueue.main.async {
                self.autoSaveCallback?()
            }
        }
    }
    
    private func hasMinimumDataForDraft() -> Bool {
        return date != nil && aktNumber != nil
    }
    
    private func createDraftFromCurrentState() -> DraftAKT? {
        guard let date = date, let aktNumber = aktNumber else { return nil }
        
        // Определяем текущий шаг на основе заполненных данных
        let currentStep = determineCurrentStep()
        
        return DraftAKT(
            date: date,
            aktNumber: aktNumber,
            comissionPeople: comissionPeople ?? [],
            organizations: organizations ?? [],
            objectCheck: objectCheck ?? [],
            violations: violations ?? [],
            descripUser: descripUser ?? "",
            predstavitely: predstavitely ?? [],
            ustranenDatePicker: ustranenDatePicker,
            predostavlenDatePicker: predostavlenDatePicker,
            utverzdenDatePicker: utverzdenDatePicker,
            currentStep: currentStep
        )
    }
    
    private func determineCurrentStep() -> AKTCreationStep {
        // Логика определения текущего шага на основе заполненных данных
        if ustranenDatePicker != nil && predostavlenDatePicker != nil && utverzdenDatePicker != nil {
            return .generate
        } else if predstavitely?.isEmpty == false {
            return .predstavitely
        } else if descripUser?.isEmpty == false {
            return .userDescription
        } else if violations?.isEmpty == false {
            return .violations
        } else if objectCheck?.isEmpty == false {
            return .objectCheck
        } else if organizations?.isEmpty == false {
            return .organizations
        } else {
            return .dateAndNumber
        }
    }
    
    // MARK: - Load from draft
    private func loadFromDraft() {
        if let draft = DraftManager.shared.loadDraft() {
            loadFromDraft(draft)
        }
    }
    
    func loadFromDraft(_ draft: DraftAKT) {
        // Временно отключаем автосохранение при загрузке
        autoSaveEnabled = false
        
        date = draft.date
        aktNumber = draft.aktNumber
        comissionPeople = draft.comissionPeople
        organizations = draft.organizations
        objectCheck = draft.objectCheck
        violations = draft.violations
        descripUser = draft.descripUser
        predstavitely = draft.predstavitely
        ustranenDatePicker = draft.ustranenDatePicker
        predostavlenDatePicker = draft.predostavlenDatePicker
        utverzdenDatePicker = draft.utverzdenDatePicker
        
        // Включаем автосохранение обратно
        autoSaveEnabled = true
    }
    
    // MARK: - Load from AKT
    func loadFromAkt(_ akt: AKT) {
        // Временно отключаем автосохранение при загрузке
        autoSaveEnabled = false
        
        date = akt.date
        aktNumber = akt.number
        comissionPeople = akt.comission
        organizations = [akt.organization]
        objectCheck = akt.objectsCheck
        violations = akt.violations
        descripUser = akt.description
        predstavitely = akt.predstavitelyComission
        ustranenDatePicker = akt.actustranenDate
        predostavlenDatePicker = akt.actPredostavlenDate
        utverzdenDatePicker = akt.actUtverzdenDate
        
        // Включаем автосохранение обратно
        autoSaveEnabled = true
    }
    
    // MARK: - Manual save
    func forceSave() {
        saveTimer?.invalidate()
        performAutoSave()
    }
    
    // MARK: - Control auto-save
    func enableAutoSave() {
        autoSaveEnabled = true
    }
    
    func disableAutoSave() {
        autoSaveEnabled = false
        saveTimer?.invalidate()
    }
    
    // MARK: - Reset
    func reset() {
        // Отключаем автосохранение при сбросе
        disableAutoSave()
        
        comissionPeople = nil
        date = nil
        aktNumber = nil
        organizations = nil
        objectCheck = nil
        violations = nil
        descripUser = nil
        predstavitely = nil
        utverzdenDatePicker = nil
        predostavlenDatePicker = nil
        ustranenDatePicker = nil
        
        // Включаем автосохранение обратно
        enableAutoSave()
    }
    
    // MARK: - Get last save time
    func getLastSaveTime() -> Date {
        return lastSaveTime
    }
    
    // MARK: - Check if has unsaved changes
    func hasUnsavedChanges() -> Bool {
        return Date().timeIntervalSince(lastSaveTime) > saveDelay
    }
}
