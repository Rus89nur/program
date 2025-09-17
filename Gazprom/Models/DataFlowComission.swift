//
//  DataFlowComission.swift
//  Gazprom
//
//  Created by Владимир on 06.07.2025.
//

import Foundation

class DataFlowComission {
    
    static func loadHistoryArrFromFile() -> [ComissionPeople]? {
        let fileManager = FileManager.default
        guard let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Unable to get document directory")
            return nil
        }
        let filePath = documentDirectory.appendingPathComponent("ComissionPeople.plist")
        do {
            let data = try Data(contentsOf: filePath)
            let arr = try JSONDecoder().decode([ComissionPeople].self, from: data)
            return arr
        } catch {
            print("Failed to load or decode athleteArr: \(error)")
            return nil
        }
    }
    
    private static func saveArrToFile(data: Data) throws {
        let fileManager = FileManager.default
        if let documentDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let filePath = documentDirectory.appendingPathComponent("ComissionPeople.plist")
            try data.write(to: filePath)
        } else {
            throw NSError(domain: "SaveError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to get document directory"])
        }
    }
    
    static func saveArr(arr: [ComissionPeople]) {
        do {
            let data = try JSONEncoder().encode(arr)
            try saveArrToFile(data: data)
        } catch {
            print("Failed to encode or save AKT: \(error)")
        }
    }
    
    static func loadArr() -> [ComissionPeople] {
        return loadHistoryArrFromFile() ?? []
    }
}
