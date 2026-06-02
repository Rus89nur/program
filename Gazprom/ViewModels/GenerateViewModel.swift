//
//  GenerateViewModel.swift
//  Gazprom
//
//  Created by Владимир on 17.07.2025.
//

import Foundation
import UIKit
import ZIPFoundation

class GenerateViewModel {
    
    // Константы для ширины колонок в таблице комиссии
    private static var commissionPositionColumnWidth = 4000  // Ширина колонки должности
    private static var commissionFioColumnWidth = 8000       // Ширина колонки ФИО
    
    // Константы для ширины столбцов подписей комиссии (в сантиметрах * 1000 для Word)
    private static var commissionSignatureNameColumnWidth = 5103    // Должность - 9.0 см
    private static var commissionSignatureEmptyColumnWidth = 425    // Пустой столбец - 0.75 см
    private static var commissionSignatureLineColumnWidth = 4096    // Столбец подписи - 7.23 см
    
    // Константы для ширины колонок в таблице представителей
    private static var representativePositionColumnWidth = 4000  // Ширина колонки должности
    private static var representativeFioColumnWidth = 8000       // Ширина колонки ФИО
    
    // Константы для ширины столбцов таблицы нарушений (в сантиметрах * 1000 для Word)
    private static var violationNumberColumnWidth = 1410        // № п/п - 1.41 см
    private static var violationFormulationColumnWidth = 7570   // Формулировка несоответствия - 7.57 см
    private static var violationDescriptionColumnWidth = 5400   // Формулировка нарушения - 5.4 см
    private static var violationNoteColumnWidth = 2810          // Примечание - 2.81 см
    
    // #region agent log
    // Функция для записи debug логов в NDJSON формате
    private static func debugLog(location: String, message: String, data: [String: Any], hypothesisId: String) {
        let logPath = "/Users/ruslan/Desktop/Рабочие версии/13.12.2025 раб/Gazprom.xcodeproj/.cursor/debug.log"
        
        print("🔍 [DEBUG_LOG] Вызов debugLog: \(message) (hypothesis: \(hypothesisId))")
        
        // Создаем директорию, если её нет
        let logDir = (logPath as NSString).deletingLastPathComponent
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: logDir) {
            do {
                try fileManager.createDirectory(atPath: logDir, withIntermediateDirectories: true, attributes: nil)
                print("🔍 [DEBUG_LOG] Директория создана: \(logDir)")
            } catch {
                print("🔍 [DEBUG_LOG] Ошибка создания директории: \(error.localizedDescription)")
                return
            }
        }
        
        // Преобразуем data в JSON-совместимый формат
        let sanitizedData = sanitizeForJSON(data)
        
