//
//  MainAKTViewModel.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation
import UIKit
import Combine

// MARK: - Simple Realtime AKT System (Integrated)
protocol SimpleRealtimeAKTObserver: AnyObject {
    func aktDidChange(_ change: String)
    func aktDidSave(_ akt: AKT)
}

class SimpleRealtimeAKTManager: ObservableObject {
    static let shared = SimpleRealtimeAKTManager()
    
    @Published var currentAkt: AKT?
    @Published var hasUnsavedChanges: Bool = false
    @Published var lastChangeTime: Date?
    
    private var saveTimer: Timer?
    private let saveDelay: TimeInterval = 2.0
    /// Очередь для записи черновика на диск, чтобы не блокировать main
    private let saveQueue = DispatchQueue(label: "realtime.save", qos: .utility)
    private var changeHistory: [String] = []
    private let changeSubject = PassthroughSubject<String, Never>()
    private let saveSubject = PassthroughSubject<AKT, Never>()
    
    var changePublisher: AnyPublisher<String, Never> {
        changeSubject.eraseToAnyPublisher()
    }
    
    var savePublisher: AnyPublisher<AKT, Never> {
        saveSubject.eraseToAnyPublisher()
    }
    
    private init() {
        loadCurrentAkt()
    }
    
    func startEditing(_ akt: AKT) {
        print("🔄 [REALTIME] Начинаем редактирование акта №\(akt.number)")
        print("   🆔 ID акта: \(akt.id.uuidString)")
        print("   📋 Количество нарушений: \(akt.violations.count)")
        currentAkt = akt
        hasUnsavedChanges = false
        changeHistory.removeAll()
        _ = DataFlowAKT.createEditableAKT(from: akt)
        print("✅ [REALTIME] Редактирование акта инициализировано")
    }
    
    func finishEditing() {
        print("✅ [REALTIME] Завершаем редактирование акта")
        saveChangesImmediately { [weak self] in
            guard let self = self else { return }
            self.hasUnsavedChanges = false
            self.currentAkt = nil
            self.changeHistory.removeAll()
            DataFlowAKT.deleteEditableAKT()
        }
    }
    
    func updateOrganization(_ organization: Organization) {
        guard var akt = currentAkt else { 
            print("❌ [REALTIME] currentAkt is nil, cannot update organization")
            return 
        }
        
        print("🔄 [REALTIME] Обновление организации в SimpleRealtimeAKTManager")
        print("   🔢 Номер акта: \(akt.number)")
        print("   🆔 ID акта: \(akt.id.uuidString)")
        print("   🏢 Текущая организация: \(akt.organization.title)")
        print("   🏢 Новая организация: \(organization.title)")
        
        akt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        print("✅ [REALTIME] Акт обновлен с новой организацией")
        print("   🏢 Финальная организация в акте: \(akt.organization.title)")
        
        recordChange("Обновлена организация: \(organization.title)")
        updateAkt(akt)
    }
    
    func updateViolations(_ violations: [Violations]) {
        guard let akt = currentAkt else {
            print("❌ [UPDATE_VIOLATIONS] currentAkt is nil, cannot update violations")
            return
        }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлены нарушения (\(violations.count) шт.)")
        updateAkt(updatedAkt)
    }
    
    func updateDescription(_ description: String) {
        guard let akt = currentAkt else { return }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлены выводы")
        updateAkt(updatedAkt)
    }
    
    func updateNumber(_ number: String) {
        guard let akt = currentAkt else { return }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлен номер акта: \(number)")
        updateAkt(updatedAkt)
    }
    
    func updatePredstavitely(_ predstavitely: [PredstavitelyComission]) {
        guard let akt = currentAkt else { return }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: predstavitely,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлены представители (\(predstavitely.count) шт.)")
        updateAkt(updatedAkt)
    }
    
    func updateObjectsCheck(_ objectsCheck: [ObjectCheck]) {
        guard let akt = currentAkt else { return }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: akt.comission,
            organization: akt.organization,
            objectsCheck: objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлены объекты проверки (\(objectsCheck.count) шт.)")
        updateAkt(updatedAkt)
    }
    
    func updateCommission(_ commission: [ComissionPeople]) {
        guard let akt = currentAkt else { return }
        
        let updatedAkt = AKT(
            id: akt.id,
            number: akt.number,
            date: akt.date,
            comission: commission,
            organization: akt.organization,
            objectsCheck: akt.objectsCheck,
            predstavitelyComission: akt.predstavitelyComission,
            violations: akt.violations,
            description: akt.description,
            actustranenDate: akt.actustranenDate,
            actPredostavlenDate: akt.actPredostavlenDate,
            actUtverzdenDate: akt.actUtverzdenDate,
            urlAct: akt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: akt.realDateCreate,
            uniqueID: akt.uniqueID // Сохраняем uniqueID
        )
        
        recordChange("Обновлена комиссия (\(commission.count) чел.)")
        updateAkt(updatedAkt)
    }
    
    /// Сохраняет черновик на диск. Тяжёлый I/O и логирование — только в saveQueue; при срабатывании таймера main только ставит задачу в очередь.
    /// - Parameter completion: вызывается на main после завершения сохранения (для finishEditing).
    func saveChangesImmediately(completion: (() -> Void)? = nil) {
        saveTimer?.invalidate()
        saveTimer = nil
        guard let akt = currentAkt else {
            completion?()
            return
        }
        // Минимум работы на main: только dispatch. Весь I/O — в фоне.
        saveQueue.async { [weak self] in
            DataFlowAKT.updateEditableAKT(akt)
            DispatchQueue.main.async {
                guard let self = self else { completion?(); return }
                self.saveSubject.send(akt)
                self.hasUnsavedChanges = false
                self.lastChangeTime = Date()
                completion?()
            }
        }
    }
    
    /// Принудительное сохранение изменений (можно вызывать из UI)
    func forceSaveChanges() {
        saveChangesImmediately()
    }
    
    /// Получить информацию о текущем статусе редактирования
    func getStatusInfo() -> String {
        if currentAkt == nil {
            return "Редактирование не активно"
        }
        if hasUnsavedChanges {
            return "Есть несохраненные изменения (\(changeHistory.count))"
        } else {
            return "Все изменения сохранены"
        }
    }
    
    private func loadCurrentAkt() {
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            currentAkt = editableAkt.akt
            print("📱 [REALTIME] Загружен редактируемый акт №\(editableAkt.akt.number)")
        }
    }
    
    private func recordChange(_ description: String) {
        changeHistory.append(description)
        if changeHistory.count > 50 {
            changeHistory.removeFirst()
        }
        changeSubject.send(description)
        print("📝 [REALTIME] Зафиксировано изменение: \(description)")
    }
    
    private func updateAkt(_ akt: AKT) {
        currentAkt = akt
        hasUnsavedChanges = true
        lastChangeTime = Date()
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: saveDelay, repeats: false) { [weak self] _ in
            self?.saveChangesImmediately()
        }
    }
    
    // MARK: - Deinitialization
    
    deinit {
        saveTimer?.invalidate()
        saveTimer = nil
        print("✅ SimpleRealtimeAKTManager deallocated")
    }
}

class SimpleRealtimeAKTObserverManager {
    static let shared = SimpleRealtimeAKTObserverManager()
    
    private var observers: [WeakObserver] = []
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
    }
    
    private func setupObservers() {
        SimpleRealtimeAKTManager.shared.changePublisher
            .sink { [weak self] change in
                self?.notifyObservers { $0.aktDidChange(change) }
            }
            .store(in: &cancellables)
        
        SimpleRealtimeAKTManager.shared.savePublisher
            .sink { [weak self] akt in
                self?.notifyObservers { $0.aktDidSave(akt) }
            }
            .store(in: &cancellables)
    }
    
    func addObserver(_ observer: SimpleRealtimeAKTObserver) {
        observers.removeAll { $0.observer == nil }
        if !observers.contains(where: { $0.observer === observer }) {
            observers.append(WeakObserver(observer: observer))
            print("👁️ [REALTIME] Добавлен наблюдатель: \(type(of: observer))")
        }
    }
    
    func removeObserver(_ observer: SimpleRealtimeAKTObserver) {
        let beforeCount = observers.count
        observers.removeAll { $0.observer === observer || $0.observer == nil }
        let afterCount = observers.count
        
        // Логируем только если наблюдатель действительно был удален
        if beforeCount > afterCount {
            print("👁️ [REALTIME] Удален наблюдатель: \(type(of: observer))")
        } else if beforeCount == afterCount {
            // Наблюдатель не был найден - возможно, уже был удален ранее
            print("⚠️ [REALTIME] Попытка удалить несуществующий наблюдатель: \(type(of: observer))")
        }
    }
    
    private func notifyObservers(_ action: (SimpleRealtimeAKTObserver) -> Void) {
        observers.forEach { weakObserver in
            if let observer = weakObserver.observer {
                action(observer)
            }
        }
        observers.removeAll { $0.observer == nil }
    }
}

private class WeakObserver {
    weak var observer: SimpleRealtimeAKTObserver?
    
