//
//  ViolationModel.swift
//  Gazprom
//
//  Created by Владимир on 08.07.2025.
//

import Foundation
import CoreXLSX
import xlsxwriter

// Lightweight logger shim to ensure compilation if Logger is not linked in target
// Uses simple print in DEBUG builds to avoid target linking issues
fileprivate enum Logger {
    static func debug(_ message: String) {
        #if DEBUG
        print("🔍 [DEBUG] \(message)")
        #endif
    }
    static func info(_ message: String) {
        #if DEBUG
        print("ℹ️ [INFO] \(message)")
        #endif
    }
    static func warning(_ message: String) {
        #if DEBUG
        print("⚠️ [WARNING] \(message)")
        #endif
    }
    static func error(_ message: String) {
        #if DEBUG
        print("❌ [ERROR] \(message)")
        #endif
    }
}

// MARK: - Виды нарушений
public enum ViolationType: String, CaseIterable {
    case trainingIndustrialSafety = "Обучение работников в области производственной безопасности"
    case ppeProvisionAndUse = "Обеспечение работников СИЗ, применении работниками СИЗ"
    case workAtHeight = "Работы на высоте"
    case fireHazardWorks = "Пожароопасные работы"
    case gasHazardWorks = "Газоопасные работы"
    case earthworks = "Земляные работы"
    case loadingUnloadingWorks = "Погрузочно-разгрузочные работы,складирование материалов"
    case toolsAndFixturesOperation = "Эксплуатация инструмента и приспособлений"
    case machinesAndLiftingOperation = "Эксплуатация машин и механизмов, подъёмных сооружений, подъёмных средств, подъёмных механизмов"
    case gasCylindersOperationTransportStorage = "Эксплуатация, перевозка, хранение баллонов с сжиженным газом и газовых баллонов"
    case fireSafety = "Пожарная безопасность"
    case electricalSafety = "Электробезопасность"
    case roadSafetyPassengersCargo = "Безопасность дорожного движения, перевозка пассажиров и грузов"
    case sanitaryAndHouseholdProvision = "Санитарно-бытовое обеспечение"
    case internalControlOrganization = "Организация внутреннего контроля за соблюдением требований производственной безопасности на ОРП"
    case incidentManagementOrganization = "Организация работы с происшествиями (несчастными случаями, авариями, инцидентами, пожарами, транспортными происшествиями)"
    case otherWorks = "Прочие работы"
    
    public var displayName: String {
        return self.rawValue
    }
    
    /// Иконка для типа нарушения
    public var icon: String {
        switch self {
        case .trainingIndustrialSafety:
            return "📚" // Обучение
        case .ppeProvisionAndUse:
            return "🦺" // СИЗ
        case .workAtHeight:
            return "🪜" // Работы на высоте
        case .fireHazardWorks:
            return "🔥" // Пожароопасные работы
        case .gasHazardWorks:
            return "💨" // Газоопасные работы
        case .earthworks:
            return "⛏️" // Земляные работы
        case .loadingUnloadingWorks:
            return "📦" // Погрузка-разгрузка
        case .toolsAndFixturesOperation:
            return "🔧" // Инструменты
        case .machinesAndLiftingOperation:
            return "🏗️" // Машины и механизмы
        case .gasCylindersOperationTransportStorage:
            return "💨" // Баллоны с газом
        case .fireSafety:
            return "🔥" // Пожарная безопасность
        case .electricalSafety:
            return "⚡" // Электробезопасность
        case .roadSafetyPassengersCargo:
            return "🚗" // Дорожное движение
        case .sanitaryAndHouseholdProvision:
            return "🚿" // Санитарно-бытовое
        case .internalControlOrganization:
            return "🚨" // Внутренний контроль
        case .incidentManagementOrganization:
            return "🚨" // Происшествия
        case .otherWorks:
            return "📋" // Прочие работы
        }
    }
}

public class ViolationsModel {
    
