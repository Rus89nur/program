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
    
    init(number: String, date: Date, comission: [ComissionPeople], organization: Organization, objectsCheck: [ObjectCheck], predstavitelyComission: [PredstavitelyComission], violations: [Violations], description: String, actustranenDate: Date, actPredostavlenDate: Date, actUtverzdenDate: Date, urlAct: URL, realDateCreate: Date) {
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
    
    init(title: String) {
        self.id = UUID()
        self.title = title
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
    
    init( title: String, mesto: String, urlToPravilo: String, photo: [Data]) {
        self.id = UUID()
        self.title = title
        self.mesto = mesto
        self.urlToPravilo = urlToPravilo
        self.photo = photo
    }
}

struct PredstavitelyComission: Codable, Identifiable {
    let id: UUID
    let fio: String
    let jobTitle: String
    
    init(fio: String, jobTitle: String) {
        self.id = UUID()
        self.fio = fio
        self.jobTitle = jobTitle
    }
}
