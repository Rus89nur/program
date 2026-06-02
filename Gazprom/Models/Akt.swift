//
//  AktModel.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation

struct AKT: Codable, Identifiable {
    let id: UUID
    let number: String //Number
    let date: Date //DateReview
    let comission: [ComissionPeople] //Comission
    let organization: Organization // ReviewObject
    let objectsCheck: [ObjectCheck] //NameObject
    let predstavitelyComission: [PredstavitelyComission] //PredVoice
    let violations: [Violations] // PoradNum - TitleViolatation - ddescpitVi - urlDoc
    let description: String // Conclusion
    let actustranenDate: Date //ustranenDate
    let actPredostavlenDate: Date //predostavlenDate
    let actUtverzdenDate: Date //UtverzderDate
    let urlToFllACT: URL? //ПУТЬ К ЗАПолненному акту
    let realDateCreate: Date
    var uniqueID: String? // Уникальный идентификатор для предотвращения дубликатов
    
    init(number: String, date: Date, comission: [ComissionPeople], organization: Organization, objectsCheck: [ObjectCheck], predstavitelyComission: [PredstavitelyComission], violations: [Violations], description: String, actustranenDate: Date, actPredostavlenDate: Date, actUtverzdenDate: Date, urlAct: URL, realDateCreate: Date, existingUniqueIDs: [String] = []) {
        self.id = UUID()
        self.number = number
        self.date = date
        self.comission = comission
        self.organization = organization
        self.objectsCheck = objectsCheck
        self.predstavitelyComission = predstavitelyComission
        self.violations = violations
        self.description = description
        self.actustranenDate = actustranenDate
        self.actPredostavlenDate = actPredostavlenDate
        self.actUtverzdenDate = actUtverzdenDate
        self.urlToFllACT = urlAct
        self.realDateCreate = realDateCreate
        
        // Генерируем уникальный ID с проверкой на дубликаты
        self.uniqueID = AktDuplicateChecker.generateUniqueIDWithDuplicateCheck(
            date: date,
            aktNumber: number,
            existingIDs: existingUniqueIDs
        ) ?? AktUniqueIDGenerator.generateUniqueID(date: date, aktNumber: number)
    }
    
    // Инициализатор для обновления существующего акта с сохранением ID
    init(id: UUID, number: String, date: Date, comission: [ComissionPeople], organization: Organization, objectsCheck: [ObjectCheck], predstavitelyComission: [PredstavitelyComission], violations: [Violations], description: String, actustranenDate: Date, actPredostavlenDate: Date, actUtverzdenDate: Date, urlAct: URL, realDateCreate: Date, uniqueID: String? = nil) {
        self.id = id
        self.number = number
        self.date = date
        self.comission = comission
        self.organization = organization
        self.objectsCheck = objectsCheck
        self.predstavitelyComission = predstavitelyComission
        self.violations = violations
        self.description = description
        self.actustranenDate = actustranenDate
        self.actPredostavlenDate = actPredostavlenDate
        self.actUtverzdenDate = actUtverzdenDate
        self.urlToFllACT = urlAct
        self.realDateCreate = realDateCreate
        
        // Если uniqueID не передан, генерируем его для старых актов (миграция)
        if let existingUniqueID = uniqueID {
            self.uniqueID = existingUniqueID
        } else {
            // Генерируем uniqueID для старых актов без него
            self.uniqueID = AktUniqueIDGenerator.generateUniqueID(date: date, aktNumber: number)
        }
    }
    
    // Метод для обновления существующего акта с сохранением ID и даты создания
    func updated(with newUrl: URL) -> AKT {
        return AKT(
            id: self.id, // Сохраняем оригинальный ID
            number: self.number,
            date: self.date,
            comission: self.comission,
            organization: self.organization,
            objectsCheck: self.objectsCheck,
            predstavitelyComission: self.predstavitelyComission,
            violations: self.violations,
            description: self.description,
            actustranenDate: self.actustranenDate,
            actPredostavlenDate: self.actPredostavlenDate,
            actUtverzdenDate: self.actUtverzdenDate,
            urlAct: newUrl,
            realDateCreate: self.realDateCreate, // Сохраняем оригинальную дату создания
            uniqueID: self.uniqueID // Сохраняем оригинальный uniqueID
        )
    }
    
    /// Миграция: генерирует uniqueID для старых актов, у которых его нет
    func withGeneratedUniqueID(existingUniqueIDs: [String] = []) -> AKT {
        if self.uniqueID != nil {
            // Уже есть uniqueID, возвращаем как есть
            return self
        }
        
        // Генерируем новый uniqueID с проверкой на дубликаты
        let newUniqueID = AktDuplicateChecker.generateUniqueIDWithDuplicateCheck(
            date: self.date,
            aktNumber: self.number,
            existingIDs: existingUniqueIDs
        ) ?? AktUniqueIDGenerator.generateUniqueID(date: self.date, aktNumber: self.number)
        
        return AKT(
            id: self.id,
            number: self.number,
            date: self.date,
            comission: self.comission,
            organization: self.organization,
            objectsCheck: self.objectsCheck,
            predstavitelyComission: self.predstavitelyComission,
            violations: self.violations,
            description: self.description,
            actustranenDate: self.actustranenDate,
            actPredostavlenDate: self.actPredostavlenDate,
            actUtverzdenDate: self.actUtverzdenDate,
            urlAct: self.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: self.realDateCreate,
            uniqueID: newUniqueID
        )
    }
}

// MARK: - AKT Format Helpers

extension AKT {
    var isShortFormat: Bool {
        let prefixes = ["Сокращенный:", "Сокращённый:", "Внешний:"]
        return violations.contains { violation in
            prefixes.contains(where: { violation.title.hasPrefix($0) })
        }
    }
    
    var isFullFormat: Bool {
        if isShortFormat {
            return false
        }
        
        if let path = urlToFllACT?.path, !path.isEmpty {
            return true
        }
        
        let legacyFullNumbers: Set<String> = ["19", "20"]
        return legacyFullNumbers.contains(number)
    }
}

// MARK: - AKT Elimination Dates Extension
extension AKT {
    /// Обновляет даты устранения для всех нарушений акта с учётом продлённых сроков
    /// Если у нарушения есть продлённый срок, он сохраняется, если новая дата меньше продлённой
    /// Если новая дата больше продлённого срока, обновляется originalEliminationDate
    /// - Parameters:
    ///   - aktId: ID акта
    ///   - newEliminationDate: Новая дата устранения
    ///   - forceUpdate: Если true, принудительно обновляет даты, игнорируя продлённые сроки (используется при изменении даты предоставления отчета в истории)
    static func updateEliminationDatesFromAkt(_ aktId: UUID, newEliminationDate: Date, forceUpdate: Bool = false) {
        // Вызываем метод из ViolationEliminationManager, который определен в этом же файле
        // Метод находится в классе ViolationEliminationManager, который определен ниже в файле
        ViolationEliminationManager.updateEliminationDatesFromAkt(aktId, newEliminationDate: newEliminationDate, forceUpdate: forceUpdate)
    }
}

struct ComissionPeople: Codable, Identifiable {
    let id: UUID
    let fio: String
    let jobTitle: String
    
    init(fio: String, jobTitle: String) {
        self.id = UUID()
        self.fio = fio
        self.jobTitle = jobTitle
    }
}

struct Organization: Codable, Identifiable {
    let id: UUID
    let title: String
    let shortTitle: String
    
    init(title: String, shortTitle: String = "") {
        self.id = UUID()
        self.title = title
        self.shortTitle = shortTitle.isEmpty ? title : shortTitle
    }
    
    // Для обратной совместимости с существующими данными
    enum CodingKeys: String, CodingKey {
        case id, title, shortTitle
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        // Если shortTitle отсутствует в данных, используем title
        shortTitle = (try? container.decode(String.self, forKey: .shortTitle)) ?? title
    }
}

struct ObjectCheck: Codable, Identifiable {
    let id: UUID
    let title: String
    let subTitle: String
    
    init(title: String, subTitle: String) {
        self.id = UUID()
        self.title = title
        self.subTitle = subTitle
    }
}

struct Violations: Codable, Identifiable {
    let id: UUID
    var title: String
    let mesto: String
    let urlToPravilo: String
    let photo: [Data]
    let vid: String // Вид нарушения
    let formulaFromRules: String? // Формулировка из правил
    
    init( title: String, mesto: String, urlToPravilo: String, photo: [Data], vid: String = "", formulaFromRules: String? = nil) {
        self.id = UUID()
        self.title = title
        self.mesto = mesto
        self.urlToPravilo = urlToPravilo
        self.photo = photo
        self.vid = vid
        self.formulaFromRules = formulaFromRules
    }
}

struct PredstavitelyComission: Codable, Identifiable {
    let id: UUID
    let fio: String
    let jobTitle: String
    let organization: String
    
    init(fio: String, jobTitle: String, organization: String = "") {
        self.id = UUID()
        self.fio = fio
        self.jobTitle = jobTitle
        self.organization = organization
    }
    
    init(id: UUID, fio: String, jobTitle: String, organization: String = "") {
        self.id = id
        self.fio = fio
        self.jobTitle = jobTitle
        self.organization = organization
    }
}

