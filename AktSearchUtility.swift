//
//  AktSearchUtility.swift
//  Gazprom
//
//  Утилита для поиска акта по номеру во всех возможных местах
//

import Foundation

/// Утилита для поиска акта по номеру
class AktSearchUtility {
    
    /// Ищет акт по номеру во всех возможных местах
    /// - Parameter number: Номер акта для поиска
    /// - Returns: Результат поиска с информацией о местоположении
    static func findAkt(number: String) -> SearchResult {
        print("🔍 [SEARCH] Начинаем поиск акта №\(number)...")
        print(String(repeating: "=", count: 60))
        
        var results: [SearchLocation] = []
        
        // 1. Проверяем историю актов
        print("📋 [SEARCH] Проверяем историю актов...")
        let history = DataFlowAKT.loadArr()
        if let akt = history.first(where: { $0.number == number }) {
            print("✅ [SEARCH] Акт №\(number) найден в истории!")
            results.append(SearchLocation(
                location: "История актов",
                akt: akt,
                details: "Акт находится в основной истории актов"
            ))
        } else {
            print("❌ [SEARCH] Акт №\(number) не найден в истории")
        }
        
        // 2. Проверяем корзину
        print("🗑️ [SEARCH] Проверяем корзину...")
        let trash = TrashManager.loadTrash()
        if let akt = trash.first(where: { $0.number == number }) {
            print("✅ [SEARCH] Акт №\(number) найден в корзине!")
            results.append(SearchLocation(
                location: "Корзина",
                akt: akt,
                details: "Акт был удален и находится в корзине"
            ))
        } else {
            print("❌ [SEARCH] Акт №\(number) не найден в корзине")
        }
        
        // 3. Проверяем редактируемый акт
        print("✏️ [SEARCH] Проверяем редактируемый акт...")
        if let editableAkt = DataFlowAKT.getEditableAKT(), editableAkt.akt.number == number {
            print("✅ [SEARCH] Акт №\(number) найден как редактируемый!")
            results.append(SearchLocation(
                location: "Редактируемый акт",
                akt: editableAkt.akt,
                details: "Акт находится в режиме редактирования"
            ))
        } else {
            print("❌ [SEARCH] Акт №\(number) не найден как редактируемый")
        }
        
        // 4. Проверяем резервные копии
        print("💾 [SEARCH] Проверяем резервные копии...")
        let backups = BackupManager.listBackups()
        print("   Найдено резервных копий: \(backups.count)")
        
        for backup in backups {
            print("   🔍 Проверяем бэкап: \(backup.fileName)")
            if let akt = findAktInBackup(backupURL: backup.fileURL, number: number) {
                print("✅ [SEARCH] Акт №\(number) найден в бэкапе: \(backup.fileName)")
                results.append(SearchLocation(
                    location: "Резервная копия: \(backup.formattedDate)",
                    akt: akt,
                    details: "Акт найден в резервной копии от \(backup.formattedDate)"
                ))
            }
        }
        
        print(String(repeating: "=", count: 60))
        print("📊 [SEARCH] Результаты поиска:")
        print("   Найдено совпадений: \(results.count)")
        
        return SearchResult(
            number: number,
            found: !results.isEmpty,
            locations: results
        )
    }
    
    /// Ищет акт в конкретном бэкапе
    private static func findAktInBackup(backupURL: URL, number: String) -> AKT? {
        guard let jsonData = try? Data(contentsOf: backupURL) else {
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backup = try? decoder.decode(AppBackup.self, from: jsonData) else {
            return nil
        }
        
        // Ищем в основных актах
        if let akt = backup.akts.first(where: { $0.number == number }) {
            return akt
        }
        
        // Ищем в корзине бэкапа
        if let akt = backup.trash.first(where: { $0.number == number }) {
            return akt
        }
        
        // Ищем в редактируемом акте бэкапа
        if let editableAkt = backup.editableAkt, editableAkt.akt.number == number {
            return editableAkt.akt
        }
        
        return nil
    }
    
    /// Восстанавливает акт из найденного местоположения
    static func restoreAkt(number: String) -> Bool {
        print("🔄 [RESTORE] Начинаем восстановление акта №\(number)...")
        
        let searchResult = findAkt(number: number)
        
        guard searchResult.found else {
            print("❌ [RESTORE] Акт №\(number) не найден ни в одном месте")
            return false
        }
        
        // Если акт найден в корзине, восстанавливаем его
        if searchResult.locations.contains(where: { $0.location == "Корзина" }) {
            print("🔄 [RESTORE] Восстанавливаем акт из корзины...")
            return TrashManager.restoreAktByNumber(number)
        }
        
        // Если акт найден в бэкапе, извлекаем его и добавляем в историю
        if let backupLocation = searchResult.locations.first(where: { $0.location.contains("Резервная копия") }) {
            print("🔄 [RESTORE] Акт найден в резервной копии, извлекаем...")
            let akt = backupLocation.akt
            
            // Проверяем, нет ли уже такого акта в истории
            var history = DataFlowAKT.loadArr()
            if !history.contains(where: { $0.id == akt.id || $0.number == akt.number }) {
                history.append(akt)
                DataFlowAKT.saveArr(arr: history)
                print("✅ [RESTORE] Акт №\(number) восстановлен из резервной копии и добавлен в историю")
                return true
            } else {
                print("ℹ️ [RESTORE] Акт №\(number) уже существует в истории")
                return true
            }
        }
        
        // Если акт уже в истории или редактируемый, он уже доступен
        if searchResult.locations.contains(where: { $0.location == "История актов" || $0.location == "Редактируемый акт" }) {
            print("✅ [RESTORE] Акт №\(number) уже доступен в приложении")
            return true
        }
        
        return false
    }
    
    /// Быстрый поиск акта номер 25
    static func findAkt25() -> SearchResult {
        return findAkt(number: "25")
    }
    
    /// Восстанавливает акт номер 25, если он найден
    static func restoreAkt25() -> Bool {
        return restoreAkt(number: "25")
    }
}

// MARK: - Search Result Models
struct SearchResult {
    let number: String
    let found: Bool
    let locations: [SearchLocation]
    
    var summary: String {
        if !found {
            return "Акт №\(number) не найден ни в одном месте"
        }
        
        var summary = "Акт №\(number) найден в \(locations.count) месте(ах):\n"
        for (index, location) in locations.enumerated() {
            summary += "\(index + 1). \(location.location)\n"
            summary += "   \(location.details)\n"
        }
        return summary
    }
}

struct SearchLocation {
    let location: String
    let akt: AKT
    let details: String
}


