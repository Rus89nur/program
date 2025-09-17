//
//  ViolationModel.swift
//  Gazprom
//
//  Created by Владимир on 08.07.2025.
//

import Foundation
import CoreXLSX
import xlsxwriter

class ViolationsModel {
    
    static func returnAvialableViolation() -> [Violation] {
        guard let path = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("⚠️ Путь не найден в UserDefaults")
            return []
        }
        
        print("🔍 Путь к файлу: \(path)")
        print("🔍 Файл существует: \(FileManager.default.fileExists(atPath: path))")
        
        guard let file = XLSXFile(filepath: path) else {
            print("❌ Не удалось открыть Excel-файл по пути: \(path)")
            return []
        }
        
        print("✅ Excel-файл успешно открыт")
        
        var violations: [Violation] = []
        
        do {
            guard let sharedStrings = try file.parseSharedStrings() else {
                print("⚠️ SharedStrings не найдены")
                return []
            }
            
            print("✅ SharedStrings найдены")
            
            let worksheetPaths = try file.parseWorksheetPaths()
            print("🔍 Найдено листов: \(worksheetPaths.count)")
            
            for (index, path) in worksheetPaths.enumerated() {
                print("🔍 Обрабатываем лист \(index + 1): \(path)")
                let worksheet = try file.parseWorksheet(at: path)
                let rows = worksheet.data?.rows.dropFirst() ?? []
                
                print("🔍 Найдено строк данных: \(rows.count)")
                
                for (rowIndex, row) in rows.enumerated() {
                    let values = row.cells.map { $0.stringValue(sharedStrings) ?? "" }
                    print("📊 Строка \(rowIndex + 1): \(values)")
                    guard values.count >= 5 else { 
                        print("⚠️ Строка \(rowIndex + 1) содержит недостаточно данных: \(values.count) колонок")
                        continue 
                    }
                    
                    let violation = Violation(
                        number: Int(values[0]) ?? 0,
                        titie: values[1],
                        subTitle: values[2],
                        description: values[3].isEmpty ? nil : values[3],
                        vid: values[4]
                    )
                    
                    violations.append(violation)
                    print("✅ Добавлено нарушение: \(violation.titie)")
                }
            }
        } catch {
            print("❌ Ошибка чтения Excel: \(error)")
        }
        