// MARK: - DeadlineHistoryEntry
struct DeadlineHistoryEntry: Codable, Identifiable {
    let id: UUID
    let deadlineDate: Date
    let changeDate: Date
    let reason: String?
    let isOriginal: Bool
    
    init(deadlineDate: Date, changeDate: Date = Date(), reason: String? = nil, isOriginal: Bool = false) {
        self.id = UUID()
        self.deadlineDate = deadlineDate
        self.changeDate = changeDate
        self.reason = reason
        self.isOriginal = isOriginal
    }
    
    init(id: UUID, deadlineDate: Date, changeDate: Date = Date(), reason: String? = nil, isOriginal: Bool = false) {
        self.id = id
        self.deadlineDate = deadlineDate
        self.changeDate = changeDate
        self.reason = reason
        self.isOriginal = isOriginal
    }
}

// MARK: - ViolationElimination
struct ViolationElimination: Codable, Identifiable {
    let id: UUID
    let aktId: UUID
    let aktNumber: String
    let violationId: UUID
    let violationTitle: String
    let isEliminated: Bool
    let eliminationDate: Date?
    let deadlineHistory: [DeadlineHistoryEntry]
    
    // Обратная совместимость - для старых записей
    let originalEliminationDate: Date?
    let newEliminationDate: Date?
    
    init(aktId: UUID, aktNumber: String, violationId: UUID, violationTitle: String, isEliminated: Bool = false, eliminationDate: Date? = nil, originalEliminationDate: Date? = nil, newEliminationDate: Date? = nil, deadlineHistory: [DeadlineHistoryEntry] = []) {
        self.id = UUID()
        self.aktId = aktId
        self.aktNumber = aktNumber
        self.violationId = violationId
        self.violationTitle = violationTitle
        self.isEliminated = isEliminated
        self.eliminationDate = eliminationDate
        self.originalEliminationDate = originalEliminationDate
        self.newEliminationDate = newEliminationDate
        
        // Если есть история сроков, используем её, иначе создаем из старых полей
        if !deadlineHistory.isEmpty {
            self.deadlineHistory = deadlineHistory
        } else {
            var history: [DeadlineHistoryEntry] = []
            if let originalDate = originalEliminationDate {
                history.append(DeadlineHistoryEntry(deadlineDate: originalDate, isOriginal: true))
            }
            if let newDate = newEliminationDate {
                history.append(DeadlineHistoryEntry(deadlineDate: newDate, reason: "Перенос срока"))
            }
            self.deadlineHistory = history
        }
    }
    
    init(id: UUID, aktId: UUID, aktNumber: String, violationId: UUID, violationTitle: String, isEliminated: Bool = false, eliminationDate: Date? = nil, originalEliminationDate: Date? = nil, newEliminationDate: Date? = nil, deadlineHistory: [DeadlineHistoryEntry] = []) {
        self.id = id
        self.aktId = aktId
        self.aktNumber = aktNumber
        self.violationId = violationId
        self.violationTitle = violationTitle
        self.isEliminated = isEliminated
        self.eliminationDate = eliminationDate
        self.originalEliminationDate = originalEliminationDate
        self.newEliminationDate = newEliminationDate
        
        // Если есть история сроков, используем её, иначе создаем из старых полей
        if !deadlineHistory.isEmpty {
            self.deadlineHistory = deadlineHistory
        } else {
            var history: [DeadlineHistoryEntry] = []
            if let originalDate = originalEliminationDate {
                history.append(DeadlineHistoryEntry(deadlineDate: originalDate, isOriginal: true))
            }
            if let newDate = newEliminationDate {
                history.append(DeadlineHistoryEntry(deadlineDate: newDate, reason: "Перенос срока"))
            }
            self.deadlineHistory = history
        }
    }
    
    // Метод для проверки просроченности нарушения
    var isOverdue: Bool {
        let currentDate = Date()
        let deadlineDate = currentDeadlineDate
        
        guard let deadline = deadlineDate else { 
            return false 
        }
        
        // Если нарушение устранено, то оно не просрочено
        if isEliminated { 
            return false 
        }
        
        // Сравниваем только даты без времени
        let calendar = Calendar.current
        let currentDateOnly = calendar.startOfDay(for: currentDate)
        let deadlineDateOnly = calendar.startOfDay(for: deadline)
        
        // Нарушение считается просроченным, если текущая дата >= сроку (включительно)
        // То есть если сегодня день срока, то нарушение уже просрочено
        return currentDateOnly >= deadlineDateOnly
    }
    
    // Метод для получения текущего срока устранения
    var currentDeadlineDate: Date? {
        // Сначала проверяем новую систему истории
        if !deadlineHistory.isEmpty {
            // Сортируем по дате изменения (самая последняя запись) и возвращаем deadlineDate
            return deadlineHistory.sorted(by: { $0.changeDate > $1.changeDate }).first?.deadlineDate
        }
        
        // Обратная совместимость со старой системой
        return newEliminationDate ?? originalEliminationDate
    }
    
    // Метод для получения даты срока устранения (обратная совместимость)
    var effectiveDeadlineDate: Date? {
        return currentDeadlineDate
    }
    
    // Метод для добавления нового срока
    func addNewDeadline(_ newDeadline: Date, reason: String? = nil) -> ViolationElimination {
        var newHistory = deadlineHistory
        newHistory.append(DeadlineHistoryEntry(deadlineDate: newDeadline, reason: reason))
        
        let updatedElimination = ViolationElimination(
            id: self.id,
            aktId: self.aktId,
            aktNumber: self.aktNumber,
            violationId: self.violationId,
            violationTitle: self.violationTitle,
            isEliminated: self.isEliminated,
            eliminationDate: self.eliminationDate,
            originalEliminationDate: newDeadline, // Обновляем основную дату на новую
            newEliminationDate: newDeadline,
            deadlineHistory: newHistory
        )
        
        // ВАЖНО: Сохраняем обновленную запись в UserDefaults
        ViolationEliminationManager.updateElimination(updatedElimination)
        
        // ВАЖНО: Обновляем основной срок акта на основе ближайшего нарушения
        if ViolationEliminationManager.updateMainDeadlineForAkt(self.aktId) {
            print("✅ Основной срок акта обновлен на основе нарушений")
        } else {
            print("⚠️ Не удалось обновить основной срок акта")
        }
        
        return updatedElimination
    }
    
    // Метод для получения истории сроков (отсортированной по дате изменения)
    var sortedDeadlineHistory: [DeadlineHistoryEntry] {
        return deadlineHistory.sorted(by: { $0.changeDate > $1.changeDate })
    }
}

// MARK: - ViolationEliminationManager
class ViolationEliminationManager {
    private static let eliminationsKey = "ViolationEliminations"
    
    // Кэширование для избежания множественных чтений из UserDefaults
    private static var cachedEliminations: [ViolationElimination]? = nil
    private static var cacheNeedsUpdate = false
    
    // Батчинг сохранения: частые вызовы объединяются в одно сохранение через saveDebounceInterval
    private static let saveDebounceInterval: TimeInterval = 0.25
    private static var saveWorkItem: DispatchWorkItem?
    private static var pendingEliminations: [ViolationElimination]?
    private static let saveQueue = DispatchQueue(label: "ru.gazprom.eliminations.save")
    
    // #region agent log
    private static func _agentLog(location: String, message: String, data: [String: Any], hypothesisId: String) {
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        let payload: [String: Any] = [
            "id": "log_\(nowMs)",
            "timestamp": nowMs,
            "location": location,
            "message": message,
            "data": data,
            "runId": "run1",
            "hypothesisId": hypothesisId
        ]
        DataFlowAKT.agentWriteDebugLog(payload)
    }
    // #endregion
    
    /// Немедленная запись (бэкап, выход из приложения и т.д.)
    static func saveEliminationsImmediate(_ eliminations: [ViolationElimination]) {
        saveQueue.sync {
            saveWorkItem?.cancel()
            saveWorkItem = nil
            pendingEliminations = nil
        }
        performSave(eliminations)
    }
    
    static func saveEliminations(_ eliminations: [ViolationElimination]) {
        saveQueue.async {
            pendingEliminations = eliminations
            saveWorkItem?.cancel()
            let item = DispatchWorkItem {
                let toSave = pendingEliminations
                pendingEliminations = nil
                saveWorkItem = nil
                if let toSave = toSave {
                    performSave(toSave)
                }
            }
            saveWorkItem = item
            saveQueue.asyncAfter(deadline: .now() + saveDebounceInterval, execute: item)
        }
    }
    
    private static func performSave(_ eliminations: [ViolationElimination]) {
        let eliminated = eliminations.filter { $0.isEliminated }.count
        _agentLog(location: "Akt.swift:saveEliminations", message: "saveEliminations called", data: ["total": eliminations.count, "eliminatedCount": eliminated], hypothesisId: "D")
        if let encoded = try? JSONEncoder().encode(eliminations) {
            UserDefaults.standard.set(encoded, forKey: eliminationsKey)
            cachedEliminations = eliminations
            cacheNeedsUpdate = false
        }
    }
    