    /// Уведомление об изменении реестра нарушений (добавление, обновление, удаление). Подписка на него позволяет обновлять списки без перезапуска приложения.
    public static let violationsDidChangeNotification = Notification.Name("ViolationsModel.violationsDidChange")
    
    // Ключ для отслеживания первого запуска приложения
    private static let firstLaunchKey = "FirstLaunchCompleted"
    
    private static func notifyViolationsDidChange() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: violationsDidChangeNotification, object: nil)
        }
    }
    
    // Проверяем, является ли это первым запуском после установки
    public static func isFirstLaunch() -> Bool {
        return !UserDefaults.standard.bool(forKey: firstLaunchKey)
    }
    
    // Отмечаем, что первый запуск завершен
    public static func markFirstLaunchCompleted() {
        UserDefaults.standard.set(true, forKey: firstLaunchKey)
        // UserDefaults автоматически синхронизируется в iOS, synchronize() не нужен
    }
    
    // Очищаем все данные о нарушениях
    public static func clearViolationsData() {
        UserDefaults.standard.removeObject(forKey: "ImportedExcelFilePath")
        Logger.debug("🧹 Данные о нарушениях очищены")
    }
    
    // Принудительная очистка всех данных при критических ошибках
    public static func forceClearAllDataOnError() {
        Logger.warning("🚨 Принудительная очистка всех данных из-за критических ошибок")
        
        // Очищаем все ключи, связанные с приложением
        let keysToRemove = [
            "ImportedExcelFilePath",
            "FirstLaunchCompleted",
            "DraftAKT",
            "EditableAKT",
            "AKTHistory"
        ]
        
        for key in keysToRemove {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Очищаем все ключи, содержащие большие данные
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        for key in allKeys {
            if let data = UserDefaults.standard.data(forKey: key), data.count > 100000 {
                UserDefaults.standard.removeObject(forKey: key)
                Logger.debug("🗑️ Удален ключ с большими данными: \(key)")
            }
        }
        
        // UserDefaults автоматически синхронизируется в iOS
        
        // Очищаем кэш
        URLCache.shared.removeAllCachedResponses()
        
        Logger.debug("✅ Принудительная очистка завершена")
    }
    
    // Поиск Excel файлов в папке Documents
    public static func findExcelFilesInDocuments() -> [String] {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            Logger.error("Не удалось получить папку Documents")
            return []
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            let excelFiles = files.filter { $0.pathExtension.lowercased() == "xlsx" || $0.pathExtension.lowercased() == "xls" }
            let filePaths = excelFiles.map { $0.path }
            
            Logger.debug("🔍 Найдено Excel файлов в Documents: \(filePaths.count)")
            #if DEBUG
            for filePath in filePaths {
                Logger.debug("   - \(filePath)")
            }
            #endif
            
            return filePaths
        } catch {
            Logger.error("Ошибка поиска файлов в Documents: \(error)")
            return []
        }
    }
    
    // Автоматический поиск и установка пути к Excel файлу
    public static func autoFindAndSetExcelPath() -> Bool {
        let excelFiles = findExcelFilesInDocuments()
        
        // Ищем файл с именем "Реестр нарушений" (без учета номера версии)
        if let reestrFile = excelFiles.first(where: { $0.contains("Реестр нарушений") && !$0.contains(" 2") && !$0.contains(" 3") }) {
            // Проверяем, что файл можно открыть
            if validateExcelFile(at: reestrFile) {
                UserDefaults.standard.set(reestrFile, forKey: "ImportedExcelFilePath")
                Logger.debug("✅ Автоматически найден основной файл реестра: \(reestrFile)")
                return true
            }
        }
        
        // Если не найден основной файл, ищем любой файл с "Реестр нарушений"
        if let reestrFile = excelFiles.first(where: { $0.contains("Реестр нарушений") }) {
            if validateExcelFile(at: reestrFile) {
                UserDefaults.standard.set(reestrFile, forKey: "ImportedExcelFilePath")
                Logger.debug("✅ Автоматически найден файл реестра: \(reestrFile)")
                return true
            }
        }
        
        // Если не найден специфический файл, берем первый валидный Excel файл
        for excelFile in excelFiles {
            if validateExcelFile(at: excelFile) {
                UserDefaults.standard.set(excelFile, forKey: "ImportedExcelFilePath")
                Logger.debug("✅ Автоматически установлен первый валидный Excel файл: \(excelFile)")
                return true
            }
        }
        
        Logger.warning("Валидные Excel файлы не найдены в папке Documents")
        return false
    }
    
    // Валидация Excel файла
    private static func validateExcelFile(at path: String) -> Bool {
        guard FileManager.default.fileExists(atPath: path) else {
            Logger.error("Файл не существует: \(path)")
            return false
        }
        
        // Проверяем размер файла
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: path)
            if let fileSize = attributes[.size] as? NSNumber {
                let sizeInMB = fileSize.doubleValue / (1024 * 1024)
                if sizeInMB > 50 { // 50MB лимит
                    Logger.error("Файл слишком большой: \(sizeInMB)MB")
                    return false
                }
            }
        } catch {
            Logger.error("Ошибка проверки атрибутов файла: \(error)")
            return false
        }
        
        // Проверяем, что файл можно открыть
        guard let file = XLSXFile(filepath: path) else {
            Logger.error("Не удалось открыть Excel файл: \(path)")
            return false
        }
        
        // Проверяем, что файл содержит данные
        do {
            let worksheetPaths = try file.parseWorksheetPaths()
            if worksheetPaths.isEmpty {
                Logger.error("Excel файл не содержит листов: \(path)")
                return false
            }
        } catch {
            Logger.error("Ошибка чтения Excel файла: \(error)")
            return false
        }
        
        return true
    }
    
    // Принудительная очистка всех данных (для тестирования или сброса)
    public static func forceClearAllData() {
        clearViolationsData()
        UserDefaults.standard.removeObject(forKey: firstLaunchKey)
        Logger.debug("🔄 Все данные приложения сброшены")
    }
    
    // Проверяем, нужно ли показать уведомление о необходимости импорта
    public static func shouldShowImportNotification() -> Bool {
        return isFirstLaunch() || UserDefaults.standard.string(forKey: "ImportedExcelFilePath") == nil
    }
    
    /// Возвращает следующий порядковый номер для нового нарушения (максимальный в реестре + 1).
    /// Используется при переносе нарушения из акта в базу.
    public static func nextViolationNumber() -> Int {
        let all = returnAvailableViolation()
        let maxNumber = all.compactMap { $0.number }.max() ?? 0
        return maxNumber + 1
    }
    
    public static func returnAvailableViolation() -> [Violation] {
        // Сначала пытаемся получить путь из UserDefaults
        var currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
        
        // Если путь потерян, пробуем найти файл автоматически (например, после очистки UserDefaults)
        if currentPath == nil {
            Logger.warning("Путь к Excel не найден в UserDefaults. Пытаемся восстановить автоматически...")
            if autoFindAndSetExcelPath() {
                currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath")
                if let restoredPath = currentPath {
                    Logger.info("✅ Путь к Excel восстановлен автоматически: \(restoredPath)")
                }
            }
        }
        
        // Если путь так и не найден — возвращаем пустой массив, но не очищаем ключ
        guard let path = currentPath else {
            if isFirstLaunch() {
                Logger.info("Первый запуск приложения - нарушения не загружены, требуется импорт")
            } else {
                Logger.warning("Путь не найден в UserDefaults даже после авто-поиска — требуется импорт")
            }
            return []
        }
        
        // Если файл найден, отмечаем, что первый запуск завершен
        if isFirstLaunch() {
            markFirstLaunchCompleted()
            Logger.debug("✅ Первый запуск завершен, файл найден: \(path)")
        }
        
        Logger.debug("🔍 Путь к файлу: \(path)")
        Logger.debug("🔍 Файл существует: \(FileManager.default.fileExists(atPath: path))")
        
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: path) else {
            Logger.error("Файл не существует по пути: \(path)")
            
            // Пытаемся найти файл автоматически перед очисткой пути
            Logger.debug("🔄 Пытаемся найти файл автоматически...")
            if autoFindAndSetExcelPath() {
                // Если файл найден автоматически, используем новый путь
                if let newPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") {
                    Logger.debug("✅ Файл найден автоматически: \(newPath)")
                    // Рекурсивно вызываем метод с новым путем
                    return returnAvailableViolation()
                }
            }
            
            // ВАЖНО: НЕ очищаем путь автоматически! Это приводит к потере данных при закрытии модальных окон
            // Пользователь должен явно импортировать новый файл если нужно
            // UserDefaults.standard.removeObject(forKey: "ImportedExcelFilePath")
            Logger.warning("⚠️ Файл не найден автоматически - требуется повторный импорт")
            Logger.warning("⚠️ Путь НЕ очищен для предотвращения потери данных")
            return []
        }
        
        guard let file = XLSXFile(filepath: path) else {
            Logger.error("Не удалось открыть Excel-файл по пути: \(path)")
            return []
        }
        
        Logger.debug("✅ Excel-файл успешно открыт")
        
        var violations: [Violation] = []
        
        do {
            guard let sharedStrings = try file.parseSharedStrings() else {
                Logger.warning("SharedStrings не найдены")
                return []
            }
            
            Logger.debug("✅ SharedStrings найдены")
            
            let worksheetPaths = try file.parseWorksheetPaths()
            Logger.debug("🔍 Найдено листов: \(worksheetPaths.count)")
            
            for (index, path) in worksheetPaths.enumerated() {
                Logger.debug("🔍 Обрабатываем лист \(index + 1): \(path)")
                let worksheet = try file.parseWorksheet(at: path)
                let rows = worksheet.data?.rows.dropFirst() ?? []
                
                Logger.debug("🔍 Найдено строк данных: \(rows.count)")
                
                for (rowIndex, row) in rows.enumerated() {
                    let values = row.cells.map { $0.stringValue(sharedStrings) ?? "" }
                    #if DEBUG
                    Logger.debug("📊 Строка \(rowIndex + 1): \(values)")
                    #endif
                    
                    // Проверяем минимальное количество колонок (должно быть 5, но может быть и 6)
                    guard values.count >= 5 else { 
                        Logger.warning("Строка \(rowIndex + 1) содержит недостаточно данных: \(values.count) колонок")
                        continue 
                    }
                    
                    // Дополнительная проверка на пустые значения
                    let number = Int(values[0]) ?? 0
                    let title = values[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let subtitle = values[2].trimmingCharacters(in: .whitespacesAndNewlines)
                    let description = values[3].trimmingCharacters(in: .whitespacesAndNewlines)
                    let vid = values[4].trimmingCharacters(in: .whitespacesAndNewlines)
                    let formulaFromRules = values.count > 5 ? values[5].trimmingCharacters(in: .whitespacesAndNewlines) : ""
                    
                    // Пропускаем строки с пустым заголовком
                    if title.isEmpty {
                        Logger.warning("Строка \(rowIndex + 1) пропущена: пустой заголовок")
                        continue
                    }
                    
                    let violation = Violation(
                        number: number > 0 ? number : nil,
                        title: title,
                        subTitle: subtitle,
                        description: description.isEmpty ? nil : description,
                        vid: vid.isEmpty ? nil : vid,
                        formulaFromRules: formulaFromRules.isEmpty ? nil : formulaFromRules
                    )
                    
                    // Проверяем валидность данных (проверка длины полей)
                    let titleLength = violation.title.count
                    let subtitleLength = violation.subTitle.count
                    let descriptionLength = violation.description?.count ?? 0
                    let vidLength = violation.vid?.count ?? 0
                    
                    // Проверяем, что длина данных не превышает разумные пределы
                    let isValid = titleLength <= 1000 && 
                                 subtitleLength <= 2000 && 
                                 descriptionLength <= 1000 && 
                                 vidLength <= 500
                    
                    if isValid {
                        violations.append(violation)
                        #if DEBUG
                        Logger.debug("✅ Добавлено нарушение: \(violation.title)")
                        #endif
                    } else {
                        Logger.warning("Строка \(rowIndex + 1) пропущена: некорректные данные (превышена длина полей)")
                    }
                }
            }
        } catch {
            Logger.error("Ошибка чтения Excel: \(error)")
            // В случае ошибки пытаемся найти файл автоматически
            if violations.isEmpty {
                Logger.debug("🔄 Пытаемся найти файл автоматически после ошибки...")
                if autoFindAndSetExcelPath() {
                    // Если файл найден, пытаемся загрузить снова
                    if let newPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath"),
                       FileManager.default.fileExists(atPath: newPath) {
                        Logger.debug("✅ Файл найден автоматически, повторная попытка загрузки...")
                        // Рекурсивно вызываем метод с новым путем
                        return returnAvailableViolation()
                    }
                }
                // ВАЖНО: НЕ очищаем путь автоматически! Это приводит к потере данных при закрытии модальных окон
                // Пользователь должен явно импортировать новый файл если нужно
                // Logger.debug("🔄 Очищаем проблемный путь к файлу...")
                // UserDefaults.standard.removeObject(forKey: "ImportedExcelFilePath")
                Logger.warning("⚠️ Ошибка чтения файла, но путь НЕ очищен для предотвращения потери данных")
            }
        }
        
        Logger.info("📊 Итого загружено нарушений: \(violations.count)")
        
        // Сохраняем путь в UserDefaults для надежности (на случай, если он был потерян)
        if let currentPath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath"),
           FileManager.default.fileExists(atPath: currentPath) {
            // Путь уже сохранен и файл существует - все хорошо
        } else if !violations.isEmpty {
            // Если нарушения загружены, но путь не сохранен, пытаемся найти файл
            Logger.debug("⚠️ Нарушения загружены, но путь не сохранен. Пытаемся найти файл...")
            _ = autoFindAndSetExcelPath()
        }
        
        return violations
    }
    
    
    public static func delete(item: Violation) {
        let allViolations = returnAvailableViolation()

        // Удаляем item по всем значениям полей (полное совпадение)
        let filtered = allViolations.filter { violation in
            return !(
                violation.number == item.number &&
                violation.title == item.title &&
                violation.subTitle == item.subTitle &&
                violation.description == item.description &&
                violation.vid == item.vid &&
                violation.formulaFromRules == item.formulaFromRules
            )
        }

        // Получаем путь к файлу (тот же файл, который был импортирован)
        guard let oldFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            Logger.error("❌ Не удалось получить путь к файлу из UserDefaults")
            return
        }
        
        // Проверяем, что файл существует
        guard FileManager.default.fileExists(atPath: oldFilePath) else {
            Logger.error("❌ Файл не существует по пути: \(oldFilePath)")
            return
        }
        
        Logger.debug("💾 Сохраняем изменения в импортированный файл: \(oldFilePath)")

        // Перезаписываем файл (тот же файл, который был импортирован)
        let wb = Workbook(name: oldFilePath)
        let ws = wb.addWorksheet()

        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения", "Формулировка из правил"]
        for (col, value) in headers.enumerated() {
            ws.write(.string(value), [0, col])
        }

        // Запись данных
        for (rowIdx, violation) in filtered.enumerated() {
            let row = rowIdx + 1
            ws.write(.number(Double(violation.number ?? 0)), [row, 0])
            ws.write(.string(violation.title), [row, 1])
            ws.write(.string(violation.subTitle), [row, 2])
            ws.write(.string(violation.description ?? "-"), [row, 3])
            ws.write(.string(violation.vid ?? "-"), [row, 4])
            ws.write(.string(violation.formulaFromRules ?? "-"), [row, 5])
        }

        wb.close()
        
        // Проверяем, что файл действительно сохранен
        if FileManager.default.fileExists(atPath: oldFilePath) {
            Logger.debug("✅ Нарушение удалено. Файл успешно сохранён в импортированный файл: \(oldFilePath)")
        } else {
            Logger.error("❌ Ошибка: файл не найден после сохранения")
        }
        notifyViolationsDidChange()
    }

    
    
    public static func addNewViolation(violation: Violation) {
        // Получаем текущие нарушения
        var allViolations = returnAvailableViolation()
        
        // Добавляем новое нарушение
        allViolations.append(violation)
        
        // Получаем путь к файлу (тот же файл, который был импортирован)
        guard let filePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            Logger.error("❌ Не удалось получить путь к файлу из UserDefaults")
            return
        }
        
        // Проверяем, что файл существует
        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("❌ Файл не существует по пути: \(filePath)")
            return
        }
        
        Logger.debug("💾 Сохраняем изменения в импортированный файл: \(filePath)")
        
        // Создаём новый Excel-файл по этому пути (перезаписывает существующий)
        let wb = Workbook(name: filePath)
        let ws = wb.addWorksheet()
        
        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения", "Формулировка из правил"]
        for (col, header) in headers.enumerated() {
            ws.write(.string(header), [0, col])
        }
        
        // Записываем все нарушения, включая новое
        for (rowIdx, item) in allViolations.enumerated() {
            let row = rowIdx + 1 // Начинаем с 1, предполагая, что 0 — это заголовок

            let number = Double(item.number ?? row)
            let title = item.title
            let subtitle = item.subTitle
            let description = (item.description?.isEmpty ?? true) ? "-" : item.description
            let vid = (item.vid?.isEmpty ?? true) ? "-" : item.vid
            let formulaFromRules = (item.formulaFromRules?.isEmpty ?? true) ? "-" : item.formulaFromRules
            
            #if DEBUG
            Logger.debug("Запись: \(number), \(title), \(subtitle), \(description ?? "nil"), \(vid ?? "nil"), \(formulaFromRules ?? "nil")")
            #endif

            ws.write(.number(number), [row, 0])
            ws.write(.string(title), [row, 1])
            ws.write(.string(subtitle), [row, 2])
            ws.write(.string(description ?? "-"), [row, 3])
            ws.write(.string(vid ?? "-"), [row, 4])
            ws.write(.string(formulaFromRules ?? "-"), [row, 5])
        }

        
        // Сохраняем файл (перезаписывает существующий файл по тому же пути)
        wb.close()
        
        // Проверяем, что файл действительно сохранен
        if FileManager.default.fileExists(atPath: filePath) {
            Logger.debug("✅ Добавлено новое нарушение. Файл успешно сохранён в импортированный файл: \(filePath)")
        } else {
            Logger.error("❌ Ошибка: файл не найден после сохранения")
        }
        notifyViolationsDidChange()
    }
    
    /// Совпадение по ключевым полям (номер, формулировка, ссылка) — для поиска при расхождении опционалов (nil vs "-").
    private static func isSameRow(_ a: Violation, _ b: Violation) -> Bool {
        a.number == b.number && a.title == b.title && a.subTitle == b.subTitle
    }
    
    public static func updateViolation(oldViolation: Violation, newViolation: Violation) {
        // Получаем все нарушения
        var allViolations = returnAvailableViolation()
        
        let exactMatchesCount = allViolations.filter { $0 == oldViolation }.count
        if exactMatchesCount > 0 {
            // Заменяем все точные вхождения (избегаем дубликатов: старая + новая карточка)
            allViolations = allViolations.map { $0 == oldViolation ? newViolation : $0 }
            Logger.debug("Обновлено вхождений нарушения (точное совпадение): \(exactMatchesCount)")
        } else if let index = allViolations.firstIndex(where: { isSameRow($0, oldViolation) }) {
            // Резерв: совпадение по номеру + формулировка + ссылка (если опционалы различаются: nil vs "-")
            allViolations[index] = newViolation
            Logger.debug("Обновлено нарушение по ключевым полям (индекс \(index))")
        } else {
            Logger.error("Не удалось найти нарушение для обновления (ни точного, ни по ключевым полям)")
            return
        }
        
        // Получаем путь к файлу (тот же файл, который был импортирован)
        guard let filePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            Logger.error("❌ Не удалось получить путь к файлу из UserDefaults")
            return
        }
        
        // Проверяем, что файл существует
        guard FileManager.default.fileExists(atPath: filePath) else {
            Logger.error("❌ Файл не существует по пути: \(filePath)")
            return
        }
        
        Logger.debug("💾 Сохраняем изменения в импортированный файл: \(filePath)")
        
        // Перезаписываем файл с обновленными данными (тот же файл, который был импортирован)
        let wb = Workbook(name: filePath)
        let ws = wb.addWorksheet()
        
        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения", "Формулировка из правил"]
        for (col, header) in headers.enumerated() {
            ws.write(.string(header), [0, col])
        }
        
        // Записываем все нарушения
        for (rowIdx, violation) in allViolations.enumerated() {
            let row = rowIdx + 1
            
            let number = Double(violation.number ?? row)
            let title = violation.title
            let subtitle = violation.subTitle
            let description = violation.description?.count ?? 0 <= 0 ? "--" : violation.description
            let vid = violation.vid?.count ?? 0 <= 0 ? "--" : violation.vid
            let formulaFromRules = violation.formulaFromRules?.count ?? 0 <= 0 ? "--" : violation.formulaFromRules
            
            ws.write(.number(number), [row, 0])
            ws.write(.string(title), [row, 1])
            ws.write(.string(subtitle), [row, 2])
            ws.write(.string(description ?? "-"), [row, 3])
            ws.write(.string(vid ?? "-"), [row, 4])
            ws.write(.string(formulaFromRules ?? "-"), [row, 5])
        }
        
        // Сохраняем файл (перезаписывает существующий файл по тому же пути)
        wb.close()
        
        // Проверяем, что файл действительно сохранен
        if FileManager.default.fileExists(atPath: filePath) {
            Logger.debug("✅ Нарушение обновлено. Файл успешно сохранён в импортированный файл: \(filePath)")
        } else {
            Logger.error("❌ Ошибка: файл не найден после сохранения")
        }
        notifyViolationsDidChange()
    }

    
    
    public struct Violation: Equatable {
        public let number: Int?
        public let title: String
        public let subTitle: String
        public let description: String?
        public let vid: String?
        public let formulaFromRules: String?
        
        // Добавляем инициализатор для создания копии с изменениями
        public init(number: Int?, title: String, subTitle: String, description: String?, vid: String?, formulaFromRules: String? = nil) {
            self.number = number
            self.title = title
            self.subTitle = subTitle
            self.description = description
            self.vid = vid
            self.formulaFromRules = formulaFromRules
        }
        
        // Метод для создания обновленной копии
        public func updated(
            number: Int? = nil,
            title: String? = nil,
            subTitle: String? = nil,
            description: String? = nil,
            vid: String? = nil,
            formulaFromRules: String? = nil
        ) -> Violation {
            return Violation(
                number: number ?? self.number,
                title: title ?? self.title,
                subTitle: subTitle ?? self.subTitle,
                description: description ?? self.description,
                vid: vid ?? self.vid,
                formulaFromRules: formulaFromRules ?? self.formulaFromRules
            )
        }
    }
}
