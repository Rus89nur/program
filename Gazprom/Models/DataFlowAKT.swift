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
    
    init(akt: AKT, isEditable: Bool = true) {
        self.id = akt.id
        self.akt = akt
        self.isEditable = isEditable
        self.lastModified = Date()
    }
}

class DataFlowAKT {
    
    // MARK: - File Paths
    private static let historyFileName = "AKT.plist"
    private static let editableFileName = "EditableAKT.plist"
    
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
            let arr = try JSONDecoder().decode([AKT].self, from: data)
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
            try data.write(to: filePath)
        } else {
            throw NSError(domain: "SaveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get document directory"])
        }
    }
    
    static func saveHistoryArr(arr: [AKT]) {
        do {
            let data = try JSONEncoder().encode(arr)
            try saveHistoryArrToFile(data: data)
        } catch {
            print("Failed to encode or save history AKT: \(error)")
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
            return editableAkt
        } catch {
            print("Failed to load editable AKT: \(error)")
            return nil
        }
    }
    
    private static func saveEditableAKTToFile(data: Data) throws {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = documentDirectory.appendingPathComponent(editableFileName)
            try data.write(to: filePath)
        } else {
            throw NSError(domain: "SaveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get document directory"])
        }
    }
    
    static func saveEditableAKT(_ editableAkt: EditableAKT) {
        do {
            let data = try JSONEncoder().encode(editableAkt)
            try saveEditableAKTToFile(data: data)
            print("✅ Редактируемый АКТ сохранен: №\(editableAkt.akt.number)")
        } catch {
            print("Failed to encode or save editable AKT: \(error)")
        }
    }
    
    static func deleteEditableAKT() {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get document directory")
            return
        }
        let filePath = documentDirectory.appendingPathComponent(editableFileName)
        do {
            try fileManager.removeItem(at: filePath)
            print("✅ Редактируемый АКТ удален")
        } catch {
            print("Failed to delete editable AKT: \(error)")
        }
    }
    
    // MARK: - Combined Operations
    static func saveArr(arr: [AKT]) {
        // Сохраняем в историю (read-only)
        saveHistoryArr(arr: arr)
    }
    
    static func loadArr() -> [AKT] {
        return loadHistoryArrFromFile() ?? []
    }
    
    // MARK: - New Methods for Editable AKT System
    static func createEditableAKT(from akt: AKT) -> EditableAKT {
        let editableAkt = EditableAKT(akt: akt, isEditable: true)
        saveEditableAKT(editableAkt)
        return editableAkt
    }
    
    static func updateEditableAKT(_ updatedAkt: AKT) {
        let editableAkt = EditableAKT(akt: updatedAkt, isEditable: true)
        saveEditableAKT(editableAkt)
    }
    
    static func getEditableAKT() -> EditableAKT? {
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
        guard let editableAkt = loadEditableAKTFromFile() else { 
            print("⚠️ Нет редактируемого акта для переноса в историю")
            return 
        }
        
        print("🔄 Переносим АКТ №\(editableAkt.akt.number) в историю")
        print("   Количество нарушений: \(editableAkt.akt.violations.count)")
        
        // Загружаем текущую историю
        var historyArray = loadHistoryArrFromFile() ?? []
        
        // Ищем существующий акт с таким же номером
        if let existingIndex = historyArray.firstIndex(where: { $0.number == editableAkt.akt.number }) {
            print("   Найден существующий акт №\(editableAkt.akt.number) в позиции \(existingIndex)")
            print("   Удаляем старую версию и заменяем на новую")
            
            // Удаляем старую версию
            historyArray.remove(at: existingIndex)
            
            // Добавляем новую версию
            historyArray.append(editableAkt.akt)
        } else {
            print("   Акт №\(editableAkt.akt.number) не найден в истории, добавляем как новый")
            // Если акт не найден, добавляем как новый
            historyArray.append(editableAkt.akt)
        }
        
        // Сохраняем обновленную историю
        saveHistoryArr(arr: historyArray)
        
        // Удаляем редактируемый акт
        deleteEditableAKT()
        
        print("✅ АКТ №\(editableAkt.akt.number) обновлен в истории")
        print("   Общее количество актов в истории: \(historyArray.count)")
    }
    
    // MARK: - Replace Editable AKT (for updates)
    static func replaceEditableAKT(with newAkt: AKT) {
        // Удаляем старый редактируемый акт
        deleteEditableAKT()
        
        // Создаем новый редактируемый акт
        _ = createEditableAKT(from: newAkt)
        
        print("✅ Редактируемый АКТ заменен на №\(newAkt.number)")
    }
    
    // MARK: - Update Existing AKT in History
    static func updateExistingAktInHistory(_ updatedAkt: AKT) {
        print("🔄 Обновляем существующий АКТ №\(updatedAkt.number) в истории")
        
        // Загружаем текущую историю
        var historyArray = loadHistoryArrFromFile() ?? []
        
        // Ищем существующий акт с таким же номером
        if let existingIndex = historyArray.firstIndex(where: { $0.number == updatedAkt.number }) {
            print("   Найден существующий акт №\(updatedAkt.number) в позиции \(existingIndex)")
            print("   Заменяем на обновленную версию")
            
            // Заменяем старую версию на новую
            historyArray[existingIndex] = updatedAkt
            
            // Сохраняем обновленную историю
            saveHistoryArr(arr: historyArray)
            
            print("✅ АКТ №\(updatedAkt.number) обновлен в истории")
        } else {
            print("   Акт №\(updatedAkt.number) не найден в истории, добавляем как новый")
            // Если акт не найден, добавляем как новый
            historyArray.append(updatedAkt)
            saveHistoryArr(arr: historyArray)
        }
    }
}