    static func loadEliminations() -> [ViolationElimination] {
        // Используем кэш если он есть и актуален
        if let cached = cachedEliminations, !cacheNeedsUpdate {
            return cached
        }
        
        guard let data = UserDefaults.standard.data(forKey: eliminationsKey),
              let eliminations = try? JSONDecoder().decode([ViolationElimination].self, from: data) else {
            // #region agent log
            _agentLog(location: "Akt.swift:loadEliminations", message: "loadEliminations decode failed or empty", data: ["hasData": UserDefaults.standard.data(forKey: eliminationsKey) != nil], hypothesisId: "E")
            // #endregion
            cachedEliminations = []
            cacheNeedsUpdate = false
            return []
        }
        
        // Обновляем кэш
        cachedEliminations = eliminations
        cacheNeedsUpdate = false
        return eliminations
    }
    
    // Метод для принудительного обновления кэша (например, после внешних изменений)
    static func invalidateCache() {
        cacheNeedsUpdate = true
        cachedEliminations = nil
    }
    
    // Метод для получения eliminations с использованием кэша
    static func getEliminationsWithCache() -> [ViolationElimination] {
        return loadEliminations()
    }
    
    static func addElimination(_ elimination: ViolationElimination) {
        print("🔄 [ELIMINATION_MANAGER] addElimination вызван для нарушения: \(elimination.violationId)")
        var eliminations = loadEliminations()
        
        // ВАЖНО: Проверяем на дубликаты по violationId перед добавлением
        // Если уже есть запись для этого нарушения, обновляем её вместо создания новой
        if let existingIndex = eliminations.firstIndex(where: { $0.violationId == elimination.violationId }) {
            print("⚠️ [ELIMINATION_MANAGER] Найдена существующая запись для нарушения \(elimination.violationId), обновляем вместо создания новой")
            let existing = eliminations[existingIndex]
            print("   Старая запись: ID=\(existing.id), isEliminated=\(existing.isEliminated)")
            print("   Новая запись: ID=\(elimination.id), isEliminated=\(elimination.isEliminated)")
            
            // Сохраняем оригинальный ID существующей записи, но обновляем данные
            let updatedElimination = ViolationElimination(
                id: existing.id, // Сохраняем оригинальный ID
                aktId: elimination.aktId,
                aktNumber: elimination.aktNumber,
                violationId: elimination.violationId,
                violationTitle: elimination.violationTitle,
                isEliminated: elimination.isEliminated,
                eliminationDate: elimination.eliminationDate,
                originalEliminationDate: elimination.originalEliminationDate ?? existing.originalEliminationDate,
                newEliminationDate: elimination.newEliminationDate ?? existing.newEliminationDate,
                deadlineHistory: elimination.deadlineHistory.isEmpty ? existing.deadlineHistory : elimination.deadlineHistory
            )
            eliminations[existingIndex] = updatedElimination
            print("✅ [ELIMINATION_MANAGER] Запись обновлена вместо создания дубликата")
        } else {
            eliminations.append(elimination)
            print("✅ [ELIMINATION_MANAGER] Новая запись добавлена")
        }
        
        saveEliminations(eliminations)
    }
    
    // Батч-версия для добавления нескольких eliminations сразу
    static func addEliminations(_ newEliminations: [ViolationElimination]) {
        print("🔄 [ELIMINATION_MANAGER] addEliminations вызван для \(newEliminations.count) записей")
        var eliminations = loadEliminations()
        
        // Создаем словарь существующих записей по violationId для быстрого поиска
        var existingByViolationId: [UUID: Int] = [:]
        for (index, elimination) in eliminations.enumerated() {
            existingByViolationId[elimination.violationId] = index
        }
        
        var addedCount = 0
        var updatedCount = 0
        
        for elimination in newEliminations {
            if let existingIndex = existingByViolationId[elimination.violationId] {
                // Обновляем существующую запись
                let existing = eliminations[existingIndex]
                let updatedElimination = ViolationElimination(
                    id: existing.id,
                    aktId: elimination.aktId,
                    aktNumber: elimination.aktNumber,
                    violationId: elimination.violationId,
                    violationTitle: elimination.violationTitle,
                    isEliminated: elimination.isEliminated,
                    eliminationDate: elimination.eliminationDate,
                    originalEliminationDate: elimination.originalEliminationDate ?? existing.originalEliminationDate,
                    newEliminationDate: elimination.newEliminationDate ?? existing.newEliminationDate,
                    deadlineHistory: elimination.deadlineHistory.isEmpty ? existing.deadlineHistory : elimination.deadlineHistory
                )
                eliminations[existingIndex] = updatedElimination
                updatedCount += 1
            } else {
                eliminations.append(elimination)
                existingByViolationId[elimination.violationId] = eliminations.count - 1
                addedCount += 1
            }
        }
        
        print("✅ [ELIMINATION_MANAGER] Добавлено: \(addedCount), обновлено: \(updatedCount)")
        saveEliminations(eliminations)
    }
    
    static func updateElimination(_ elimination: ViolationElimination) {
        print("🔄 [ELIMINATION_MANAGER] updateElimination вызван для записи: \(elimination.id)")
        var eliminations = loadEliminations()
        
        // Сначала ищем по ID
        if let index = eliminations.firstIndex(where: { $0.id == elimination.id }) {
            eliminations[index] = elimination
            saveEliminations(eliminations)
            print("✅ [ELIMINATION_MANAGER] Запись обновлена по ID")
            // Кэш обновляется в saveEliminations
        } else {
            // Если не найдено по ID, ищем по violationId (на случай если ID изменился)
            if let index = eliminations.firstIndex(where: { $0.violationId == elimination.violationId }) {
                print("⚠️ [ELIMINATION_MANAGER] Запись не найдена по ID, но найдена по violationId, обновляем")
                let existing = eliminations[index]
                // Сохраняем оригинальный ID
                let updatedElimination = ViolationElimination(
                    id: existing.id,
                    aktId: elimination.aktId,
                    aktNumber: elimination.aktNumber,
                    violationId: elimination.violationId,
                    violationTitle: elimination.violationTitle,
                    isEliminated: elimination.isEliminated,
                    eliminationDate: elimination.eliminationDate,
                    originalEliminationDate: elimination.originalEliminationDate ?? existing.originalEliminationDate,
                    newEliminationDate: elimination.newEliminationDate ?? existing.newEliminationDate,
                    deadlineHistory: elimination.deadlineHistory.isEmpty ? existing.deadlineHistory : elimination.deadlineHistory
                )
                eliminations[index] = updatedElimination
                saveEliminations(eliminations)
                print("✅ [ELIMINATION_MANAGER] Запись обновлена по violationId")
            } else {
                print("❌ [ELIMINATION_MANAGER] Запись не найдена, добавляем как новую")
                addElimination(elimination)
            }
        }
    }
    
    // Батч-версия для обновления нескольких eliminations сразу
    static func updateEliminations(_ eliminations: [ViolationElimination]) {
        var allEliminations = loadEliminations()
        var hasUpdates = false
        
        for elimination in eliminations {
            if let index = allEliminations.firstIndex(where: { $0.id == elimination.id }) {
                allEliminations[index] = elimination
                hasUpdates = true
            }
        }
        
        if hasUpdates {
            saveEliminations(allEliminations)
        }
    }
    
    static func getEliminationsForAkt(_ aktId: UUID) -> [ViolationElimination] {
        // Используем кэшированные данные
        let allEliminations = getEliminationsWithCache()
        let filtered = allEliminations.filter { $0.aktId == aktId }
        
        // ВАЖНО: Удаляем дубликаты по violationId для этого акта
        // Это предотвращает двойной подсчет в статистике
        var seenViolationIds: Set<UUID> = []
        var uniqueEliminations: [ViolationElimination] = []
        
        for elimination in filtered {
            if !seenViolationIds.contains(elimination.violationId) {
                seenViolationIds.insert(elimination.violationId)
                uniqueEliminations.append(elimination)
            } else {
                print("⚠️ [ELIMINATION_MANAGER] Найден дубликат для акта \(aktId), нарушения \(elimination.violationId)")
            }
        }
        
        if filtered.count != uniqueEliminations.count {
            print("⚠️ [ELIMINATION_MANAGER] Для акта \(aktId) найдено \(filtered.count - uniqueEliminations.count) дубликатов, возвращаем только уникальные")
        }
        
        return uniqueEliminations
    }
    
    static func getEliminationForViolation(_ violationId: UUID) -> ViolationElimination? {
        // Используем кэшированные данные
        let allEliminations = getEliminationsWithCache()
        let matches = allEliminations.filter { $0.violationId == violationId }
        
        // Если найдено несколько записей (дубликаты), возвращаем самую новую или первую
        if matches.count > 1 {
            print("⚠️ [ELIMINATION_MANAGER] Найдено \(matches.count) дубликатов для нарушения \(violationId)")
            // Возвращаем первую найденную, но логируем проблему
            // В идеале нужно удалить дубликаты, но это делается отдельным методом
            return matches.first
        }
        
        return matches.first
    }
    