    init(observer: SimpleRealtimeAKTObserver) {
        self.observer = observer
    }
}

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
            return "Выводы"
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
    
    // Максимальный размер данных для UserDefaults (4MB)
    private let maxUserDefaultsSize = 4 * 1024 * 1024
    
    // Кэш для черновика, чтобы избежать повторных загрузок
    private var cachedDraft: DraftAKT?
    private var lastLoadTime: Date?
    private let cacheTimeout: TimeInterval = 1.0 // 1 секунда кэширования
    
    private init() {}
    
    // MARK: - Save Draft
    func saveDraft(_ draft: DraftAKT) {
        do {
            let data = try JSONEncoder().encode(draft)
            
            // Проверяем размер данных
            if data.count > maxUserDefaultsSize {
                print("⚠️ Размер данных черновика превышает лимит UserDefaults (\(data.count) байт)")
                // Сохраняем в файл вместо UserDefaults
                saveDraftToFile(draft)
                // Обновляем кэш
                self.cachedDraft = draft
                self.lastLoadTime = Date()
                return
            }
            
            // Очищаем старые данные перед сохранением
            userDefaults.removeObject(forKey: draftKey)
            userDefaults.removeObject(forKey: "\(draftKey)_in_file")
            userDefaults.removeObject(forKey: "\(draftKey)_file_path")
            
            userDefaults.set(data, forKey: draftKey)
            userDefaults.synchronize()
            print("✅ Черновик АКТ сохранен в UserDefaults: \(draft.currentStep.displayName)")
            
            // Обновляем кэш
            self.cachedDraft = draft
            self.lastLoadTime = Date()
        } catch {
            print("❌ Ошибка сохранения черновика: \(error)")
            // В случае ошибки пытаемся сохранить в файл
            saveDraftToFile(draft)
            // Обновляем кэш
            self.cachedDraft = draft
            self.lastLoadTime = Date()
        }
    }
    
    // MARK: - Save Draft to File
    private func saveDraftToFile(_ draft: DraftAKT) {
        do {
            let data = try JSONEncoder().encode(draft)
            let fileManager = FileManager.default
            guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Не удалось получить папку документов")
                return
            }
            
            let fileURL = documentDirectory.appendingPathComponent("DraftAKT.json")
            try data.write(to: fileURL)
            
            // Сохраняем флаг, что черновик находится в файле
            userDefaults.set(true, forKey: "\(draftKey)_in_file")
            userDefaults.set(fileURL.path, forKey: "\(draftKey)_file_path")
            
            print("✅ Черновик АКТ сохранен в файл: \(fileURL.path)")
        } catch {
            print("❌ Ошибка сохранения черновика в файл: \(error)")
        }
    }
    
    // MARK: - Load Draft
    func loadDraft() -> DraftAKT? {
        // Проверяем кэш
        if let cachedDraft = cachedDraft,
           let lastLoadTime = lastLoadTime,
           Date().timeIntervalSince(lastLoadTime) < cacheTimeout {
            return cachedDraft
        }
        
        // Загружаем черновик
        let draft: DraftAKT?
        
        // Проверяем, находится ли черновик в файле
        if userDefaults.bool(forKey: "\(draftKey)_in_file") {
            draft = loadDraftFromFile()
        } else {
            // Пытаемся загрузить из UserDefaults
            guard let data = userDefaults.data(forKey: draftKey) else {
                print("⚠️ Черновик не найден")
                self.cachedDraft = nil
                self.lastLoadTime = nil
                return nil
            }
            
            do {
                let loadedDraft = try JSONDecoder().decode(DraftAKT.self, from: data)
                print("✅ Черновик АКТ загружен из UserDefaults: \(loadedDraft.currentStep.displayName)")
                draft = loadedDraft
            } catch {
                print("❌ Ошибка загрузки черновика из UserDefaults: \(error)")
                self.cachedDraft = nil
                self.lastLoadTime = nil
                return nil
            }
        }
        
        // Обновляем кэш
        self.cachedDraft = draft
        self.lastLoadTime = Date()
        
        return draft
    }
    
    // MARK: - Load Draft from File
    private func loadDraftFromFile() -> DraftAKT? {
        guard let filePath = userDefaults.string(forKey: "\(draftKey)_file_path") else {
            print("❌ Путь к файлу черновика не найден")
            return nil
        }
        
        let fileURL = URL(fileURLWithPath: filePath)
        
        // Проверяем существование файла перед загрузкой
        guard FileManager.default.fileExists(atPath: filePath) else {
            print("❌ Файл черновика не существует по пути: \(filePath)")
            // Очищаем флаги, если файл не существует
            userDefaults.removeObject(forKey: "\(draftKey)_in_file")
            userDefaults.removeObject(forKey: "\(draftKey)_file_path")
            userDefaults.synchronize()
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let draft = try JSONDecoder().decode(DraftAKT.self, from: data)
            print("✅ Черновик АКТ загружен из файла: \(draft.currentStep.displayName)")
            return draft
        } catch {
            print("❌ Ошибка загрузки черновика из файла: \(error)")
            // Очищаем флаги при ошибке загрузки
            userDefaults.removeObject(forKey: "\(draftKey)_in_file")
            userDefaults.removeObject(forKey: "\(draftKey)_file_path")
            userDefaults.synchronize()
            return nil
        }
    }
    
    // MARK: - Delete Draft
    func deleteDraft() {
        // Удаляем из UserDefaults
        userDefaults.removeObject(forKey: draftKey)
        
        // Если черновик был в файле, удаляем файл
        if userDefaults.bool(forKey: "\(draftKey)_in_file") {
            if let filePath = userDefaults.string(forKey: "\(draftKey)_file_path") {
                let fileURL = URL(fileURLWithPath: filePath)
                do {
                    try FileManager.default.removeItem(at: fileURL)
                    print("✅ Файл черновика удален: \(filePath)")
                } catch {
                    print("❌ Ошибка удаления файла черновика: \(error)")
                }
            }
            
            // Очищаем флаги
            userDefaults.removeObject(forKey: "\(draftKey)_in_file")
            userDefaults.removeObject(forKey: "\(draftKey)_file_path")
        }
        
        // Очищаем кэш
        self.cachedDraft = nil
        self.lastLoadTime = nil
        
        print("✅ Черновик АКТ удален")
    }
    
    // MARK: - Check if Draft Exists
    func hasDraft() -> Bool {
        // Проверяем, есть ли черновик в файле
        if userDefaults.bool(forKey: "\(draftKey)_in_file") {
            if let filePath = userDefaults.string(forKey: "\(draftKey)_file_path") {
                let exists = FileManager.default.fileExists(atPath: filePath)
                if !exists {
                    // Очищаем флаги, если файл не существует
                    userDefaults.removeObject(forKey: "\(draftKey)_in_file")
                    userDefaults.removeObject(forKey: "\(draftKey)_file_path")
                    userDefaults.synchronize()
                    print("🧹 Путь к файлу очищен - требуется повторная загрузка")
                }
                return exists
            } else {
                // Очищаем флаг, если путь не найден
                userDefaults.removeObject(forKey: "\(draftKey)_in_file")
                userDefaults.synchronize()
            }
        }
        
        // Проверяем, есть ли черновик в UserDefaults
        return userDefaults.data(forKey: draftKey) != nil
    }
    
    // MARK: - Get Draft Info
    func getDraftInfo() -> (step: AKTCreationStep, violationsCount: Int)? {
        guard let draft = loadDraft() else { return nil }
        return (draft.currentStep, draft.violations.count)
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        self.cachedDraft = nil
        self.lastLoadTime = nil
        print("✅ Кэш черновика очищен")
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

// MARK: - DataCache
class DataCache {
    static let shared = DataCache()
    
    private var cache: [String: Any] = [:]
    private var lastUpdate: [String: Date] = [:]
    private let cacheTimeout: TimeInterval = 30.0 // 30 секунд кэширования
    
    private init() {}
    
    func get<T>(_ key: String, factory: () -> T) -> T {
        if let cached = cache[key] as? T,
           let lastUpdate = lastUpdate[key],
           Date().timeIntervalSince(lastUpdate) < cacheTimeout {
            print("📦 Данные загружены из кэша: \(key)")
            return cached
        }
        
        print("🔄 Загружаем данные: \(key)")
        let newValue = factory()
        cache[key] = newValue
        lastUpdate[key] = Date()
        return newValue
    }
    
    func invalidate(_ key: String) {
        cache.removeValue(forKey: key)
        lastUpdate.removeValue(forKey: key)
        print("🗑️ Кэш очищен: \(key)")
    }
    
    func invalidateAll() {
        cache.removeAll()
        lastUpdate.removeAll()
        print("🗑️ Весь кэш очищен")
    }
}

class MainAKTViewModel: SimpleRealtimeAKTObserver {
    
    var collectionReloadBinding: (()->())?
    var continueButtonUpdateBinding: (()->())?
    
    // Realtime AKT Integration
    private var cancellables = Set<AnyCancellable>()
    private let realtimeManager = SimpleRealtimeAKTManager.shared
    
    // Serial queue для безопасного доступа к данным
    private let serialQueue = DispatchQueue(label: "com.gazprom.akt.serial", qos: .userInitiated)
    
    init() {
        setupRealtimeIntegration()
    }
    
    deinit {
        print("🔄 MainAKTViewModel deinit - очистка ресурсов")
        cleanupRealtimeIntegration()
        print("✅ MainAKTViewModel deallocated")
    }
    
    // Используем продвинутое кэширование для массивов данных
    private var _aktArray: [AKT] = []
    var aktArray: [AKT] {
        get {
            // Если данные уже загружены, возвращаем их
            if !_aktArray.isEmpty {
                return _aktArray
            }
            
            // Загружаем данные только если массив пустой
            _aktArray = DataFlowAKT.loadArr()
            return _aktArray
        }
        set {
            _aktArray = newValue
        }
    }
    
    // MARK: - Refresh Data
    
    // Кэш для предотвращения повторных загрузок
    private var lastRefreshTime: Date?
    private let refreshCooldown: TimeInterval = 2.0 // 2 секунды между обновлениями
    
    func refreshAktArray() {
        // Проверяем, нужно ли обновлять данные
        if let lastRefresh = lastRefreshTime,
           Date().timeIntervalSince(lastRefresh) < refreshCooldown {
            return // Пропускаем обновление, если прошло меньше cooldown времени
        }
        
        let newData = DataFlowAKT.loadArr()
        // Убираем дубликаты по (номер, год даты проверки) — оставляем первое вхождение
        let calendar = Calendar.current
        var seen: Set<String> = []
        var dropped: [(id: String, number: String, year: Int)] = []
        aktArray = newData.filter { akt in
            let year = calendar.component(.year, from: akt.date)
            let key = "\(akt.number)_\(year)"
            guard !seen.contains(key) else {
                dropped.append((akt.id.uuidString, akt.number, year))
                return false
            }
            seen.insert(key)
            return true
        }
        if aktArray.count != newData.count {
            print("🔄 Массив актов: удалено \(newData.count - aktArray.count) дубликатов по (номер, год), осталось \(aktArray.count)")
            for d in dropped { print("   🗑️ Дедуп: удалён №\(d.number), год=\(d.year), ID=\(d.id.prefix(8))...") }
            DataFlowAKT.writeDebugLog(["location": "MainAKTViewModel.swift:refreshAktArray", "message": "REFRESH_DEDUP", "data": ["newData_count": newData.count, "after_count": aktArray.count, "dropped_count": dropped.count, "dropped": dropped.map { ["id": $0.id, "number": $0.number, "year": $0.year] }, "kept_ids": aktArray.map { $0.id.uuidString }, "kept_numbers": aktArray.map { $0.number }] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "B"])
            DataFlowAKT.saveArr(arr: aktArray)
        }
        lastRefreshTime = Date()
        print("🔄 Массив актов обновлен: \(aktArray.count) элементов")
    }
    
    // MARK: - Async Data Loading
    func loadAktArrayAsync(completion: @escaping ([AKT]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let aktArray = DataFlowAKT.loadArr()
            
            DispatchQueue.main.async {
                self.aktArray = aktArray
                self.lastRefreshTime = Date()
                completion(aktArray)
                print("✅ Асинхронная загрузка актов завершена: \(aktArray.count) элементов")
            }
        }
    }
    
    func loadComissionArrayAsync(completion: @escaping ([ComissionPeople]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let comissionArray = DataFlowComission.loadArr()
            
            DispatchQueue.main.async {
                self.comissionArray = comissionArray
                completion(comissionArray)
                print("✅ Асинхронная загрузка комиссии завершена: \(comissionArray.count) элементов")
            }
        }
    }
    
    func loadOrganizationsArrayAsync(completion: @escaping ([Organization]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let organizationsArray = DataFlowOrganizations.loadArr()
            
            DispatchQueue.main.async {
                self.organizationsArray = organizationsArray
                completion(organizationsArray)
                print("✅ Асинхронная загрузка организаций завершена: \(organizationsArray.count) элементов")
            }
        }
    }
    
    func forceRefreshAktArray() {
        // Принудительное обновление без проверки cooldown
        DataCache.shared.invalidate("aktArray")
        _aktArray = DataFlowAKT.loadArr()
        lastRefreshTime = Date()
    }
    lazy var comissionArray: [ComissionPeople] = DataFlowComission.loadArr()
    lazy var organizationsArray: [Organization] = DataFlowOrganizations.loadArr()
    lazy var objectCheckArray: [ObjectCheck] = DataFlowObjectsReview.loadArr()
    lazy var predstavitelyArray: [PredstavitelyComission] = DataFlowPredstavitely.loadArr()
    let templateModel = TemplateModel()
    
    // MARK: - Inspection Plan (Schedule) Helpers
    private let monthlyPlanKey = "MonthlyInspectionPlan"
    
    /// Установить месячный план проверок (график)
    func setMonthlyInspectionPlan(_ plan: Int) {
        let normalized = max(0, plan)
        UserDefaults.standard.set(normalized, forKey: monthlyPlanKey)
        UserDefaults.standard.synchronize()
    }
    
    /// Получить месячный план проверок (по умолчанию 0 если не задан)
    func getMonthlyInspectionPlan() -> Int {
        let value = UserDefaults.standard.integer(forKey: monthlyPlanKey)
        return max(0, value)
    }
    
    /// Количество выполненных проверок в текущем месяце
    func getInspectionsDoneThisMonth() -> Int {
        refreshAktArray()
        let calendar = Calendar.current
        let now = Date()
        return aktArray.filter { akt in
            return calendar.isDate(akt.date, equalTo: now, toGranularity: .month) &&
                   calendar.isDate(akt.date, equalTo: now, toGranularity: .year)
        }.count
    }
    
    /// Прогресс выполнения графика (done, plan, percent 0..1)
    func getInspectionProgress() -> (done: Int, plan: Int, percent: Double) {
        // Принудительно обновляем данные актов, чтобы фактические даты были актуальными
        // Используем forceRefreshAktArray, чтобы обойти cooldown и гарантировать актуальность данных
        forceRefreshAktArray()
        
        // По умолчанию используем все записи графика (если есть), иначе сохраняем старую логику по месяцам
        let items = ScheduleManager.shared.loadScheduleItems()
        print("🔍 [PROGRESS] Всего записей в графике: \(items.count)")
        if !items.isEmpty {
            // Обновляем фактические даты перед расчетом
            print("🔍 [PROGRESS] Обновляем фактические даты...")
            ScheduleManager.shared.updateActualDatesForAllItems()
            // Загружаем обновленные элементы после обновления дат
            let updatedItems = ScheduleManager.shared.loadScheduleItems()
            
            // Фильтруем по году, выбранному в разделе «График» (SelectedAktYear)
            let filteredItems = filterScheduleItemsBySelectedScheduleYear(updatedItems)
            
            let plan = filteredItems.count
            let done = filteredItems.filter { $0.actualDate != nil }.count
            let percent = plan > 0 ? min(1.0, max(0.0, Double(done) / Double(plan))) : 0.0
            
            // Подробное логирование для отладки
            print("🔍 [PROGRESS] План: \(plan), Выполнено: \(done), Процент: \(Int(percent * 100))%")
            
            // Логируем детали по каждой записи
            for (index, item) in filteredItems.enumerated() {
                let status = item.actualDate != nil ? "✅ ВЫПОЛНЕНО" : "❌ НЕ ВЫПОЛНЕНО"
                let actualDateStr = item.actualDate != nil ? "\(item.formattedActualDate ?? "?")" : "нет даты"
                print("🔍 [PROGRESS] \(index + 1). \(item.objectCheck.title) - План: \(item.formattedDate), Факт: \(actualDateStr) - \(status)")
            }
            
            return (done, plan, percent)
        }
        // Fallback: считаем по актам текущего месяца и ручному плану
        let done = getInspectionsDoneThisMonth()
        let plan = getMonthlyInspectionPlan()
        guard plan > 0 else { return (done, plan, 0.0) }
        let percent = min(1.0, max(0.0, Double(done) / Double(plan)))
        return (done, plan, percent)
    }
    
    /// Фильтрует записи графика по году, выбранному в разделе «График» (getSelectedYear / SelectedAktYear).
    /// Если год не выбран — возвращаются все записи.
    private func filterScheduleItemsBySelectedScheduleYear(_ items: [ScheduleItem]) -> [ScheduleItem] {
        guard let selectedYear = getSelectedYear(), selectedYear > 0 else {
            return items
        }
        let calendar = Calendar.current
        return items.filter { calendar.component(.year, from: $0.scheduledDate) == selectedYear }
    }
    
    /// Прогресс по графику только за текущий месяц (done, plan, percent 0..1)
    func getInspectionProgressCurrentMonth() -> (done: Int, plan: Int, percent: Double) {
        // Принудительно обновляем данные актов, чтобы фактические даты были актуальными
        // Используем forceRefreshAktArray, чтобы обойти cooldown и гарантировать актуальность данных
        forceRefreshAktArray()
        
        let all = ScheduleManager.shared.loadScheduleItems()
        if !all.isEmpty {
            ScheduleManager.shared.updateActualDatesForAllItems()
            let updatedAll = ScheduleManager.shared.loadScheduleItems()
            let filteredByYear = filterScheduleItemsBySelectedScheduleYear(updatedAll)
            let calendar = Calendar.current
            let now = Date()
            // Если выбран год в разделе «График» — месяц этого года; иначе текущий месяц/год
            let refYear = getSelectedYear() ?? calendar.component(.year, from: now)
            let refMonth = calendar.component(.month, from: now)
            let items = filteredByYear.filter {
                calendar.component(.year, from: $0.scheduledDate) == refYear &&
                calendar.component(.month, from: $0.scheduledDate) == refMonth
            }
            let plan = items.count
            let done = items.filter { $0.actualDate != nil }.count
            let percent = plan > 0 ? min(1.0, max(0.0, Double(done) / Double(plan))) : 0.0
            return (done, plan, percent)
        }
        // Fallback на старую логику
        let done = getInspectionsDoneThisMonth()
        let plan = getMonthlyInspectionPlan()
        let percent = plan > 0 ? min(1.0, max(0.0, Double(done) / Double(plan))) : 0.0
        return (done, plan, percent)
    }
    
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
        if let akt = akt {
            print("🟢 [VIEWMODEL] setLastOpenedAkt: Сохраняем акт №\(akt.number) (ID: \(akt.id.uuidString))")
            lastOpenedAkt = akt
            // Сохраняем ID последнего открытого акта в UserDefaults
            UserDefaults.standard.set(akt.id.uuidString, forKey: lastOpenedAktKey)
            UserDefaults.standard.synchronize()
            print("🟢 [VIEWMODEL] setLastOpenedAkt: Сохранено в UserDefaults с ключом '\(lastOpenedAktKey)'")
        } else {
            print("🟢 [VIEWMODEL] setLastOpenedAkt: Очищаем lastOpenedAkt")
            lastOpenedAkt = nil
            // Очищаем сохраненный ID
            UserDefaults.standard.removeObject(forKey: lastOpenedAktKey)
            UserDefaults.standard.synchronize()
        }
        
        // Уведомляем о необходимости обновления кнопки "Продолжить"
        DispatchQueue.main.async {
            print("🟢 [VIEWMODEL] setLastOpenedAkt: Вызываем continueButtonUpdateBinding")
            self.continueButtonUpdateBinding?()
        }
    }
    
    func getLastOpenedAkt() -> AKT? {
        // При пустом массиве принудительно подгружаем историю, чтобы не возвращать "последний открытый" при ещё не загруженном списке
        if aktArray.isEmpty {
            lastRefreshTime = nil
            refreshAktArray()
        }
        
        // #region agent log
        let logDict: [String: Any] = ["location": "MainAKTViewModel.swift:getLastOpenedAkt:start", "message": "НАЧАЛО ПОИСКА ПОСЛЕДНЕГО ОТКРЫТОГО АКТА", "data": ["aktArray_count": aktArray.count], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "F"]
        DataFlowAKT.writeDebugLog(logDict)
        // #endregion
        
        print("🔴 [VIEWMODEL] getLastOpenedAkt: Начинаем поиск последнего открытого акта")
        print("🔴 [VIEWMODEL] getLastOpenedAkt: aktArray содержит \(aktArray.count) актов")
        
        // ИСПРАВЛЕНИЕ: Сначала проверяем EditableAKT - это актуальная версия с последними изменениями
        if let editableAkt = DataFlowAKT.getEditableAKT() {
            print("🔴 [VIEWMODEL] getLastOpenedAkt: ✅ Найден EditableAKT №\(editableAkt.akt.number) (ID: \(editableAkt.akt.id.uuidString))")
            print("🔴 [VIEWMODEL] getLastOpenedAkt: 📋 Количество нарушений в EditableAKT: \(editableAkt.akt.violations.count)")
            print("🔴 [VIEWMODEL] getLastOpenedAkt: 📋 Нарушения в EditableAKT:")
            for (index, violation) in editableAkt.akt.violations.enumerated() {
                print("      [\(index)] ID: \(violation.id.uuidString.prefix(8))..., vid: '\(violation.vid)', title: '\(violation.title.prefix(30))...'")
            }
            
            // #region agent log - простой способ
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let logFile = documentsPath.appendingPathComponent("debug.log")
            let logMessage = "\(Date()): [getLastOpenedAkt] Загружен EditableAKT №\(editableAkt.akt.number), нарушений: \(editableAkt.akt.violations.count)\n"
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFile.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: logFile)
                }
            }
            // #endregion
            
            // #region agent log
            let violationsInfo = editableAkt.akt.violations.enumerated().map { index, violation in
                ["index": index, "id": violation.id.uuidString, "vid": violation.vid, "title": violation.title]
            }
            let logDict2: [String: Any] = ["location": "MainAKTViewModel.swift:getLastOpenedAkt:found_editable", "message": "НАЙДЕН EDITABLEAKT", "data": ["akt_id": editableAkt.akt.id.uuidString, "akt_number": editableAkt.akt.number, "violations_count": editableAkt.akt.violations.count, "violations": violationsInfo], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "F"]
            DataFlowAKT.writeDebugLog(logDict2)
            // #endregion
            
            lastOpenedAkt = editableAkt.akt
            return editableAkt.akt
        } else {
            print("🔴 [VIEWMODEL] getLastOpenedAkt: ⚠️ EditableAKT не найден, ищем в истории")
        }
        
        // Если EditableAKT не найден, ищем в истории
        // Всегда проверяем UserDefaults, чтобы получить актуальный ID
        if let lastOpenedAktIdString = UserDefaults.standard.string(forKey: lastOpenedAktKey) {
            print("🔴 [VIEWMODEL] getLastOpenedAkt: Найден ID в UserDefaults: \(lastOpenedAktIdString)")
            
            if let lastOpenedAktId = UUID(uuidString: lastOpenedAktIdString) {
                print("🔴 [VIEWMODEL] getLastOpenedAkt: Ищем акт с ID \(lastOpenedAktId) в массиве из \(aktArray.count) актов")
                
                // Логируем все ID актов в массиве
                for (index, akt) in aktArray.enumerated() {
                    print("🔴 [VIEWMODEL] getLastOpenedAkt: актArray[\(index)]: №\(akt.number), ID: \(akt.id)")
                }
                
                // Ищем акт в обновленном массиве актов
                lastOpenedAkt = aktArray.first { $0.id == lastOpenedAktId }
                
                if let found = lastOpenedAkt {
                    print("🔴 [VIEWMODEL] getLastOpenedAkt: ✅ Найден акт №\(found.number) (ID: \(found.id)) в истории")
                } else {
                    print("🔴 [VIEWMODEL] getLastOpenedAkt: ❌ Акт с ID \(lastOpenedAktId) НЕ найден в aktArray")
                }
                
                return lastOpenedAkt
            } else {
                print("🔴 [VIEWMODEL] getLastOpenedAkt: ❌ Не удалось преобразовать строку \(lastOpenedAktIdString) в UUID")
            }
        } else {
            print("🔴 [VIEWMODEL] getLastOpenedAkt: ❌ В UserDefaults нет значения для ключа '\(lastOpenedAktKey)'")
            lastOpenedAkt = nil
        }
        
        print("🔴 [VIEWMODEL] getLastOpenedAkt: Возвращаем nil")
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
        print("🟡 [VIEWMODEL] getLastAktForContinue: Начинаем поиск акта для продолжения")
        
        // Обновляем массив актов перед поиском
        refreshAktArray()
        print("🟡 [VIEWMODEL] getLastAktForContinue: После refreshAktArray: \(aktArray.count) актов")
        
        // 1. Если есть черновик - значит последним делали новый акт
        if hasDraft() {
            print("🟡 [VIEWMODEL] getLastAktForContinue: Есть черновик, возвращаем nil")
            return nil // Черновик обрабатывается отдельно
        }
        
        // 2. Проверяем последний открытый акт и редактируемый акт
        print("🟡 [VIEWMODEL] getLastAktForContinue: Проверяем getLastOpenedAkt() и редактируемый акт...")
        let lastOpened = getLastOpenedAkt()
        let editableAkt = DataFlowAKT.getEditableAKT()
        
        // Приоритет 1: сокращенные акты всегда имеют приоритет
        // Сначала проверяем последний открытый акт - если он сокращенный, возвращаем его
        if let lastOpened = lastOpened {
            let isShort = lastOpened.isShortFormat
            print("🟡 [VIEWMODEL] getLastAktForContinue: Найден последний открытый акт №\(lastOpened.number), сокращенный: \(isShort)")
            
            if isShort {
                print("🟡 [VIEWMODEL] getLastAktForContinue: ✅ Последний открытый акт №\(lastOpened.number) - сокращенный, возвращаем его (приоритет)")
                return lastOpened
            }
        }
        
        // Приоритет 2: Если редактируемый акт - сокращенный, возвращаем его
        if let editableAkt = editableAkt {
            let isShort = editableAkt.akt.isShortFormat
            print("🟡 [VIEWMODEL] getLastAktForContinue: Есть редактируемый акт №\(editableAkt.akt.number), сокращенный: \(isShort)")
            
            if isShort {
                print("🟡 [VIEWMODEL] getLastAktForContinue: ✅ Редактируемый акт №\(editableAkt.akt.number) - сокращенный, возвращаем его")
                return editableAkt.akt
            }
        }
        
        // Приоритет 3: Если есть редактируемый акт (не сокращенный) - значит последним редактировали акт
        if let editableAkt = editableAkt {
            print("🟡 [VIEWMODEL] getLastAktForContinue: Есть редактируемый акт №\(editableAkt.akt.number) (полный), возвращаем его")
            return editableAkt.akt
        }
        
        // Приоритет 4: Если есть последний открытый акт (не сокращенный) - значит последним открывали из истории
        if let lastOpened = lastOpened {
            print("🟡 [VIEWMODEL] getLastAktForContinue: ✅ Возвращаем последний открытый акт №\(lastOpened.number) (полный)")
            return lastOpened
        }
        
        // 5. Если ничего не найдено - показываем пустую кнопку
        print("🟡 [VIEWMODEL] getLastAktForContinue: ❌ Ничего не найдено, возвращаем nil")
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
            return "Выводы"
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
            print("⚠️ [COMMISSION_CREATE] Попытка создать дублирующегося члена комиссии: \(fio)")
            print("   👤 ФИО: \(fio)")
            print("   💼 Должность: \(jobTitle)")
            print("   ❌ Дубликат: true")
            escaping(false)
        } else {
            let newUser = ComissionPeople(fio: fio, jobTitle: jobTitle)
            
            // Логируем создание нового члена комиссии
            print("➕ [COMMISSION_CREATE] Создание нового члена комиссии")
            print("   👤 ФИО: \(fio)")
            print("   💼 Должность: \(jobTitle)")
            print("   📊 Общее количество в комиссии: \(comissionArray.count + 1)")
            print("   🆔 ID: \(newUser.id.uuidString)")
            
            comissionArray.append(newUser)
            DataFlowComission.saveArr(arr: comissionArray)
            
            // Логируем сохранение массива комиссии
            print("💾 [COMMISSION_SAVE] Сохранение массива комиссии")
            print("   📊 Количество членов: \(comissionArray.count)")
            print("   👤 Новый член: \(fio)")
            print("   💼 Должность: \(jobTitle)")
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: comissionArray, // Обновляем комиссию в акте
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новым членом комиссии")
                
                // Логируем обновление редактируемого акта
                print("🔄 [AKT_UPDATE] Обновление акта с новым членом комиссии")
                print("   🔢 Номер акта: \(updatedAkt.number)")
                print("   🆔 ID акта: \(updatedAkt.id.uuidString)")
                print("   👤 Новый член комиссии: \(fio)")
                print("   💼 Должность: \(jobTitle)")
                print("   📊 Общее количество в комиссии: \(updatedAkt.comission.count)")
            }
            
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
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: newOrganization, // Используем новую организацию
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новой организацией")
            }
            
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
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: objectCheckArray, // Обновляем объекты проверки в акте
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новым объектом проверки")
            }
            
            escaping(true)
        }
    }
    
    func createNewPredstavitel(title: String, subtitle: String, organization: String = "", escaping: @escaping(Bool) -> Void) {
        if predstavitelyArray.contains(where: {$0.fio == title}) {
            escaping(false)
        } else {
            let newPredstavitel = PredstavitelyComission(fio: title, jobTitle: subtitle, organization: organization)
            predstavitelyArray.append(newPredstavitel)
            DataFlowPredstavitely.saveArr(arr: predstavitelyArray)
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: predstavitelyArray, // Обновляем представителей в акте
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новым представителем")
            }
            
            escaping(true)
        }
    }
    
    func updateOrganization(at index: Int, newTitle: String, newShortTitle: String = "", escaping: @escaping(Bool) -> Void) {
        print("🔄 [ORGANIZATION_UPDATE] НАЧАЛО ОБНОВЛЕНИЯ ОРГАНИЗАЦИИ")
        print("   📊 Индекс: \(index)")
        print("   🏢 Новое название: \(newTitle)")
        print("   🏢 Новое краткое название: \(newShortTitle)")
        print("   📋 Размер массива организаций: \(organizationsArray.count)")
        
        guard index < organizationsArray.count else {
            print("❌ [ORGANIZATION_UPDATE] Индекс \(index) выходит за границы массива")
            escaping(false)
            return
        }
        
        // Проверяем, что новое название не совпадает с существующими (кроме текущего)
        let otherOrganizations = organizationsArray.enumerated().compactMap { idx, org in
            return idx != index ? org : nil
        }
        
        if otherOrganizations.contains(where: { $0.title == newTitle }) {
            print("❌ [ORGANIZATION_UPDATE] Организация с названием '\(newTitle)' уже существует")
            escaping(false)
        } else {
            let oldOrganization = organizationsArray[index]
            let updatedOrganization = Organization(title: newTitle, shortTitle: newShortTitle)
            organizationsArray[index] = updatedOrganization
            DataFlowOrganizations.saveArr(arr: organizationsArray)
            
            print("🔄 [ORGANIZATION_UPDATE] Обновление организации")
            print("   🏢 Старое название: \(oldOrganization.title)")
            print("   🏢 Новое название: \(updatedOrganization.title)")
            print("   📊 Обновлено в массиве организаций")
            
            // Обновляем редактируемый акт, если он существует и использует эту организацию
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                if editableAkt.akt.organization.title == oldOrganization.title {
                    let updatedAkt = AKT(
                        id: editableAkt.akt.id,
                        number: editableAkt.akt.number,
                        date: editableAkt.akt.date,
                        comission: editableAkt.akt.comission,
                        organization: updatedOrganization, // Используем обновленную организацию
                        objectsCheck: editableAkt.akt.objectsCheck,
                        predstavitelyComission: editableAkt.akt.predstavitelyComission,
                        violations: editableAkt.akt.violations,
                        description: editableAkt.akt.description,
                        actustranenDate: editableAkt.akt.actustranenDate,
                        actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                        actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                        urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                        realDateCreate: editableAkt.akt.realDateCreate
                    )
                    updateEditableAKT(updatedAkt)
                    print("✅ Редактируемый АКТ обновлен с новой организацией")
                } else {
                    print("ℹ️ Редактируемый акт использует другую организацию, пропускаем обновление")
                }
            }
            
            // Обновляем все акты в истории, которые используют эту организацию
            print("🔄 Обновляем все акты в истории, которые используют эту организацию...")
            var updatedCount = 0
            for i in 0..<aktArray.count {
                if aktArray[i].organization.title == oldOrganization.title {
                    let updatedAkt = AKT(
                        id: aktArray[i].id,
                        number: aktArray[i].number,
                        date: aktArray[i].date,
                        comission: aktArray[i].comission,
                        organization: updatedOrganization,
                        objectsCheck: aktArray[i].objectsCheck,
                        predstavitelyComission: aktArray[i].predstavitelyComission,
                        violations: aktArray[i].violations,
                        description: aktArray[i].description,
                        actustranenDate: aktArray[i].actustranenDate,
                        actPredostavlenDate: aktArray[i].actPredostavlenDate,
                        actUtverzdenDate: aktArray[i].actUtverzdenDate,
                        urlAct: aktArray[i].urlToFllACT ?? URL(fileURLWithPath: ""),
                        realDateCreate: aktArray[i].realDateCreate
                    )
                    aktArray[i] = updatedAkt
                    updatedCount += 1
                    print("   ✅ Обновлен акт №\(updatedAkt.number)")
                }
            }
            
            if updatedCount > 0 {
                // Сохраняем обновленный массив актов
                DataFlowAKT.saveArr(arr: aktArray)
                print("✅ Обновлено \(updatedCount) актов в истории")
                
                // Уведомляем UI об обновлении
                DispatchQueue.main.async {
                    self.collectionReloadBinding?()
                }
            } else {
                print("ℹ️ Не найдено актов, использующих эту организацию")
            }
            
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
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: objectCheckArray, // Обновляем объекты проверки в акте
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новыми объектами проверки")
            }
            
            escaping(true)
        }
    }
    
    func updatePredstavitely(at index: Int, newFio: String, newJobTitle: String, newOrganization: String = "", escaping: @escaping(Bool) -> Void) {
        guard index < predstavitelyArray.count else {
            print("❌ [PREDSTAVITELY_UPDATE] Индекс \(index) выходит за границы массива (размер: \(predstavitelyArray.count))")
            escaping(false)
            return
        }
        
        // Сохраняем ID для поиска элемента, чтобы избежать проблем с изменением индекса
        let original = predstavitelyArray[index]
        let targetId = original.id
        
        print("🔄 [PREDSTAVITELY_UPDATE] Начало обновления представителя")
        print("   📊 Индекс: \(index)")
        print("   🆔 ID: \(targetId.uuidString)")
        print("   👤 Старое ФИО: \(original.fio)")
        print("   👤 Новое ФИО: \(newFio)")
        print("   💼 Старая должность: \(original.jobTitle)")
        print("   💼 Новая должность: \(newJobTitle)")
        print("   🏢 Старая организация: \(original.organization)")
        print("   🏢 Новая организация: \(newOrganization)")
        
        // Проверяем, что новое ФИО не совпадает с существующими (кроме текущего)
        let otherPredstavitely = predstavitelyArray.enumerated().compactMap { idx, pred in
            return idx != index ? pred : nil
        }
        
        if otherPredstavitely.contains(where: { $0.fio == newFio }) {
            print("❌ [PREDSTAVITELY_UPDATE] Представитель с ФИО '\(newFio)' уже существует")
            escaping(false)
        } else {
            // Используем ID для поиска элемента, чтобы избежать проблем с изменением индекса
            guard let foundIndex = predstavitelyArray.firstIndex(where: { $0.id == targetId }) else {
                print("❌ [PREDSTAVITELY_UPDATE] Не найден представитель с ID \(targetId.uuidString)")
                escaping(false)
                return
            }
            
            let updatedPredstavitely = PredstavitelyComission(id: original.id, fio: newFio, jobTitle: newJobTitle, organization: newOrganization)
            predstavitelyArray[foundIndex] = updatedPredstavitely
            
            print("💾 [PREDSTAVITELY_UPDATE] Сохранение массива представителей...")
            DataFlowPredstavitely.saveArr(arr: predstavitelyArray)
            print("✅ [PREDSTAVITELY_UPDATE] Массив представителей сохранен (размер: \(predstavitelyArray.count))")
            
            // Перезагружаем массив из файла для проверки сохранения
            let reloadedArray = DataFlowPredstavitely.loadArr()
            if let reloadedItem = reloadedArray.first(where: { $0.id == targetId }) {
                print("✅ [PREDSTAVITELY_UPDATE] Проверка сохранения: данные успешно сохранены")
                print("   👤 ФИО в файле: \(reloadedItem.fio)")
                print("   💼 Должность в файле: \(reloadedItem.jobTitle)")
                print("   🏢 Организация в файле: \(reloadedItem.organization)")
                
                // Обновляем массив в модели актуальными данными из файла
                predstavitelyArray = reloadedArray
            } else {
                print("⚠️ [PREDSTAVITELY_UPDATE] Предупреждение: не удалось найти обновленный элемент после перезагрузки")
            }

            // Обновляем шаблон нового АКТа, если представитель уже выбран
            if let currentTemplatePredstavitely = templateModel.predstavitely {
                templateModel.predstavitely = currentTemplatePredstavitely.map { rep in
                    guard rep.id == updatedPredstavitely.id else { return rep }
                    return PredstavitelyComission(id: rep.id, fio: newFio, jobTitle: newJobTitle, organization: newOrganization)
                }
            }

            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedSelected = editableAkt.akt.predstavitelyComission.map { rep in
                    guard rep.id == updatedPredstavitely.id else { return rep }
                    return PredstavitelyComission(id: rep.id, fio: newFio, jobTitle: newJobTitle, organization: newOrganization)
                }
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: updatedSelected,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с актуальными данными представителя")
            }

            // Обновляем систему реального времени, если представитель выбран в текущем акте
            if let currentAkt = SimpleRealtimeAKTManager.shared.currentAkt,
               currentAkt.predstavitelyComission.contains(where: { $0.id == updatedPredstavitely.id }) {
                let realtimeUpdated = currentAkt.predstavitelyComission.map { rep in
                    guard rep.id == updatedPredstavitely.id else { return rep }
                    return PredstavitelyComission(id: rep.id, fio: newFio, jobTitle: newJobTitle, organization: newOrganization)
                }
                SimpleRealtimeAKTManager.shared.updatePredstavitely(realtimeUpdated)
            }

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
            
            // Обновляем редактируемый акт, если он существует
            if let editableAkt = DataFlowAKT.getEditableAKT() {
                let updatedAkt = AKT(
                    id: editableAkt.akt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: comissionArray, // Обновляем комиссию в акте
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: editableAkt.akt.realDateCreate
                )
                updateEditableAKT(updatedAkt)
                print("✅ Редактируемый АКТ обновлен с новой комиссией")
            }
            
            escaping(true)
        }
    }
    
    // MARK: - AKT Array Management
    func updateAktInArray(_ updatedAkt: AKT, completion: (() -> Void)? = nil) {
        // Используем serial queue для безопасного доступа
        serialQueue.async { [weak self] in
            guard let self = self else { return }
            
            print("🔄 [UPDATE_ARRAY] НАЧАЛО ОБНОВЛЕНИЯ АКТА В МАССИВЕ")
            print("   📋 Детали акта для обновления:")
            print("      Номер: \(updatedAkt.number)")
            print("      ID: \(updatedAkt.id)")
            print("      Дата проверки: \(updatedAkt.date)")
            print("      Дата предоставления отчета: \(updatedAkt.actPredostavlenDate)")
            print("      Дата устранения: \(updatedAkt.actustranenDate)")
            print("      Организация: \(updatedAkt.organization.title)")
            print("      Количество нарушений: \(updatedAkt.violations.count)")
            print("      URL документа: \(updatedAkt.urlToFllACT?.path ?? "нет")")
            
            // ИСПРАВЛЕНИЕ: Обновляем aktArray из истории перед проверкой, чтобы избежать дубликатов
            // Это гарантирует, что мы работаем с актуальными данными
            print("   🔄 Обновляем aktArray из истории для синхронизации...")
            self.aktArray = DataFlowAKT.loadArr()
            print("   ✅ aktArray обновлен из истории: \(self.aktArray.count) актов")
            
            print("   📊 Текущее состояние массива:")
            print("      Размер массива: \(self.aktArray.count)")
            print("      Номера актов в массиве: \(self.aktArray.map { $0.number })")
            print("      ID актов в массиве: \(self.aktArray.map { $0.id })")
            
            // ИСПРАВЛЕНИЕ: Ищем по ID, а не по номеру, так как ID не меняется при редактировании
            // Это предотвращает создание дубликатов при изменении номера акта
            if let index = self.aktArray.firstIndex(where: { $0.id == updatedAkt.id }) {
                print("   ✅ Найден акт с ID \(updatedAkt.id.uuidString) в позиции \(index)")
                print("      Старый номер: \(self.aktArray[index].number)")
                print("      Новый номер: \(updatedAkt.number)")
                print("      ID: \(updatedAkt.id.uuidString)")
                
                // Обновляем акт в массиве
                print("   📅 Старая дата предоставления отчета в массиве: \(self.aktArray[index].actPredostavlenDate)")
                let oldViolations = self.aktArray[index].violations
                self.aktArray[index] = updatedAkt
                print("   📅 Новая дата предоставления отчета в массиве: \(self.aktArray[index].actPredostavlenDate)")
                print("   🔄 Акт обновлен в массиве")
                
                // ИСПРАВЛЕНИЕ: Обновляем нарушения через SimpleRealtimeAKTManager, если акт редактируется
                // Это исправляет проблему с рассинхроном при открытии через историю
                if SimpleRealtimeAKTManager.shared.currentAkt?.id == updatedAkt.id {
                    print("   🔄 Обновляем нарушения через SimpleRealtimeAKTManager...")
                    // #region agent log
                    let logDict: [String: Any] = ["location": "MainAKTViewModel.swift:updateAktInArray:update_violations", "message": "ОБНОВЛЕНИЕ НАРУШЕНИЙ ЧЕРЕЗ REALTIME", "data": ["akt_id": updatedAkt.id.uuidString, "akt_number": updatedAkt.number, "old_violations_count": oldViolations.count, "new_violations_count": updatedAkt.violations.count], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "D"]
                    DataFlowAKT.writeDebugLog(logDict)
                    // #endregion
                    SimpleRealtimeAKTManager.shared.updateViolations(updatedAkt.violations)
                    print("   ✅ Нарушения обновлены через SimpleRealtimeAKTManager")
                } else {
                    print("   ℹ️ Акт не редактируется в SimpleRealtimeAKTManager, пропускаем обновление")
                }
                
                // Сохраняем обновленный массив
                print("   🔄 Сохраняем обновленный массив через DataFlowAKT.saveArr...")
                DataFlowAKT.saveArr(arr: self.aktArray)
                print("   ✅ DataFlowAKT.saveArr завершен")
                
                print("✅ [UPDATE_ARRAY] АКТ обновлен в массиве: №\(updatedAkt.number) (ID: \(updatedAkt.id.uuidString))")
            } else {
                // ИСПРАВЛЕНИЕ: Проверяем дубликаты по номеру И ГОДУ перед добавлением
                // Если акт с таким номером и годом уже есть, но с другим ID - это проблема данных
                // ВАЖНО: Используем дату проверки (akt.date) вместо даты создания (akt.realDateCreate)
                let calendar = Calendar.current
                let updatedAktYear = calendar.component(.year, from: updatedAkt.date)
                if let duplicateByNumber = self.aktArray.first(where: { akt in
                    let aktYear = calendar.component(.year, from: akt.date)
                    return akt.number == updatedAkt.number && 
                           aktYear == updatedAktYear
                }) {
                    print("   ⚠️ [UPDATE_ARRAY] Обнаружен акт с таким же номером и годом, но другим ID!")
                    print("      Существующий акт: №\(duplicateByNumber.number), год: \(calendar.component(.year, from: duplicateByNumber.date)), ID: \(duplicateByNumber.id.uuidString)")
                    print("      Новый акт: №\(updatedAkt.number), год: \(updatedAktYear), ID: \(updatedAkt.id.uuidString)")
                    print("   🔄 Обновляем существующий акт по номеру (приоритет существующего ID)...")
                    
                    // Обновляем существующий акт, сохраняя его оригинальный ID
                    if let index = self.aktArray.firstIndex(where: { $0.id == duplicateByNumber.id }) {
                        let mergedAkt = AKT(
                            id: duplicateByNumber.id, // Сохраняем оригинальный ID
                            number: updatedAkt.number,
                            date: updatedAkt.date,
                            comission: updatedAkt.comission,
                            organization: updatedAkt.organization,
                            objectsCheck: updatedAkt.objectsCheck,
                            predstavitelyComission: updatedAkt.predstavitelyComission,
                            violations: updatedAkt.violations,
                            description: updatedAkt.description,
                            actustranenDate: updatedAkt.actustranenDate,
                            actPredostavlenDate: updatedAkt.actPredostavlenDate,
                            actUtverzdenDate: updatedAkt.actUtverzdenDate,
                            urlAct: updatedAkt.urlToFllACT ?? URL(fileURLWithPath: ""),
                            realDateCreate: duplicateByNumber.realDateCreate // Сохраняем оригинальную дату создания
                        )
                        self.aktArray[index] = mergedAkt
                        print("   ✅ Существующий акт обновлен с сохранением оригинального ID")
                    }
                } else {
                    print("❌ [UPDATE_ARRAY] Акт с ID \(updatedAkt.id.uuidString) не найден в массиве для обновления!")
                    print("   Доступные ID в массиве: \(self.aktArray.map { $0.id.uuidString })")
                    print("   Доступные номера в массиве: \(self.aktArray.map { $0.number })")
                    
                    // Если акт не найден и нет дубликата по номеру, добавляем как новый
                    print("   🔄 Добавляем акт как новый...")
                    self.aktArray.append(updatedAkt)
                    print("   ✅ Акт добавлен в массив")
                }
                
                print("   🔄 Сохраняем массив через DataFlowAKT.saveArr...")
                DataFlowAKT.saveArr(arr: self.aktArray)
                print("   ✅ DataFlowAKT.saveArr завершен")
                
                print("✅ [UPDATE_ARRAY] Акт №\(updatedAkt.number) обработан")
            }
            
            // Уведомляем о необходимости обновления коллекции в главном потоке
            print("   🔄 Уведомляем UI об обновлении...")
            DispatchQueue.main.async { [weak self] in
                self?.collectionReloadBinding?()
                // Вызываем completion после завершения сохранения
                completion?()
            }
            print("   ✅ UI уведомлен об обновлении")
            
            print("✅ [UPDATE_ARRAY] Обновление акта в массиве завершено")
        }
    }
    
    func addNewAktToArray(_ newAkt: AKT) {
        // #region agent log
        let logDict: [String: Any] = ["location": "MainAKTViewModel.swift:addNewAktToArray", "message": "ДОБАВЛЕНИЕ НОВОГО АКТА", "data": ["akt_id": newAkt.id.uuidString, "akt_number": newAkt.number, "array_count_before": aktArray.count, "existing_numbers": aktArray.map { $0.number }, "existing_ids": aktArray.map { $0.id.uuidString }], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "B"]
        DataFlowAKT.writeDebugLog(logDict)
        // #endregion
        
        // ИСПРАВЛЕНИЕ: Проверяем, существует ли уже акт с таким ID или номером
        // Обновляем массив актов перед проверкой
        refreshAktArray()
        
        // Проверяем по ID (приоритет) - ID должен быть уникальным
        if let existingIndexById = aktArray.firstIndex(where: { $0.id == newAkt.id }) {
            print("⚠️ [ADD_NEW_AKT] Акт с ID \(newAkt.id.uuidString) уже существует в массиве на позиции \(existingIndexById)")
            print("   🔢 Номер существующего акта: \(aktArray[existingIndexById].number)")
            print("   🔢 Номер нового акта: \(newAkt.number)")
            print("   🔄 Обновляем существующий акт вместо добавления нового")
            
            // Обновляем существующий акт вместо добавления нового
            aktArray[existingIndexById] = newAkt
            DataFlowAKT.saveArr(arr: aktArray)
            print("✅ Акт №\(newAkt.number) обновлен в массиве (найден по ID)")
            
            // Уведомляем о необходимости обновления коллекции
            DispatchQueue.main.async {
                self.collectionReloadBinding?()
            }
            return
        }
        
        // Проверяем по номеру И ГОДУ - если номер занят другим актом в том же году, это ошибка данных
        // ВАЖНО: Проверяем дубликаты только по номеру и году, а не только по номеру
        // ИСПРАВЛЕНИЕ: Используем дату проверки (akt.date) вместо даты создания (akt.realDateCreate)
        let calendar = Calendar.current
        let newAktYear = calendar.component(.year, from: newAkt.date)
        if let existingIndexByNumber = aktArray.firstIndex(where: { akt in
            let aktYear = calendar.component(.year, from: akt.date)
            return akt.number == newAkt.number && 
                   aktYear == newAktYear && 
                   akt.id != newAkt.id
        }) {
            print("⚠️ [ADD_NEW_AKT] Акт с номером \(newAkt.number) и годом \(newAktYear) уже существует в массиве на позиции \(existingIndexByNumber)")
            print("   🆔 ID существующего акта: \(aktArray[existingIndexByNumber].id.uuidString)")
            print("   🆔 ID нового акта: \(newAkt.id.uuidString)")
            print("   ⚠️ Обнаружен конфликт номеров в том же году - заменяем существующий акт новым")
            // #region agent log
            DataFlowAKT.writeDebugLog(["location": "MainAKTViewModel.swift:addNewAktToArray", "message": "ADD_REPLACE_BY_NUMBER_YEAR", "data": ["replaced_akt_id": aktArray[existingIndexByNumber].id.uuidString, "replaced_akt_number": aktArray[existingIndexByNumber].number, "replaced_violations_count": aktArray[existingIndexByNumber].violations.count, "new_akt_id": newAkt.id.uuidString, "new_akt_number": newAkt.number, "new_violations_count": newAkt.violations.count] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "C"])
            // #endregion
            // Заменяем существующий акт новым (новый акт имеет приоритет)
            aktArray[existingIndexByNumber] = newAkt
            DataFlowAKT.saveArr(arr: aktArray)
            print("✅ Акт №\(newAkt.number) заменен в массиве (найден по номеру и году)")
            
            // Уведомляем о необходимости обновления коллекции
            DispatchQueue.main.async {
                self.collectionReloadBinding?()
            }
            return
        }
        
        // Акт не найден - добавляем новый
        print("✅ [ADD_NEW_AKT] Акт №\(newAkt.number) не найден в массиве, добавляем как новый")
        aktArray.append(newAkt)
        DataFlowAKT.saveArr(arr: aktArray)
        print("✅ Новый АКТ добавлен в массив: №\(newAkt.number)")
        
        // Уведомляем о необходимости обновления коллекции
        DispatchQueue.main.async {
            self.collectionReloadBinding?()
        }
    }
    
    // MARK: - Number Validation
    func isAktNumberAvailable(_ number: String, forYear year: Int? = nil, excludingAktId: UUID? = nil) -> Bool {
        // Обновляем массив актов
        refreshAktArray()
        
        // Определяем год для проверки
        let targetYear: Int
        if let year = year {
            targetYear = year
        } else {
            // Если год не указан, используем текущий год
            targetYear = Calendar.current.component(.year, from: Date())
        }
        
        print("🔍 [VIEWMODEL] Проверка номера \(number) для года \(targetYear), исключая акт: \(excludingAktId?.uuidString ?? "нет")")
        print("🔍 [VIEWMODEL] Всего актов в массиве: \(aktArray.count)")
        
        // ИСПРАВЛЕНИЕ: Используем дату проверки (akt.date) вместо даты создания (akt.realDateCreate)
        // Номера актов должны быть уникальны в разрезе даты проверки, а не даты создания
        let calendar = Calendar.current
        let existingAkt = aktArray.first { akt in
            // ИСПРАВЛЕНИЕ: Используем akt.date (дата проверки) вместо akt.realDateCreate
            let aktYear = calendar.component(.year, from: akt.date)
            let matches = akt.number == number && 
                   aktYear == targetYear && 
                   (excludingAktId == nil || akt.id != excludingAktId)
            if matches {
                print("🔍 [VIEWMODEL] Найден акт с номером \(akt.number) в году \(aktYear) (date: \(akt.date), realDateCreate: \(akt.realDateCreate))")
            }
            return matches
        }
        
        let isAvailable = existingAkt == nil
        print("🔍 [VIEWMODEL] Результат: номер \(number) для года \(targetYear) - \(isAvailable ? "доступен" : "занят")")
        return isAvailable
    }
    
    func getOccupiedAktNumbers(forYear year: Int? = nil) -> Set<String> {
        // Обновляем массив актов
        refreshAktArray()
        
        // ИСПРАВЛЕНИЕ: Используем дату проверки (akt.date) вместо даты создания (akt.realDateCreate)
        // Номера актов должны быть уникальны в разрезе даты проверки, а не даты создания
        let filteredAkts: [AKT]
        if let year = year {
            let calendar = Calendar.current
            filteredAkts = aktArray.filter { akt in
                // ИСПРАВЛЕНИЕ: Используем akt.date (дата проверки) вместо akt.realDateCreate
                let aktYear = calendar.component(.year, from: akt.date)
                return aktYear == year
            }
        } else {
            filteredAkts = aktArray
        }
        
        // Возвращаем множество занятых номеров
        return Set(filteredAkts.map { $0.number })
    }
    
    func getNextAvailableAktNumber(forYear year: Int? = nil) -> String {
        let occupiedNumbers = getOccupiedAktNumbers(forYear: year)
        var number = 1
        
        while occupiedNumbers.contains("\(number)") {
            number += 1
        }
        
        return "\(number)"
    }
    
    // MARK: - Year Management
    
    /// Получает список годов, в которых есть акты
    func getAvailableYears() -> [Int] {
        // ВАЖНО: Принудительно обновляем данные, игнорируя cooldown,
        // чтобы всегда получать актуальный список годов, включая новые акты
        let newData = DataFlowAKT.loadArr()
        aktArray = newData
        lastRefreshTime = Date()
        
        let calendar = Calendar.current
        let years = Set(aktArray.map { calendar.component(.year, from: $0.date) })
        return Array(years).sorted(by: >) // Сортируем по убыванию (новые годы первыми)
    }
    
    /// Получает выбранный год из UserDefaults
    func getSelectedYear() -> Int? {
        let year = UserDefaults.standard.integer(forKey: "SelectedAktYear")
        // 0 означает "не выбран" (показывать все годы)
        return year > 0 ? year : nil
    }
    
    /// Сохраняет выбранный год в UserDefaults (0 означает "все годы")
    func setSelectedYear(_ year: Int) {
        // Если передан 0, удаляем сохраненное значение (показывать все годы)
        if year == 0 {
            UserDefaults.standard.removeObject(forKey: "SelectedAktYear")
        } else {
            UserDefaults.standard.set(year, forKey: "SelectedAktYear")
        }
        UserDefaults.standard.synchronize()
    }
    
    /// Получает акты для выбранного года (или все акты, если год не выбран)
    func getAktsForSelectedYear() -> [AKT] {
        refreshAktArray()
        
        guard let selectedYear = getSelectedYear() else {
            return aktArray
        }
        
        let calendar = Calendar.current
        return aktArray.filter { akt in
            let aktYear = calendar.component(.year, from: akt.date)
            return aktYear == selectedYear
        }
    }

    // MARK: - New AKT Creation with Editable System
    func createNewAktAndMakeEditable(_ newAkt: AKT) {
        // Создаем редактируемый акт
        createEditableAKT(from: newAkt)
        // Критично: переключаем realtime на новый акт, иначе currentAkt остаётся старым (например №1)
        // и при следующем сохранении старый акт перезапишет EditableAKT — получится слияние/потеря акта.
        realtimeManager.startEditing(newAkt)
        
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
        print("🔄 [SAVE] НАЧАЛО СОХРАНЕНИЯ ИЗМЕНЕНИЙ В РЕДАКТИРУЕМЫЙ АКТ")
        print("   📋 Детали акта:")
        print("      Номер: \(updatedAkt.number)")
        print("      ID: \(updatedAkt.id)")
        print("      Дата: \(updatedAkt.date)")
        print("      Организация: \(updatedAkt.organization.title)")
        print("      Количество нарушений: \(updatedAkt.violations.count)")
        print("      Количество членов комиссии: \(updatedAkt.comission.count)")
        print("      URL документа: \(updatedAkt.urlToFllACT?.path ?? "нет")")
        
        // Обновляем редактируемый акт
        print("   🔄 Вызываем updateEditableAKT...")
        updateEditableAKT(updatedAkt)
        print("   ✅ updateEditableAKT завершен")
        
        print("✅ [SAVE] Изменения сохранены в редактируемый АКТ №\(updatedAkt.number)")
    }
    
    // MARK: - Finalize Editable AKT (move to history)
    func finalizeEditableAktToHistory() {
        print("🏁 [FINALIZE] НАЧАЛО ФИНАЛИЗАЦИИ РЕДАКТИРУЕМОГО АКТА В ИСТОРИЮ")
        
        // Перемещаем редактируемый акт в историю
        print("   🔄 Вызываем moveEditableToHistory...")
        moveEditableToHistory()
        print("   ✅ moveEditableToHistory завершен")
        
        // Очищаем последний открытый акт
        print("   🔄 Очищаем последний открытый акт...")
        clearLastOpenedAkt()
        print("   ✅ Последний открытый акт очищен")
        
        // ОБНОВЛЯЕМ ДАННЫЕ
        print("   🔄 Инвалидируем кэш aktArray...")
        DataCache.shared.invalidate("aktArray")
        print("   ✅ Кэш aktArray инвалидирован")
        
        print("   🔄 Принудительно обновляем массив актов...")
        forceRefreshAktArray()
        print("   ✅ Массив актов обновлен")
        
        // УВЕДОМЛЯЕМ ОБ ОБНОВЛЕНИИ ИСТОРИИ СРАЗУ
        print("   🔄 Уведомляем об обновлении UI...")
        collectionReloadBinding?()
        print("   ✅ UI уведомлен об обновлении")
        
        print("✅ [FINALIZE] Финализация редактируемого акта в историю завершена")
    }
    
    // MARK: - Realtime AKT Integration Methods
    
    private var isRealtimeIntegrationSetup = false
    private var isRealtimeIntegrationCleaned = false
    
    private func setupRealtimeIntegration() {
        // Защита от повторной настройки
        guard !isRealtimeIntegrationSetup else {
            print("⚠️ [REALTIME] Интеграция уже настроена, пропускаем")
            return
        }
        
        isRealtimeIntegrationSetup = true
        isRealtimeIntegrationCleaned = false
        
        // Подключаемся к системе реального времени
        SimpleRealtimeAKTObserverManager.shared.addObserver(self)
        
        // Подписываемся на изменения статуса
        realtimeManager.$hasUnsavedChanges
            .receive(on: DispatchQueue.main)
            .sink { hasChanges in
                if hasChanges {
                    print("📝 [REALTIME] Есть несохраненные изменения в MainAKTViewModel")
                }
        }
        .store(in: &cancellables)
    }
    
    private func cleanupRealtimeIntegration() {
        // Защита от повторной очистки
        guard !isRealtimeIntegrationCleaned else {
            print("⚠️ [REALTIME] Интеграция уже очищена, пропускаем")
            return
        }
        
        guard isRealtimeIntegrationSetup else {
            print("⚠️ [REALTIME] Интеграция не была настроена, пропускаем очистку")
            return
        }
        
        isRealtimeIntegrationCleaned = true
        
        // Отключаемся от системы реального времени
        SimpleRealtimeAKTObserverManager.shared.removeObserver(self)
        
        // Отменяем все подписки
        cancellables.removeAll()
        
        print("🔗 [REALTIME] Интеграция очищена для MainAKTViewModel")
    }
    
    // MARK: - RealtimeAKTObserver Methods
    
    func aktDidChange(_ change: String) {
        print("📝 [REALTIME] Получено изменение в MainAKTViewModel: \(change)")
        
        // Обновляем UI при необходимости
        DispatchQueue.main.async {
            // Уведомляем о необходимости обновления коллекции
            self.collectionReloadBinding?()
        }
    }
    
    func aktDidSave(_ akt: AKT) {
        print("💾 [REALTIME] Акт сохранен в MainAKTViewModel")
        
        // Обновляем локальное состояние
        DispatchQueue.main.async {
            // Обновляем массив актов
            self.refreshAktArray()
            
            // Уведомляем о необходимости обновления коллекции
            self.collectionReloadBinding?()
        }
    }
    
    // MARK: - Realtime AKT Helper Methods
    
    /// Начинает редактирование акта в системе реального времени
    func startRealtimeEditing(_ akt: AKT) {
        // #region agent log
        let logDict: [String: Any] = ["location": "MainAKTViewModel.swift:startRealtimeEditing", "message": "НАЧАЛО РЕДАКТИРОВАНИЯ В REALTIME", "data": ["akt_id": akt.id.uuidString, "akt_number": akt.number, "violations_count": akt.violations.count], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "sessionId": "debug-session", "runId": "run1", "hypothesisId": "D"]
        DataFlowAKT.writeDebugLog(logDict)
        // #endregion
        print("🔄 [REALTIME] startRealtimeEditing: Начинаем редактирование акта №\(akt.number)")
        realtimeManager.startEditing(akt)
        print("✅ [REALTIME] startRealtimeEditing: Редактирование запущено")
    }
    
    /// Завершает редактирование акта в системе реального времени
    func finishRealtimeEditing() {
        realtimeManager.finishEditing()
    }
    
    /// Принудительно сохраняет изменения в системе реального времени
    func saveRealtimeChanges() {
        realtimeManager.saveChangesImmediately()
    }
    
    /// Получает статус редактирования в реальном времени
    func getRealtimeEditingStatus() -> (isEditing: Bool, hasChanges: Bool, lastChange: Date?, changesCount: Int) {
        let manager = SimpleRealtimeAKTManager.shared
        return (
            isEditing: manager.currentAkt != nil,
            hasChanges: manager.hasUnsavedChanges,
            lastChange: manager.lastChangeTime,
            changesCount: 0 // Можно добавить счетчик изменений в менеджер при необходимости
        )
    }
}