        let logEntry: [String: Any] = [
            "sessionId": "debug-session",
            "runId": "run1",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "data": sanitizedData,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000)
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: logEntry, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                if let fileHandle = FileHandle(forWritingAtPath: logPath) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write((jsonString + "\n").data(using: .utf8)!)
                    fileHandle.closeFile()
                } else {
                    // Если файл не существует, создаем его
                    try? jsonString.write(toFile: logPath, atomically: true, encoding: .utf8)
                }
            }
        } catch {
            // Если не удалось сериализовать, просто пропускаем логирование
            print("⚠️ [DEBUG_LOG] Ошибка сериализации JSON: \(error.localizedDescription)")
        }
    }
    
    /// Преобразует значение в JSON-совместимый формат
    /// Преобразует все не-строковые ключи в строки и все не-JSON-совместимые типы в строки
    private static func sanitizeForJSON(_ value: Any) -> Any {
        // Обрабатываем nil
        if value is NSNull {
            return NSNull()
        }
        
        switch value {
        case let dict as [String: Any]:
            return dict.mapValues { sanitizeForJSON($0) }
        case let dict as [AnyHashable: Any]:
            // Преобразуем словари с не-строковыми ключами
            var result: [String: Any] = [:]
            for (key, val) in dict {
                result[String(describing: key)] = sanitizeForJSON(val)
            }
            return result
        case let array as [Any]:
            return array.map { sanitizeForJSON($0) }
        case let url as URL:
            return url.absoluteString
        case let date as Date:
            let formatter = ISO8601DateFormatter()
            return formatter.string(from: date)
        case let nsRange as NSRange:
            return ["location": nsRange.location, "length": nsRange.length]
        case let string as String:
            return string
        case let int as Int:
            return int
        case let double as Double:
            return double
        case let float as Float:
            return Double(float)
        case let bool as Bool:
            return bool
        default:
            // Для всех остальных типов используем строковое представление
            return String(describing: value)
        }
    }
    // #endregion
    
    // Методы для настройки ширины колонок комиссии
    static func setCommissionColumnWidths(positionWidth: Int, fioWidth: Int) {
        commissionPositionColumnWidth = positionWidth
        commissionFioColumnWidth = fioWidth
    }
    
    static func getCommissionColumnWidths() -> (positionWidth: Int, fioWidth: Int) {
        return (commissionPositionColumnWidth, commissionFioColumnWidth)
    }
    
    // Методы для настройки ширины столбцов подписей комиссии
    static func setCommissionSignatureColumnWidths(nameWidth: Int, emptyWidth: Int, lineWidth: Int) {
        commissionSignatureNameColumnWidth = nameWidth
        commissionSignatureEmptyColumnWidth = emptyWidth
        commissionSignatureLineColumnWidth = lineWidth
    }
    
    static func getCommissionSignatureColumnWidths() -> (nameWidth: Int, emptyWidth: Int, lineWidth: Int) {
        return (commissionSignatureNameColumnWidth, commissionSignatureEmptyColumnWidth, commissionSignatureLineColumnWidth)
    }
    
    private static func normalizedJobTitle(_ title: String) -> String {
        guard !title.isEmpty else { return title }
        
        var result = ""
        var firstLetterHandled = false
        
        for character in title {
            guard character.isLetter else {
                result.append(character)
                continue
            }
            
            let characterString = String(character)
            
            if !firstLetterHandled {
                result.append(contentsOf: characterString.uppercased())
                firstLetterHandled = true
                continue
            }
            
            let isOriginallyUppercase = characterString == characterString.uppercased() && characterString != characterString.lowercased()
            if isOriginallyUppercase {
                result.append(character)
            } else {
                result.append(contentsOf: characterString.lowercased())
            }
        }
        
        return result
    }
    
    // Методы для настройки ширины колонок представителей
    static func setRepresentativeColumnWidths(positionWidth: Int, fioWidth: Int) {
        representativePositionColumnWidth = positionWidth
        representativeFioColumnWidth = fioWidth
    }
    
    static func getRepresentativeColumnWidths() -> (positionWidth: Int, fioWidth: Int) {
        return (representativePositionColumnWidth, representativeFioColumnWidth)
    }
    
    // Методы для настройки ширины столбцов таблицы нарушений
    static func setViolationTableColumnWidths(numberWidth: Int, formulationWidth: Int, descriptionWidth: Int, noteWidth: Int) {
        violationNumberColumnWidth = numberWidth
        violationFormulationColumnWidth = formulationWidth
        violationDescriptionColumnWidth = descriptionWidth
        violationNoteColumnWidth = noteWidth
    }
    
    static func getViolationTableColumnWidths() -> (numberWidth: Int, formulationWidth: Int, descriptionWidth: Int, noteWidth: Int) {
        return (violationNumberColumnWidth, violationFormulationColumnWidth, violationDescriptionColumnWidth, violationNoteColumnWidth)
    }
    
    // Функция для очистки старых файлов актов из временной папки
    static func cleanupOldActFiles() {
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory
        
        do {
            let files = try fileManager.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.creationDateKey], options: [])
            let actFiles = files.filter { $0.lastPathComponent.hasPrefix("Акт №") && $0.pathExtension == "docx" }
            
            // Удаляем файлы старше 1 часа
            let oneHourAgo = Date().addingTimeInterval(-3600)
            
            for file in actFiles {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let creationDate = attributes[.creationDate] as? Date,
                   creationDate < oneHourAgo {
                    try fileManager.removeItem(at: file)
                    print("🗑️ Удален старый файл акта: \(file.lastPathComponent)")
                }
            }
        } catch {
            print("⚠️ Ошибка при очистке старых файлов актов: \(error)")
        }
    }
    
    //TODO: -доделать базовую подстановку
    
    func generate(url: URL, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstav: [PredstavitelyComission], datePredostavlen: Date, dateUstranen: Date, utverzdenDate: Date, escaping: @escaping(URL?) -> Void) {
        
        print("🔧 [GENERATE_VIEWMODEL] ========== НАЧАЛО generate ==========")
        print("⚠️ [ERROR_LOG] Generate method called - URL: \(url.path)")
        print("   📋 Входные параметры:")
        print("      URL шаблона: \(url.path)")
        print("      Номер акта: \(aktNumber)")
        print("      Дата проверки: \(date)")
        print("      Количество комиссии: \(comissionPeople.count)")
        print("      Количество организаций: \(organizations.count)")
        print("      Количество объектов: \(objectCheck.count)")
        print("      Количество нарушений: \(violations.count)")
        print("      Количество представителей: \(predstav.count)")
        print("      Длина описания: \(descripUser.count) символов")
        print("      Дата предоставления: \(datePredostavlen)")
        print("      Дата устранения: \(dateUstranen)")
        print("      Дата утверждения: \(utverzdenDate)")

        if url.isFileURL {
            print("   ✅ Файл загружен локально: \(url.lastPathComponent)")
            
            let comissionString = comissionPeople
                .map { "\($0.jobTitle) - \($0.fio)" }
                .joined(separator: ", ")
            
            let predstavString = predstav
                .map { "\($0.jobTitle.prefix(1).lowercased() + $0.jobTitle.dropFirst()) - \($0.fio)" }
                .joined(separator: ", ")
            
            
            let formattedDate = formatData(date: date)
            let ustronenie = formatData(date: dateUstranen)
            let predostavlenie = formatData(date: datePredostavlen)
            let utverzdenFormatDate = formatData(date: utverzdenDate)
            
            // Отладочная информация для дат
            print("📅 Отладочная информация о датах:")
            print("   Дата акта: \(formattedDate)")
            print("   Дата устранения: \(ustronenie)")
            print("   Дата предоставления: \(predostavlenie)")
            print("   Дата утверждения: \(utverzdenFormatDate)")

            let swapData: [String: Any] = [
                "Number": aktNumber,
                "NameObject": objectCheck.first?.title ?? "",
                "Comission": comissionString,
                "DateReview": " \(formattedDate)",
                "ReviewObject": organizations.first?.title ?? "",
                "PoradNum": 0,
                "TitleViolatation": "",
                "ddescpitVi": "",
                "urlDoc": url.absoluteString,
                "Conclusion": descripUser,
                "Pedstav": predstavString,
                "ustranenDate": ustronenie,
                "predostavlenDate": predostavlenie,
                "UtverzderDate": utverzdenFormatDate
            ]
            
            // Дополнительные плейсхолдеры для совместимости
            let additionalPlaceholders: [String: Any] = [
                "poradNum": 0,
                "titleViolatation": "",
                "ddescpitVi": "",
                "urlDoc": url.absoluteString,
                "predostavlenDate": predostavlenie,
                "ustranenDate": ustronenie,
                "utverzderDate": utverzdenFormatDate
            ]
            
            // Объединяем основные и дополнительные плейсхолдеры
            var allPlaceholders = swapData
            for (key, value) in additionalPlaceholders {
                allPlaceholders[key] = value
            }
            
            print(allPlaceholders)

            print("   🔍 Шаг 6: Вызов processDocxTemplate...")
            processDocxTemplate(from: url, with: allPlaceholders, violations: violations, predstav: predstav, comissionPeople: comissionPeople, aktNumber: aktNumber) { resultURL in
                print("   📥 [GENERATE_VIEWMODEL] Callback от processDocxTemplate получен")
                if let finalURL = resultURL {
                    print("   ✅ [GENERATE_VIEWMODEL] Документ с подстановками сохранен: \(finalURL.path)")
                    print("      Файл существует: \(FileManager.default.fileExists(atPath: finalURL.path))")
                    escaping(finalURL)
                } else {
                    print("   ❌ [GENERATE_VIEWMODEL] processDocxTemplate вернул nil")
                    print("      Произошла ошибка при обработке шаблона")
                    print("⚠️ [ERROR_LOG] processDocxTemplate returned nil - check logs above for details")
                    escaping(nil)
                }
                print("   🔧 [GENERATE_VIEWMODEL] ========== КОНЕЦ generate ==========")
            }
        } else {
            print("   ❌ [GENERATE_VIEWMODEL] URL не является файловым URL")
            print("      URL: \(url.absoluteString)")
            print("⚠️ [ERROR_LOG] URL is not file URL: \(url.absoluteString)")
            print("   🔧 [GENERATE_VIEWMODEL] ========== КОНЕЦ generate (неверный URL) ==========")
            escaping(nil)
        }
    }
    
    func processDocxTemplate(from url: URL,
                             with swapData: [String: Any],
                             violations: [Violations],
                             predstav: [PredstavitelyComission],
                             comissionPeople: [ComissionPeople],
                             aktNumber: String,
                             completion: @escaping (URL?) -> Void) {
        print("📄 [PROCESS_DOCX] ========== НАЧАЛО processDocxTemplate ==========")
        print("⚠️ [ERROR_LOG] processDocxTemplate called - URL: \(url.path), aktNumber: \(aktNumber)")
        print("   📋 Входные параметры:")
        print("      URL шаблона: \(url.path)")
        print("      Номер акта: \(aktNumber)")
        print("      Количество нарушений: \(violations.count)")
        print("      Количество представителей: \(predstav.count)")
        print("      Количество комиссии: \(comissionPeople.count)")
        print("      Количество плейсхолдеров: \(swapData.count)")
        
        // Очищаем старые файлы актов перед генерацией нового
        print("   🔍 Шаг 1: Очистка старых файлов...")
        Self.cleanupOldActFiles()
        print("   ✅ Очистка завершена")
        
        let fileManager = FileManager()
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        print("   🔍 Шаг 2: Создание временной директории...")
        print("      Путь: \(tempDir.path)")
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            print("   ✅ Временная директория создана")
            
            print("   🔍 Шаг 3: Распаковка ZIP архива шаблона...")
            try fileManager.unzipItem(at: url, to: tempDir)
            print("   ✅ ZIP архив распакован")
            
            print("   🔍 Шаг 4: Чтение document.xml...")
            let documentXML = tempDir.appendingPathComponent("word/document.xml")
            guard fileManager.fileExists(atPath: documentXML.path) else {
                print("   ❌ [PROCESS_DOCX] Файл document.xml не найден: \(documentXML.path)")
                print("      Проверьте структуру шаблона")
                completion(nil)
                return
            }
            print("   ✅ Файл document.xml найден")
            
            var xmlString = try String(contentsOf: documentXML, encoding: .utf8)
            let xmlSize = xmlString.count
            print("   ✅ document.xml прочитан, размер: \(xmlSize) символов")

            print("   🔍 Шаг 5: Поиск шаблона строки с 'PoradNum'...")
            guard let rowTemplateRange = xmlString.range(
                of: "<w:tr(?:(?!<w:tr).)*?PoradNum(?:(?!<w:tr).)*?</w:tr>",
                options: [.regularExpression]
            ) else {
                print("   ❌ [PROCESS_DOCX] Шаблонная строка с 'PoradNum' не найдена")
                print("      Проверьте, что в шаблоне есть строка с плейсхолдером PoradNum")
                print("      Размер XML: \(xmlSize) символов")
                completion(nil)
                return
            }
            print("   ✅ Шаблонная строка с 'PoradNum' найдена")

            var rowTemplate = String(xmlString[rowTemplateRange])
            
            print("   📋 Шаблон строки найден:")
            print("      Размер шаблона: \(rowTemplate.count) символов")
            // Отладочный вывод: показываем первые 500 символов шаблона для диагностики
            let templatePreview = String(rowTemplate.prefix(500))
            print("      Первые 500 символов:")
            print(templatePreview)
            print("      ...")
            
            // ВАЖНО: Сначала обновляем ширину столбцов в tblGrid (определение сетки таблицы)
            print("   🔍 Шаг 4.1: Обновление ширины столбцов в tblGrid...")
            xmlString = updateTableGridColumnWidths(in: xmlString)
            
            // Затем устанавливаем ширину столбцов в шаблоне строки (чтобы новые строки создавались с правильными ширинами)
            print("   🔍 Шаг 4.2: Вызов setViolationTableColumnWidths для шаблона строки...")
            let rowTemplateBefore = rowTemplate
            rowTemplate = setViolationTableColumnWidths(in: rowTemplate)
            
            // Проверяем, что изменения применились
            let hasChanges = rowTemplate != rowTemplateBefore
            print("   📊 Результат вызова setViolationTableColumnWidths:")
            print("      Изменения применены: \(hasChanges)")
            print("      Размер до: \(rowTemplateBefore.count) символов")
            print("      Размер после: \(rowTemplate.count) символов")
            
            if hasChanges {
                let afterPreview = String(rowTemplate.prefix(500))
                print("      ✅ Шаблон изменен после установки ширины столбцов")
                print("      Первые 500 символов после изменений:")
                print(afterPreview)
                print("      ...")
            } else {
                print("      ❌ КРИТИЧЕСКАЯ ОШИБКА: Шаблон не изменился!")
                print("      Возможно, элементы w:tcW не найдены или не заменены")
            }
            
            var allRows = ""
            
            for (index, violation) in violations.enumerated() {
                var row = rowTemplate
                row = row.replacingOccurrences(of: "PoradNum", with: "\(index + 1)" + ".")
                row = row.replacingOccurrences(of: "TitleViolatation", with: violation.mesto)
                row = row.replacingOccurrences(of: "ddescpitVi", with: violation.title)
                row = row.replacingOccurrences(of: "urlDoc", with: violation.urlToPravilo)
                allRows += row
            }

            xmlString.replaceSubrange(rowTemplateRange, with: allRows)
            
            // ВАЖНО: Обновляем ширину столбцов во ВСЕХ строках таблицы нарушений ПОСЛЕ добавления всех строк
            // Это гарантирует, что все строки (включая заголовок и все добавленные строки) имеют правильные ширины
            print("   🔍 Шаг 4.3: Обновление ширины столбцов во всех строках таблицы нарушений (после добавления строк)...")
            xmlString = updateAllTableRowColumnWidths(in: xmlString)
            
            // Финальная проверка состояния таблицы нарушений
            print("   🔍 Шаг 4.4: Финальная проверка состояния таблицы нарушений...")
            // #region agent log
            do {
                let finalNsString = xmlString as NSString
                let markerText = "В ходе проверки выявлены следующие нарушения:"
                let markerRange = finalNsString.range(of: markerText)
                if markerRange.location != NSNotFound {
                    let searchStartLocation = markerRange.location + markerRange.length
                    let searchRange = NSRange(location: searchStartLocation, length: finalNsString.length - searchStartLocation)
                    let tablePattern = "<w:tbl>(.*?)</w:tbl>"
                    let tableRegex = try NSRegularExpression(pattern: tablePattern, options: [.dotMatchesLineSeparators])
                    let tableMatches = tableRegex.matches(in: xmlString, options: [], range: searchRange)
                    
                    print("      🔍 Найдено таблиц после маркера: \(tableMatches.count)")
                    
                    for tableMatch in tableMatches {
                        let tableRange = tableMatch.range
                        if tableRange.location != NSNotFound {
                            let tableContent = finalNsString.substring(with: tableRange)
                            if tableContent.contains("№ п/п") {
                                print("      📋 Найдена таблица нарушений для финальной проверки")
                                
                                // Проверяем tblW
                                let tblWPattern = "<w:tblW\\s+w:w=\"([0-9]+)\"\\s+w:type=\"dxa\"\\s*/>"
                                if let tblWRegex = try? NSRegularExpression(pattern: tblWPattern) {
                                    let tblWMatches = tblWRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: (tableContent as NSString).length))
                                    let finalTblW = tblWMatches.first.flatMap { $0.numberOfRanges > 1 ? (tableContent as NSString).substring(with: $0.range(at: 1)) : nil } ?? "not found"
                                    print("      📏 ФИНАЛЬНОЕ tblW таблицы нарушений: \(finalTblW)")
                                    
                                    // Проверяем tblLayout
                                    let hasLayoutFixed = tableContent.contains("<w:tblLayout w:type=\"fixed\"")
                                    print("      📏 ФИНАЛЬНЫЙ tblLayout fixed: \(hasLayoutFixed)")
                                    
                                    // Проверяем gridCol
                                    let gridColPattern = "<w:gridCol\\s+w:w=\"([0-9]+)\"\\s*/>"
                                    if let gridColRegex = try? NSRegularExpression(pattern: gridColPattern) {
                                        let gridColMatches = gridColRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: (tableContent as NSString).length))
                                        let gridColValues = gridColMatches.prefix(4).compactMap { match -> String? in
                                            guard match.numberOfRanges > 1 else { return nil }
                                            return (tableContent as NSString).substring(with: match.range(at: 1))
                                        }
                                        print("      📏 ФИНАЛЬНЫЕ gridCol значения: \(gridColValues)")
                                        
                                        // Проверяем w:tcW
                                        let tcWPattern = "<w:tcW\\s+w:w=\"([0-9]+)\"\\s+w:type=\"dxa\"\\s*/>"
                                        if let tcWRegex = try? NSRegularExpression(pattern: tcWPattern) {
                                            let tcWMatches = tcWRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: (tableContent as NSString).length))
                                            let sampleTcWValues = tcWMatches.prefix(8).compactMap { match -> String? in
                                                guard match.numberOfRanges > 1 else { return nil }
                                                return (tableContent as NSString).substring(with: match.range(at: 1))
                                            }
                                            print("      📏 ФИНАЛЬНЫЕ w:tcW значения (первые 8): \(sampleTcWValues)")
                                            print("      📏 ФИНАЛЬНОЕ общее количество w:tcW: \(tcWMatches.count)")
                                            
                                            // Проверяем сумму gridCol
                                            let sumGridCol = gridColValues.compactMap { Int($0) }.reduce(0, +)
                                            print("      📏 Сумма gridCol значений: \(sumGridCol)")
                                            if let tblWInt = Int(finalTblW) {
                                                print("      📏 Соответствие tblW и суммы gridCol: \(tblWInt == sumGridCol ? "✅ СОВПАДАЕТ" : "❌ НЕ СОВПАДАЕТ (tblW=\(tblWInt), сумма=\(sumGridCol))")")
                                            }
                                            
                                            Self.debugLog(
                                                location: "GenerateViewModel.swift:351",
                                                message: "Final state check after all updates",
                                                data: [
                                                    "finalTblW": finalTblW,
                                                    "hasLayoutFixed": hasLayoutFixed,
                                                    "gridColValues": gridColValues,
                                                    "sampleTcWValues": sampleTcWValues,
                                                    "totalTcWCount": tcWMatches.count,
                                                    "sumGridCol": sumGridCol
                                                ],
                                                hypothesisId: "D"
                                            )
                                        }
                                    }
                                }
                                break
                            }
                        }
                    }
                } else {
                    print("      ⚠️ Маркер '\(markerText)' не найден для финальной проверки")
                }
            } catch {
                print("      ❌ Ошибка при финальной проверке: \(error)")
            }
            // #endregion
            
            // Добавляем таблицу с членами комиссии перед представителями
            print("   🔍 Шаг 6: Поиск маркера 'PredVoice' для вставки таблицы комиссии...")
            
            // Ищем маркер в разных вариантах: как простой текст и внутри XML-тегов
            var commissionMarkerRange: Range<String.Index>? = nil
            
            // Сначала ищем как простой текст
            if let range = xmlString.range(of: "PredVoice") {
                commissionMarkerRange = range
                print("   ✅ Маркер 'PredVoice' найден как простой текст")
            } else {
                // Ищем внутри XML-тегов: <w:t>PredVoice</w:t>
                let pattern = "<w:t[^>]*>PredVoice</w:t>"
                if let regex = try? NSRegularExpression(pattern: pattern, options: []),
                   let match = regex.firstMatch(in: xmlString, options: [], range: NSRange(location: 0, length: xmlString.utf16.count)) {
                    let nsRange = match.range
                    if let range = Range(nsRange, in: xmlString) {
                        commissionMarkerRange = range
                        print("   ✅ Маркер 'PredVoice' найден внутри XML-тегов")
                    }
                }
            }
            
            if let commissionMarkerRange = commissionMarkerRange {
                print("   ✅ Маркер 'PredVoice' найден, начинаем формирование таблицы комиссии...")
                print("      Количество членов комиссии: \(comissionPeople.count)")
                
                var commissionTable = "<w:tbl>"

                for (index, person) in comissionPeople.enumerated() {
                    let fullName = person.fio
                    let position = Self.normalizedJobTitle(person.jobTitle)
                    let label = "\(position) — \(fullName)"
                    
                    print("      📝 Обработка члена комиссии \(index + 1)/\(comissionPeople.count): \(label)")

                    let row = """
                    <w:tr>
                      <w:tc>
                        <w:tcPr><w:tcW w:w="\(Self.commissionSignatureNameColumnWidth)" w:type="dxa"/></w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="left"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t>\(label)</w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                      <w:tc>
                        <w:tcPr><w:tcW w:w="\(Self.commissionSignatureEmptyColumnWidth)" w:type="dxa"/></w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="center"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t></w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                      <w:tc>
                        <w:tcPr>
                          <w:tcW w:w="\(Self.commissionSignatureLineColumnWidth)" w:type="dxa"/>
                          <w:vAlign w:val="top"/>
                        </w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="center"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t></w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                    </w:tr>
                    <w:tr>
                      <w:trPr><w:trHeight w:val="280" w:hRule="atLeast"/></w:trPr>
                      <w:tc>
                        <w:tcPr>
                          <w:tcW w:w="\(Self.commissionSignatureNameColumnWidth)" w:type="dxa"/>
                          <w:vAlign w:val="top"/>
                        </w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="left"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t></w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                      <w:tc>
                        <w:tcPr>
                          <w:tcW w:w="\(Self.commissionSignatureEmptyColumnWidth)" w:type="dxa"/>
                          <w:vAlign w:val="top"/>
                        </w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="center"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t></w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                      <w:tc>
                        <w:tcPr>
                          <w:tcW w:w="\(Self.commissionSignatureLineColumnWidth)" w:type="dxa"/>
                          <w:vAlign w:val="top"/>
                          <w:tcBorders>
                            <w:top w:val="single" w:sz="4" w:space="0" w:color="000000"/>
                          </w:tcBorders>
                        </w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="center"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="20"/>
                            </w:rPr>
                            <w:t>(подпись)</w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                    </w:tr>
                    """

                    commissionTable += row
                }

                commissionTable += "</w:tbl>"
                
                print("   ✅ Таблица комиссии сформирована, размер: \(commissionTable.count) символов")
                print("      Количество строк в таблице: \(comissionPeople.count * 2) (по 2 строки на каждого члена)")
                
                // Вставляем только таблицу с членами комиссии
                xmlString.replaceSubrange(commissionMarkerRange, with: commissionTable)
                print("   ✅ Таблица комиссии успешно вставлена в документ")
            } else {
                print("   ❌ [PROCESS_DOCX] Маркер 'PredVoice' не найден в документе!")
                print("      ⚠️ Таблица с подписантами членами комиссии НЕ будет добавлена в акт")
                print("      Проверьте, что в шаблоне документа присутствует маркер 'PredVoice'")
            }

           
            
            print("   🔍 Шаг 7: Поиск шаблона строки с 'tempOne' для фотографий...")
            guard let photoRowRange = xmlString.range(
                of: "<w:tr[^>]*>(?:(?!<\\/w:tr>).)*?tempOne.*?<\\/w:tr>",
                options: [.regularExpression]
            ) else {
                print("   ❌ [PROCESS_DOCX] Не удалось найти шаблон строки с tempOne")
                print("      Проверьте, что в шаблоне есть строка с плейсхолдером tempOne для фотографий")
                completion(nil)
                return
            }
            print("   ✅ Шаблонная строка с 'tempOne' найдена")

            let photoRowTemplate = String(xmlString[photoRowRange])
            var allPhotoRows = ""
            var globalImageIndex = 0
            var relsSnippets = ""
            var violNumb = 0
            var globIndex = 0
            
            print("   📋 Шаблон строки с фотографиями найден, длина: \(photoRowTemplate.count) символов")
            
            print("   🔍 Шаг 8: Подготовка директории для медиа-файлов...")
            let mediaDir = tempDir.appendingPathComponent("word/media")
            if !fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)
                print("      ✅ Директория media создана: \(mediaDir.path)")
            } else {
                print("      ✅ Директория media уже существует: \(mediaDir.path)")
            }

            print("   🔍 Шаг 9: Обработка нарушений и фотографий...")
            print("      Всего нарушений: \(violations.count)")
            var totalPhotos = 0
            for violation in violations {
                totalPhotos += violation.photo.count
            }
            print("      Всего фотографий: \(totalPhotos)")
            
            for (violationIndex, violation) in violations.enumerated() {
                violNumb += 1
                guard !violation.photo.isEmpty else {
                    print("      ⚠️ Нарушение \(violNumb) не содержит фотографий, пропускаем")
                    continue
                }
                globIndex += 1
                print("      📸 Обработка нарушения \(violNumb) (\(violationIndex + 1)/\(violations.count)):")
                print("         Количество фотографий: \(violation.photo.count)")
                var row = photoRowTemplate
                row = row.replacingOccurrences(of: "tempOne", with: "\(globIndex).")
                row = row.replacingOccurrences(of: "tempTwo", with: "\(violNumb).")

                var imageXMLSnippets = ""

                for (photoIndex, photoData) in violation.photo.enumerated() {
                    globalImageIndex += 1
                    print("         🖼️ Обработка фотографии \(photoIndex + 1)/\(violation.photo.count) (глобальный индекс: \(globalImageIndex)):")
                    print("            Размер данных: \(photoData.count) байт (\(photoData.count / 1024) KB)")

                    // 1. Получаем UIImage из Data
                    guard let originalImage = UIImage(data: photoData) else {
                        print("            ❌ Не удалось создать UIImage из данных")
                        continue
                    }
                    print("            ✅ UIImage создан: \(originalImage.size.width)x\(originalImage.size.height)")

                    // 2. Перерисовываем изображение без EXIF
                    let fixedImage = fixImageOrientation(image: originalImage)
                    print("            ✅ Ориентация исправлена: \(fixedImage.size.width)x\(fixedImage.size.height)")

                    // 3. Сжимаем изображение для акта (уже сжато при добавлении, но дополнительно оптимизируем)
                    guard let fixedImageData = compressImageForAct(fixedImage, aggressive: false) else {
                        print("            ❌ Не удалось сжать изображение")
                        continue
                    }
                    print("            ✅ Изображение сжато: \(fixedImageData.count) байт (\(fixedImageData.count / 1024) KB)")

                    // 4. Сохраняем его в файл
                    let imageName = "image\(globalImageIndex).jpg"
                    let imagePath = mediaDir.appendingPathComponent(imageName)
                    do {
                        try fixedImageData.write(to: imagePath)
                        print("            ✅ Файл сохранен: \(imageName)")
                    } catch {
                        print("            ❌ Ошибка сохранения файла \(imageName): \(error)")
                        continue
                    }

                    // 5. Всё остальное остаётся без изменений
                    let relId = "rIdImage\(globalImageIndex)"
                    let relationship = """
                    <Relationship Id="\(relId)" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/\(imageName)"/>
                    """
                    relsSnippets += relationship + "\n"

                    let imageEmbedXML = """
                    <w:r>
                      <w:drawing>
                        <wp:inline>
                          <wp:extent cx="2880000" cy="2880000"/>
                          <wp:effectExtent l="0" t="0" r="0" b="0"/>
                          <wp:docPr id="\(globalImageIndex)" name="Image\(globalImageIndex)"/>
                          <wp:cNvGraphicFramePr>
                            <a:graphicFrameLocks xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" noChangeAspect="1"/>
                          </wp:cNvGraphicFramePr>
                          <a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">
                            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                              <pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                <pic:nvPicPr>
                                  <pic:cNvPr id="0" name="image\(globalImageIndex).jpg"/>
                                  <pic:cNvPicPr/>
                                </pic:nvPicPr>
                                <pic:blipFill>
                                  <a:blip r:embed="\(relId)" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/>
                                  <a:stretch>
                                    <a:fillRect/>
                                  </a:stretch>
                                </pic:blipFill>
                                <pic:spPr>
                                  <a:xfrm>
                                    <a:off x="0" y="0"/>
                                    <a:ext cx="2880000" cy="2880000"/>
                                  </a:xfrm>
                                  <a:prstGeom prst="rect">
                                    <a:avLst/>
                                  </a:prstGeom>
                                </pic:spPr>
                              </pic:pic>
                            </a:graphicData>
                          </a:graphic>
                        </wp:inline>
                      </w:drawing>
                    </w:r>
                    """

                    imageXMLSnippets += imageEmbedXML
                }


                row = row.replacingOccurrences(of: "tempThree", with: imageXMLSnippets)
                allPhotoRows += row
                print("         ✅ Строка для нарушения \(violNumb) сформирована")
            }
            
            print("      ✅ Обработка всех нарушений завершена")
            print("         Всего обработано изображений: \(globalImageIndex)")
            print("         Всего сформировано строк: \(globIndex)")

            print("   🔍 Обновление relationships...")
            //   Обновляем relationships один раз после цикла
            let relsPath = tempDir.appendingPathComponent("word/_rels/document.xml.rels")
            guard fileManager.fileExists(atPath: relsPath.path) else {
                print("   ❌ [PROCESS_DOCX] Файл relationships не найден: \(relsPath.path)")
                completion(nil)
                return
            }
            print("      ✅ Файл relationships найден")
            
            var relsXML = try String(contentsOf: relsPath, encoding: .utf8)
            print("      ✅ relationships прочитан, размер: \(relsXML.count) символов")
            print("      📝 Добавление \(globalImageIndex) relationships для изображений...")
            relsXML = relsXML.replacingOccurrences(of: "</Relationships>", with: relsSnippets + "</Relationships>")
            try relsXML.write(to: relsPath, atomically: true, encoding: .utf8)
            print("      ✅ relationships обновлен и сохранен")

            print("   🔍 Замена шаблона фотографий в document.xml...")
            //   Заменяем в document.xml шаблон одной строки на все строки
            xmlString.replaceSubrange(photoRowRange, with: allPhotoRows)
            print("      ✅ Шаблон заменен, добавлено \(globIndex) строк с фотографиями")

            print("   🔍 Шаг 10: Замена плейсхолдеров в document.xml...")
            print("      Всего плейсхолдеров для замены: \(swapData.count)")
            var replacedCount = 0
            var notFoundCount = 0

            for (key, value) in swapData {
                let placeholder = key
                var replaced = false
                
                // Пробуем разные варианты написания плейсхолдера
                let variants = [
                    placeholder,
                    placeholder.lowercased(),
                    placeholder.uppercased(),
                    placeholder.capitalized,
                    placeholder.replacingOccurrences(of: "Date", with: "date"),
                    placeholder.replacingOccurrences(of: "date", with: "Date")
                ]
                
                for variant in variants {
                    // Используем более агрессивный поиск - ищем плейсхолдер в любом контексте
                    if xmlString.range(of: variant, options: .caseInsensitive) != nil {
                        // Заменяем все вхождения (не только первое)
                        let originalString = xmlString
                        xmlString = xmlString.replacingOccurrences(of: variant, with: "\(value)", options: .caseInsensitive)
                        
                        if xmlString != originalString {
                            print("      ✅ Заменен плейсхолдер '\(variant)' на '\(String(describing: value).prefix(50))'")
                            replaced = true
                            replacedCount += 1
                            break
                        }
                    }
                }
                
                if !replaced {
                    print("      ⚠️ Плейсхолдер '\(placeholder)' не найден в шаблоне")
                    notFoundCount += 1
                    
                    // Дополнительная диагностика для важных плейсхолдеров
                    if placeholder.contains("Date") || placeholder.contains("date") {
                        print("🔍 Ищем варианты '\(placeholder)' в XML:")
                        let lines = xmlString.components(separatedBy: .newlines)
                        for (index, line) in lines.enumerated() {
                            if line.lowercased().contains(placeholder.lowercased()) || 
                               line.lowercased().contains("предоставлен") ||
                               line.lowercased().contains("устранен") ||
                               line.lowercased().contains("утвержден") {
                                print("   Строка \(index + 1): \(line)")
                            }
                        }
                    }
                }
            }
            
            // Дополнительная проверка для всех плейсхолдеров дат
            let datePlaceholders = ["predostavlenDate", "ustranenDate", "UtverzderDate", "utverzderDate"]
            for placeholder in datePlaceholders {
                if xmlString.contains(placeholder) {
                    print("   ⚠️ В шаблоне все еще остался текст '\(placeholder)' - замена не сработала")
                    
                    // Получаем значение из swapData
                    let value: String
                    if placeholder.lowercased() == "predostavlendate" {
                        value = swapData["predostavlenDate"] as? String ?? swapData["predostavlenDate"] as? String ?? ""
                    } else if placeholder.lowercased() == "ustranendate" {
                        value = swapData["ustranenDate"] as? String ?? swapData["ustranenDate"] as? String ?? ""
                    } else if placeholder.lowercased() == "utverzderdate" {
                        value = swapData["UtverzderDate"] as? String ?? swapData["utverzderDate"] as? String ?? ""
                    } else {
                        value = swapData[placeholder] as? String ?? ""
                    }
                    
                    if !value.isEmpty {
                        // Пробуем разные варианты написания с case-insensitive поиском
                        let variants = [
                            placeholder,
                            placeholder.capitalized,
                            placeholder.uppercased(),
                            placeholder.lowercased(),
                            placeholder.replacingOccurrences(of: "Date", with: "date"),
                            placeholder.replacingOccurrences(of: "date", with: "Date")
                        ]
                        
                        var replaced = false
                        for variant in variants {
                            // Используем case-insensitive поиск и замену
                            if xmlString.range(of: variant, options: .caseInsensitive) != nil {
                                let originalString = xmlString
                                xmlString = xmlString.replacingOccurrences(of: variant, with: value, options: .caseInsensitive)
                                
                                if xmlString != originalString {
                                    print("      🔧 Заменен вариант '\(variant)' на '\(value)' (case-insensitive)")
                                    replaced = true
                                    replacedCount += 1
                                    if notFoundCount > 0 {
                                        notFoundCount -= 1
                                    }
                                    break
                                }
                            }
                        }
                        
                        if !replaced {
                            print("      ❌ Не удалось заменить '\(placeholder)' даже после дополнительных попыток")
                            print("      🔍 Пробуем найти через регулярное выражение...")
                            // Последняя попытка - через регулярное выражение
                            do {
                                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: placeholder))\\b"
                                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                                let range = NSRange(location: 0, length: xmlString.utf16.count)
                                if regex.firstMatch(in: xmlString, options: [], range: range) != nil {
                                    xmlString = regex.stringByReplacingMatches(in: xmlString, options: [], range: range, withTemplate: value)
                                    print("      🔧 Заменен через регулярное выражение: '\(placeholder)' -> '\(value)'")
                                    replaced = true
                                    replacedCount += 1
                                    if notFoundCount > 0 {
                                        notFoundCount -= 1
                                    }
                                }
                            } catch {
                                print("      ❌ Ошибка при создании регулярного выражения: \(error)")
                            }
                        }
                    } else {
                        print("      ❌ Значение для '\(placeholder)' не найдено в swapData")
                    }
                } else {
                    print("      ✅ Текст '\(placeholder)' успешно заменен")
                }
            }

            
            print("      ✅ Замена плейсхолдеров завершена:")
            print("         Заменено: \(replacedCount)")
            print("         Не найдено: \(notFoundCount)")
            
            //TODO:  ЕСЛИ ДОБАВЛЯЕМ ОДНО НАРУШЕНИЕ _ ВСЕ РАБОТЕТ, А ЕСЛИ НЕСКОЛЬОК_ ТО НЕ РАБОТАЕТ

            print("   🔍 Сохранение обновленного document.xml...")
            try xmlString.write(to: documentXML, atomically: true, encoding: .utf8)
            print("      ✅ document.xml сохранен")
            
            print("   🔍 Шаг 10: Создание итогового DOCX файла...")
            // Создаем название файла в формате "Акт №17" с уникальным идентификатором
            // Используем более надежный способ: номер акта + дата + короткий хеш
            // Это обеспечит уникальность и предотвратит дубликаты
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd"
            let dateString = dateFormatter.string(from: Date())
            let normalizedAktNumber = aktNumber.trimmingCharacters(in: .whitespaces).uppercased().replacingOccurrences(of: " ", with: "-")
            // Используем короткий хеш для дополнительной уникальности
            let shortHash = String(abs(aktNumber.hashValue % 10000)).padding(toLength: 4, withPad: "0", startingAt: 0)
            let uniqueId = "\(dateString)-\(normalizedAktNumber)-\(shortHash)"
            let fileName = "Акт №\(aktNumber)_\(uniqueId).docx"
            
            // ВАЖНО: Сохраняем в Documents вместо tmp, чтобы файл не удалялся системой при нехватке памяти
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let newDocxURL = documentsURL.appendingPathComponent(fileName)
            print("      Имя файла: \(fileName)")
            print("      Путь: \(newDocxURL.path)")
            print("      URL абсолютный: \(newDocxURL.absoluteString)")
            print("      Директория Documents: \(documentsURL.path)")
            print("      ⚠️ Сохраняем в Documents (не в tmp) для защиты от удаления системой")
            
            // Проверяем, что директория Documents существует
            if !fileManager.fileExists(atPath: documentsURL.path) {
                print("      ⚠️ Директория Documents не существует, создаем...")
                do {
                    try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true, attributes: nil)
                    print("      ✅ Директория Documents создана")
                } catch {
                    print("      ❌ Ошибка при создании директории Documents: \(error)")
                    completion(nil)
                    return
                }
            } else {
                print("      ✅ Директория Documents существует")
            }
            
            // Удаляем старый файл, если он существует
            if fileManager.fileExists(atPath: newDocxURL.path) {
                print("      ⚠️ Старый файл существует, удаляем...")
                try fileManager.removeItem(at: newDocxURL)
                print("      ✅ Старый файл удален")
            }
            
            print("      🔄 Архивирование в ZIP...")
            try fileManager.zipItem(at: tempDir, to: newDocxURL, shouldKeepParent: false)
            print("      ✅ ZIP архив создан")
            
            // Проверяем, что файл действительно создан
            guard fileManager.fileExists(atPath: newDocxURL.path) else {
                print("      ❌ [PROCESS_DOCX] КРИТИЧЕСКАЯ ОШИБКА: Файл не был создан после архивирования!")
                print("      Путь: \(newDocxURL.path)")
                completion(nil)
                return
            }
            print("      ✅ Файл подтвержден: существует на диске")
            
            // Проверяем размер файла
            if let attributes = try? fileManager.attributesOfItem(atPath: newDocxURL.path),
               let fileSize = attributes[FileAttributeKey.size] as? Int {
                print("      📊 Размер файла до оптимизации: \(fileSize) байт (\(fileSize / 1024) KB)")
                
                if fileSize == 0 {
                    print("      ❌ [PROCESS_DOCX] КРИТИЧЕСКАЯ ОШИБКА: Файл пустой!")
                    completion(nil)
                    return
                }
            } else {
                print("      ⚠️ Не удалось получить размер файла")
            }
            
            print("   🔍 Шаг 11: Оптимизация размера файла...")
            // Проверяем размер итогового файла и при необходимости дополнительно сжимаем
            let finalURL = optimizeFileSizeIfNeeded(newDocxURL, tempDir: tempDir, violations: violations, fileManager: fileManager)
            
            // Финальная проверка файла перед возвратом
            print("   🔍 Финальная проверка файла перед возвратом...")
            guard fileManager.fileExists(atPath: finalURL.path) else {
                print("   ❌ [PROCESS_DOCX] КРИТИЧЕСКАЯ ОШИБКА: Файл не существует после оптимизации!")
                print("      Путь: \(finalURL.path)")
                print("   📄 [PROCESS_DOCX] ========== КОНЕЦ processDocxTemplate (ошибка - файл не найден) ==========")
                completion(nil)
                return
            }
            
            // Проверяем финальный размер
            if let attributes = try? fileManager.attributesOfItem(atPath: finalURL.path),
               let fileSize = attributes[FileAttributeKey.size] as? Int {
                print("      📊 Финальный размер файла: \(fileSize) байт (\(fileSize / 1024) KB)")
                
                if fileSize == 0 {
                    print("   ❌ [PROCESS_DOCX] КРИТИЧЕСКАЯ ОШИБКА: Файл пустой после оптимизации!")
                    print("   📄 [PROCESS_DOCX] ========== КОНЕЦ processDocxTemplate (ошибка - файл пустой) ==========")
                    completion(nil)
                    return
                }
            } else {
                print("      ⚠️ Не удалось получить финальный размер файла")
            }
            
            print("   ✅ [PROCESS_DOCX] Генерация завершена успешно!")
            print("      Финальный URL: \(finalURL.path)")
            print("      Файл существует: \(fileManager.fileExists(atPath: finalURL.path))")
            print("      Директория: \(finalURL.deletingLastPathComponent().path)")
            print("   📄 [PROCESS_DOCX] ========== КОНЕЦ processDocxTemplate (успех) ==========")
            completion(finalURL)
        } catch {
            print("   ❌ [PROCESS_DOCX] Ошибка при обработке DOCX:")
            print("      Тип ошибки: \(type(of: error))")
            print("      Описание: \(error.localizedDescription)")
            print("      Детали: \(error)")
            print("⚠️ [ERROR_LOG] CRITICAL ERROR in processDocxTemplate: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("      Код ошибки: \(nsError.code)")
                print("      Домен: \(nsError.domain)")
                print("      UserInfo: \(nsError.userInfo)")
                print("⚠️ [ERROR_LOG] NSError code: \(nsError.code), domain: \(nsError.domain)")
            }
            print("   📄 [PROCESS_DOCX] ========== КОНЕЦ processDocxTemplate (ошибка) ==========")
            completion(nil)
        }
    }

    func fixImageOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        // Валидация изображения для предотвращения NaN ошибок
        guard NumberValidation.validateImageSize(image) else {
            print("❌ Ошибка: недопустимый размер или scale изображения")
            return image
        }
        
        let imageSize = image.size
        let imageScale = image.scale

        UIGraphicsBeginImageContextWithOptions(imageSize, false, imageScale)
        image.draw(in: CGRect(origin: .zero, size: imageSize))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }
    
    // MARK: - Image Compression
    func compressImageForAct(_ image: UIImage, aggressive: Bool = false) -> Data? {
        print("🖼️ Сжимаем изображение для акта")
        print("   Исходный размер: \(image.size.width)x\(image.size.height)")
        
        // Агрессивные настройки сжатия для уменьшения размера файла до 5 МБ
        let maxSize: CGFloat = aggressive ? 450 : 550  // Уменьшенный размер для документов
        let quality: CGFloat = aggressive ? 0.35 : 0.45  // Более низкое качество для экономии места
        let maxFileSize = aggressive ? 50 * 1024 : 60 * 1024 // 50-60KB - оптимальный размер для актов
        
        // 1. Изменяем размер изображения если необходимо
        let resizedImage = resizeImageIfNeeded(image, maxSize: maxSize)
        print("   Изменен размер до: \(resizedImage.size.width)x\(resizedImage.size.height)")
        
        // 2. Сжимаем с адаптивным качеством
        let compressedData = compressImageToTargetSize(resizedImage, targetQuality: quality, maxFileSize: maxFileSize)
        
        if let data = compressedData {
            let finalSizeKB = data.count / 1024
            print("   ✅ Сжатие завершено. Размер файла: \(finalSizeKB)KB")
            return data
        } else {
            print("   ❌ Ошибка сжатия изображения")
            return nil
        }
    }
    
    private func resizeImageIfNeeded(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let originalSize = image.size
        let maxDimension = max(originalSize.width, originalSize.height)
        
        // Если изображение уже меньше максимального размера, возвращаем как есть
        if maxDimension <= maxSize {
            return image
        }
        
        let scale = maxSize / maxDimension
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        // Создаем контекст для изменения размера
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }
        
        image.draw(in: CGRect(origin: .zero, size: newSize))
        return UIGraphicsGetImageFromCurrentImageContext() ?? image
    }
    
    private func compressImageToTargetSize(_ image: UIImage, targetQuality: CGFloat, maxFileSize: Int) -> Data? {
        var quality = targetQuality
        var data: Data?
        
        // Пробуем разные уровни качества пока не достигнем нужного размера
        while quality > 0.1 {
            if let jpegData = image.jpegData(compressionQuality: quality) {
                if jpegData.count <= maxFileSize {
                    data = jpegData
                    print("   Найдено подходящее качество: \(quality)")
                    break
                } else {
                    quality -= 0.1
                    print("   Качество \(quality) слишком большое, уменьшаем...")
                }
            } else {
                break
            }
        }
        
        // Если даже с минимальным качеством не помещается, используем последнее доступное
        if data == nil {
            data = image.jpegData(compressionQuality: 0.1)
            print("   ⚠️ Используем минимальное качество из-за ограничений размера")
        }
        
        return data
    }


    
    func formatData(date: Date) -> String {
        let formatte = DateFormatter()
        formatte.dateFormat = "dd.MM.yyyy"
        return formatte.string(from: date)
    }
    
    // Функция для обновления ширины столбцов в tblGrid (определение сетки таблицы)
    private func updateTableGridColumnWidths(in xmlString: String) -> String {
        print("   🔧 [UPDATE_TBL_GRID] ========== НАЧАЛО updateTableGridColumnWidths ==========")
        
        var result = xmlString
        
        // Заменяем ширину столбцов по порядку
        let columnWidths = [
            Self.violationNumberColumnWidth,        // 1410 (1.41 см)
            Self.violationFormulationColumnWidth,   // 7570 (7.57 см)
            Self.violationDescriptionColumnWidth,   // 5400 (5.4 см)
            Self.violationNoteColumnWidth           // 2810 (2.81 см)
        ]
        
        print("      📏 Целевые ширины столбцов в tblGrid:")
        for (index, width) in columnWidths.enumerated() {
            print("         Столбец \(index + 1): \(width)")
        }
        
        // Ищем tblGrid с определением столбцов
        // Паттерн: <w:tblGrid><w:gridCol w:w="число"/>... (4 раза)
        let tblGridPattern = "<w:tblGrid>(.*?)</w:tblGrid>"
        
        do {
            let regex = try NSRegularExpression(pattern: tblGridPattern, options: [.dotMatchesLineSeparators])
            let nsString = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            print("      🔍 Найдено tblGrid элементов: \(matches.count)")
            
            for (matchIndex, match) in matches.enumerated() {
                if match.numberOfRanges > 1 {
                    let gridContentRange = match.range(at: 1)
                    if gridContentRange.location != NSNotFound {
                        let gridContent = nsString.substring(with: gridContentRange)
                        print("      📋 Содержимое tblGrid \(matchIndex + 1): \(String(gridContent.prefix(200)))...")
                        
                        // Ищем все gridCol в этом tblGrid
                        let gridColPattern = "<w:gridCol\\s+w:w=\"([0-9]+)\"\\s*/>"
                        let gridColRegex = try NSRegularExpression(pattern: gridColPattern, options: [])
                        let gridColMatches = gridColRegex.matches(in: gridContent, options: [], range: NSRange(location: 0, length: (gridContent as NSString).length))
                        
                        print("         🔍 Найдено gridCol в tblGrid: \(gridColMatches.count)")
                        
                        if gridColMatches.count >= 4 {
                            // Заменяем gridCol в обратном порядке
                            var updatedGridContent = gridContent
                            let gridContentNsString = gridContent as NSString
                            
                            // Берем первые 4 gridCol для замены
                            let gridColsToReplace = Array(gridColMatches.prefix(4))
                            
                            for (index, gridColMatch) in gridColsToReplace.enumerated().reversed() {
                                if index < columnWidths.count {
                                    let gridColRange = gridColMatch.range
                                    if gridColRange.location != NSNotFound {
                                        let oldGridCol = gridContentNsString.substring(with: gridColRange)
                                        let newGridCol = oldGridCol.replacingOccurrences(
                                            of: "w:w=\"[0-9]+\"",
                                            with: "w:w=\"\(columnWidths[index])\"",
                                            options: .regularExpression
                                        )
                                        updatedGridContent = (updatedGridContent as NSString).replacingCharacters(in: gridColRange, with: newGridCol)
                                        print("         ✅ Заменен gridCol \(index + 1): \(oldGridCol) -> \(newGridCol)")
                                    }
                                }
                            }
                            
                            // Заменяем содержимое tblGrid в основном XML
                            let fullMatchRange = match.range
                            if fullMatchRange.location != NSNotFound {
                                let oldTblGrid = nsString.substring(with: fullMatchRange)
                                // Заменяем gridContent внутри старого tblGrid
                                let newTblGrid = oldTblGrid.replacingOccurrences(
                                    of: gridContent,
                                    with: updatedGridContent
                                )
                                
                                let beforeReplace = result
                                result = (result as NSString).replacingCharacters(in: fullMatchRange, with: newTblGrid)
                                
                                if beforeReplace != result {
                                    print("      ✅ tblGrid \(matchIndex + 1) обновлен успешно")
                                } else {
                                    print("      ❌ ОШИБКА: tblGrid \(matchIndex + 1) не обновлен")
                                }
                                
                                // Дополнительно обновляем tblW и фиксируем layout для таблицы нарушений
                                let totalWidth = columnWidths.reduce(0, +)
                                // #region agent log
                                Self.debugLog(
                                    location: "GenerateViewModel.swift:1094",
                                    message: "Computing totalWidth for tblW update",
                                    data: [
                                        "columnWidths": columnWidths,
                                        "totalWidth": totalWidth,
                                        "matchIndex": matchIndex
                                    ],
                                    hypothesisId: "E"
                                )
                                // #endregion
                                let updatedNSString = result as NSString
                                
                                // Ищем границы таблицы, которая содержит этот tblGrid
                                let searchEnd = fullMatchRange.location + (newTblGrid as NSString).length
                                let tableStartRange = updatedNSString.range(of: "<w:tbl", options: [.backwards], range: NSRange(location: 0, length: searchEnd))
                                let tableEndRange = updatedNSString.range(of: "</w:tbl>", options: [], range: NSRange(location: fullMatchRange.location, length: updatedNSString.length - fullMatchRange.location))
                                
                                print("      🔍 Поиск границ таблицы для tblGrid \(matchIndex + 1):")
                                print("         tableStartRange найден: \(tableStartRange.location != NSNotFound ? "✅ ДА (позиция: \(tableStartRange.location))" : "❌ НЕТ")")
                                print("         tableEndRange найден: \(tableEndRange.location != NSNotFound ? "✅ ДА (позиция: \(tableEndRange.location))" : "❌ НЕТ")")
                                
                                // #region agent log
                                Self.debugLog(
                                    location: "GenerateViewModel.swift:1103",
                                    message: "Searching for table boundaries",
                                    data: [
                                        "tableStartFound": tableStartRange.location != NSNotFound,
                                        "tableEndFound": tableEndRange.location != NSNotFound,
                                        "searchEnd": searchEnd,
                                        "tableStartLocation": tableStartRange.location != NSNotFound ? tableStartRange.location : -1,
                                        "tableEndLocation": tableEndRange.location != NSNotFound ? tableEndRange.location : -1
                                    ],
                                    hypothesisId: "F"
                                )
                                // #endregion
                                
                                if tableStartRange.location != NSNotFound && tableEndRange.location != NSNotFound {
                                    let tableRange = NSRange(location: tableStartRange.location, length: tableEndRange.location + tableEndRange.length - tableStartRange.location)
                                    let tableContent = updatedNSString.substring(with: tableRange)
                                    
                                    // Обрабатываем только таблицу нарушений (содержит "№ п/п")
                                    // #region agent log
                                    let isViolationsTable = tableContent.contains("№ п/п")
                                    print("      🔍 Проверка таблицы на нарушения:")
                                    print("         Размер таблицы: \(tableContent.count) символов")
                                    print("         Содержит '№ п/п': \(isViolationsTable ? "✅ ДА" : "❌ НЕТ")")
                                    Self.debugLog(
                                        location: "GenerateViewModel.swift:1108",
                                        message: "Checking if table is violations table",
                                        data: [
                                            "isViolationsTable": isViolationsTable,
                                            "tableSize": tableContent.count
                                        ],
                                        hypothesisId: "F"
                                    )
                                    // #endregion
                                    if isViolationsTable {
                                        print("      ✅ Это таблица нарушений, начинаем обновление tblW и tblLayout")
                                        var updatedTableContent = tableContent
                                        
                                        // Логируем первые 500 символов таблицы для диагностики
                                        print("      📋 Первые 500 символов таблицы: \(String(tableContent.prefix(500)))")
                                        
                                        let tableContentNsString = tableContent as NSString
                                        var oldTblWValue: String? = nil
                                        var tblWUpdated = false
                                        
                                        // Используем более простой и надежный подход: заменяем значение w:w в любом tblW элементе
                                        // Ищем все вхождения w:w="число" в контексте tblW
                                        let tblWWithValuePattern = "(<w:tblW[^>]*w:w=\")([0-9]+)(\"[^>]*w:type=\"dxa\"[^>]*/?>)"
                                        
                                        if let tblWRegex = try? NSRegularExpression(pattern: tblWWithValuePattern, options: []) {
                                            let matches = tblWRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: tableContentNsString.length))
                                            print("      🔍 Найдено tblW элементов: \(matches.count)")
                                            
                                            if let match = matches.first, match.numberOfRanges >= 3 {
                                                // Извлекаем старое значение
                                                oldTblWValue = tableContentNsString.substring(with: match.range(at: 2))
                                                print("      📏 Старое tblW таблицы нарушений: \(oldTblWValue!)")
                                                
                                                // Заменяем значение w:w
                                                let fullMatchRange = match.range
                                                let beforeValue = tableContentNsString.substring(with: match.range(at: 1))
                                                let afterValue = tableContentNsString.substring(with: match.range(at: 3))
                                                let newTblW = beforeValue + "\(totalWidth)" + afterValue
                                                
                                                updatedTableContent = tableContentNsString.replacingCharacters(in: fullMatchRange, with: newTblW)
                                                tblWUpdated = true
                                                print("      ✅ Заменен tblW: \(oldTblWValue!) -> \(totalWidth)")
                                            }
                                        }
                                        
                                        // Если не найдено, пробуем найти просто элемент tblW и заменить в нем w:w
                                        if !tblWUpdated {
                                            // Ищем просто <w:tblW...> и заменяем w:w="число" внутри него
                                            let simpleTblWPattern = "<w:tblW[^>]*>"
                                            if let simpleRegex = try? NSRegularExpression(pattern: simpleTblWPattern) {
                                                let matches = simpleRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: tableContentNsString.length))
                                                print("      🔍 Попытка простого поиска '<w:tblW[^>]*>': найдено \(matches.count)")
                                                
                                                if let match = matches.first {
                                                    let tblWElement = tableContentNsString.substring(with: match.range)
                                                    print("      📋 Найденный элемент tblW: \(tblWElement)")
                                                    
                                                    // Извлекаем старое значение w:w
                                                    let wValuePattern = "w:w=\"([0-9]+)\""
                                                    if let wValueRegex = try? NSRegularExpression(pattern: wValuePattern) {
                                                        let wMatches = wValueRegex.matches(in: tblWElement, options: [], range: NSRange(location: 0, length: (tblWElement as NSString).length))
                                                        if let wMatch = wMatches.first, wMatch.numberOfRanges > 1 {
                                                            oldTblWValue = (tblWElement as NSString).substring(with: wMatch.range(at: 1))
                                                            print("      📏 Извлечено старое значение tblW: \(oldTblWValue!)")
                                                            
                                                            // Заменяем w:w="число" на w:w="totalWidth"
                                                            let newTblWElement = tblWElement.replacingOccurrences(
                                                                of: "w:w=\"\(oldTblWValue!)\"",
                                                                with: "w:w=\"\(totalWidth)\""
                                                            )
                                                            
                                                            // Заменяем весь элемент в таблице
                                                            updatedTableContent = tableContentNsString.replacingCharacters(in: match.range, with: newTblWElement)
                                                            tblWUpdated = true
                                                            print("      ✅ Заменен tblW: \(oldTblWValue!) -> \(totalWidth)")
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        
                                        // Если tblW все еще не обновлен, добавляем его
                                        if !tblWUpdated {
                                            print("      ⚠️ tblW не найден, добавляем новый")
                                            // Ищем начало tblPr
                                            let tblPrStartPattern = "<w:tblPr>"
                                            let tblPrStartRange = tableContentNsString.range(of: tblPrStartPattern)
                                            if tblPrStartRange.location != NSNotFound {
                                                // Добавляем tblW после <w:tblPr>
                                                let insertPosition = tblPrStartRange.location + tblPrStartRange.length
                                                let newTblW = "<w:tblW w:w=\"\(totalWidth)\" w:type=\"dxa\"/>"
                                                updatedTableContent = tableContentNsString.replacingCharacters(in: NSRange(location: insertPosition, length: 0), with: newTblW)
                                                tblWUpdated = true
                                                print("      ✅ Добавлен новый tblW: \(totalWidth)")
                                            } else {
                                                // Если tblPr не найден, ищем tblStyle и добавляем перед ним
                                                let tblStyleRange = tableContentNsString.range(of: "<w:tblStyle")
                                                if tblStyleRange.location != NSNotFound {
                                                    let newTblW = "<w:tblW w:w=\"\(totalWidth)\" w:type=\"dxa\"/>"
                                                    updatedTableContent = tableContentNsString.replacingCharacters(in: NSRange(location: tblStyleRange.location, length: 0), with: newTblW)
                                                    tblWUpdated = true
                                                    print("      ✅ Добавлен новый tblW перед tblStyle: \(totalWidth)")
                                                } else {
                                                    print("      ❌ Не удалось найти место для вставки tblW (нет ни tblPr, ни tblStyle)")
                                                }
                                            }
                                        }
                                        
                                        // Теперь обновляем tblLayout
                                        let hasLayout = updatedTableContent.contains("<w:tblLayout")
                                        if !hasLayout {
                                            // Ищем tblStyle и добавляем tblLayout перед ним
                                            let updatedTableContentNsString = updatedTableContent as NSString
                                            let tblStyleRange = updatedTableContentNsString.range(of: "<w:tblStyle")
                                            if tblStyleRange.location != NSNotFound {
                                                let newLayout = "<w:tblLayout w:type=\"fixed\"/>"
                                                updatedTableContent = updatedTableContentNsString.replacingCharacters(in: NSRange(location: tblStyleRange.location, length: 0), with: newLayout)
                                                print("      ✅ Добавлен tblLayout w:type=\"fixed\"")
                                            }
                                        } else {
                                            // Обновляем существующий tblLayout
                                            let layoutPattern = "<w:tblLayout[^>]*>"
                                            if let layoutRegex = try? NSRegularExpression(pattern: layoutPattern) {
                                                let layoutMatches = layoutRegex.matches(in: updatedTableContent, options: [], range: NSRange(location: 0, length: (updatedTableContent as NSString).length))
                                                if let layoutMatch = layoutMatches.first {
                                                    let updatedTableContentNsString = updatedTableContent as NSString
                                                    let newLayout = "<w:tblLayout w:type=\"fixed\"/>"
                                                    updatedTableContent = updatedTableContentNsString.replacingCharacters(in: layoutMatch.range, with: newLayout)
                                                    print("      ✅ Обновлен tblLayout на w:type=\"fixed\"")
                                                }
                                            }
                                        }
                                        
                                        // Применяем изменения к основному XML
                                        if updatedTableContent != tableContent {
                                            result = (result as NSString).replacingCharacters(in: tableRange, with: updatedTableContent)
                                            print("      ✅ Таблица нарушений обновлена: tblW=\(totalWidth), layout=fixed")
                                            
                                            // #region agent log
                                            Self.debugLog(
                                                location: "GenerateViewModel.swift:1150",
                                                message: "tblPr updated successfully",
                                                data: [
                                                    "tableUpdated": true,
                                                    "newTblW": totalWidth,
                                                    "layoutFixed": true,
                                                    "oldTblW": oldTblWValue ?? "none"
                                                ],
                                                hypothesisId: "A"
                                            )
                                            // #endregion
                                        } else {
                                            print("      ⚠️ Таблица нарушений не изменилась")
                                        }
                                    } else {
                                        print("      ⚠️ Таблица не является таблицей нарушений (не содержит '№ п/п')")
                                    }
                                } else {
                                    print("      ⚠️ Границы таблицы не найдены для tblGrid \(matchIndex + 1)")
                                }
                            }
                        } else {
                            print("      ⚠️ В tblGrid найдено меньше 4 gridCol (\(gridColMatches.count))")
                        }
                    }
                }
            }
        } catch {
            print("      ❌ Ошибка при обновлении tblGrid: \(error)")
        }
        
        print("   🔧 [UPDATE_TBL_GRID] ========== КОНЕЦ updateTableGridColumnWidths ==========")
        return result
    }
    
    // Функция для обновления ширины столбцов во всех строках таблицы нарушений (включая заголовок)
    private func updateAllTableRowColumnWidths(in xmlString: String) -> String {
        print("   🔧 [UPDATE_ALL_ROWS] ========== НАЧАЛО updateAllTableRowColumnWidths ==========")
        
        var result = xmlString
        
        // Заменяем ширину столбцов по порядку
        let columnWidths = [
            Self.violationNumberColumnWidth,        // 1410 (1.41 см)
            Self.violationFormulationColumnWidth,   // 7570 (7.57 см)
            Self.violationDescriptionColumnWidth,   // 5400 (5.4 см)
            Self.violationNoteColumnWidth           // 2810 (2.81 см)
        ]
        
        print("      📏 Целевые ширины столбцов:")
        for (index, width) in columnWidths.enumerated() {
            print("         Столбец \(index + 1): \(width)")
        }
        
        // Ищем таблицу нарушений более точно - по тексту "В ходе проверки выявлены следующие нарушения:" и затем "№ п/п"
        // Это гарантирует, что мы обновляем именно таблицу нарушений
        let markerText = "В ходе проверки выявлены следующие нарушения:"
        let tableStartMarker = "№ п/п"
        
        do {
            let nsString = result as NSString
            
            // Находим маркер начала таблицы нарушений
            let markerRange = nsString.range(of: markerText)
            if markerRange.location != NSNotFound {
                let searchStartLocation = markerRange.location + markerRange.length
                
                print("      📋 Найден маркер '\(markerText)' на позиции: \(markerRange.location)")
                
                // Ищем все таблицы после маркера и находим ту, которая содержит "№ п/п"
                let searchRange = NSRange(location: searchStartLocation, length: nsString.length - searchStartLocation)
                
                // Используем регулярное выражение для поиска всей таблицы целиком
                let tablePattern = "<w:tbl>(.*?)</w:tbl>"
                let tableRegex = try NSRegularExpression(pattern: tablePattern, options: [.dotMatchesLineSeparators])
                let tableMatches = tableRegex.matches(in: result, options: [], range: searchRange)
                
                print("      🔍 Найдено таблиц после маркера: \(tableMatches.count)")
                
                // Ищем таблицу, которая содержит "№ п/п"
                var foundTable: (range: NSRange, content: String)? = nil
                for tableMatch in tableMatches {
                    let tableRange = tableMatch.range
                    if tableRange.location != NSNotFound {
                        let tableContent = nsString.substring(with: tableRange)
                        if tableContent.contains(tableStartMarker) {
                            foundTable = (tableRange, tableContent)
                            print("      📋 Найдена таблица нарушений, размер: \(tableContent.count) символов")
                            break
                        }
                    }
                }
                
                if let (tableRange, tableContent) = foundTable {
                        // Ищем все w:tcW в этой таблице
                        let tcWPattern = "<w:tcW\\s+w:w=\"([0-9]+)\"\\s+w:type=\"dxa\"\\s*/>"
                        let tcWRegex = try NSRegularExpression(pattern: tcWPattern, options: [])
                        let tcWMatches = tcWRegex.matches(in: tableContent, options: [], range: NSRange(location: 0, length: (tableContent as NSString).length))
                        
                        print("         🔍 Найдено w:tcW в таблице нарушений: \(tcWMatches.count)")
                        // #region agent log
                        Self.debugLog(
                            location: "GenerateViewModel.swift:1237",
                            message: "Found w:tcW elements in violations table",
                            data: [
                                "tcWCount": tcWMatches.count,
                                "expectedMultipleOf4": tcWMatches.count % 4 == 0,
                                "tableSize": tableContent.count
                            ],
                            hypothesisId: "B"
                        )
                        // #endregion
                        
                        if tcWMatches.count > 0 && tcWMatches.count % 4 == 0 {
                            // Обновляем w:tcW по группам по 4 (каждая строка имеет 4 столбца)
                            var updatedTableContent = tableContent
                            let tableContentNsString = tableContent as NSString
                            
                            // Обрабатываем каждую группу из 4 w:tcW в обратном порядке
                            var processedCount = 0
                            for groupStart in stride(from: 0, to: tcWMatches.count, by: 4).reversed() {
                                let groupEnd = min(groupStart + 4, tcWMatches.count)
                                let groupMatches = Array(tcWMatches[groupStart..<groupEnd])
                                
                                // Заменяем в обратном порядке внутри группы, чтобы позиции не сдвигались
                                for (localIndex, match) in groupMatches.enumerated().reversed() {
                                    if localIndex < columnWidths.count {
                                        let matchRange = match.range
                                        if matchRange.location != NSNotFound {
                                            let oldValue = tableContentNsString.substring(with: matchRange)
                                            let newValue = "<w:tcW w:w=\"\(columnWidths[localIndex])\" w:type=\"dxa\"/>"
                                            updatedTableContent = (updatedTableContent as NSString).replacingCharacters(in: matchRange, with: newValue)
                                            processedCount += 1
                                            if processedCount <= 8 || processedCount % 4 == 0 {
                                                print("            ✅ Заменен w:tcW (группа \(groupStart/4 + 1), столбец \(localIndex + 1)): \(oldValue) -> \(newValue)")
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // Заменяем таблицу в основном XML
                            if updatedTableContent != tableContent {
                                result = (result as NSString).replacingCharacters(in: tableRange, with: updatedTableContent)
                                print("      ✅ Таблица нарушений обновлена, обработано w:tcW: \(processedCount) из \(tcWMatches.count)")
                                // #region agent log
                                Self.debugLog(
                                    location: "GenerateViewModel.swift:1270",
                                    message: "Table updated successfully",
                                    data: [
                                        "processedCount": processedCount,
                                        "totalTcWCount": tcWMatches.count,
                                        "tableChanged": true
                                    ],
                                    hypothesisId: "B"
                                )
                                // #endregion
                            } else {
                                print("      ⚠️ Таблица нарушений не изменилась")
                                // #region agent log
                                Self.debugLog(
                                    location: "GenerateViewModel.swift:1274",
                                    message: "Table content did not change",
                                    data: [
                                        "processedCount": processedCount,
                                        "totalTcWCount": tcWMatches.count,
                                        "tableChanged": false
                                    ],
                                    hypothesisId: "B"
                                )
                                // #endregion
                            }
                        } else {
                            print("      ⚠️ В таблице нарушений найдено \(tcWMatches.count) w:tcW (ожидается кратное 4)")
                        }
                    } else {
                        print("      ⚠️ Не найдена таблица с '\(tableStartMarker)' после маркера")
                    }
            } else {
                print("      ⚠️ Не удалось найти маркер '\(markerText)'")
            }
        } catch {
            print("      ❌ Ошибка при обновлении строк таблицы: \(error)")
        }
        
        print("   🔧 [UPDATE_ALL_ROWS] ========== КОНЕЦ updateAllTableRowColumnWidths ==========")
        return result
    }
    
    // Функция для установки ширины столбцов в таблице нарушений
    private func setViolationTableColumnWidths(in xmlString: String) -> String {
        var result = xmlString
        
        // Заменяем ширину столбцов по порядку
        let columnWidths = [
            Self.violationNumberColumnWidth,        // 1410 (1.41 см)
            Self.violationFormulationColumnWidth,   // 7570 (7.57 см)
            Self.violationDescriptionColumnWidth,   // 5400 (5.4 см)
            Self.violationNoteColumnWidth           // 2810 (2.81 см)
        ]
        
        print("   🔧 [SET_COLUMN_WIDTHS] ========== НАЧАЛО setViolationTableColumnWidths ==========")
        // #region agent log
        Self.debugLog(
            location: "GenerateViewModel.swift:1535",
            message: "setViolationTableColumnWidths called",
            data: [
                "xmlStringSize": xmlString.count,
                "columnWidths": columnWidths
            ],
            hypothesisId: "B"
        )
        // #endregion
        print("      📏 Входные параметры:")
        print("         Размер XML строки: \(xmlString.count) символов")
        print("         Целевые ширины столбцов:")
        print("            Столбец 1: \(Self.violationNumberColumnWidth) (1.41 см)")
        print("            Столбец 2: \(Self.violationFormulationColumnWidth) (7.57 см)")
        print("            Столбец 3: \(Self.violationDescriptionColumnWidth) (5.4 см)")
        print("            Столбец 4: \(Self.violationNoteColumnWidth) (2.81 см)")
        print("      📋 Первые 1000 символов XML для диагностики:")
        print(String(xmlString.prefix(1000)))
        print("      ...")
        
        // Ищем элементы w:tcW - они могут быть в разных форматах
        // Формат 1: <w:tcW w:w="число" w:type="dxa"/>
        // Формат 2: <w:tcW w:type="dxa" w:w="число"/>
        // Формат 3: <w:tcW w:w="число" w:type="dxa"></w:tcW>
        // Формат 4: внутри <w:tcPr><w:tcW .../></w:tcPr>
        
        let nsString = result as NSString
        var widthMatches: [(range: NSRange, value: String)] = []
        
        print("      🔍 Шаг 1: Поиск всех вхождений w:w=\"число\"...")
        // Сначала ищем все вхождения w:w="число" и проверяем их контекст
        do {
            let widthPattern = "w:w=\"([0-9]+)\""
            let widthRegex = try NSRegularExpression(pattern: widthPattern, options: [])
            let allMatches = widthRegex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
            
            print("         ✅ Найдено всего вхождений w:w=\"число\": \(allMatches.count)")
            
            // Фильтруем только те, которые находятся в контексте w:tcW
            for (matchIndex, match) in allMatches.enumerated() {
                let matchRange = match.range
                if matchRange.location != NSNotFound {
                    // Проверяем контекст вокруг (200 символов в каждую сторону)
                    let contextStart = max(0, matchRange.location - 200)
                    let contextEnd = min(nsString.length, matchRange.location + matchRange.length + 200)
                    let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
                    let context = nsString.substring(with: contextRange)
                    
                    let value = nsString.substring(with: match.range(at: 1))
                    print("         🔍 Вхождение \(matchIndex + 1): w:w=\"\(value)\" на позиции \(matchRange.location)")
                    
                    // Ищем в контексте признаки элемента w:tcW
                    let hasTcW = context.contains("tcW")
                    let hasTcPr = context.contains("tcPr")
                    print("            Содержит 'tcW': \(hasTcW)")
                    print("            Содержит 'tcPr': \(hasTcPr)")
                    print("            Контекст (первые 150 символов): \(String(context.prefix(150)))")
                    
                    if hasTcW || hasTcPr {
                        widthMatches.append((range: matchRange, value: value))
                        print("            ✅ Добавлено в список для замены (всего: \(widthMatches.count))")
                    } else {
                        print("            ⚠️ Пропущено (не в контексте w:tcW или w:tcPr)")
                    }
                }
            }
            
            print("      ✅ Найдено элементов в контексте w:tcW/w:tcPr: \(widthMatches.count)")
        } catch {
            print("      ❌ Ошибка при создании регулярного выражения: \(error)")
        }
        
        // Если нашли элементы через контекст, используем их
        if !widthMatches.isEmpty && widthMatches.count >= 4 {
            print("      ✅ Шаг 2: Используем элементы, найденные через контекст")
            print("         Найдено \(widthMatches.count) элементов, берем первые 4")
            // Берем первые 4 и заменяем в обратном порядке
            let matchesToReplace = Array(widthMatches.prefix(4))
            
            for (index, matchInfo) in matchesToReplace.enumerated().reversed() {
                if index < columnWidths.count {
                    let matchRange = matchInfo.range
                    let oldValue = nsString.substring(with: matchRange)
                    let newValue = "w:w=\"\(columnWidths[index])\""
                    print("         🔄 Замена столбца \(index + 1):")
                    print("            Старое значение: \(oldValue)")
                    print("            Новое значение: \(newValue)")
                    print("            Позиция: \(matchRange.location), длина: \(matchRange.length)")
                    
                    let beforeReplace = result
                    result = (result as NSString).replacingCharacters(in: matchRange, with: newValue)
                    
                    if beforeReplace != result {
                        print("            ✅ Замена выполнена успешно")
                    } else {
                        print("            ❌ ОШИБКА: Замена не выполнена! Строка не изменилась!")
                    }
                }
            }
        } else {
            // Если не нашли через контекст, используем простой подход - заменяем первые 4 вхождения
            print("      ⚠️ Шаг 2: Не найдено достаточно элементов через контекст (\(widthMatches.count) < 4)")
            print("         Используем простой подход - заменяем первые 4 вхождения")
            do {
                let pattern = "w:w=\"([0-9]+)\""
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: nsString.length))
                
                print("         ✅ Найдено вхождений w:w=\"число\": \(matches.count)")
                
                let matchesToReplace = Array(matches.prefix(4))
                print("         Берем первые \(matchesToReplace.count) для замены")
                
                for (index, match) in matchesToReplace.enumerated().reversed() {
                    if index < columnWidths.count {
                        let matchRange = match.range
                        if matchRange.location != NSNotFound {
                            let oldValue = nsString.substring(with: matchRange)
                            let newValue = "w:w=\"\(columnWidths[index])\""
                            print("         🔄 Замена столбца \(index + 1):")
                            print("            Старое значение: \(oldValue)")
                            print("            Новое значение: \(newValue)")
                            print("            Позиция: \(matchRange.location), длина: \(matchRange.length)")
                            
                            let beforeReplace = result
                            result = (result as NSString).replacingCharacters(in: matchRange, with: newValue)
                            
                            if beforeReplace != result {
                                print("            ✅ Замена выполнена успешно")
                            } else {
                                print("            ❌ ОШИБКА: Замена не выполнена! Строка не изменилась!")
                            }
                        }
                    }
                }
            } catch {
                print("         ❌ Ошибка при создании регулярного выражения: \(error)")
            }
        }
        
        // Проверяем, что изменения применились
        let hasChanges = result != xmlString
        // #region agent log
        // Проверяем, сколько w:tcW с правильными значениями теперь в результате
        var foundCorrectWidths = [Int: Int]() // [columnIndex: count]
        for (index, width) in columnWidths.enumerated() {
            let pattern = "<w:tcW[^>]*w:w=\"\(width)\"[^>]*w:type=\"dxa\""
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let count = regex.numberOfMatches(in: result, options: [], range: NSRange(location: 0, length: (result as NSString).length))
                foundCorrectWidths[index] = count
            }
        }
        Self.debugLog(
            location: "GenerateViewModel.swift:1690",
            message: "setViolationTableColumnWidths result",
            data: [
                "hasChanges": hasChanges,
                "sizeBefore": xmlString.count,
                "sizeAfter": result.count,
                "foundCorrectWidths": foundCorrectWidths
            ],
            hypothesisId: "B"
        )
        // #endregion
        print("      📊 Результат:")
        print("         Изменения применены: \(hasChanges)")
        print("         Размер до: \(xmlString.count) символов")
        print("         Размер после: \(result.count) символов")
        
        if hasChanges {
            // Показываем примеры изменений
            print("      🔍 Проверка изменений (поиск новых значений в результате)...")
            for (index, width) in columnWidths.enumerated() {
                let searchValue = "w:w=\"\(width)\""
                let count = result.components(separatedBy: searchValue).count - 1
                if count > 0 {
                    print("         ✅ Столбец \(index + 1): найдено новое значение \(searchValue) (\(count) раз)")
                } else {
                    print("         ⚠️ Столбец \(index + 1): новое значение \(searchValue) НЕ найдено")
                }
            }
        } else {
            print("      ❌ КРИТИЧЕСКАЯ ОШИБКА: Изменения не применены!")
            print("      🔍 Показываем первые 500 символов результата для диагностики:")
            print(String(result.prefix(500)))
        }
        
        print("   🔧 [SET_COLUMN_WIDTHS] ========== КОНЕЦ setViolationTableColumnWidths ==========")
        
        return result
    }
    
    // MARK: - File Size Optimization
    private func optimizeFileSizeIfNeeded(_ fileURL: URL, tempDir: URL, violations: [Violations], fileManager: FileManager) -> URL {
        let maxFileSize = 5 * 1024 * 1024 // 5 МБ
        
        // Проверяем размер файла
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int else {
            print("⚠️ Не удалось получить размер файла")
            return fileURL
        }
        
        print("📊 Размер файла после генерации: \(formatFileSize(fileSize))")
        
        // Если файл меньше 5 МБ, возвращаем как есть
        if fileSize <= maxFileSize {
            print("✅ Размер файла в пределах нормы (≤5 МБ)")
            return fileURL
        }
        
        print("⚠️ Размер файла превышает 5 МБ, начинаем дополнительное сжатие...")
        
        // Вычисляем, насколько нужно уменьшить размер
        let targetSize = maxFileSize
        let currentSize = fileSize
        let compressionRatio = Double(targetSize) / Double(currentSize)
        
        print("   Текущий размер: \(formatFileSize(currentSize))")
        print("   Целевой размер: \(formatFileSize(targetSize))")
        print("   Коэффициент сжатия: \(String(format: "%.2f", compressionRatio))")
        
        // Пересжимаем все изображения с более агрессивными настройками
        let mediaDir = tempDir.appendingPathComponent("word/media")
        var totalSaved = 0
        var currentImageIndex = 0
        
        // Пересчитываем индексы изображений в том же порядке, как они были созданы
        for violation in violations {
            guard !violation.photo.isEmpty else { continue }
            
            for photoData in violation.photo {
                currentImageIndex += 1
                guard let image = UIImage(data: photoData) else { continue }
                
                // Используем агрессивное сжатие
                guard let compressedData = compressImageForAct(image, aggressive: true) else { continue }
                
                // Находим соответствующий файл изображения
                let imageName = "image\(currentImageIndex).jpg"
                let imagePath = mediaDir.appendingPathComponent(imageName)
                
                if fileManager.fileExists(atPath: imagePath.path) {
                    let oldSize = (try? fileManager.attributesOfItem(atPath: imagePath.path))?[.size] as? Int ?? 0
                    try? compressedData.write(to: imagePath)
                    let newSize = compressedData.count
                    totalSaved += (oldSize - newSize)
                    print("   📉 Изображение \(imageName): \(formatFileSize(oldSize)) → \(formatFileSize(newSize))")
                }
            }
        }
        
        print("   💾 Всего сэкономлено: \(formatFileSize(totalSaved))")
        
        // Пересоздаем DOCX файл с оптимизированными изображениями
        do {
            // Удаляем старый файл
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            
            // Создаем новый файл
            try fileManager.zipItem(at: tempDir, to: fileURL, shouldKeepParent: false)
            
            // Проверяем новый размер
            if let newAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let newFileSize = newAttributes[.size] as? Int {
                print("📊 Новый размер файла: \(formatFileSize(newFileSize))")
                
                // Если все еще превышает 5 МБ, применяем еще более агрессивное сжатие
                if newFileSize > maxFileSize {
                    print("⚠️ Файл все еще превышает 5 МБ (\(formatFileSize(newFileSize))), применяем максимальное сжатие...")
                    let maxCompressedURL = applyMaximumCompression(fileURL: fileURL, tempDir: tempDir, violations: violations, fileManager: fileManager)
                    
                    // Проверяем результат максимального сжатия
                    if let finalAttributes = try? fileManager.attributesOfItem(atPath: maxCompressedURL.path),
                       let finalSize = finalAttributes[.size] as? Int {
                        if finalSize > maxFileSize {
                            print("⚠️ Файл все еще превышает 5 МБ после максимального сжатия (\(formatFileSize(finalSize)))")
                            print("   Применяем экстремальное сжатие...")
                            return applyExtremeCompression(fileURL: maxCompressedURL, tempDir: tempDir, violations: violations, fileManager: fileManager)
                        }
                    }
                    
                    return maxCompressedURL
                }
            }
            
            return fileURL
        } catch {
            print("❌ Ошибка при пересоздании файла: \(error)")
            return fileURL
        }
    }
    
    private func applyMaximumCompression(fileURL: URL, tempDir: URL, violations: [Violations], fileManager: FileManager) -> URL {
        print("🔥 Применяем максимальное сжатие...")
        
        let mediaDir = tempDir.appendingPathComponent("word/media")
        var currentImageIndex = 0
        
        // Максимально агрессивное сжатие: 350px, качество 0.25, максимум 40KB
        for violation in violations {
            guard !violation.photo.isEmpty else { continue }
            
            for photoData in violation.photo {
                currentImageIndex += 1
                guard let image = UIImage(data: photoData) else { continue }
                
                // Максимальное сжатие
                let maxSize: CGFloat = 350
                let quality: CGFloat = 0.25
                let maxFileSizeBytes = 40 * 1024
                
                let resizedImage = resizeImageIfNeeded(image, maxSize: maxSize)
                guard let compressedData = compressImageToTargetSize(resizedImage, targetQuality: quality, maxFileSize: maxFileSizeBytes) else { continue }
                
                // Находим соответствующий файл изображения
                let imageName = "image\(currentImageIndex).jpg"
                let imagePath = mediaDir.appendingPathComponent(imageName)
                
                if fileManager.fileExists(atPath: imagePath.path) {
                    try? compressedData.write(to: imagePath)
                    print("   🔥 Максимальное сжатие: \(imageName) → \(formatFileSize(compressedData.count))")
                }
            }
        }
        
        // Пересоздаем файл
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.zipItem(at: tempDir, to: fileURL, shouldKeepParent: false)
            
            if let newAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let newFileSize = newAttributes[.size] as? Int {
                print("📊 Финальный размер файла: \(formatFileSize(newFileSize))")
            }
            
            return fileURL
        } catch {
            print("❌ Ошибка при максимальном сжатии: \(error)")
            return fileURL
        }
    }
    
    private func applyExtremeCompression(fileURL: URL, tempDir: URL, violations: [Violations], fileManager: FileManager) -> URL {
        print("💥 Применяем экстремальное сжатие...")
        
        let mediaDir = tempDir.appendingPathComponent("word/media")
        var currentImageIndex = 0
        
        // Экстремальное сжатие: 300px, качество 0.2, максимум 35KB
        for violation in violations {
            guard !violation.photo.isEmpty else { continue }
            
            for photoData in violation.photo {
                currentImageIndex += 1
                guard let image = UIImage(data: photoData) else { continue }
                
                // Экстремальное сжатие
                let maxSize: CGFloat = 300
                let quality: CGFloat = 0.2
                let maxFileSizeBytes = 35 * 1024
                
                let resizedImage = resizeImageIfNeeded(image, maxSize: maxSize)
                guard let compressedData = compressImageToTargetSize(resizedImage, targetQuality: quality, maxFileSize: maxFileSizeBytes) else { continue }
                
                // Находим соответствующий файл изображения
                let imageName = "image\(currentImageIndex).jpg"
                let imagePath = mediaDir.appendingPathComponent(imageName)
                
                if fileManager.fileExists(atPath: imagePath.path) {
                    try? compressedData.write(to: imagePath)
                    print("   💥 Экстремальное сжатие: \(imageName) → \(formatFileSize(compressedData.count))")
                }
            }
        }
        
        // Пересоздаем файл
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.zipItem(at: tempDir, to: fileURL, shouldKeepParent: false)
            
            if let newAttributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let newFileSize = newAttributes[.size] as? Int {
                print("📊 Финальный размер файла после экстремального сжатия: \(formatFileSize(newFileSize))")
            }
            
            return fileURL
        } catch {
            print("❌ Ошибка при экстремальном сжатии: \(error)")
            return fileURL
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
}