    /// Мигрирует «сиротские» записи устранения: при смене violationId (после редактирования акта)
    /// привязывает старые записи к текущим нарушениям по совпадению title, сохраняя isEliminated.
    static func migrateOrphanEliminationsToCurrentViolations(akts: [AKT]) {
        var allEliminations = loadEliminations()
        var hasChanges = false
        
        for akt in akts {
            let currentViolationIds = Set(akt.violations.map { $0.id })
            let aktEliminations = allEliminations.filter { $0.aktId == akt.id }
            let orphans = aktEliminations.filter { !currentViolationIds.contains($0.violationId) }
            if orphans.isEmpty { continue }
            
            var claimedCurrentIds = Set(allEliminations.filter { $0.aktId == akt.id && currentViolationIds.contains($0.violationId) }.map { $0.violationId })
            
            for orphan in orphans {
                guard let matchIndex = akt.violations.firstIndex(where: { v in
                    v.title == orphan.violationTitle && !claimedCurrentIds.contains(v.id)
                }) else { continue }
                let newViolationId = akt.violations[matchIndex].id
                claimedCurrentIds.insert(newViolationId)
                guard let index = allEliminations.firstIndex(where: { $0.id == orphan.id }) else { continue }
                let updated = ViolationElimination(
                    id: orphan.id,
                    aktId: orphan.aktId,
                    aktNumber: orphan.aktNumber,
                    violationId: newViolationId,
                    violationTitle: orphan.violationTitle,
                    isEliminated: orphan.isEliminated,
                    eliminationDate: orphan.eliminationDate,
                    originalEliminationDate: orphan.originalEliminationDate,
                    newEliminationDate: orphan.newEliminationDate,
                    deadlineHistory: orphan.deadlineHistory
                )
                allEliminations[index] = updated
                hasChanges = true
            }
        }
        if hasChanges {
            saveEliminations(allEliminations)
            print("✅ [ELIMINATION_MANAGER] Миграция сиротских записей устранения выполнена")
        }
    }
    
    /// Удаляет дубликаты записей устранения (оставляет только одну запись для каждого violationId)
    static func removeDuplicateEliminations() {
        print("🔄 [ELIMINATION_MANAGER] Начинаем удаление дубликатов")
        let eliminations = loadEliminations()
        let initialCount = eliminations.count
        let initialEliminated = eliminations.filter { $0.isEliminated }.count
        // #region agent log
        _agentLog(location: "Akt.swift:removeDuplicateEliminations:before", message: "before dedup", data: ["total": initialCount, "eliminatedCount": initialEliminated], hypothesisId: "B")
        // #endregion
        
        // Группируем по violationId
        var seenViolationIds: Set<UUID> = []
        var uniqueEliminations: [ViolationElimination] = []
        var duplicatesRemoved = 0
        var removedWasEliminated = 0
        var keptWasEliminated = 0
        
        for elimination in eliminations {
            if !seenViolationIds.contains(elimination.violationId) {
                seenViolationIds.insert(elimination.violationId)
                uniqueEliminations.append(elimination)
                if elimination.isEliminated { keptWasEliminated += 1 }
            } else {
                duplicatesRemoved += 1
                if elimination.isEliminated { removedWasEliminated += 1 }
                print("   🗑️ Удален дубликат для нарушения \(elimination.violationId)")
            }
        }
        
        // #region agent log
        let afterEliminated = uniqueEliminations.filter { $0.isEliminated }.count
        _agentLog(location: "Akt.swift:removeDuplicateEliminations:after", message: "after dedup", data: ["total": uniqueEliminations.count, "eliminatedCount": afterEliminated, "duplicatesRemoved": duplicatesRemoved, "removedWasEliminated": removedWasEliminated, "keptWasEliminated": keptWasEliminated], hypothesisId: "B")
        // #endregion
        if duplicatesRemoved > 0 {
            saveEliminations(uniqueEliminations)
            print("✅ [ELIMINATION_MANAGER] Удалено дубликатов: \(duplicatesRemoved), было: \(initialCount), стало: \(uniqueEliminations.count)")
        } else {
            print("ℹ️ [ELIMINATION_MANAGER] Дубликатов не найдено")
        }
    }
    
    // Батч-версия для получения eliminations для нескольких актов сразу
    static func getEliminationsForAkts(_ aktIds: [UUID]) -> [UUID: [ViolationElimination]] {
        let allEliminations = getEliminationsWithCache()
        var result: [UUID: [ViolationElimination]] = [:]
        let aktIdsSet = Set(aktIds)
        
        // Сначала собираем все записи для нужных актов
        var tempResult: [UUID: [ViolationElimination]] = [:]
        for elimination in allEliminations {
            if aktIdsSet.contains(elimination.aktId) {
                if tempResult[elimination.aktId] == nil {
                    tempResult[elimination.aktId] = []
                }
                tempResult[elimination.aktId]?.append(elimination)
            }
        }
        
        // Затем удаляем дубликаты по violationId для каждого акта
        for (aktId, eliminations) in tempResult {
            var seenViolationIds: Set<UUID> = []
            var uniqueEliminations: [ViolationElimination] = []
            
            for elimination in eliminations {
                if !seenViolationIds.contains(elimination.violationId) {
                    seenViolationIds.insert(elimination.violationId)
                    uniqueEliminations.append(elimination)
                }
            }
            
            if eliminations.count != uniqueEliminations.count {
                print("⚠️ [ELIMINATION_MANAGER] Для акта \(aktId) найдено \(eliminations.count - uniqueEliminations.count) дубликатов")
            }
            
            result[aktId] = uniqueEliminations
        }
        
        return result
    }
    
    static func createEliminationsForAkt(_ akt: AKT) {
        print("🔍 [VIOLATION_ELIMINATION] createEliminationsForAkt вызван для акта №\(akt.number)")
        print("   📅 Дата проверки акта: \(akt.date)")
        
        let existingEliminations = getEliminationsForAkt(akt.id)
        print("   📊 Найдено существующих записей: \(existingEliminations.count)")
        
        // ИСПРАВЛЕНИЕ: Для коротких актов используем дату предоставления отчета
        // Для обычных актов рассчитываем как дата проверки + 1 месяц
        let correctEliminationDate: Date
        if akt.isShortFormat {
            // Для коротких актов используем дату предоставления отчета
            correctEliminationDate = akt.actPredostavlenDate
            print("   ✅ Дата устранения для короткого акта (дата предоставления отчета): \(correctEliminationDate)")
        } else if let calculatedDate = Calendar.current.date(byAdding: .month, value: 1, to: akt.date) {
            // Для обычных актов: дата проверки + 1 месяц
            correctEliminationDate = calculatedDate
            print("   ✅ Дата устранения рассчитана (дата проверки + 1 месяц): \(correctEliminationDate)")
        } else {
            // Если не удалось рассчитать, используем дату из акта
            correctEliminationDate = akt.actustranenDate
            print("   ⚠️ Не удалось рассчитать, используем дату из акта: \(correctEliminationDate)")
        }
        
        print("   📋 Нарушений в акте: \(akt.violations.count)")
        
        for violation in akt.violations {
            // ВАЖНО: Используем getEliminationForViolation для проверки существования
            // Это предотвращает создание дубликатов
            if ViolationEliminationManager.getEliminationForViolation(violation.id) == nil {
                print("   🔄 Создаем запись для нарушения: \(violation.title.prefix(30))...")
                
                // Создаем запись с историей сроков
                // Используем рассчитанную дату устранения
                let originalDeadline = DeadlineHistoryEntry(
                    deadlineDate: correctEliminationDate,
                    changeDate: akt.realDateCreate, // Используем дату создания акта
                    isOriginal: true
                )
                
                let elimination = ViolationElimination(
                    aktId: akt.id,
                    aktNumber: akt.number,
                    violationId: violation.id,
                    violationTitle: violation.title,
                    originalEliminationDate: correctEliminationDate,
                    deadlineHistory: [originalDeadline]
                )
                addElimination(elimination)
                print("      ✅ Запись создана с датой устранения: \(correctEliminationDate)")
            } else {
                print("   ℹ️ Запись для нарушения уже существует: \(violation.title.prefix(30))...")
            }
        }
        
        print("✅ [VIOLATION_ELIMINATION] Завершено создание записей устранения для акта №\(akt.number)")
    }
    
