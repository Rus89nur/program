//
//  TemplateModel.swift
//  Gazprom
//
//  Created by Владимир on 04.08.2025.
//

import Foundation

class TemplateModel {
    
    var comissionPeople: [ComissionPeople]?
    var date: Date?
    var aktNumber: String?
    var organizations: [Organization]?
    var objectCheck: [ObjectCheck]?
    var violations: [Violations]?
    var descripUser: String?
    var predstavitely: [PredstavitelyComission]?
    var ustranenDatePicker: Date?
    var predostavlenDatePicker: Date?
    var utverzdenDatePicker: Date?
    
    func reset() {
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
    }
}
