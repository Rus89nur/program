//
//  DataFlow.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation

// MARK: - Editable AKT Management
struct EditableAKT: Codable {
    let id: UUID
    let akt: AKT
    let isEditable: Bool
    let lastModified: Date
    
    init(akt: AKT, isEditable: Bool = true, lastModified: Date = Date()) {
        self.id = akt.id
        self.akt = akt
        self.isEditable = isEditable
        self.lastModified = lastModified
    }
}

class DataFlowAKT {
    
    // MARK: - File Paths
    private static let historyFileName = "AKT.plist"
    private static let editableFileName = "EditableAKT.plist"
    
    // MARK: - Logging Helper
    /// Записывает лог в debug.log в папке Documents приложения (старая система логов)
    /// Публичная функция для использования из других файлов. НЕ используется для debug-mode.
    static func writeDebugLog(_ logDict: [String: Any]) {
        guard let logData = try? JSONSerialization.data(withJSONObject: logDict),
              let newlineData = "\n".data(using: .utf8) else { return }
        let dataToWrite = logData + newlineData
        let fileManager = FileManager.default
        
        // На iOS приложение в песочнице — пишем в Documents (единственное надёжное место)
        guard let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let documentsLogFile = documentsDir.appendingPathComponent("debug.log")
        
        do {
            if fileManager.fileExists(atPath: documentsLogFile.path) {
                let fileHandle = try FileHandle(forWritingTo: documentsLogFile)
                defer { fileHandle.closeFile() }
                fileHandle.seekToEndOfFile()
                fileHandle.write(dataToWrite)
                fileHandle.synchronizeFile()
            } else {
                try dataToWrite.write(to: documentsLogFile, options: .atomic)
            }
        } catch {
            print("❌ [LOG] Ошибка записи в Documents/debug.log: \(error.localizedDescription)")
        }
    }
    
    // #region agent log
    private static let agentLogQueue = DispatchQueue(label: "dataflow.agent_log", qos: .utility)
    private static let agentLogFileName = "agent_debug.log"

    /// Пишет NDJSON-запись в Documents/agent_debug.log (без сетевых запросов, чтобы не блокировать и не зависать при недоступности сервера).
    static func agentIngestLog(location: String, message: String, data: [String: Any], hypothesisId: String, runId: String = "run1") {
        let payload: [String: Any] = [
            "id": "log_\(Int(Date().timeIntervalSince1970 * 1000))_\(String(UUID().uuidString.prefix(8)))",
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "location": location,
            "message": message,
            "data": data,
            "runId": runId,
            "hypothesisId": hypothesisId
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }

        // Только локальный лог; HTTP к 127.0.0.1 отключён — при недоступности сервера возможны зависания
        agentLogQueue.async {
            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
            let logURL = documentsDir.appendingPathComponent(agentLogFileName)
            guard let newline = "\n".data(using: .utf8) else { return }
            let line = body + newline
            do {
                if FileManager.default.fileExists(atPath: logURL.path) {
                    let handle = try FileHandle(forWritingTo: logURL)
                    defer { handle.closeFile() }
                    handle.seekToEndOfFile()
                    handle.write(line)
                } else {
                    try line.write(to: logURL, options: .atomic)
                }
            } catch {
                // не логируем в консоль, чтобы не засорять вывод
            }
        }
    }
    // #endregion