        print("📊 Итого загружено нарушений: \(violations.count)")
        return violations
    }
    
    
    static func delete(item: Violation) {
        let allViolations = returnAvialableViolation()

        // Удаляем item по всем значениям полей (полное совпадение)
        let filtered = allViolations.filter { violation in
            return !(
                violation.number == item.number &&
                violation.titie == item.titie &&
                violation.subTitle == item.subTitle &&
                violation.description == item.description &&
                violation.vid == item.vid
            )
        }

        // Получаем старый путь
        guard let oldFilePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("❌ Не удалось получить путь к файлу")
            return
        }

        // Перезаписываем файл
        let wb = Workbook(name: oldFilePath)
        let ws = wb.addWorksheet()

        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения"]
        for (col, value) in headers.enumerated() {
            ws.write(.string(value), [0, col])
        }

        // Запись данных
        for (rowIdx, violation) in filtered.enumerated() {
            let row = rowIdx + 1
            ws.write(.number(Double(violation.number ?? 0)), [row, 0])
            ws.write(.string(violation.titie), [row, 1])
            ws.write(.string(violation.subTitle), [row, 2])
            ws.write(.string(violation.description ?? "-"), [row, 3])
            ws.write(.string(violation.vid ?? "-"), [row, 4])
        }

        wb.close()

        print("✅ Файл перезаписан по пути: \(oldFilePath)")
    }

    
    
    static func addNewViolation(violation: Violation) {
        // Получаем текущие нарушения
        var allViolations = returnAvialableViolation()
        
        // Добавляем новое нарушение
        allViolations.append(violation)
        
        // Получаем путь к файлу
        guard let filePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("❌ Не удалось получить путь к файлу")
            return
        }
        
        // Создаём новый Excel-файл по этому пути
        let wb = Workbook(name: filePath)
        let ws = wb.addWorksheet()
        
        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения"]
        for (col, header) in headers.enumerated() {
            ws.write(.string(header), [0, col])
        }
        
        // Записываем все нарушения, включая новое
        for (rowIdx, item) in allViolations.enumerated() {
            let row = rowIdx + 1 // Начинаем с 1, предполагая, что 0 — это заголовок

            let number = Double(item.number ?? row)
            let title = item.titie
            let subtitle = item.subTitle
            let description = (item.description?.isEmpty ?? true) ? "-" : item.description
            let vid = (item.vid?.isEmpty ?? true) ? "-" : item.vid
            
            print(number, title, subtitle, description ?? "nil", vid ?? "nil")

            ws.write(.number(number), [row, 0])
            ws.write(.string(title), [row, 1])
            ws.write(.string(subtitle), [row, 2])
            ws.write(.string(description ?? "-"), [row, 3])
            ws.write(.string(vid ?? "-"), [row, 4])
        }

        
        // Сохраняем файл
        wb.close()
        
        print("✅ Добавлено новое нарушение. Файл обновлён по пути: \(filePath)")
    }
    
    static func updateViolation(oldViolation: Violation, newViolation: Violation) {
        // Получаем все нарушения
        var allViolations = returnAvialableViolation()
        
        // Находим индекс старого нарушения
        guard let index = allViolations.firstIndex(where: { $0 == oldViolation }) else {
            print("❌ Не удалось найти нарушение для обновления")
            return
        }
        
        // Заменяем старое нарушение на новое
        allViolations[index] = newViolation
        
        // Получаем путь к файлу
        guard let filePath = UserDefaults.standard.string(forKey: "ImportedExcelFilePath") else {
            print("❌ Не удалось получить путь к файлу")
            return
        }
        
        // Перезаписываем файл с обновленными данными
        let wb = Workbook(name: filePath)
        let ws = wb.addWorksheet()
        
        // Заголовки
        let headers = ["№", "Формулировка несоответствия", "Ссылка на нормативный документ", "Примечание", "Вид нарушения"]
        for (col, header) in headers.enumerated() {
            ws.write(.string(header), [0, col])
        }
        
        // Записываем все нарушения
        for (rowIdx, violation) in allViolations.enumerated() {
            let row = rowIdx + 1
            
            let number = Double(violation.number ?? row)
            let title = violation.titie
            let subtitle = violation.subTitle
            let description = violation.description?.count ?? 0 <= 0 ? "--" : violation.description
            let vid = violation.vid?.count ?? 0 <= 0 ? "--" : violation.vid
            
            ws.write(.number(number), [row, 0])
            ws.write(.string(title), [row, 1])
            ws.write(.string(subtitle), [row, 2])
            ws.write(.string(description ?? "-"), [row, 3])
            ws.write(.string(vid ?? "-"), [row, 4])
        }
        
        // Сохраняем файл
        wb.close()
        
        print("✅ Нарушение обновлено. Файл сохранён по пути: \(filePath)")
    }

    
    
    struct Violation: Equatable {
        let number: Int?
        let titie: String
        let subTitle: String
        let description: String?
        let vid: String?
        
        // Добавляем инициализатор для создания копии с изменениями
        init(number: Int?, titie: String, subTitle: String, description: String?, vid: String?) {
            self.number = number
            self.titie = titie
            self.subTitle = subTitle
            self.description = description
            self.vid = vid
        }
        
        // Метод для создания обновленной копии
        func updated(
            number: Int? = nil,
            titie: String? = nil,
            subTitle: String? = nil,
            description: String? = nil,
            vid: String? = nil
        ) -> Violation {
            return Violation(
                number: number ?? self.number,
                titie: titie ?? self.titie,
                subTitle: subTitle ?? self.subTitle,
                description: description ?? self.description,
                vid: vid ?? self.vid
            )
        }
    }
}