    // Батч-версия для создания eliminations для нескольких актов сразу
    static func createEliminationsForAkts(_ akts: [AKT]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 [VIOLATION_ELIMINATION] Батч-создание eliminations для \(akts.count) актов")
        
        // Загружаем все существующие eliminations один раз
        let allExistingEliminations = loadEliminations()
        let existingEliminated = allExistingEliminations.filter { $0.isEliminated }.count
        // #region agent log
        _agentLog(location: "Akt.swift:createEliminationsForAkts:start", message: "createEliminationsForAkts start", data: ["aktsCount": akts.count, "existingTotal": allExistingEliminations.count, "existingEliminated": existingEliminated], hypothesisId: "C")
        // #endregion
        // ВАЖНО: Создаем Set всех существующих violationId для глобальной проверки на дубликаты
        let allExistingViolationIds = Set(allExistingEliminations.map { $0.violationId })
        
        var newEliminations: [ViolationElimination] = []
        
        for akt in akts {
            // ИСПРАВЛЕНИЕ: Для коротких актов используем дату предоставления отчета
            // Для обычных актов рассчитываем как дата проверки + 1 месяц
            let correctEliminationDate: Date
            if akt.isShortFormat {
                // Для коротких актов используем дату предоставления отчета
                correctEliminationDate = akt.actPredostavlenDate
            } else if let calculatedDate = Calendar.current.date(byAdding: .month, value: 1, to: akt.date) {
                // Для обычных актов: дата проверки + 1 месяц
                correctEliminationDate = calculatedDate
            } else {
                correctEliminationDate = akt.actustranenDate
            }
            
            // Создаем записи только для нарушений, для которых еще нет eliminations (глобальная проверка)
            for violation in akt.violations {
                // ВАЖНО: Проверяем глобально, а не только по акту, чтобы избежать дубликатов
                if !allExistingViolationIds.contains(violation.id) {
                    let originalDeadline = DeadlineHistoryEntry(
                        deadlineDate: correctEliminationDate,
                        changeDate: akt.realDateCreate,
                        isOriginal: true
                    )
                    
                    let elimination = ViolationElimination(
                        aktId: akt.id,
                        aktNumber: akt.number,
                        violationId: violation.id,
                        violationTitle: violation.title,
                        originalEliminationDate: correctEliminationDate,
                        deadlineHistory: [originalDeadline]
                    )
                    newEliminations.append(elimination)
                }
            }
        }
        
        // Сохраняем все новые eliminations одним батчем
        // addEliminations уже проверяет на дубликаты, но мы проверили заранее для оптимизации
        if !newEliminations.isEmpty {
            addEliminations(newEliminations)
            let afterAll = loadEliminations()
            // #region agent log
            _agentLog(location: "Akt.swift:createEliminationsForAkts:after", message: "createEliminationsForAkts after add", data: ["newAdded": newEliminations.count, "totalAfter": afterAll.count, "eliminatedAfter": afterAll.filter { $0.isEliminated }.count], hypothesisId: "C")
            // #endregion
            print("✅ [VIOLATION_ELIMINATION] Создано \(newEliminations.count) новых записей за \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime)) сек")
        } else {
            print("ℹ️ [VIOLATION_ELIMINATION] Все eliminations уже существуют")
        }
    }
    
    // MARK: - Новые методы для работы с историей сроков
    
    
    /// Получает историю сроков для нарушения
    static func getDeadlineHistoryForViolation(_ violationId: UUID) -> [DeadlineHistoryEntry] {
        guard let elimination = getEliminationForViolation(violationId) else {
            return []
        }
        return elimination.sortedDeadlineHistory
    }
    
    /// Получает текущий срок устранения для нарушения
    static func getCurrentDeadlineForViolation(_ violationId: UUID) -> Date? {
        guard let elimination = getEliminationForViolation(violationId) else {
            return nil
        }
        return elimination.currentDeadlineDate
    }
    
    /// Проверяет, есть ли просроченные нарушения в акте
    static func hasOverdueViolationsInAkt(_ aktId: UUID) -> Bool {
        let eliminations = getEliminationsForAkt(aktId)
        return eliminations.contains { elimination in
            !elimination.isEliminated && elimination.isOverdue
        }
    }
    
    /// Получает все просроченные нарушения в акте
    static func getOverdueViolationsInAkt(_ aktId: UUID) -> [ViolationElimination] {
        let eliminations = getEliminationsForAkt(aktId)
        return eliminations.filter { elimination in
            !elimination.isEliminated && elimination.isOverdue
        }
    }
    
    /// Получает статистику по нарушениям в акте
    static func getViolationStatisticsForAkt(_ aktId: UUID) -> (total: Int, eliminated: Int, overdue: Int, onTime: Int) {
        let eliminations = getEliminationsForAkt(aktId)
        let total = eliminations.count
        let eliminated = eliminations.filter { $0.isEliminated }.count
        let overdue = eliminations.filter { $0.isOverdue }.count
        let onTime = total - eliminated - overdue
        
        return (total: total, eliminated: eliminated, overdue: overdue, onTime: onTime)
    }
    
    /// Получает наиболее ранний срок устранения среди неустраненных нарушений в акте
    static func getEarliestDeadlineForAkt(_ aktId: UUID) -> Date? {
        let eliminations = getEliminationsForAkt(aktId)
        // ВАЖНО: Получаем сроки только неустраненных нарушений
        let uneliminatedEliminations = eliminations.filter { !$0.isEliminated }
        let deadlines = uneliminatedEliminations.compactMap { $0.currentDeadlineDate }
        
        // Если есть неустраненные нарушения, возвращаем самый ранний срок
        if let earliestDeadline = deadlines.min() {
            print("🔍 [EARLIEST_DEADLINE] Найден самый ранний срок среди неустраненных нарушений: \(earliestDeadline)")
            print("   Количество неустраненных нарушений: \(uneliminatedEliminations.count)")
            return earliestDeadline
        }
        
        // Если все нарушения устранены, возвращаем срок из самого акта
        let allAkts = DataFlowAKT.loadArr()
        if let akt = allAkts.first(where: { $0.id == aktId }) {
            print("🔍 [EARLIEST_DEADLINE] Все нарушения устранены, используем срок из акта: \(akt.actustranenDate)")
            return akt.actustranenDate
        }
        
        print("⚠️ [EARLIEST_DEADLINE] Акт не найден")
        return nil
    }
    
    /// Обновляет основной срок устранения акта на основе нарушений
    static func updateMainDeadlineForAkt(_ aktId: UUID) -> Bool {
        print("🔄 [UPDATE_MAIN_DEADLINE] Начинаем обновление основного срока для акта: \(aktId)")
        
        // Сначала проверяем, есть ли нарушения в акте
        let allAkts = DataFlowAKT.loadArr()
        guard let akt = allAkts.first(where: { $0.id == aktId }) else {
            print("❌ [UPDATE_MAIN_DEADLINE] Акт с ID \(aktId) не найден")
            return false
        }
        
        print("🔍 [UPDATE_MAIN_DEADLINE] Найден акт №\(akt.number) с \(akt.violations.count) нарушениями")
        print("   Текущий основной срок: \(akt.actustranenDate)")
        
        // Если в акте нет нарушений, не обновляем срок
        if akt.violations.isEmpty {
            print("ℹ️ [UPDATE_MAIN_DEADLINE] Акт №\(akt.number) не содержит нарушений, пропускаем обновление срока")
            return true
        }
        
        guard let earliestDeadline = getEarliestDeadlineForAkt(aktId) else {
            print("⚠️ [UPDATE_MAIN_DEADLINE] Не найден срок устранения для акта \(aktId)")
            return false
        }
        
        print("🔍 [UPDATE_MAIN_DEADLINE] Найден самый ранний срок: \(earliestDeadline)")
        
        // Проверяем, нужно ли обновлять срок
        if abs(akt.actustranenDate.timeIntervalSince(earliestDeadline)) < 60 { // разница меньше 1 минуты
            print("ℹ️ [UPDATE_MAIN_DEADLINE] Срок не изменился, пропускаем обновление")
            return true
        }
        
        // Находим индекс акта в массиве
        guard let aktIndex = allAkts.firstIndex(where: { $0.id == aktId }) else {
            print("❌ [UPDATE_MAIN_DEADLINE] Акт с ID \(aktId) не найден в массиве")
            return false
        }
        
        var updatedAkts = allAkts
        let currentAkt = updatedAkts[aktIndex]
        
        // Создаем обновленный акт с новым сроком устранения
        let updatedAkt = AKT(
            id: currentAkt.id,
            number: currentAkt.number,
            date: currentAkt.date,
            comission: currentAkt.comission,
            organization: currentAkt.organization,
            objectsCheck: currentAkt.objectsCheck,
            predstavitelyComission: currentAkt.predstavitelyComission,
            violations: currentAkt.violations,
            description: currentAkt.description,
            actustranenDate: earliestDeadline, // Обновляем основной срок
            actPredostavlenDate: currentAkt.actPredostavlenDate,
            actUtverzdenDate: currentAkt.actUtverzdenDate,
            urlAct: currentAkt.urlToFllACT ?? URL(fileURLWithPath: ""),
            realDateCreate: currentAkt.realDateCreate
        )
        
        updatedAkts[aktIndex] = updatedAkt
        
        // Сохраняем обновленные акты
        DataFlowAKT.saveArr(arr: updatedAkts)
        
        // ВАЖНО: Очищаем кэш eliminations, чтобы обновленные данные загружались заново
        ViolationEliminationManager.invalidateCache()
        
        print("✅ [UPDATE_MAIN_DEADLINE] Основной срок устранения акта №\(akt.number) обновлен")
        print("   Старый срок: \(akt.actustranenDate)")
        print("   Новый срок: \(earliestDeadline)")
        
        // Проверяем, что данные действительно сохранились
        let savedAkts = DataFlowAKT.loadArr()
        if let savedAkt = savedAkts.first(where: { $0.id == aktId }) {
            print("   Проверка сохранения: \(savedAkt.actustranenDate)")
            if abs(savedAkt.actustranenDate.timeIntervalSince(earliestDeadline)) < 60 {
                print("✅ [UPDATE_MAIN_DEADLINE] Данные успешно сохранены")
            } else {
                print("❌ [UPDATE_MAIN_DEADLINE] Ошибка сохранения данных!")
            }
        }
        
        // ВАЖНО: Отправляем уведомление об обновлении дат устранения для обновления UI в других разделах
        NotificationCenter.default.post(
            name: NSNotification.Name("ViolationEliminationDatesUpdated"),
            object: nil,
            userInfo: ["aktId": aktId]
        )
        
        return true
    }
    
