//
//  GenerateViewModel.swift
//  Gazprom
//
//  Created by Владимир on 17.07.2025.
//

import Foundation
import UIKit

class GenerateViewModel {
    
    //TODO: -доделать базовую подстановку
    
    func generate(url: URL, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstav: [PredstavitelyComission], datePredostavlen: Date, dateUstranen: Date, utverzdenDate: Date, escaping: @escaping(URL?) -> Void) {

        if url.isFileURL {
            do {
                print("Файл загружен локально: \(url.lastPathComponent)")
                
                let comissionString = comissionPeople
                    .map { "\($0.jobTitle.lowercased()) - \($0.fio)" }
                    .joined(separator: ", ")
                
                let predstavString = predstav
                    .map { "\($0.jobTitle.lowercased()) - \($0.fio)" }
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
                
                print(swapData)

                processDocxTemplate(from: url, with: swapData, violations: violations, predstav: comissionPeople) { resultURL in
                       if let finalURL = resultURL {
                           escaping(finalURL)
                           print("Документ с подстановками сохранен: \(finalURL)")
                       } else {
                           escaping(nil)
                       }
                   }

            }
        }
    }
    
    func processDocxTemplate(from url: URL,
                             with swapData: [String: Any],
                             violations: [Violations],
                             predstav: [ComissionPeople],
                             completion: @escaping (URL?) -> Void) {
        let fileManager = FileManager()
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
            try fileManager.unzipItem(at: url, to: tempDir)
            
            let documentXML = tempDir.appendingPathComponent("word/document.xml")
            var xmlString = try String(contentsOf: documentXML, encoding: .utf8)

            guard let rowTemplateRange = xmlString.range(
                of: "<w:tr(?:(?!<w:tr).)*?PoradNum(?:(?!<w:tr).)*?</w:tr>",
                options: [.regularExpression]
            ) else {
                print("❌ Шаблонная строка с 'PoradNum' не найдена")
                completion(nil)
                return
            }

            let rowTemplate = String(xmlString[rowTemplateRange])
            var allRows = ""
            
            for (index, violation) in violations.enumerated() {
                var row = rowTemplate
                row = row.replacingOccurrences(of: "PoradNum", with: "\(index + 1)" + ".")
                row = row.replacingOccurrences(of: "TitleViolatation", with: violation.mesto + ".")
                row = row.replacingOccurrences(of: "ddescpitVi", with: violation.title + ".")
                row = row.replacingOccurrences(of: "urlDoc", with: violation.urlToPravilo + ".")
                allRows += row
            }

            xmlString.replaceSubrange(rowTemplateRange, with: allRows)
            
            
            if let markerRange = xmlString.range(of: "PredVoice") {
                var predstavTable = "<w:tbl>"

                for person in predstav {
                    let fullName = person.fio
                    let position = person.jobTitle.capitalized
                    let label = "\(position) — \(fullName)"

                    let row = """
                    <w:tr>
                      <w:tc>
                        <w:tcPr><w:tcW w:w="4000" w:type="dxa"/></w:tcPr>
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
                        <w:tcPr><w:tcW w:w="8000" w:type="dxa"/></w:tcPr>
                        <w:p>
                          <w:pPr><w:jc w:val="right"/></w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="28"/>
                            </w:rPr>
                            <w:t>_______________________________</w:t>
                          </w:r>
                        </w:p>
                        <w:p>
                          <w:pPr>
                            <w:jc w:val="right"/>
                            <w:spacing w:before="100" w:after="0"/>
                          </w:pPr>
                          <w:r>
                            <w:rPr>
                              <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/>
                              <w:sz w:val="20"/>
                            </w:rPr>
                            <w:t>(подпись)&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;&#x00A0;</w:t>
                          </w:r>
                        </w:p>
                      </w:tc>
                    </w:tr>
                    """

                    predstavTable += row
                }

                predstavTable += "</w:tbl>"
                xmlString.replaceSubrange(markerRange, with: predstavTable)
            }

           
            
            guard let photoRowRange = xmlString.range(
                of: "<w:tr[^>]*>(?:(?!<\\/w:tr>).)*?tempOne.*?<\\/w:tr>",
                options: [.regularExpression]
            ) else {
                print("❌ Не удалось найти шаблон строки с numbPho")
                return
            }

            let photoRowTemplate = String(xmlString[photoRowRange])
            var allPhotoRows = ""
            var globalImageIndex = 0
            var relsSnippets = ""
            var violNumb = 0
            var globIndex = 0
            
            print(photoRowTemplate)
            print("\nDOOOO")
            
            let mediaDir = tempDir.appendingPathComponent("word/media")
            if !fileManager.fileExists(atPath: mediaDir.path) {
                try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)
            }

            
            for (_, violation) in violations.enumerated() {
                violNumb += 1
                guard !violation.photo.isEmpty else {
                    continue }
                globIndex += 1
                var row = photoRowTemplate
                row = row.replacingOccurrences(of: "tempOne", with: "\(globIndex).")
                row = row.replacingOccurrences(of: "tempTwo", with: "\(violNumb).")

                var imageXMLSnippets = ""

                for photoData in violation.photo {
                    globalImageIndex += 1

                    // 1. Получаем UIImage из Data
                    guard let originalImage = UIImage(data: photoData) else { continue }

                    // 2. Перерисовываем изображение без EXIF
                    let fixedImage = fixImageOrientation(image: originalImage)

                    // 3. Сохраняем новое изображение как JPEG
                    guard let fixedImageData = fixedImage.jpegData(compressionQuality: 1.0) else { continue }

                    // 4. Сохраняем его в файл
                    let imageName = "image\(globalImageIndex).jpg"
                    let imagePath = mediaDir.appendingPathComponent(imageName)
                    try fixedImageData.write(to: imagePath)

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
            }

          //   Обновляем relationships один раз после цикла
            let relsPath = tempDir.appendingPathComponent("word/_rels/document.xml.rels")
            var relsXML = try String(contentsOf: relsPath, encoding: .utf8)
            relsXML = relsXML.replacingOccurrences(of: "</Relationships>", with: relsSnippets + "</Relationships>")
            try relsXML.write(to: relsPath, atomically: true, encoding: .utf8)

          //   Заменяем в document.xml шаблон одной строки на все строки
            xmlString.replaceSubrange(photoRowRange, with: allPhotoRows)


            for (key, value) in swapData {
                let placeholder = key
                if xmlString.contains(placeholder) {
                    xmlString = xmlString.replacingOccurrences(of: placeholder, with: "\(value)")
                    print("✅ Заменен плейсхолдер '\(key)' на '\(value)'")
                } else {
                    print("⚠️ Плейсхолдер '\(placeholder)' не найден в шаблоне")
                    
                    // Дополнительная диагностика для predostavlenDate
                    if placeholder == "predostavlenDate" {
                        print("🔍 Ищем варианты 'predostavlenDate' в XML:")
                        let lines = xmlString.components(separatedBy: .newlines)
                        for (index, line) in lines.enumerated() {
                            if line.lowercased().contains("predostavlen") || line.lowercased().contains("предоставлен") {
                                print("   Строка \(index + 1): \(line)")
                            }
                        }
                    }
                }
            }
            
            // Дополнительная проверка для всех плейсхолдеров дат
            let datePlaceholders = ["predostavlenDate", "ustranenDate", "UtverzderDate"]
            for placeholder in datePlaceholders {
                if xmlString.contains(placeholder) {
                    print("❌ В шаблоне все еще остался текст '\(placeholder)' - замена не сработала")
                    
                    // Попробуем заменить вручную для predostavlenDate
                    if placeholder == "predostavlenDate" {
                        let predostavlenie = swapData["predostavlenDate"] as? String ?? ""
                        
                        // Пробуем разные варианты написания
                        let variants = [
                            "predostavlenDate",
                            "PredostavlenDate", 
                            "PREDOSTAVLENDATE",
                            "predostavlenDate",
                            "predostavlen_date",
                            "Predostavlen_Date"
                        ]
                        
                        for variant in variants {
                            if xmlString.contains(variant) {
                                xmlString = xmlString.replacingOccurrences(of: variant, with: predostavlenie)
                                print("🔧 Заменен вариант '\(variant)' на '\(predostavlenie)'")
                                break
                            }
                        }
                        
                        // Если ничего не найдено, попробуем найти по регулярному выражению
                        if xmlString.contains("predostavlenDate") {
                            print("🔍 Пробуем найти по регулярному выражению...")
                            let pattern = "predostavlenDate"
                            if let range = xmlString.range(of: pattern, options: .regularExpression) {
                                xmlString.replaceSubrange(range, with: predostavlenie)
                                print("🔧 Заменен по регулярному выражению на '\(predostavlenie)'")
                            }
                        }
                    }
                } else {
                    print("✅ Текст '\(placeholder)' успешно заменен")
                }
            }

            
            //TODO:  ЕСЛИ ДОБАВЛЯЕМ ОДНО НАРУШЕНИЕ _ ВСЕ РАБОТЕТ, А ЕСЛИ НЕСКОЛЬОК_ ТО НЕ РАБОТАЕТ

            try xmlString.write(to: documentXML, atomically: true, encoding: .utf8)
            let newDocxURL = fileManager.temporaryDirectory.appendingPathComponent("result_\(UUID().uuidString).docx")
            try fileManager.zipItem(at: tempDir, to: newDocxURL, shouldKeepParent: false)

            completion(newDocxURL)
        } catch {
            print("❌ Ошибка при обработке DOCX: \(error)")
            completion(nil)
        }
    }

    func fixImageOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }


    
    func formatData(date: Date) -> String {
        let formatte = DateFormatter()
        formatte.dateFormat = "dd.MM.yyyy"
        return formatte.string(from: date)
    }
    
}