    /// Специальный логгер для debug-mode Cursor.
    /// Пишет NDJSON в Documents/agent_debug.log (доступен через «Файлы» и экран отладки)
    /// и дублирует в `.cursor/debug-29ae0b.log` на Mac при запуске в симуляторе.
    static func agentWriteDebugLog(_ logDict: [String: Any]) {
        guard let logData = try? JSONSerialization.data(withJSONObject: logDict),
              let newlineData = "\n".data(using: .utf8) else {
            return
        }
        let dataToWrite = logData + newlineData
        appendDebugLogData(dataToWrite, fileName: agentLogFileName)
        
        let workspaceLogPath = "/Users/ruslan/Desktop/Program_08_04_2026/.cursor/debug-29ae0b.log"
        let workspaceURL = URL(fileURLWithPath: workspaceLogPath)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: workspaceURL.path) {
            if let handle = try? FileHandle(forWritingTo: workspaceURL) {
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(dataToWrite)
            }
        } else {
            try? dataToWrite.write(to: workspaceURL, options: .atomic)
        }
    }
    
    /// URL файла agent_debug.log в Documents (для просмотра и экспорта из приложения).
    static func getAgentDebugLogFileURL() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let url = documentsDir.appendingPathComponent(agentLogFileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    /// Читает agent_debug.log целиком (NDJSON, по одной записи на строку).
    static func readAgentDebugLogs() -> String {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return ""
        }
        let url = documentsDir.appendingPathComponent(agentLogFileName)
        guard FileManager.default.fileExists(atPath: url.path),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return ""
        }
        return text
    }
    
    /// Объединённый текст debug.log + agent_debug.log для экрана отладки.
    static func readCombinedDebugLogs() -> String {
        var sections: [String] = []
        if let debugPath = getDebugLogPath(), FileManager.default.fileExists(atPath: debugPath),
           let debugText = try? String(contentsOfFile: debugPath, encoding: .utf8),
           !debugText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("=== debug.log ===\n\(debugText)")
        }
        let agentText = readAgentDebugLogs()
        if !agentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append("=== agent_debug.log ===\n\(agentText)")
        }
        if sections.isEmpty {
            return "Логи пока пусты.\n\nВыполните «Загрузить из актов» в разделе «Обучение по фото» или другие действия — записи появятся здесь."
        }
        return sections.joined(separator: "\n\n")
    }
    
    /// Очищает agent_debug.log.
    static func clearAgentDebugLogs() {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = documentsDir.appendingPathComponent(agentLogFileName)
        try? "".write(to: url, atomically: true, encoding: .utf8)
    }
    
    private static func appendDebugLogData(_ data: Data, fileName: String) {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let url = documentsDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { handle.closeFile() }
                handle.seekToEndOfFile()
                handle.write(data)
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    /// URL файла debug.log в папке Documents приложения (для экспорта/шаринга)
    static func getDebugLogFileURL() -> URL? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let url = documentsDir.appendingPathComponent("debug.log")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    
    /// Читает все логи из debug.log файла
    /// - Returns: Массив строк с логами или пустой массив, если файл не найден
    static func readDebugLogs() -> [String] {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [LOG] Не удалось получить путь к Documents директории")
            return []
        }
        
        let logFile = documentsDir.appendingPathComponent("debug.log")
        
        guard FileManager.default.fileExists(atPath: logFile.path) else {
            print("ℹ️ [LOG] Файл логов не найден: \(logFile.path)")
            return []
        }
        
        do {
            let content = try String(contentsOf: logFile, encoding: .utf8)
            // Разделяем по строкам и фильтруем пустые
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            print("✅ [LOG] Прочитано \(lines.count) строк из файла логов")
            return lines
        } catch {
            print("❌ [LOG] Ошибка чтения файла логов: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Получает путь к файлу логов
    /// - Returns: Путь к файлу логов или nil, если не удалось получить
    static func getDebugLogPath() -> String? {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let logFile = documentsDir.appendingPathComponent("debug.log")
        return logFile.path
    }
    
    /// Очищает файл логов
    static func clearDebugLogs() {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [LOG] Не удалось получить путь к Documents директории")
            return
        }
        
        let logFile = documentsDir.appendingPathComponent("debug.log")
        
        guard FileManager.default.fileExists(atPath: logFile.path) else {
            print("ℹ️ [LOG] Файл логов не найден, очистка не требуется")
            return
        }
        
        do {
            try "".write(to: logFile, atomically: true, encoding: .utf8)
            print("✅ [LOG] Файл логов очищен")
        } catch {
            print("❌ [LOG] Ошибка очистки файла логов: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Caching
    private static var cachedAkts: [AKT]? = nil
    private static var lastLoadTime: Date? = nil
    private static let cacheValidityDuration: TimeInterval = 300 // 5 минут для уменьшения частых вызовов
    private static var isLoading = false // Флаг для предотвращения одновременных загрузок
    private static var isMovingToHistory = false // Флаг для предотвращения повторных вызовов moveEditableToHistory
    
    // MARK: - History AKT Management (Read-only)
    static func loadHistoryArrFromFile() -> [AKT]? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get document directory")
            return nil
        }
        let filePath = documentDirectory.appendingPathComponent(historyFileName)
        do {
            let data = try Data(contentsOf: filePath)
            var arr = try JSONDecoder().decode([AKT].self, from: data)
            
            // ИСПРАВЛЕНИЕ: Проверяем и исправляем дубликаты ID при загрузке
            arr = fixDuplicateIDs(in: arr)
            
            // МИГРАЦИЯ: Генерируем uniqueID для старых актов без него
            let existingUniqueIDs = arr.compactMap { $0.uniqueID }
            arr = arr.map { akt in
                if akt.uniqueID == nil {
                    return akt.withGeneratedUniqueID(existingUniqueIDs: existingUniqueIDs)
                }
                return akt
            }
            writeDebugLog(["location": "DataFlowAKT.swift:loadHistoryArrFromFile", "message": "LOAD_HISTORY_FROM_FILE", "data": ["count": arr.count, "numbers": arr.map { $0.number }, "ids": arr.map { $0.id.uuidString }] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "LOAD"])
            return arr
        } catch {
            print("Failed to load or decode history AKT: \(error)")
            return nil
        }
    }
    
    private static func saveHistoryArrToFile(data: Data) throws {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = documentDirectory.appendingPathComponent(historyFileName)
            // ИСПРАВЛЕНИЕ: Используем атомарную запись для предотвращения повреждения файла
            try data.write(to: filePath, options: .atomic)
        } else {
            throw NSError(domain: "SaveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get document directory"])
        }
    }
    
    static func saveHistoryArr(arr: [AKT]) {
        print("💾 [SAVE_HISTORY] НАЧАЛО СОХРАНЕНИЯ ИСТОРИИ АКТОВ")
        print("   📊 Детали для сохранения:")
        print("      Количество актов: \(arr.count)")
        print("      Номера актов: \(arr.map { $0.number })")
        print("      ID актов: \(arr.map { $0.id })")
        
        // ИСПРАВЛЕНИЕ: Обрабатываем дубликаты по ID умнее
        // Если есть несколько актов с одинаковым ID, но разными номерами - это проблема данных
        // Вместо удаления, присваиваем дубликатам новые уникальные ID, чтобы сохранить все акты
        var uniqueByID: [AKT] = []
        var seenIDs: Set<UUID> = []
        
        
        // Проходим массив в прямом порядке, чтобы сохранить порядок актов
        for akt in arr {
            if !seenIDs.contains(akt.id) {
                // ID уникален - добавляем акт как есть
                uniqueByID.append(akt)
                seenIDs.insert(akt.id)
            } else {
                // Найден дубликат по ID - присваиваем новый уникальный ID для сохранения акта
                print("   ⚠️ Обнаружен дубликат по ID: №\(akt.number), ID: \(akt.id.uuidString)")
                print("   🔄 Присваиваем новый уникальный ID для сохранения акта")
                // #region agent log
                DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:saveHistoryArr", "message": "SAVE_HISTORY_DUPLICATE_BY_ID_NEW_UUID", "data": ["akt_number": akt.number, "old_id": akt.id.uuidString] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "E"])
                // #endregion
                // Создаем новый акт с новым уникальным ID, но теми же данными
                let newAkt = AKT(
                    id: UUID(), // Новый уникальный ID
                    number: akt.number,
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
                    realDateCreate: akt.realDateCreate // Сохраняем оригинальную дату создания
                )
                uniqueByID.append(newAkt)
                seenIDs.insert(newAkt.id)
                print("   ✅ Акт №\(akt.number) сохранен с новым ID: \(newAkt.id.uuidString)")
            }
        }
        
        // НОВАЯ ПРОВЕРКА: Удаляем дубликаты по uniqueID (основная проверка)
        var uniqueByUniqueID: [AKT] = []
        var seenUniqueIDs: Set<String> = []
        
        // Сначала обрабатываем акты с uniqueID
        for akt in uniqueByID {
            if let uniqueID = akt.uniqueID {
                if !seenUniqueIDs.contains(uniqueID) {
                    uniqueByUniqueID.append(akt)
                    seenUniqueIDs.insert(uniqueID)
                } else {
                    print("   ⚠️ Обнаружен дубликат по uniqueID: №\(akt.number), uniqueID: \(uniqueID)")
                    print("   🔄 Пропускаем дубликат")
                }
            } else {
                // Если у акта нет uniqueID, генерируем его
                let generatedUniqueID = AktDuplicateChecker.generateUniqueIDWithDuplicateCheck(
                    date: akt.date,
                    aktNumber: akt.number,
                    existingIDs: Array(seenUniqueIDs)
                ) ?? AktUniqueIDGenerator.generateUniqueID(date: akt.date, aktNumber: akt.number)
                
                if !seenUniqueIDs.contains(generatedUniqueID) {
                    let aktWithUniqueID = akt.withGeneratedUniqueID(existingUniqueIDs: Array(seenUniqueIDs))
                    uniqueByUniqueID.append(aktWithUniqueID)
                    seenUniqueIDs.insert(generatedUniqueID)
                } else {
                    print("   ⚠️ Сгенерированный uniqueID уже существует, пропускаем акт №\(akt.number)")
                }
            }
        }
        
        // Удаляем дубликаты по (год, номер): в одном году номер акта должен быть уникальным
        var uniqueByYearNumber: [AKT] = []
        var seenYearNumber: Set<String> = []
        let calendar = Calendar.current
        for akt in uniqueByUniqueID {
            let year = calendar.component(.year, from: akt.date)
            let normalizedNumber = akt.number
                .trimmingCharacters(in: .whitespaces)
                .uppercased()
            let yearNumberKey = "\(year)-\(normalizedNumber)"
            if !seenYearNumber.contains(yearNumberKey) {
                seenYearNumber.insert(yearNumberKey)
                uniqueByYearNumber.append(akt)
            } else {
                print("   ⚠️ Пропущен дубликат по (год, номер): №\(akt.number), год \(year)")
                // #region agent log
                DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:saveHistoryArr", "message": "SAVE_HISTORY_SKIP_YEAR_NUMBER", "data": ["skipped_id": akt.id.uuidString, "skipped_number": akt.number, "year": year, "violations_count": akt.violations.count] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "E"])
                // #endregion
            }
        }
        
        // Удаляем дубликаты по комбинации ID+номер (на случай, если есть акты с одинаковым ID и номером)
        var uniqueAkts: [AKT] = []
        var seenCombinations: Set<String> = []
        
        for akt in uniqueByYearNumber {
            let combination = "\(akt.id.uuidString)-\(akt.number)"
            if !seenCombinations.contains(combination) {
                uniqueAkts.append(akt)
                seenCombinations.insert(combination)
            } else {
                print("   ⚠️ Пропущен дубликат по комбинации ID+номер: №\(akt.number), ID: \(akt.id.uuidString)")
            }
        }
        
        // Детальное логирование для отладки
        if arr.count != uniqueAkts.count {
            print("   🔍 [DEBUG] Детальный анализ обработки дубликатов:")
            print("      Исходное количество: \(arr.count)")
            print("      После обработки: \(uniqueAkts.count)")
            print("      Обработано дубликатов: \(arr.count - uniqueAkts.count)")
            
            // Проверяем, какие акты были обработаны (получили новые ID)
            let originalNumbers = Set(arr.map { $0.number })
            let uniqueNumbers = Set(uniqueAkts.map { $0.number })
            let processedNumbers = originalNumbers.subtracting(uniqueNumbers)
            
            if !processedNumbers.isEmpty {
                print("      🔄 Номера актов, которым присвоены новые ID: \(Array(processedNumbers).sorted())")
                
                // Проверяем, почему они были обработаны
                for processedNumber in processedNumbers {
                    let processedAkts = arr.filter { $0.number == processedNumber }
                    print("      🔍 Акт №\(processedNumber):")
                    for processedAkt in processedAkts {
                        let combination = "\(processedAkt.id.uuidString)-\(processedAkt.number)"
                        let isInSeen = seenCombinations.contains(combination)
                        print("         ID: \(processedAkt.id.uuidString), комбинация: \(combination), в seenCombinations: \(isInSeen)")
                    }
                }
            }
        }
        
        let duplicatesProcessed = arr.count - uniqueAkts.count
        if duplicatesProcessed > 0 {
            print("   ⚠️ Обнаружено дубликатов: \(duplicatesProcessed)")
            print("   🔄 Обработано дубликатов (присвоены новые ID): \(duplicatesProcessed)")
            
            // Проверяем, есть ли акты с одинаковым ID, но разными номерами (это не должно происходить после исправления)
            // Если все еще есть дубликаты по ID, это означает, что они прошли через предыдущую обработку
            // В этом случае присваиваем им новые ID
            let idsWithMultipleNumbers = Dictionary(grouping: uniqueAkts, by: { $0.id })
                .filter { $0.value.count > 1 }
            
            if !idsWithMultipleNumbers.isEmpty {
                print("   ⚠️ Обнаружены акты с одинаковым ID, но разными номерами (после обработки):")
                for (id, akts) in idsWithMultipleNumbers {
                    print("      ID: \(id.uuidString), номера: \(akts.map { $0.number })")
                }
                print("   🔄 Присваиваем новым актам уникальные ID для сохранения всех данных")
                
                // Обрабатываем дубликаты: оставляем первый акт с оригинальным ID, остальным присваиваем новые ID
                var finalUniqueAkts: [AKT] = []
                var finalSeenIDs: Set<UUID> = []
                
                for akt in uniqueAkts {
                    if !finalSeenIDs.contains(akt.id) {
                        // Первый акт с этим ID - оставляем как есть
                        finalUniqueAkts.append(akt)
                        finalSeenIDs.insert(akt.id)
                    } else {
                        // Дубликат по ID - присваиваем новый уникальный ID
                        print("   🔄 Присваиваем новый ID для акта №\(akt.number)")
                        let newAkt = AKT(
                            id: UUID(), // Новый уникальный ID
                            number: akt.number,
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
                            realDateCreate: akt.realDateCreate
                        )
                        finalUniqueAkts.append(newAkt)
                        finalSeenIDs.insert(newAkt.id)
                        print("   ✅ Акт №\(akt.number) сохранен с новым ID: \(newAkt.id.uuidString)")
                    }
                }
                uniqueAkts = finalUniqueAkts
                print("   ✅ Все дубликаты по ID обработаны, сохранено \(uniqueAkts.count) уникальных актов")
            }
        }
        
        // Детальное логирование начала операции
        print("💾 [AKT_ARRAY_SAVE] Начало сохранения истории актов")
        print("   📊 Количество актов (после удаления дубликатов): \(uniqueAkts.count)")
        print("   🔢 Номера актов: \(uniqueAkts.map { $0.number })")
        print("   🆔 ID актов: \(uniqueAkts.map { $0.id.uuidString })")
        print("   📋 Общее количество нарушений: \(uniqueAkts.reduce(0) { $0 + $1.violations.count })")
        print("   🏢 Количество уникальных организаций: \(Set(uniqueAkts.map { $0.organization.title }).count)")
        
        // Измеряем производительность операции
        let startTime = Date()
        do {
            print("   🔄 Кодируем массив в JSON...")
            let data = try JSONEncoder().encode(uniqueAkts)
            print("   ✅ JSON кодирование завершено, размер данных: \(data.count) байт")
            
            print("   🔄 Сохраняем данные в файл...")
            try saveHistoryArrToFile(data: data)
            print("   ✅ Данные сохранены в файл")
            
            // Логируем успешное сохранение каждого акта
            for akt in uniqueAkts {
                print("   💾 [AKT_SAVE] Сохранение акта в историю")
                print("      🔢 Номер: \(akt.number)")
                print("      🆔 ID: \(akt.id.uuidString)")
                print("      📊 Размер файла: \(data.count) байт")
                print("      ✅ Кодирование успешно")
            }
            
            let duration = Date().timeIntervalSince(startTime)
            print("✅ [SAVE_HISTORY] Сохранение истории актов завершено успешно")
            print("   ⏱️ Время выполнения: \(String(format: "%.2f", duration * 1000)) мс")
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            print("❌ [SAVE_HISTORY] Ошибка сохранения истории актов: \(error)")
            print("   ⏱️ Время до ошибки: \(String(format: "%.2f", duration * 1000)) мс")
            print("   📊 Количество актов: \(arr.count)")
            print("   🔢 Номера актов: \(arr.map { $0.number })")
        }
    }
    
    // MARK: - Editable AKT Management
    static func loadEditableAKTFromFile() -> EditableAKT? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get document directory")
            return nil
        }
        let filePath = documentDirectory.appendingPathComponent(editableFileName)
        do {
            let data = try Data(contentsOf: filePath)
            let editableAkt = try JSONDecoder().decode(EditableAKT.self, from: data)
            
            // Детальное логирование загруженного редактируемого акта
            print("📥 [EDITABLE_AKT_LOAD] Редактируемый акт загружен из файла")
            print("   🔢 Номер акта: \(editableAkt.akt.number)")
            print("   🆔 ID акта: \(editableAkt.akt.id.uuidString)")
            print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
            
            // Анализ фотографий
            var totalPhotos = 0
            var totalPhotosSize: Int64 = 0
            var violationsWithPhotos = 0
            var violationsWithoutPhotos = 0
            
            for violation in editableAkt.akt.violations {
                if violation.photo.isEmpty {
                    violationsWithoutPhotos += 1
                } else {
                    violationsWithPhotos += 1
                    totalPhotos += violation.photo.count
                    for photoData in violation.photo {
                        totalPhotosSize += Int64(photoData.count)
                    }
                }
            }
            
            print("   📷 Нарушений с фото: \(violationsWithPhotos)")
            print("   📷 Нарушений без фото: \(violationsWithoutPhotos)")
            print("   📷 Всего фотографий: \(totalPhotos)")
            print("   💾 Размер фотографий: \(formatBytes(totalPhotosSize))")
            print("   📊 Размер файла: \(data.count) байт (\(String(format: "%.2f", Double(data.count) / 1024.0 / 1024.0)) МБ)")
            
            if violationsWithPhotos > 0 && totalPhotos == 0 {
                print("   ⚠️ ВНИМАНИЕ: Обнаружены нарушения с фото, но фотографии пустые!")
            }
            
            return editableAkt
        } catch {
            // Файл отсутствует (Code=260) — нормальная ситуация, когда нет черновика акта; не засоряем консоль
            let ns = error as NSError
            if ns.domain != NSCocoaErrorDomain || ns.code != 260 {
                print("Failed to load editable AKT: \(error)")
            }
            return nil
        }
    }
    
    // MARK: - Helper
    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) Б"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.2f КБ", Double(bytes) / 1024.0)
        } else {
            return String(format: "%.2f МБ", Double(bytes) / (1024.0 * 1024.0))
        }
    }
    
    private static func saveEditableAKTToFile(data: Data) throws {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = documentDirectory.appendingPathComponent(editableFileName)
            // ИСПРАВЛЕНИЕ: Используем атомарную запись для предотвращения повреждения файла
            // .atomic гарантирует, что файл будет записан полностью или не будет записан вообще
            try data.write(to: filePath, options: .atomic)
        } else {
            throw NSError(domain: "SaveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get document directory"])
        }
    }
    
    static func saveEditableAKT(_ editableAkt: EditableAKT) {
        // Детальное логирование начала операции
        print("💾 [EDITABLE_AKT_SAVE] Начало сохранения редактируемого акта")
        print("   🔢 Номер акта: \(editableAkt.akt.number)")
        print("   🆔 ID акта: \(editableAkt.akt.id.uuidString)")
        print("   ✏️ Редактируемый: \(editableAkt.isEditable)")
        print("   📅 Последнее изменение: \(editableAkt.lastModified)")
        print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
        
        // Анализ фотографий перед сохранением
        var totalPhotos = 0
        var totalPhotosSize: Int64 = 0
        var violationsWithPhotos = 0
        var violationsWithoutPhotos = 0
        
        for violation in editableAkt.akt.violations {
            if violation.photo.isEmpty {
                violationsWithoutPhotos += 1
            } else {
                violationsWithPhotos += 1
                totalPhotos += violation.photo.count
                for photoData in violation.photo {
                    totalPhotosSize += Int64(photoData.count)
                }
            }
        }
        
        print("   📷 Нарушений с фото: \(violationsWithPhotos)")
        print("   📷 Нарушений без фото: \(violationsWithoutPhotos)")
        print("   📷 Всего фотографий: \(totalPhotos)")
        print("   💾 Размер фотографий: \(formatBytes(totalPhotosSize))")
        
        do {
            let data = try JSONEncoder().encode(editableAkt)
            try saveEditableAKTToFile(data: data)
            print("✅ Редактируемый АКТ сохранен: №\(editableAkt.akt.number)")
            
            // Логируем успешное сохранение
            print("✅ [EDITABLE_AKT_SAVE] Редактируемый акт сохранен успешно")
            print("   📊 Размер файла: \(data.count) байт (\(String(format: "%.2f", Double(data.count) / 1024.0 / 1024.0)) МБ)")
            print("   ✅ Кодирование успешно")
            
            if totalPhotos > 0 {
                print("   ✅ Фотографии включены в сохранение: \(totalPhotos) шт., размер: \(formatBytes(totalPhotosSize))")
            } else {
                print("   ⚠️ ВНИМАНИЕ: Фотографии отсутствуют в редактируемом акте!")
            }
        } catch {
            print("Failed to encode or save editable AKT: \(error)")
            
            // Логируем ошибку
            print("❌ [EDITABLE_AKT_SAVE] Ошибка сохранения редактируемого акта")
            print("   🔢 Номер акта: \(editableAkt.akt.number)")
            print("   🆔 ID акта: \(editableAkt.akt.id.uuidString)")
            print("   ❌ Ошибка: \(error.localizedDescription)")
        }
    }
    
    static func deleteEditableAKT() {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get document directory")
            print("❌ [EDITABLE_AKT_DELETE] Ошибка получения директории документов")
            return
        }
        let filePath = documentDirectory.appendingPathComponent(editableFileName)
        
        // Проверяем существование файла перед удалением
        guard fileManager.fileExists(atPath: filePath.path) else {
            print("ℹ️ Файл EditableAKT.plist не существует, удаление не требуется")
            print("ℹ️ [EDITABLE_AKT_DELETE] Файл не существует: \(filePath.path)")
            return
        }
        
        // Логируем начало операции удаления
        print("🗑️ [EDITABLE_AKT_DELETE] Начало удаления редактируемого акта")
        print("   📁 Путь к файлу: \(filePath.path)")
        print("   ✅ Файл существует")
        
        do {
            try fileManager.removeItem(at: filePath)
            print("✅ Редактируемый АКТ удален")
            
            // Логируем успешное удаление
            print("✅ [EDITABLE_AKT_DELETE] Редактируемый акт удален успешно")
            print("   📁 Удаленный файл: \(filePath.path)")
        } catch {
            print("❌ Ошибка удаления редактируемого АКТ: \(error)")
            
            // Логируем ошибку
            print("❌ [EDITABLE_AKT_DELETE] Ошибка удаления редактируемого акта")
            print("   📁 Путь к файлу: \(filePath.path)")
            print("   ❌ Ошибка: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save with Duplicate Check
    /// Сохраняет акт с проверкой на дубликаты
    /// - Parameter akt: Акт для сохранения
    /// - Returns: Результат сохранения (успех или ошибка)
    static func saveAktWithDuplicateCheck(_ akt: AKT) -> Result<Void, AktSaveError> {
        // Загружаем все существующие акты
        let existingAkts = loadArr()
        
        // Проверяем дубликаты
        let checkResult = AktDuplicateChecker.checkBeforeSave(akt, existingAkts: existingAkts)
        
        switch checkResult {
        case .success:
            // Если дубликатов нет, добавляем акт в массив и сохраняем
            var updatedAkts = existingAkts
            
            // Проверяем, есть ли уже акт с таким ID (обновление существующего)
            if let index = updatedAkts.firstIndex(where: { $0.id == akt.id }) {
                // Обновляем существующий акт
                updatedAkts[index] = akt
                print("✅ [SAVE_AKT] Обновлен существующий акт №\(akt.number)")
            } else {
                // Добавляем новый акт
                updatedAkts.append(akt)
                print("✅ [SAVE_AKT] Добавлен новый акт №\(akt.number)")
            }
            
            // Сохраняем обновленный массив
            saveArr(arr: updatedAkts)
            return .success(())
            
        case .failure(let error):
            print("❌ [SAVE_AKT] Обнаружен дубликат: \(error.localizedDescription)")
            return .failure(error)
        }
    }
    
    // MARK: - Combined Operations
    static func saveArr(arr: [AKT]) {
        print("💾 [DATAFLOW_AKT] НАЧАЛО СОХРАНЕНИЯ МАССИВА АКТОВ")
        print("   📊 Детали массива:")
        print("      Количество актов: \(arr.count)")
        print("      Номера актов: \(arr.map { $0.number })")
        print("      ID актов: \(arr.map { $0.id })")
        print("      UniqueID актов: \(arr.map { $0.uniqueID ?? "нет" })")
        
        // #region agent log
        do {
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            let payload: [String: Any] = [
                "id": "log_\(nowMs)",
                "timestamp": nowMs,
                "location": "DataFlowAKT.swift:saveArr",
                "message": "saveArr_called",
                "data": [
                    "count": arr.count,
                    "uniqueIDs": arr.map { $0.uniqueID ?? "nil" }
                ],
                "runId": "run1",
                "hypothesisId": "H1"
            ]
            DataFlowAKT.agentWriteDebugLog(payload)
        }
        // #endregion
        
        // Проверяем дубликаты по uniqueID перед сохранением
        var processedArr = arr
        let existingUniqueIDs = arr.compactMap { $0.uniqueID }
        
        // Генерируем uniqueID для актов без него (миграция)
        processedArr = processedArr.map { akt in
            if akt.uniqueID == nil {
                return akt.withGeneratedUniqueID(existingUniqueIDs: existingUniqueIDs)
            }
            return akt
        }
        
        // Проверяем каждый акт на дубликаты
        var finalArr: [AKT] = []
        var seenUniqueIDs: Set<String> = []
        
        for akt in processedArr {
            if let uniqueID = akt.uniqueID {
                if !seenUniqueIDs.contains(uniqueID) {
                    finalArr.append(akt)
                    seenUniqueIDs.insert(uniqueID)
                } else {
                    print("   ⚠️ [DUPLICATE_CHECK] Обнаружен дубликат по uniqueID: №\(akt.number), uniqueID: \(uniqueID)")
                    print("   🔄 Пропускаем дубликат при сохранении")
                }
            } else {
                // Если все еще нет uniqueID (не должно произойти после миграции выше)
                print("   ⚠️ [DUPLICATE_CHECK] Акт без uniqueID: №\(akt.number), генерируем...")
                let newUniqueID = AktUniqueIDGenerator.generateUniqueID(date: akt.date, aktNumber: akt.number)
                let aktWithUniqueID = akt.withGeneratedUniqueID(existingUniqueIDs: Array(seenUniqueIDs))
                finalArr.append(aktWithUniqueID)
                seenUniqueIDs.insert(newUniqueID)
            }
        }
        
        if finalArr.count != arr.count {
            print("   ⚠️ [DUPLICATE_CHECK] Обнаружено дубликатов: \(arr.count - finalArr.count)")
            print("   ✅ После проверки уникальных актов: \(finalArr.count)")
        }
        
        DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:saveArr", "message": "SAVE_ARR_FINAL", "data": ["count": finalArr.count, "numbers": finalArr.map { $0.number }, "ids": finalArr.map { $0.id.uuidString }, "uniqueIDs": finalArr.map { $0.uniqueID ?? "nil" }] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "SAVE"])
        // Сохраняем в историю (read-only)
        print("   🔄 Вызываем saveHistoryArr...")
        saveHistoryArr(arr: finalArr)
        print("   ✅ saveHistoryArr завершен")
        
        // Очищаем кэш при сохранении
        print("   🔄 Очищаем кэш...")
        clearCache()
        print("   ✅ Кэш очищен")
        
        // Автоматическое резервное копирование (в фоновом режиме)
        DispatchQueue.global(qos: .utility).async {
            BackupManager.autoBackupIfNeeded()
        }
        
        print("✅ [DATAFLOW_AKT] Сохранение массива актов завершено")
    }
    
    // MARK: - Cache Management
    static func clearCache() {
        cachedAkts = nil
        lastLoadTime = nil
    }
    
    static func loadArr() -> [AKT] {
        // Проверяем кэш
        if let cached = cachedAkts,
           let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheValidityDuration {
            #if DEBUG
            print("🔍 [DATAFLOW_AKT] Возвращаем данные из кэша: \(cached.count) актов")
            #endif
            
            // ВАЖНО: Проверяем, есть ли редактируемый акт, который нужно синхронизировать с историей
            if let editableAkt = getEditableAKT() {
                print("🔄 [DATAFLOW_AKT] Найден редактируемый акт, синхронизируем с историей")
                return syncEditableAktWithHistory(cached, editableAkt: editableAkt)
            }
            
            return cached
        }
        
        // Предотвращаем одновременные загрузки
        if isLoading {
            #if DEBUG
            print("🔍 [DATAFLOW_AKT] Загрузка уже выполняется, возвращаем кэшированные данные")
            #endif
            return cachedAkts ?? []
        }
        
        isLoading = true
        #if DEBUG
        print("🔍 [DATAFLOW_AKT] Загружаем данные из файла")
        #endif
        
        // Загружаем данные из файла
        let akts = loadHistoryArrFromFile() ?? []
        
        // Сортируем акты по номеру в порядке возрастания (1, 2, 3...)
        let sortedAkts = akts.sorted { akt1, akt2 in
            // Извлекаем числовую часть из номера акта
            let number1 = extractNumberFromString(akt1.number)
            let number2 = extractNumberFromString(akt2.number)
            return number1 < number2
        }
        
        // ВАЖНО: Синхронизируем с редактируемым актом, если он существует
        let finalAkts: [AKT]
        if let editableAkt = getEditableAKT() {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let editableDateStr = dateFormatter.string(from: editableAkt.akt.date)
            print("🔄 [DATAFLOW_AKT] Синхронизируем загруженные данные с редактируемым актом")
            print("   🔢 Номер редактируемого акта: \(editableAkt.akt.number)")
            print("   📅 Дата редактируемого акта: \(editableDateStr)")
            print("   📋 Нарушений в редактируемом акте: \(editableAkt.akt.violations.count)")
            finalAkts = syncEditableAktWithHistory(sortedAkts, editableAkt: editableAkt)
        } else {
            finalAkts = sortedAkts
        }
        
        // Обновляем кэш
        cachedAkts = finalAkts
        lastLoadTime = Date()
        isLoading = false
        
        #if DEBUG
        print("🔍 [DATAFLOW_AKT] Загружено и отсортировано \(finalAkts.count) актов")
        #endif
        
        // #region agent log
        do {
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            let payload: [String: Any] = [
                "id": "log_\(nowMs)",
                "timestamp": nowMs,
                "location": "DataFlowAKT.swift:loadArr",
                "message": "loadArr_returning",
                "data": [
                    "count": finalAkts.count,
                    "numbers": finalAkts.map { $0.number }
                ],
                "runId": "run1",
                "hypothesisId": "H1"
            ]
            DataFlowAKT.agentWriteDebugLog(payload)
        }
        // #endregion
        return finalAkts
    }
    
    // MARK: - Helper Methods
    
    /// Проверяет и исправляет дубликаты ID в массиве актов
    /// Если найдены акты с одинаковым ID, но разными номерами, присваивает дубликатам новые уникальные ID
    /// - Parameter akts: Массив актов для проверки
    /// - Returns: Массив актов с уникальными ID
    static func fixDuplicateIDs(in akts: [AKT]) -> [AKT] {
        print("🔍 [FIX_DUPLICATES] Начинаем проверку дубликатов ID")
        print("   📊 Исходное количество актов: \(akts.count)")
        
        // Группируем акты по ID
        let groupedByID = Dictionary(grouping: akts, by: { $0.id })
        
        // Находим ID с несколькими актами
        let duplicateIDs = groupedByID.filter { $0.value.count > 1 }
        
        if duplicateIDs.isEmpty {
            print("   ✅ Дубликатов ID не найдено")
            return akts
        }
        
        print("   ⚠️ Найдено дубликатов ID: \(duplicateIDs.count)")
        
        var fixedAkts: [AKT] = []
        var seenIDs: Set<UUID> = []
        var fixedCount = 0
        
        // Проходим по всем актам в исходном порядке
        for akt in akts {
            if !seenIDs.contains(akt.id) {
                // Первый акт с этим ID - оставляем как есть
                fixedAkts.append(akt)
                seenIDs.insert(akt.id)
            } else {
                // Дубликат по ID - присваиваем новый уникальный ID
                print("   🔄 Исправляем дубликат: №\(akt.number), ID: \(akt.id.uuidString)")
                
                let newAkt = AKT(
                    id: UUID(), // Новый уникальный ID
                    number: akt.number,
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
                    realDateCreate: akt.realDateCreate
                )
                
                fixedAkts.append(newAkt)
                seenIDs.insert(newAkt.id)
                fixedCount += 1
                
                print("   ✅ Акт №\(akt.number) исправлен, новый ID: \(newAkt.id.uuidString)")
            }
        }
        
        // Если были исправления, сохраняем исправленный массив
        if fixedCount > 0 {
            print("   💾 Сохраняем исправленный массив актов")
            saveHistoryArr(arr: fixedAkts)
            print("   ✅ Исправлено дубликатов: \(fixedCount)")
        }
        
        print("   📊 Финальное количество актов: \(fixedAkts.count)")
        print("✅ [FIX_DUPLICATES] Проверка дубликатов завершена")
        
        return fixedAkts
    }
    
    private static func extractNumberFromString(_ string: String) -> Int {
        // Удаляем все нецифровые символы и извлекаем число
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Int($0) }
        
        // Возвращаем первое найденное число, или 0 если ничего не найдено
        return numbers.first ?? 0
    }
    
    // MARK: - Sync Editable AKT with History
    private static func syncEditableAktWithHistory(_ historyAkts: [AKT], editableAkt: EditableAKT) -> [AKT] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let editableDateStr = dateFormatter.string(from: editableAkt.akt.date)
        print("🔄 [SYNC] Синхронизация редактируемого акта с историей")
        print("   🔢 Номер редактируемого акта: \(editableAkt.akt.number)")
        print("   🆔 ID редактируемого акта: \(editableAkt.akt.id.uuidString)")
        print("   📅 Дата редактируемого акта: \(editableDateStr)")
        print("   🆔 UniqueID редактируемого акта: \(editableAkt.akt.uniqueID ?? "нет")")
        print("   📋 Количество нарушений в редактируемом акте: \(editableAkt.akt.violations.count)")
        print("   📊 Количество актов в истории: \(historyAkts.count)")
        
        var updatedHistory = historyAkts
        
        // ИСПРАВЛЕНИЕ: Приоритет поиска по uniqueID (ПРИОРИТЕТ 1) - это основной идентификатор
        // uniqueID содержит дату и номер, что гарантирует уникальность и предотвращает конфликты
        if let uniqueID = editableAkt.akt.uniqueID, let indexByUniqueID = updatedHistory.firstIndex(where: { $0.uniqueID == uniqueID }) {
            print("   ✅ Найден акт по uniqueID в истории на позиции \(indexByUniqueID)")
            let foundAkt = updatedHistory[indexByUniqueID]
            print("   🆔 UniqueID: \(uniqueID)")
            print("   🔢 Номер найденного акта: \(foundAkt.number)")
            print("   🔢 Номер редактируемого акта: \(editableAkt.akt.number)")
            print("   📋 Количество нарушений в истории: \(foundAkt.violations.count)")
            print("   📋 Количество нарушений в редактируемом акте: \(editableAkt.akt.violations.count)")
            
            // ИСПРАВЛЕНИЕ: Приоритет ВСЕГДА у редактируемого акта, если нарушения изменились
            // Сравниваем нарушения по ID, чтобы определить, были ли изменения
            let violationsCountChanged = editableAkt.akt.violations.count != foundAkt.violations.count
            let editableViolationIds = Set(editableAkt.akt.violations.map { $0.id })
            let historyViolationIds = Set(foundAkt.violations.map { $0.id })
            let violationsChanged = violationsCountChanged || editableViolationIds != historyViolationIds
            
            // ИСПРАВЛЕНИЕ: Если нарушения изменились, ВСЕГДА отдаем приоритет редактируемому акту
            if violationsChanged {
                // Нарушения изменились - ВСЕГДА обновляем историю данными из редактируемого акта
                let mergedAkt = AKT(
                    id: foundAkt.id, // Сохраняем ID из истории
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: foundAkt.realDateCreate,
                    uniqueID: uniqueID
                )
                updatedHistory[indexByUniqueID] = mergedAkt
                print("   ✅ История обновлена данными из редактируемого акта (нарушения изменились)")
                print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
            } else {
                // Нарушения не изменились - проверяем время последнего изменения
                let timeSinceLastEdit = Date().timeIntervalSince(editableAkt.lastModified)
                let editableIsNewer = timeSinceLastEdit < 86400 // 24 часа
                
                if editableIsNewer {
                    // Редактируемый акт новее - обновляем историю
                    let mergedAkt = AKT(
                        id: foundAkt.id, // Сохраняем ID из истории
                        number: editableAkt.akt.number,
                        date: editableAkt.akt.date,
                        comission: editableAkt.akt.comission,
                        organization: editableAkt.akt.organization,
                        objectsCheck: editableAkt.akt.objectsCheck,
                        predstavitelyComission: editableAkt.akt.predstavitelyComission,
                        violations: editableAkt.akt.violations,
                        description: editableAkt.akt.description,
                        actustranenDate: editableAkt.akt.actustranenDate,
                        actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                        actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                        urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                        realDateCreate: foundAkt.realDateCreate,
                        uniqueID: uniqueID
                    )
                    updatedHistory[indexByUniqueID] = mergedAkt
                    print("   ✅ История обновлена данными из редактируемого акта (приоритет у редактируемого акта)")
                    print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
                } else {
                    // История новее и нарушения не изменились - обновляем редактируемый акт данными из истории
                    let updatedEditableAkt = EditableAKT(akt: foundAkt, isEditable: editableAkt.isEditable, lastModified: Date())
                    saveEditableAKT(updatedEditableAkt)
                    print("   🔄 Редактируемый акт обновлен из истории (нарушения не изменились)")
                    print("   ✅ Акт в истории сохранен (приоритет у истории)")
                    print("   📋 Количество нарушений: \(foundAkt.violations.count)")
                }
            }
            
            // Удаляем все дубликаты по uniqueID (если есть)
            let duplicatesByUniqueID = updatedHistory.enumerated().filter { index, akt in
                index != indexByUniqueID && akt.uniqueID == uniqueID
            }
            
            if !duplicatesByUniqueID.isEmpty {
                print("   ⚠️ Обнаружены дубликаты по uniqueID: \(duplicatesByUniqueID.map { "№\($0.element.number)" })")
                for (index, _) in duplicatesByUniqueID.reversed() {
                    updatedHistory.remove(at: index)
                }
                print("   ✅ Дубликаты по uniqueID удалены")
            }
        } else if let indexById = updatedHistory.firstIndex(where: { $0.id == editableAkt.akt.id }) {
            // ПРИОРИТЕТ 2: Поиск по ID (если uniqueID не найден)
            let historyAktAtId = updatedHistory[indexById]
            print("   ✅ Найден акт по ID в истории на позиции \(indexById)")
            if historyAktAtId.number != editableAkt.akt.number {
                // Защита: не перезаписывать один акт другим. Редактируемый считаем новым актом с новым ID.
                let existingUniqueIDs = updatedHistory.compactMap { $0.uniqueID }
                var aktToAdd = editableAkt.akt
                if aktToAdd.uniqueID == nil {
                    aktToAdd = aktToAdd.withGeneratedUniqueID(existingUniqueIDs: existingUniqueIDs)
                }
                let newId = UUID()
                let editableAsNewAkt = AKT(
                    id: newId,
                    number: aktToAdd.number,
                    date: aktToAdd.date,
                    comission: aktToAdd.comission,
                    organization: aktToAdd.organization,
                    objectsCheck: aktToAdd.objectsCheck,
                    predstavitelyComission: aktToAdd.predstavitelyComission,
                    violations: aktToAdd.violations,
                    description: aktToAdd.description,
                    actustranenDate: aktToAdd.actustranenDate,
                    actPredostavlenDate: aktToAdd.actPredostavlenDate,
                    actUtverzdenDate: aktToAdd.actUtverzdenDate,
                    urlAct: aktToAdd.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: aktToAdd.realDateCreate,
                    uniqueID: aktToAdd.uniqueID
                )
                updatedHistory.append(editableAsNewAkt)
                saveEditableAKT(EditableAKT(akt: editableAsNewAkt, isEditable: editableAkt.isEditable, lastModified: Date()))
                print("   ✅ Редактируемый добавлен как новый акт с новым ID (акт №\(historyAktAtId.number) в истории не тронут)")
            } else {
                // Номер совпадает — это тот же акт, обновляем историю
                print("   🔢 Старый номер акта в истории: \(updatedHistory[indexById].number)")
                print("   🔢 Новый номер редактируемого акта: \(editableAkt.akt.number)")
                print("   📋 Количество нарушений в истории: \(updatedHistory[indexById].violations.count)")
                print("   📅 Дата предоставления отчета в истории: \(updatedHistory[indexById].actPredostavlenDate)")
                print("   📅 Дата предоставления отчета в редактируемом акте: \(editableAkt.akt.actPredostavlenDate)")
                
                let historyAkt = updatedHistory[indexById]
                let violationsCountChanged = editableAkt.akt.violations.count != historyAkt.violations.count
                let editableViolationIds = Set(editableAkt.akt.violations.map { $0.id })
                let historyViolationIds = Set(historyAkt.violations.map { $0.id })
                let violationsChanged = violationsCountChanged || editableViolationIds != historyViolationIds
                
                if violationsChanged {
                    updatedHistory[indexById] = editableAkt.akt
                    print("   ✅ История обновлена данными из редактируемого акта (нарушения изменились)")
                    print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
                } else {
                    let timeSinceLastEdit = Date().timeIntervalSince(editableAkt.lastModified)
                    let editableIsNewer = timeSinceLastEdit < 86400
                    if editableIsNewer {
                        updatedHistory[indexById] = editableAkt.akt
                        print("   ✅ История обновлена данными из редактируемого акта (приоритет у редактируемого акта)")
                    } else {
                        updatedHistory[indexById] = historyAkt
                        let updatedEditableAkt = EditableAKT(akt: historyAkt, isEditable: editableAkt.isEditable, lastModified: Date())
                        saveEditableAKT(updatedEditableAkt)
                        print("   🔄 Редактируемый акт обновлен из истории (нарушения не изменились)")
                        print("   ✅ Акт в истории сохранен (приоритет у истории)")
                        print("   📋 Количество нарушений: \(historyAkt.violations.count)")
                    }
                }
                
                let duplicatesByID = updatedHistory.enumerated().filter { index, akt in
                    index != indexById && akt.id == editableAkt.akt.id
                }
                if !duplicatesByID.isEmpty {
                    print("   ⚠️ Обнаружены дубликаты по ID: \(duplicatesByID.map { "№\($0.element.number)" })")
                    for (index, _) in duplicatesByID.reversed() {
                        updatedHistory.remove(at: index)
                    }
                    print("   ✅ Дубликаты по ID удалены")
                }
            }
        } else {
            // ПРИОРИТЕТ 3: Поиск по номеру и году (уникальность номера в разрезе года)
            let calendar = Calendar.current
            let editableYear = calendar.component(.year, from: editableAkt.akt.date)
            
            if let indexByNumberAndDate = updatedHistory.firstIndex(where: { akt in
                akt.number == editableAkt.akt.number &&
                calendar.component(.year, from: akt.date) == editableYear
            }) {
                // Найден акт с тем же номером в том же году
                print("   ✅ Найден акт по номеру и году в истории на позиции \(indexByNumberAndDate)")
                // #region agent log
                let foundAktForLog = updatedHistory[indexByNumberAndDate]
                DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:syncEditableAktWithHistory", "message": "SYNC_MATCH_NUMBER_YEAR", "data": ["editable_id": editableAkt.akt.id.uuidString, "editable_number": editableAkt.akt.number, "found_id": foundAktForLog.id.uuidString, "found_number": foundAktForLog.number, "editable_violations": editableAkt.akt.violations.count, "found_violations": foundAktForLog.violations.count] as [String: Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "A"])
                // #endregion
                let foundAkt = updatedHistory[indexByNumberAndDate]
                print("   🔢 Номер: \(editableAkt.akt.number)")
                print("   📅 Дата: \(dateFormatter.string(from: editableAkt.akt.date))")
                
                // Обновляем акт, сохраняя uniqueID если он есть
                let mergedAkt = AKT(
                    id: foundAkt.id,
                    number: editableAkt.akt.number,
                    date: editableAkt.akt.date,
                    comission: editableAkt.akt.comission,
                    organization: editableAkt.akt.organization,
                    objectsCheck: editableAkt.akt.objectsCheck,
                    predstavitelyComission: editableAkt.akt.predstavitelyComission,
                    violations: editableAkt.akt.violations,
                    description: editableAkt.akt.description,
                    actustranenDate: editableAkt.akt.actustranenDate,
                    actPredostavlenDate: editableAkt.akt.actPredostavlenDate,
                    actUtverzdenDate: editableAkt.akt.actUtverzdenDate,
                    urlAct: editableAkt.akt.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: foundAkt.realDateCreate,
                    uniqueID: editableAkt.akt.uniqueID ?? foundAkt.uniqueID // Сохраняем или генерируем uniqueID
                )
                updatedHistory[indexByNumberAndDate] = mergedAkt
                print("   ✅ Акт обновлен с сохранением ID из истории")
            } else {
                // Акт не найден ни по uniqueID, ни по ID, ни по номеру+дате - проверяем корзину перед добавлением
                let trash = TrashManager.loadTrash()
                let isInTrash = trash.contains(where: { $0.id == editableAkt.akt.id || $0.number == editableAkt.akt.number })
                
                if isInTrash {
                    print("   🗑️ Акт №\(editableAkt.akt.number) находится в корзине, НЕ восстанавливаем в историю")
                    print("   ✅ Акт был удален намеренно, оставляем его удаленным")
                } else {
                    // Убеждаемся, что у акта есть uniqueID перед добавлением
                    var aktToAdd = editableAkt.akt
                    if aktToAdd.uniqueID == nil {
                        let existingUniqueIDs = updatedHistory.compactMap { $0.uniqueID }
                        aktToAdd = aktToAdd.withGeneratedUniqueID(existingUniqueIDs: existingUniqueIDs)
                        print("   🔄 Сгенерирован uniqueID для нового акта: \(aktToAdd.uniqueID ?? "нет")")
                    }
                    print("   ⚠️ Акт №\(editableAkt.akt.number) не найден в истории и не в корзине, добавляем как новый")
                    // #region agent log
                    DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:syncEditableAktWithHistory", "message": "SYNC_APPEND_AS_NEW", "data": ["akt_number": editableAkt.akt.number, "akt_id": editableAkt.akt.id.uuidString, "uniqueID": editableAkt.akt.uniqueID ?? "nil", "history_count": updatedHistory.count] as [String : Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "A"])
                    // #endregion
                    updatedHistory.append(aktToAdd)
                }
            }
        }
        
        // Сортируем акты по номеру
        let sortedHistory = updatedHistory.sorted { akt1, akt2 in
            let number1 = extractNumberFromString(akt1.number)
            let number2 = extractNumberFromString(akt2.number)
            return number1 < number2
        }
        
        print("✅ [SYNC] Синхронизация завершена: \(sortedHistory.count) актов")
        return sortedHistory
    }
    
    // MARK: - New Methods for Editable AKT System
    static func createEditableAKT(from akt: AKT) -> EditableAKT {
        // ИСПРАВЛЕНИЕ: Если есть существующий редактируемый акт
        if let existingEditable = getEditableAKT() {
            // Если открывается тот же акт, который уже редактируется, возвращаем существующий
            if existingEditable.akt.id == akt.id || existingEditable.akt.uniqueID == akt.uniqueID {
                print("ℹ️ [CREATE_EDITABLE] Открывается тот же акт, возвращаем существующий редактируемый акт")
                return existingEditable
            }
            
            // Если открывается другой акт, быстро обновляем историю без полной перезагрузки
            // Используем оптимизированный метод для быстрого обновления одного акта
            updateExistingAktInHistoryFast(existingEditable.akt)
            print("💾 [CREATE_EDITABLE] Существующий редактируемый акт быстро обновлен в истории")
        }
        
        let editableAkt = EditableAKT(akt: akt, isEditable: true)
        saveEditableAKT(editableAkt)
        return editableAkt
    }
    
    static func updateEditableAKT(_ updatedAkt: AKT) {
        // #region agent log
        DataFlowAKT.agentIngestLog(
            location: "DataFlowAKT.swift:updateEditableAKT",
            message: "updateEditableAKT entered",
            data: ["isMainThread": Thread.isMainThread, "violationsCount": updatedAkt.violations.count],
            hypothesisId: "H4",
            runId: "run1"
        )
        // #endregion
        print("🔄 [UPDATE_EDITABLE] НАЧАЛО ОБНОВЛЕНИЯ РЕДАКТИРУЕМОГО АКТА")
        print("   📋 Детали акта для обновления:")
        print("      Номер: \(updatedAkt.number)")
        print("      ID: \(updatedAkt.id)")
        print("      Дата: \(updatedAkt.date)")
        print("      Организация: \(updatedAkt.organization.title)")
        print("      Количество нарушений: \(updatedAkt.violations.count)")
        print("      URL документа: \(updatedAkt.urlToFllACT?.path ?? "нет")")
        
        // Детальное логирование типов нарушений
        print("   📋 ДЕТАЛИ НАРУШЕНИЙ:")
        for (index, violation) in updatedAkt.violations.enumerated() {
            print("      Нарушение \(index + 1):")
            print("         ID: \(violation.id.uuidString)")
            print("         Название: \(violation.title)")
            print("         Тип (vid): '\(violation.vid)'")
            print("         Место: \(violation.mesto)")
        }
        
        
        // Детальное логирование начала операции
        print("🔄 [AKT_UPDATE] Начало обновления редактируемого акта")
        print("   🔢 Номер акта: \(updatedAkt.number)")
        print("   🆔 ID акта: \(updatedAkt.id.uuidString)")
        print("   📋 Количество нарушений: \(updatedAkt.violations.count)")
        print("   👥 Количество комиссии: \(updatedAkt.comission.count)")
        print("   🏢 Количество объектов: \(updatedAkt.objectsCheck.count)")
        print("   👤 Количество представителей: \(updatedAkt.predstavitelyComission.count)")
        
        print("   🔄 Создаем EditableAKT...")
        // ИСПРАВЛЕНИЕ: Обновляем lastModified при каждом сохранении, чтобы редактируемый акт считался новее
        let editableAkt = EditableAKT(akt: updatedAkt, isEditable: true, lastModified: Date())
        print("   ✅ EditableAKT создан")
        print("   📅 Последнее изменение установлено: \(editableAkt.lastModified)")
        
        print("   🔄 Сохраняем EditableAKT...")
        saveEditableAKT(editableAkt)
        print("   ✅ EditableAKT сохранен")
        
        // Логируем успешное обновление
        print("✅ [EDITABLE_AKT_UPDATE] Редактируемый акт обновлен успешно")
        print("   ✏️ Редактируемый: \(editableAkt.isEditable)")
        print("   📅 Последнее изменение: \(editableAkt.lastModified)")
        
        print("✅ [UPDATE_EDITABLE] Обновление редактируемого акта завершено")
    }
    
    static func getEditableAKT() -> EditableAKT? {
        // #region agent log
        DataFlowAKT.agentIngestLog(
            location: "DataFlowAKT.swift:getEditableAKT",
            message: "getEditableAKT entered",
            data: ["isMainThread": Thread.isMainThread],
            hypothesisId: "H4",
            runId: "run1"
        )
        // #endregion
        return loadEditableAKTFromFile()
    }
    
    static func finalizeEditableAKT() -> AKT? {
        guard let editableAkt = loadEditableAKTFromFile() else { return nil }
        
        // Удаляем редактируемый акт
        deleteEditableAKT()
        
        // Возвращаем финальный акт
        return editableAkt.akt
    }
    
    // MARK: - Move from Editable to History
    static func moveEditableToHistory() {
        // ЗАЩИТА ОТ ПОВТОРНЫХ ВЫЗОВОВ
        guard !isMovingToHistory else {
            print("⚠️ [EDITABLE_AKT_MOVE] moveEditableToHistory уже выполняется, пропускаем повторный вызов")
            return
        }
        
        isMovingToHistory = true
        defer { isMovingToHistory = false }
        
        print("🔄 НАЧАЛО ПЕРЕНОСА АКТА В ИСТОРИЮ")
        
        guard let editableAkt = loadEditableAKTFromFile() else { 
            print("⚠️ Нет редактируемого акта для переноса в историю")
            print("⚠️ [EDITABLE_AKT_MOVE] Нет редактируемого акта для переноса в историю")
            return 
        }
        
        // Детальное логирование начала операции
        print("🔄 [EDITABLE_AKT_MOVE] Начало переноса редактируемого акта в историю")
        print("   🔢 Номер акта: \(editableAkt.akt.number)")
        print("   🆔 ID акта: \(editableAkt.akt.id.uuidString)")
        print("   🆔 UniqueID акта: \(editableAkt.akt.uniqueID ?? "нет")")
        print("   📋 Количество нарушений: \(editableAkt.akt.violations.count)")
        print("   👥 Количество комиссии: \(editableAkt.akt.comission.count)")
        print("   🏢 Количество объектов: \(editableAkt.akt.objectsCheck.count)")
        print("   👤 Количество представителей: \(editableAkt.akt.predstavitelyComission.count)")
        
        print("📋 ДЕТАЛИ АКТА ДЛЯ ПЕРЕНОСА:")
        print("   Номер акта: \(editableAkt.akt.number)")
        print("   ID акта: \(editableAkt.akt.id)")
        print("   UniqueID акта: \(editableAkt.akt.uniqueID ?? "нет")")
        print("   Дата проверки: \(editableAkt.akt.date)")
        print("   Дата создания: \(editableAkt.akt.realDateCreate)")
        print("   Количество нарушений: \(editableAkt.akt.violations.count)")
        print("   Количество членов комиссии: \(editableAkt.akt.comission.count)")
        print("   Количество объектов проверки: \(editableAkt.akt.objectsCheck.count)")
        print("   Организация: \(editableAkt.akt.organization.title)")
        
        // Загружаем текущую историю
        var historyArray = loadHistoryArrFromFile() ?? []
        print("📊 ТЕКУЩЕЕ СОСТОЯНИЕ ИСТОРИИ:")
        print("   Количество актов в истории: \(historyArray.count)")
        print("   ID актов в истории: \(historyArray.map { $0.id })")
        print("   Номера актов в истории: \(historyArray.map { $0.number })")
        print("   UniqueID актов в истории: \(historyArray.map { $0.uniqueID ?? "нет" })")
        
        // Логируем текущее состояние истории
        print("📊 [HISTORY_LOAD] Загрузка истории для переноса")
        print("   📊 Количество актов в истории: \(historyArray.count)")
        print("   🔢 Номера актов: \(historyArray.map { $0.number })")
        print("   🆔 ID актов: \(historyArray.map { $0.id.uuidString })")
        print("   🆔 UniqueID актов: \(historyArray.map { $0.uniqueID ?? "нет" })")
        
        // ИСПРАВЛЕНИЕ: Генерируем uniqueID для актов без него перед проверкой дубликатов
        // Это важно для актов, созданных в 2026 году или других актов без uniqueID
        var aktToProcess = editableAkt.akt
        if aktToProcess.uniqueID == nil {
            print("   ⚠️ У редактируемого акта нет uniqueID, генерируем...")
            let existingUniqueIDs = historyArray.compactMap { $0.uniqueID }
            aktToProcess = aktToProcess.withGeneratedUniqueID(existingUniqueIDs: existingUniqueIDs)
            print("   ✅ Сгенерирован uniqueID: \(aktToProcess.uniqueID ?? "нет")")
        }
        
        // ИСПРАВЛЕНИЕ: Сначала проверяем по uniqueID (основная проверка на дубликаты)
        var aktProcessed = false
        if let uniqueID = aktToProcess.uniqueID {
            if let existingIndexByUniqueID = historyArray.firstIndex(where: { $0.uniqueID == uniqueID }) {
                print("🔄 ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО АКТА ПО UNIQUEID:")
                print("   Найден существующий акт с uniqueID \(uniqueID) в позиции \(existingIndexByUniqueID)")
                print("   Старый номер акта в истории: \(historyArray[existingIndexByUniqueID].number)")
                print("   Новый номер редактируемого акта: \(aktToProcess.number)")
                print("   Старый ID: \(historyArray[existingIndexByUniqueID].id.uuidString)")
                print("   Новый ID: \(aktToProcess.id.uuidString)")
                print("   📋 Количество нарушений в редактируемом акте: \(aktToProcess.violations.count)")
                print("   📋 Количество нарушений в истории: \(historyArray[existingIndexByUniqueID].violations.count)")
                
                // Обновляем акт в истории, сохраняя оригинальный ID из истории
                // ВАЖНО: Используем данные из aktToProcess, чтобы сохранить все изменения, включая нарушения
                let existingAkt = historyArray[existingIndexByUniqueID]
                let mergedAkt = AKT(
                    id: existingAkt.id, // Сохраняем оригинальный ID из истории
                    number: aktToProcess.number,
                    date: aktToProcess.date,
                    comission: aktToProcess.comission,
                    organization: aktToProcess.organization,
                    objectsCheck: aktToProcess.objectsCheck,
                    predstavitelyComission: aktToProcess.predstavitelyComission,
                    violations: aktToProcess.violations, // ВАЖНО: Сохраняем все нарушения из редактируемого акта
                    description: aktToProcess.description,
                    actustranenDate: aktToProcess.actustranenDate,
                    actPredostavlenDate: aktToProcess.actPredostavlenDate,
                    actUtverzdenDate: aktToProcess.actUtverzdenDate,
                    urlAct: aktToProcess.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: existingAkt.realDateCreate, // Сохраняем оригинальную дату создания
                    uniqueID: uniqueID // Сохраняем uniqueID
                )
                historyArray[existingIndexByUniqueID] = mergedAkt
                
                // Удаляем все остальные дубликаты по uniqueID (если есть)
                var indicesToRemove: [Int] = []
                for (index, akt) in historyArray.enumerated() {
                    if index != existingIndexByUniqueID && akt.uniqueID == uniqueID {
                        indicesToRemove.append(index)
                    }
                }
                for index in indicesToRemove.reversed() {
                    historyArray.remove(at: index)
                }
                
                print("   ✅ Акт обновлен в истории по uniqueID")
                print("   📋 Нарушений сохранено: \(mergedAkt.violations.count)")
                print("🔄 [AKT_UPDATE] Обновление существующего акта в истории по uniqueID")
                print("   🔢 Номер акта: \(aktToProcess.number)")
                print("   📍 Позиция в массиве: \(existingIndexByUniqueID)")
                print("   🆔 ID: \(mergedAkt.id.uuidString)")
                print("   🆔 UniqueID: \(uniqueID)")
                print("   ✅ Это обновление существующего акта по uniqueID")
                aktProcessed = true
            }
        }
        
        // ИСПРАВЛЕНИЕ: Приоритет поиска по ID над номером
        // ID - это уникальный идентификатор, который не меняется при редактировании
        // Это предотвращает создание дубликатов при изменении номера акта
        // Проверяем по ID только если не нашли по uniqueID
        if !aktProcessed, let existingIndexById = historyArray.firstIndex(where: { $0.id == aktToProcess.id }) {
            // Найден по ID - обновляем существующий акт
            print("🔄 ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО АКТА ПО ID:")
            print("   Найден существующий акт с ID \(aktToProcess.id.uuidString) в позиции \(existingIndexById)")
            print("   Старый номер акта в истории: \(historyArray[existingIndexById].number)")
            print("   Новый номер редактируемого акта: \(aktToProcess.number)")
            print("   📋 Количество нарушений в редактируемом акте: \(aktToProcess.violations.count)")
            print("   📋 Количество нарушений в истории: \(historyArray[existingIndexById].violations.count)")
            
            // Обновляем акт в истории, сохраняя оригинальный uniqueID из истории (если есть)
            // ВАЖНО: Используем данные из aktToProcess, чтобы сохранить все изменения, включая нарушения
            let existingAkt = historyArray[existingIndexById]
            let mergedAkt = AKT(
                id: aktToProcess.id, // Сохраняем ID редактируемого акта
                number: aktToProcess.number,
                date: aktToProcess.date,
                comission: aktToProcess.comission,
                organization: aktToProcess.organization,
                objectsCheck: aktToProcess.objectsCheck,
                predstavitelyComission: aktToProcess.predstavitelyComission,
                violations: aktToProcess.violations, // ВАЖНО: Сохраняем все нарушения из редактируемого акта
                description: aktToProcess.description,
                actustranenDate: aktToProcess.actustranenDate,
                actPredostavlenDate: aktToProcess.actPredostavlenDate,
                actUtverzdenDate: aktToProcess.actUtverzdenDate,
                urlAct: aktToProcess.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: existingAkt.realDateCreate, // Сохраняем оригинальную дату создания
                uniqueID: aktToProcess.uniqueID ?? existingAkt.uniqueID // Сохраняем uniqueID из редактируемого или из истории
            )
            historyArray[existingIndexById] = mergedAkt
            
            // Удаляем все остальные дубликаты по ID (если есть)
            var indicesToRemove: [Int] = []
            for (index, akt) in historyArray.enumerated() {
                if index != existingIndexById && akt.id == aktToProcess.id {
                    indicesToRemove.append(index)
                }
            }
            for index in indicesToRemove.reversed() {
                historyArray.remove(at: index)
            }
            
            print("   ✅ Акт обновлен в истории (номер мог измениться)")
            print("   📋 Нарушений сохранено: \(mergedAkt.violations.count)")
            print("🔄 [AKT_UPDATE] Обновление существующего акта в истории по ID")
            print("   🔢 Номер акта: \(aktToProcess.number)")
            print("   📍 Позиция в массиве: \(existingIndexById)")
            print("   🆔 ID: \(aktToProcess.id.uuidString)")
            print("   🆔 UniqueID: \(mergedAkt.uniqueID ?? "нет")")
            print("   ✅ Это обновление существующего акта по ID")
            aktProcessed = true
        }
        
        // ПРИОРИТЕТ 2: Поиск по ID (если uniqueID не найден)
        // Проверяем по ID только если не нашли по uniqueID
        if !aktProcessed, let existingIndexById = historyArray.firstIndex(where: { $0.id == aktToProcess.id }) {
            // Найден по ID - обновляем существующий акт
            print("🔄 ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО АКТА ПО ID:")
            print("   Найден существующий акт с ID \(aktToProcess.id.uuidString) в позиции \(existingIndexById)")
            let existingAkt = historyArray[existingIndexById]
            let mergedAkt = AKT(
                id: aktToProcess.id,
                number: aktToProcess.number,
                date: aktToProcess.date,
                comission: aktToProcess.comission,
                organization: aktToProcess.organization,
                objectsCheck: aktToProcess.objectsCheck,
                predstavitelyComission: aktToProcess.predstavitelyComission,
                violations: aktToProcess.violations,
                description: aktToProcess.description,
                actustranenDate: aktToProcess.actustranenDate,
                actPredostavlenDate: aktToProcess.actPredostavlenDate,
                actUtverzdenDate: aktToProcess.actUtverzdenDate,
                urlAct: aktToProcess.urlToFllACT ?? URL(fileURLWithPath: ""),
                realDateCreate: existingAkt.realDateCreate,
                uniqueID: aktToProcess.uniqueID ?? existingAkt.uniqueID
            )
            historyArray[existingIndexById] = mergedAkt
            print("   ✅ Акт обновлен по ID")
            aktProcessed = true
        }
        
        // ПРИОРИТЕТ 3: Поиск по номеру + год (уникальность номера в разрезе одного года)
        if !aktProcessed {
            let calendar = Calendar.current
            let aktYear = calendar.component(.year, from: aktToProcess.date)
            
            if let existingIndex = historyArray.firstIndex(where: { akt in
                akt.number == aktToProcess.number &&
                calendar.component(.year, from: akt.date) == aktYear
            }) {
                // Найден акт с тем же номером в том же году — обновляем его (не создаём дубликат)
                print("🔄 ОБНОВЛЕНИЕ СУЩЕСТВУЮЩЕГО АКТА ПО НОМЕРУ И ГОДУ:")
                print("   Найден существующий акт №\(aktToProcess.number) за \(aktYear) год в позиции \(existingIndex)")
                let existingAkt = historyArray[existingIndex]
                
                let mergedAkt = AKT(
                    id: existingAkt.id,
                    number: aktToProcess.number,
                    date: aktToProcess.date,
                    comission: aktToProcess.comission,
                    organization: aktToProcess.organization,
                    objectsCheck: aktToProcess.objectsCheck,
                    predstavitelyComission: aktToProcess.predstavitelyComission,
                    violations: aktToProcess.violations,
                    description: aktToProcess.description,
                    actustranenDate: aktToProcess.actustranenDate,
                    actPredostavlenDate: aktToProcess.actPredostavlenDate,
                    actUtverzdenDate: aktToProcess.actUtverzdenDate,
                    urlAct: aktToProcess.urlToFllACT ?? URL(fileURLWithPath: ""),
                    realDateCreate: existingAkt.realDateCreate,
                    uniqueID: aktToProcess.uniqueID ?? existingAkt.uniqueID
                )
                historyArray[existingIndex] = mergedAkt
                print("   ✅ Акт обновлен с сохранением ID из истории")
                aktProcessed = true
            }
        }
        
        // Добавляем новый акт только если он еще не был обработан
        if !aktProcessed {
            // ИСПРАВЛЕНИЕ: Проверяем, не находится ли акт в корзине перед добавлением
            let trash = TrashManager.loadTrash()
            let isInTrash = trash.contains(where: { $0.id == aktToProcess.id || $0.number == aktToProcess.number })
            
            if isInTrash {
                print("🗑️ АКТ В КОРЗИНЕ, НЕ ДОБАВЛЯЕМ В ИСТОРИЮ:")
                print("   Акт №\(aktToProcess.number) находится в корзине, НЕ добавляем в историю")
                print("   ✅ Акт был удален намеренно, оставляем его удаленным")
                print("   🗑️ Удаляем редактируемый акт, так как он был удален")
                deleteEditableAKT()
                return
            }
            
            // Проверка на дубликат по (год, номер): в одном году номер акта должен быть уникальным
            // Если акт с таким номером в этом году уже есть — обновляем его, не добавляем новый
            let calendar = Calendar.current
            let aktYear = calendar.component(.year, from: aktToProcess.date)
            
            if let duplicateByYearAndNumber = historyArray.first(where: { akt in
                akt.number == aktToProcess.number &&
                calendar.component(.year, from: akt.date) == aktYear &&
                akt.id != aktToProcess.id
            }) {
                print("   ⚠️ Обнаружен акт с тем же номером за \(aktYear) год (другой ID)!")
                print("      Существующий акт: №\(duplicateByYearAndNumber.number), ID: \(duplicateByYearAndNumber.id.uuidString)")
                print("      Редактируемый акт: №\(aktToProcess.number), ID: \(aktToProcess.id.uuidString)")
                print("   🔄 Обновляем существующий акт (не создаём дубликат)...")
                print("   📋 Количество нарушений в редактируемом акте: \(aktToProcess.violations.count)")
                
                if let index = historyArray.firstIndex(where: { $0.id == duplicateByYearAndNumber.id }) {
                    let mergedAkt = AKT(
                        id: duplicateByYearAndNumber.id,
                        number: aktToProcess.number,
                        date: aktToProcess.date,
                        comission: aktToProcess.comission,
                        organization: aktToProcess.organization,
                        objectsCheck: aktToProcess.objectsCheck,
                        predstavitelyComission: aktToProcess.predstavitelyComission,
                        violations: aktToProcess.violations,
                        description: aktToProcess.description,
                        actustranenDate: aktToProcess.actustranenDate,
                        actPredostavlenDate: aktToProcess.actPredostavlenDate,
                        actUtverzdenDate: aktToProcess.actUtverzdenDate,
                        urlAct: aktToProcess.urlToFllACT ?? URL(fileURLWithPath: ""),
                        realDateCreate: duplicateByYearAndNumber.realDateCreate,
                        uniqueID: aktToProcess.uniqueID ?? duplicateByYearAndNumber.uniqueID
                    )
                    historyArray[index] = mergedAkt
                    print("   ✅ Существующий акт обновлен (дубликат по год+номер не создан)")
                    print("   📋 Нарушений сохранено: \(mergedAkt.violations.count)")
                    aktProcessed = true
                }
            }
            
            if !aktProcessed {
                // Проверка на дубликат по uniqueID перед добавлением
                if let uniqueID = aktToProcess.uniqueID, historyArray.contains(where: { $0.uniqueID == uniqueID }) {
                    print("   ⚠️ Обнаружен дубликат по uniqueID: \(uniqueID)")
                    print("   🔄 Пропускаем добавление, так как акт уже существует")
                } else {
                    print("➕ ДОБАВЛЕНИЕ НОВОГО АКТА:")
                    print("   Акт №\(aktToProcess.number) не найден в истории, добавляем как новый")
                    
                    // Логируем добавление нового акта
                    print("➕ [AKT_CREATE] Добавление нового акта в историю")
                    print("   🔢 Номер акта: \(aktToProcess.number)")
                    print("   🆔 ID акта: \(aktToProcess.id.uuidString)")
                    print("   🆔 UniqueID акта: \(aktToProcess.uniqueID ?? "нет")")
                    print("   📋 Количество нарушений: \(aktToProcess.violations.count)")
                    print("   ✅ Это новый акт")
                    print("   📊 Количество в истории до добавления: \(historyArray.count)")
                    
                    // Если акт не найден и нет дубликата по номеру или uniqueID, добавляем как новый
                    historyArray.append(aktToProcess)
                }
            }
        }
        
        print("💾 СОХРАНЕНИЕ ОБНОВЛЕННОЙ ИСТОРИИ:")
        print("   Новое количество актов: \(historyArray.count)")
        
        // СОРТИРУЕМ АКТЫ ПО НОМЕРУ ДЛЯ ПРАВИЛЬНОГО ПОРЯДКА
        print("🔄 Сортируем акты по номеру для правильного порядка...")
        let sortedHistoryArray = historyArray.sorted { akt1, akt2 in
            let number1 = extractNumberFromString(akt1.number)
            let number2 = extractNumberFromString(akt2.number)
            return number1 < number2
        }
        print("   ✅ Акты отсортированы по номеру")
        print("   📊 Порядок после сортировки: \(sortedHistoryArray.map { $0.number })")
        
        // Логируем сортировку
        print("🔄 [ARRAY_UPDATE] Сортировка актов по номеру")
        print("   📊 Количество актов: \(sortedHistoryArray.count)")
        print("   🔢 Порядок после сортировки: \(sortedHistoryArray.map { $0.number })")
        print("   🆔 ID актов: \(sortedHistoryArray.map { $0.id.uuidString })")
        
        // #region agent log
        do {
            let nowMs = Int(Date().timeIntervalSince1970 * 1000)
            let payload: [String: Any] = [
                "id": "log_\(nowMs)",
                "timestamp": nowMs,
                "location": "DataFlowAKT.swift:moveEditableToHistory",
                "message": "moveEditableToHistory_beforeSave",
                "data": [
                    "count": sortedHistoryArray.count,
                    "numbers": sortedHistoryArray.map { $0.number }
                ],
                "runId": "run1",
                "hypothesisId": "H1"
            ]
            DataFlowAKT.agentWriteDebugLog(payload)
        }
        // #endregion
        
        // Сохраняем отсортированную историю
        saveHistoryArr(arr: sortedHistoryArray)
        
        // ОЧИЩАЕМ КЭШ ПОСЛЕ ОБНОВЛЕНИЯ ИСТОРИИ
        print("🔄 Очищаем кэш после обновления истории...")
        clearCache()
        print("✅ Кэш очищен")
        
        print("🗑️ УДАЛЕНИЕ РЕДАКТИРУЕМОГО АКТА:")
        // Удаляем редактируемый акт
        deleteEditableAKT()
        
        // Логируем успешное завершение операции
        print("✅ [EDITABLE_AKT_FINALIZE] Акт успешно перемещен в историю")
        print("   🔢 Номер акта: \(editableAkt.akt.number)")
        print("   🆔 ID акта: \(editableAkt.akt.id.uuidString)")
        print("   📊 Финальное количество в истории: \(sortedHistoryArray.count)")
        print("   🔢 Финальный порядок: \(sortedHistoryArray.map { $0.number })")
        print("   ✅ Операция завершена успешно")
        
        print("✅ АКТ №\(editableAkt.akt.number) УСПЕШНО ПЕРЕМЕЩЕН В ИСТОРИЮ")
        print("   Финальное количество актов в истории: \(sortedHistoryArray.count)")
        print("   Финальный порядок актов: \(sortedHistoryArray.map { $0.number })")
        print("   Финальные ID актов: \(sortedHistoryArray.map { $0.id })")
    }
    
    // MARK: - Replace Editable AKT (for updates)
    static func replaceEditableAKT(with newAkt: AKT) {
        // Удаляем старый редактируемый акт
        deleteEditableAKT()
        
        // Создаем новый редактируемый акт
        _ = createEditableAKT(from: newAkt)
        
        print("✅ Редактируемый АКТ заменен на №\(newAkt.number)")
    }
    
    // MARK: - Fast Update Existing AKT in History (Optimized)
    /// Быстро обновляет один акт в истории без полной перезагрузки массива
    /// Используется при открытии другого акта для сохранения изменений текущего акта
    static func updateExistingAktInHistoryFast(_ updatedAkt: AKT) {
        // Используем кэш, если он есть, иначе загружаем из файла
        var historyArray: [AKT]
        if let cached = cachedAkts {
            historyArray = cached
        } else {
            historyArray = loadHistoryArrFromFile() ?? []
        }
        
        // Ищем акт по uniqueID или ID
        var found = false
        if let uniqueID = updatedAkt.uniqueID, let index = historyArray.firstIndex(where: { $0.uniqueID == uniqueID }) {
            historyArray[index] = updatedAkt
            found = true
        } else if let index = historyArray.firstIndex(where: { $0.id == updatedAkt.id }) {
            historyArray[index] = updatedAkt
            found = true
        }
        
        if found {
            // #region agent log
            DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:updateExistingAktInHistoryFast", "message": "FAST_UPDATE_FOUND", "data": ["akt_number": updatedAkt.number, "akt_id": updatedAkt.id.uuidString] as [String : Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "B"])
            // #endregion
            // Обновляем кэш
            cachedAkts = historyArray
            lastLoadTime = Date()
            
            // Сохраняем в фоне, чтобы не блокировать UI
            DispatchQueue.global(qos: .utility).async {
                saveHistoryArr(arr: historyArray)
            }
        } else {
            // Акт не найден - добавляем в историю
            // #region agent log
            DataFlowAKT.writeDebugLog(["location": "DataFlowAKT.swift:updateExistingAktInHistoryFast", "message": "FAST_UPDATE_APPEND", "data": ["akt_number": updatedAkt.number, "akt_id": updatedAkt.id.uuidString, "history_count": historyArray.count] as [String : Any], "timestamp": Int(Date().timeIntervalSince1970 * 1000), "runId": "run1", "hypothesisId": "B"])
            // #endregion
            historyArray.append(updatedAkt)
            cachedAkts = historyArray
            lastLoadTime = Date()
            
            DispatchQueue.global(qos: .utility).async {
                saveHistoryArr(arr: historyArray)
            }
        }
    }
    
    // MARK: - Update Existing AKT in History
    static func updateExistingAktInHistory(_ updatedAkt: AKT) {
        print("🔄 Обновляем существующий АКТ №\(updatedAkt.number) в истории")
        
        // Загружаем текущую историю
        var historyArray = loadHistoryArrFromFile() ?? []
        
        // ИСПРАВЛЕНИЕ: Ищем сначала по uniqueID, затем по ID, затем по номеру И дате
        var found = false
        
        // 1. Поиск по uniqueID
        if let uniqueID = updatedAkt.uniqueID, let existingIndex = historyArray.firstIndex(where: { $0.uniqueID == uniqueID }) {
            print("   ✅ Найден акт по uniqueID в позиции \(existingIndex)")
            historyArray[existingIndex] = updatedAkt
            found = true
        }
        // 2. Поиск по ID
        else if let existingIndex = historyArray.firstIndex(where: { $0.id == updatedAkt.id }) {
            print("   ✅ Найден акт по ID в позиции \(existingIndex)")
            historyArray[existingIndex] = updatedAkt
            found = true
        }
        // 3. Поиск по номеру и году
        else {
            let calendar = Calendar.current
            let updatedYear = calendar.component(.year, from: updatedAkt.date)
            
            if let existingIndex = historyArray.firstIndex(where: { akt in
                akt.number == updatedAkt.number &&
                calendar.component(.year, from: akt.date) == updatedYear
            }) {
                print("   ✅ Найден акт по номеру и году в позиции \(existingIndex)")
                historyArray[existingIndex] = updatedAkt
                found = true
            }
        }
        
        if found {
            // Сохраняем обновленную историю
            saveHistoryArr(arr: historyArray)
            print("✅ АКТ №\(updatedAkt.number) обновлен в истории")
        } else {
            print("   ⚠️ Акт №\(updatedAkt.number) не найден в истории (по uniqueID, ID или номеру+дате), добавляем как новый")
            // Если акт не найден, добавляем как новый
            historyArray.append(updatedAkt)
            saveHistoryArr(arr: historyArray)
        }
    }
}