    /// Обновляет основные сроки для всех актов
    static func updateAllMainDeadlines() {
        let allAkts = DataFlowAKT.loadArr()
        var updatedCount = 0
        
        // Сначала создаем записи устранения для всех актов, если их нет
        for akt in allAkts {
            createEliminationsForAkt(akt)
        }
        
        // Затем обновляем основные сроки только для актов без пользовательских изменений
        for akt in allAkts {
            let eliminations = getEliminationsForAkt(akt.id)
            let hasUserChanges = eliminations.contains { elimination in
                elimination.deadlineHistory.count > 1 || 
                (elimination.deadlineHistory.count == 1 && !elimination.deadlineHistory.first!.isOriginal)
            }
            
            if !hasUserChanges {
                if updateMainDeadlineForAkt(akt.id) {
                    updatedCount += 1
                }
            } else {
                print("   ⚠️ Пропускаем акт №\(akt.number) - есть пользовательские изменения дат")
                print("   📊 Найдено записей с изменениями: \(eliminations.filter { $0.deadlineHistory.count > 1 || ($0.deadlineHistory.count == 1 && !$0.deadlineHistory.first!.isOriginal) }.count)")
            }
        }
        
        print("✅ Обновлено основных сроков устранения: \(updatedCount) из \(allAkts.count)")
    }
    
    /// Обновляет даты устранения для всех нарушений акта с учётом продлённых сроков
    /// Если у нарушения есть продлённый срок, он сохраняется, если новая дата меньше продлённой
    /// Если новая дата больше продлённого срока, обновляется originalEliminationDate
    /// - Parameters:
    ///   - aktId: ID акта
    ///   - newEliminationDate: Новая дата устранения
    ///   - forceUpdate: Если true, принудительно обновляет даты, игнорируя продлённые сроки (используется при изменении даты предоставления отчета в истории)
    static func updateEliminationDatesFromAkt(_ aktId: UUID, newEliminationDate: Date, forceUpdate: Bool = false) {
        print("🔄 [UPDATE_ELIMINATION_DATES] Обновление дат устранения для акта \(aktId) с новой датой: \(newEliminationDate), forceUpdate: \(forceUpdate)")
        
        // Получаем все eliminations для акта
        var allEliminations = loadEliminations()
        let aktEliminations = allEliminations.filter { $0.aktId == aktId }
        
        guard !aktEliminations.isEmpty else {
            print("ℹ️ [UPDATE_ELIMINATION_DATES] Нет записей устранения для акта \(aktId)")
            return
        }
        
        var updatedCount = 0
        var skippedCount = 0
        
        for elimination in aktEliminations {
            // Получаем текущий продлённый срок (если есть)
            let currentExtendedDeadline = elimination.currentDeadlineDate
            
            // Если есть продлённый срок и новая дата меньше продлённой - оставляем продлённый срок
            // НО: если forceUpdate = true, принудительно обновляем даты, игнорируя продлённые сроки
            if !forceUpdate, let extendedDeadline = currentExtendedDeadline, newEliminationDate < extendedDeadline {
                print("   ⚠️ Пропускаем нарушение '\(elimination.violationTitle.prefix(30))...' - продлённый срок (\(extendedDeadline)) больше новой даты (\(newEliminationDate))")
                skippedCount += 1
                continue
            }
            
            
            // Если новая дата больше продлённого срока или продлённого срока нет - обновляем originalEliminationDate
            // Но сохраняем продлённый срок в deadlineHistory, если он есть
            var updatedHistory = elimination.deadlineHistory
            
            // Если есть продлённый срок, который меньше новой даты, добавляем новую дату в историю
            if let extendedDeadline = currentExtendedDeadline, extendedDeadline < newEliminationDate {
                // Добавляем новую дату в историю как обновление
                updatedHistory.append(DeadlineHistoryEntry(
                    deadlineDate: newEliminationDate,
                    changeDate: Date(),
                    reason: "Обновление из генерации акта",
                    isOriginal: false
                ))
            } else if updatedHistory.isEmpty {
                // Если истории нет, создаём запись с новой датой
                updatedHistory.append(DeadlineHistoryEntry(
                    deadlineDate: newEliminationDate,
                    changeDate: Date(),
                    isOriginal: true
                ))
            } else {
                // Обновляем первую запись (оригинальную) на новую дату
                if let firstEntry = updatedHistory.first {
                    updatedHistory[0] = DeadlineHistoryEntry(
                        deadlineDate: newEliminationDate,
                        changeDate: Date(),
                        reason: firstEntry.reason,
                        isOriginal: true
                    )
                }
            }
            
            // Создаём обновлённую запись
            let updatedElimination = ViolationElimination(
                id: elimination.id,
                aktId: elimination.aktId,
                aktNumber: elimination.aktNumber,
                violationId: elimination.violationId,
                violationTitle: elimination.violationTitle,
                isEliminated: elimination.isEliminated,
                eliminationDate: elimination.eliminationDate,
                originalEliminationDate: newEliminationDate,
                newEliminationDate: newEliminationDate,
                deadlineHistory: updatedHistory
            )
            
            // Обновляем запись в массиве
            if let index = allEliminations.firstIndex(where: { $0.id == elimination.id }) {
                allEliminations[index] = updatedElimination
                updatedCount += 1
                print("   ✅ Обновлена дата для нарушения '\(elimination.violationTitle.prefix(30))...': \(newEliminationDate)")
            }
        }
        
        // Сохраняем обновлённые записи
        if updatedCount > 0 {
            saveEliminations(allEliminations)
            print("✅ [UPDATE_ELIMINATION_DATES] Обновлено записей: \(updatedCount), пропущено: \(skippedCount)")
            
            // Отправляем уведомление для обновления UI в разделе устранения
            NotificationCenter.default.post(
                name: NSNotification.Name("ViolationEliminationDatesUpdated"),
                object: nil,
                userInfo: ["aktId": aktId]
            )
        } else {
            print("ℹ️ [UPDATE_ELIMINATION_DATES] Нет записей для обновления, пропущено: \(skippedCount)")
        }
    }
    
    /// Обновляет даты устранения для конкретного акта при изменении даты проверки
    static func updateEliminationDatesForAkt(_ aktId: UUID) {
        print("🔄 [UPDATE_DATES] Начинаем обновление дат устранения для акта: \(aktId)")
        
        // Загружаем акт
        let allAkts = DataFlowAKT.loadArr()
        guard let akt = allAkts.first(where: { $0.id == aktId }) else {
            print("❌ [UPDATE_DATES] Акт с ID \(aktId) не найден")
            return
        }
        
        print("🔍 [UPDATE_DATES] Найден акт №\(akt.number)")
        print("   📅 Дата проверки: \(akt.date)")
        
        // ИСПРАВЛЕНИЕ: Для коротких актов используем дату предоставления отчета
        // Для обычных актов рассчитываем как дата проверки + 1 месяц
        let correctEliminationDate: Date
        if akt.isShortFormat {
            // Для коротких актов используем дату предоставления отчета
            correctEliminationDate = akt.actPredostavlenDate
            print("   ✅ Дата устранения для короткого акта (дата предоставления отчета): \(correctEliminationDate)")
        } else if let calculatedDate = Calendar.current.date(byAdding: .month, value: 1, to: akt.date) {
            // Для обычных актов: дата проверки + 1 месяц
            correctEliminationDate = calculatedDate
            print("   ✅ Дата устранения рассчитана: \(correctEliminationDate)")
        } else {
            // Если не удалось рассчитать, используем дату из акта
            correctEliminationDate = akt.actustranenDate
            print("   ⚠️ Не удалось рассчитать, используем дату из акта: \(correctEliminationDate)")
        }
        
        // Загружаем все записи устранения для этого акта
        var allEliminations = loadEliminations()
        let aktEliminations = allEliminations.filter { $0.aktId == aktId }
        
        print("   📊 Найдено записей устранения: \(aktEliminations.count)")
        
        var updatedCount = 0
        var skippedCount = 0
        
        for elimination in aktEliminations {
            print("   🔍 Проверяем запись: \(elimination.violationTitle.prefix(30))...")
            print("      📅 Текущая дата устранения: \(elimination.currentDeadlineDate?.description ?? "nil")")
            
            // Проверяем, есть ли пользовательские изменения
            let hasUserChanges = elimination.deadlineHistory.count > 1 || 
                               (elimination.deadlineHistory.count == 1 && !elimination.deadlineHistory.first!.isOriginal)
            
            if hasUserChanges {
                print("      ⚠️ Пропускаем запись с пользовательскими изменениями")
                skippedCount += 1
                continue
            }
            
            // Проверяем, отличается ли текущая дата от рассчитанной
            let currentDeadlineDate = elimination.currentDeadlineDate
            let dateDifference = abs(correctEliminationDate.timeIntervalSince(currentDeadlineDate ?? correctEliminationDate))
            
            print("      📅 Правильная дата устранения: \(correctEliminationDate)")
            print("      🔍 Разница: \(dateDifference) секунд")
            
            if dateDifference > 60 { // разница больше 1 минуты
                print("      🔄 Обновляем дату...")
                
                // Создаем обновленную запись с новой датой
                let updatedDeadlineHistory = [DeadlineHistoryEntry(
                    deadlineDate: correctEliminationDate,
                    changeDate: akt.realDateCreate,
                    isOriginal: true
                )]
                
                let updatedElimination = ViolationElimination(
                    id: elimination.id,
                    aktId: elimination.aktId,
                    aktNumber: elimination.aktNumber,
                    violationId: elimination.violationId,
                    violationTitle: elimination.violationTitle,
                    isEliminated: elimination.isEliminated,
                    eliminationDate: elimination.eliminationDate,
                    originalEliminationDate: correctEliminationDate,
                    newEliminationDate: correctEliminationDate,
                    deadlineHistory: updatedDeadlineHistory
                )
                
                // Обновляем запись в массиве
                if let index = allEliminations.firstIndex(where: { $0.id == elimination.id }) {
                    allEliminations[index] = updatedElimination
                    updatedCount += 1
                    print("      ✅ Дата обновлена")
                }
            } else {
                print("      ℹ️ Дата не изменилась")
            }
        }
        
        // Сохраняем обновленные записи
        if updatedCount > 0 {
            saveEliminations(allEliminations)
            print("✅ [UPDATE_DATES] Обновлено записей: \(updatedCount)")
            print("   ⚠️ Пропущено записей: \(skippedCount)")
        } else {
            print("ℹ️ [UPDATE_DATES] Нет записей для обновления")
            print("   ⚠️ Пропущено записей: \(skippedCount)")
        }
    }
    
    /// Батч-версия для обновления дат устранения для нескольких актов сразу
    static func updateEliminationDatesForAkts(_ aktIds: [UUID]) {
        let startTime = CFAbsoluteTimeGetCurrent()
        print("🔄 [UPDATE_DATES] Батч-обновление дат устранения для \(aktIds.count) актов")
        
        // Загружаем все акты один раз
        let allAkts = DataFlowAKT.loadArr()
        let aktIdsSet = Set(aktIds)
        let aktsToUpdate = allAkts.filter { aktIdsSet.contains($0.id) }
        
        // Загружаем все eliminations один раз
        var allEliminations = loadEliminations()
        
        var updatedCount = 0
        var skippedCount = 0
        
        for akt in aktsToUpdate {
            // Срок устранения берём из акта (actustranenDate), чтобы при изменении срока в акте раздел устранения показывал актуальную дату
            let correctEliminationDate: Date = akt.actustranenDate
            
            // Фильтруем eliminations для этого акта
            let aktEliminations = allEliminations.filter { $0.aktId == akt.id }
            
            for elimination in aktEliminations {
                // Проверяем, есть ли пользовательские изменения
                let hasUserChanges = elimination.deadlineHistory.count > 1 || 
                                   (elimination.deadlineHistory.count == 1 && !elimination.deadlineHistory.first!.isOriginal)
                
                if hasUserChanges {
                    skippedCount += 1
                    continue
                }
                
                // Проверяем, отличается ли текущая дата от рассчитанной
                let currentDeadlineDate = elimination.currentDeadlineDate
                let dateDifference = abs(correctEliminationDate.timeIntervalSince(currentDeadlineDate ?? correctEliminationDate))
                
                if dateDifference > 60 { // разница больше 1 минуты
                    // Создаем обновленную запись с новой датой
                    let updatedDeadlineHistory = [DeadlineHistoryEntry(
                        deadlineDate: correctEliminationDate,
                        changeDate: akt.realDateCreate,
                        isOriginal: true
                    )]
                    
                    let updatedElimination = ViolationElimination(
                        id: elimination.id,
                        aktId: elimination.aktId,
                        aktNumber: elimination.aktNumber,
                        violationId: elimination.violationId,
                        violationTitle: elimination.violationTitle,
                        isEliminated: elimination.isEliminated,
                        eliminationDate: elimination.eliminationDate,
                        originalEliminationDate: correctEliminationDate,
                        newEliminationDate: correctEliminationDate,
                        deadlineHistory: updatedDeadlineHistory
                    )
                    
                    // Обновляем запись в массиве
                    if let index = allEliminations.firstIndex(where: { $0.id == elimination.id }) {
                        allEliminations[index] = updatedElimination
                        updatedCount += 1
                    }
                }
            }
        }
        
        // Сохраняем все обновления одним батчем
        if updatedCount > 0 {
            saveEliminations(allEliminations)
            print("✅ [UPDATE_DATES] Обновлено \(updatedCount) записей за \(String(format: "%.3f", CFAbsoluteTimeGetCurrent() - startTime)) сек")
            print("   ⚠️ Пропущено записей: \(skippedCount)")
        } else {
            print("ℹ️ [UPDATE_DATES] Нет записей для обновления")
            print("   ⚠️ Пропущено записей: \(skippedCount)")
        }
    }
    
    /// Принудительно обновляет все записи устранения с правильными датами
    static func forceUpdateAllEliminationRecords() {
        print("🔄 Начинаем принудительное обновление всех записей устранения...")
        
        let allAkts = DataFlowAKT.loadArr()
        print("   📊 Всего актов: \(allAkts.count)")
        
        var allEliminations = loadEliminations()
        print("   📊 Всего записей устранения: \(allEliminations.count)")
        
        var updatedCount = 0
        var skippedCount = 0
        
        for akt in allAkts {
            print("🔍 Обрабатываем акт №\(akt.number)")
            print("   📅 Дата проверки: \(akt.date)")
            
            let aktEliminations = allEliminations.filter { $0.aktId == akt.id }
            print("   📊 Найдено записей устранения для акта: \(aktEliminations.count)")
            
            // ИСПРАВЛЕНИЕ: Для коротких актов используем дату предоставления отчета
            // Для обычных актов рассчитываем как дата проверки + 1 месяц
            let correctEliminationDate: Date
            if akt.isShortFormat {
                // Для коротких актов используем дату предоставления отчета
                correctEliminationDate = akt.actPredostavlenDate
                print("   ✅ Правильная дата устранения для короткого акта (дата предоставления отчета): \(correctEliminationDate)")
            } else if let calculatedDate = Calendar.current.date(byAdding: .month, value: 1, to: akt.date) {
                // Для обычных актов: дата проверки + 1 месяц
                correctEliminationDate = calculatedDate
                print("   ✅ Правильная дата устранения (дата проверки + 1 месяц): \(correctEliminationDate)")
            } else {
                correctEliminationDate = akt.actustranenDate
                print("   ⚠️ Не удалось рассчитать, используем дату из акта: \(correctEliminationDate)")
            }
            
            for elimination in aktEliminations {
                print("      🔍 Проверяем: \(elimination.violationTitle.prefix(30))...")
                print("         📅 Текущая дата устранения: \(elimination.currentDeadlineDate?.description ?? "nil")")
                
                // Проверяем, есть ли уже история сроков с пользовательскими изменениями
                let hasUserChanges = elimination.deadlineHistory.count > 1 || 
                                   (elimination.deadlineHistory.count == 1 && !elimination.deadlineHistory.first!.isOriginal)
                
                if hasUserChanges {
                    print("         ⚠️ Пропускаем запись с пользовательскими изменениями")
                    skippedCount += 1
                    continue
                }
                
                // Создаем обновленную запись с правильной историей сроков только для записей без пользовательских изменений
                let originalDeadline = DeadlineHistoryEntry(
                    deadlineDate: correctEliminationDate,
                    changeDate: akt.realDateCreate,
                    isOriginal: true
                )
                
                let updatedElimination = ViolationElimination(
                    id: elimination.id,
                    aktId: elimination.aktId,
                    aktNumber: elimination.aktNumber,
                    violationId: elimination.violationId,
                    violationTitle: elimination.violationTitle,
                    isEliminated: elimination.isEliminated,
                    eliminationDate: elimination.eliminationDate,
                    originalEliminationDate: correctEliminationDate,
                    newEliminationDate: elimination.newEliminationDate,
                    deadlineHistory: [originalDeadline]
                )
                
                // Обновляем запись в массиве
                if let index = allEliminations.firstIndex(where: { $0.id == elimination.id }) {
                    allEliminations[index] = updatedElimination
                    updatedCount += 1
                    print("         ✅ Обновлена запись")
                }
            }
        }
        
        // Сохраняем обновленные записи
        saveEliminations(allEliminations)
        
        print("✅ Принудительное обновление завершено!")
        print("   Обновлено записей: \(updatedCount)")
        print("   Пропущено записей: \(skippedCount)")
        print("   Всего записей: \(allEliminations.count)")
    }
    
    /// Добавляет новый срок устранения для нарушения
    static func addNewDeadlineForViolation(_ violationId: UUID, newDeadline: Date, reason: String?) -> Bool {
        print("🔄 Добавляем новый срок устранения для нарушения: \(violationId)")
        print("   Новый срок: \(newDeadline)")
        print("   Причина: \(reason ?? "не указана")")
        
        var allEliminations = loadEliminations()
        
        // Находим запись устранения для данного нарушения
        guard let eliminationIndex = allEliminations.firstIndex(where: { $0.violationId == violationId }) else {
            print("❌ Запись устранения для нарушения \(violationId) не найдена")
            return false
        }
        
        let elimination = allEliminations[eliminationIndex]
        
        // Создаем новую запись в истории сроков
        let newDeadlineEntry = DeadlineHistoryEntry(
            deadlineDate: newDeadline,
            changeDate: Date(),
            reason: reason,
            isOriginal: false
        )
        
        // Добавляем новую запись в историю
        var updatedHistory = elimination.deadlineHistory
        updatedHistory.append(newDeadlineEntry)
        
        // Создаем обновленную запись устранения
        // ВАЖНО: Обновляем originalEliminationDate на новую дату, чтобы она стала постоянной
        let updatedElimination = ViolationElimination(
            id: elimination.id,
            aktId: elimination.aktId,
            aktNumber: elimination.aktNumber,
            violationId: elimination.violationId,
            violationTitle: elimination.violationTitle,
            isEliminated: elimination.isEliminated,
            eliminationDate: elimination.eliminationDate,
            originalEliminationDate: newDeadline, // Устанавливаем новую дату как основную
            newEliminationDate: newDeadline,
            deadlineHistory: updatedHistory
        )
        
        // Обновляем запись в массиве
        allEliminations[eliminationIndex] = updatedElimination
        
        // Сохраняем обновленные записи
        saveEliminations(allEliminations)
        
        // ВАЖНО: Обновляем основной срок акта на основе ближайшего нарушения
        if updateMainDeadlineForAkt(elimination.aktId) {
            print("✅ Основной срок акта обновлен на основе нарушений")
        } else {
            print("⚠️ Не удалось обновить основной срок акта")
        }
        
        print("✅ Новый срок устранения добавлен успешно")
        print("   Нарушение: \(elimination.violationTitle.prefix(30))...")
        print("   Новый срок: \(newDeadline)")
        print("   Записей в истории: \(updatedHistory.count)")
        
        return true
    }
    
}

// MARK: - AktUniqueIDGenerator

/// Генератор уникальных ID для актов
/// Формат: YYYYMMDD-НОМЕР_АКТА-XXXXXX
/// где XXXXXX - случайное 6-значное число
struct AktUniqueIDGenerator {
    
    /// Генерирует уникальный ID для акта
    /// - Parameters:
    ///   - date: Дата создания акта
    ///   - aktNumber: Номер акта, выбранный пользователем
    /// - Returns: Уникальный строковый идентификатор
    static func generateUniqueID(date: Date, aktNumber: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        
        // Нормализуем номер акта (убираем пробелы, приводим к верхнему регистру)
        let normalizedAktNumber = aktNumber
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        // Генерируем случайное 6-значное число для дополнительной уникальности
        let randomSuffix = String(format: "%06d", Int.random(in: 0...999999))
        
        // Формируем уникальный ID: YYYYMMDD-НОМЕР-XXXXXX
        return "\(dateString)-\(normalizedAktNumber)-\(randomSuffix)"
    }
    
    /// Проверяет валидность формата уникального ID
    /// - Parameter uniqueID: ID для проверки
    /// - Returns: true, если формат корректный
    static func isValidFormat(_ uniqueID: String) -> Bool {
        // Формат: YYYYMMDD-НОМЕР-XXXXXX
        let pattern = "^\\d{8}-[A-Z0-9\\-]+-\\d{6}$"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: uniqueID.utf16.count)
        return regex?.firstMatch(in: uniqueID, options: [], range: range) != nil
    }
    
    /// Извлекает дату из уникального ID
    /// - Parameter uniqueID: Уникальный ID
    /// - Returns: Дата создания или nil, если не удалось распарсить
    static func extractDate(from uniqueID: String) -> Date? {
        let components = uniqueID.components(separatedBy: "-")
        guard components.count >= 1 else { return nil }
        
        let dateString = components[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        return dateFormatter.date(from: dateString)
    }
    
    /// Извлекает номер акта из уникального ID
    /// - Parameter uniqueID: Уникальный ID
    /// - Returns: Номер акта или nil
    static func extractAktNumber(from uniqueID: String) -> String? {
        let components = uniqueID.components(separatedBy: "-")
        guard components.count >= 2 else { return nil }
        
        // Номер акта - это все компоненты между датой и случайным суффиксом
        let numberComponents = components.dropFirst().dropLast()
        return numberComponents.joined(separator: "-")
    }
}

// MARK: - AktDuplicateChecker

/// Ошибки при сохранении акта
enum AktSaveError: Error, LocalizedError {
    case duplicateFound(String)
    case potentialDuplicate(date: Date, number: String)
    case saveFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .duplicateFound(let uniqueID):
            return "Акт с таким уникальным ID уже существует: \(uniqueID)"
        case .potentialDuplicate(let date, let number):
            let year = Calendar.current.component(.year, from: date)
            return "Акт с номером \(number) за \(year) год уже существует"
        case .saveFailed(let error):
            return "Ошибка сохранения: \(error.localizedDescription)"
        }
    }
}

/// Менеджер для проверки и предотвращения дубликатов актов
class AktDuplicateChecker {
    
    /// Проверяет, существует ли акт с таким же уникальным ID
    /// - Parameters:
    ///   - uniqueID: Уникальный ID для проверки
    ///   - existingAktIDs: Массив существующих уникальных ID
    /// - Returns: true, если дубликат найден
    static func isDuplicate(uniqueID: String, in existingAktIDs: [String]) -> Bool {
        return existingAktIDs.contains(uniqueID)
    }
    
    /// Проверяет дубликаты по комбинации **года** и номера акта.
    /// В одном году номер акта должен быть уникальным (проверка в разрезе года).
    /// - Parameters:
    ///   - date: Дата акта (используется только год)
    ///   - aktNumber: Номер акта
    ///   - existingAkts: Массив существующих актов
    /// - Returns: true, если найден акт с тем же номером в том же году
    static func hasPotentialDuplicate(
        date: Date,
        aktNumber: String,
        in existingAkts: [AKT]
    ) -> Bool {
        let calendar = Calendar.current
        let targetYear = calendar.component(.year, from: date)
        let normalizedAktNumber = aktNumber
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return existingAkts.contains { existingAkt in
            let existingYear = calendar.component(.year, from: existingAkt.date)
            let existingNormalizedNumber = existingAkt.number
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: "\\", with: "-")
            
            return existingYear == targetYear && existingNormalizedNumber == normalizedAktNumber
        }
    }
    
    /// Генерирует уникальный ID с проверкой на дубликаты
    /// Если дубликат найден, генерирует новый ID с другим случайным суффиксом
    /// - Parameters:
    ///   - date: Дата создания
    ///   - aktNumber: Номер акта
    ///   - existingIDs: Существующие уникальные ID
    ///   - maxAttempts: Максимальное количество попыток генерации (по умолчанию 100)
    /// - Returns: Уникальный ID или nil, если не удалось сгенерировать за maxAttempts попыток
    static func generateUniqueIDWithDuplicateCheck(
        date: Date,
        aktNumber: String,
        existingIDs: [String],
        maxAttempts: Int = 100
    ) -> String? {
        var attempts = 0
        
        while attempts < maxAttempts {
            let uniqueID = AktUniqueIDGenerator.generateUniqueID(
                date: date,
                aktNumber: aktNumber
            )
            
            if !isDuplicate(uniqueID: uniqueID, in: existingIDs) {
                return uniqueID
            }
            
            attempts += 1
        }
        
        // Если не удалось сгенерировать уникальный ID за maxAttempts попыток,
        // добавляем timestamp для гарантированной уникальности
        let timestamp = Int(Date().timeIntervalSince1970 * 1000) % 1000000
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: date)
        let normalizedAktNumber = aktNumber
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
        
        return "\(dateString)-\(normalizedAktNumber)-\(String(format: "%06d", timestamp))"
    }
    
    /// Проверяет акт на дубликаты перед сохранением (по uniqueID и по номеру в разрезе года).
    /// - Parameters:
    ///   - akt: Акт для проверки
    ///   - existingAkts: Массив существующих актов
    /// - Returns: Результат проверки (успех или ошибка)
    static func checkBeforeSave(_ akt: AKT, existingAkts: [AKT]) -> Result<Void, AktSaveError> {
        // Исключаем сам сохраняемый акт (при обновлении по id)
        let others = existingAkts.filter { $0.id != akt.id }
        
        // Проверяем дубликаты по uniqueID среди остальных актов
        let existingUniqueIDs = others.compactMap { $0.uniqueID }
        if let uniqueID = akt.uniqueID, isDuplicate(uniqueID: uniqueID, in: existingUniqueIDs) {
            return .failure(.duplicateFound(uniqueID))
        }
        
        // Проверка по номеру в разрезе одного года: в одном году номер должен быть уникальным
        if hasPotentialDuplicate(date: akt.date, aktNumber: akt.number, in: others) {
            return .failure(.potentialDuplicate(date: akt.date, number: akt.number))
        }
        
        return .success(())
    }
}
