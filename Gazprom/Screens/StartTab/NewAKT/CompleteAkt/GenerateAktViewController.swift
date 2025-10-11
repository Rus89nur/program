//
//  GenerateAktViewController.swift
//  Gazprom
//
//  Created by Владимир on 17.07.2025.
//

import UIKit
import UniformTypeIdentifiers
import QuickLook

class GenerateAktViewController: UIViewController, QLPreviewControllerDelegate, QLPreviewControllerDataSource {
    
    private let generateViewModel = GenerateViewModel()
    
    let viewModel: MainAKTViewModel
    let comissionPeople: [ComissionPeople]
    var date: Date
    let aktNumber: String
    let organizations: [Organization]
    let objectCheck: [ObjectCheck]
    let violations: [Violations]
    let descripUser: String
    let predstavitely: [PredstavitelyComission]
    
    var akt: AKT?
    var documentURL: URL?
    
    private let ustranenDatePicker = UIDatePicker() //дата устранения - ustranenDate
    private let predostavlenDatePicker = UIDatePicker() //дата предоставления - predostavlenDate
    private let utverzdenDatePicker = UIDatePicker() //дата утверждения - UtverzderDate
    
    init(viewModel: MainAKTViewModel, comissionPeople: [ComissionPeople], date: Date, aktNumber: String, organizations: [Organization], objectCheck: [ObjectCheck], violations: [Violations], descripUser: String, predstavitely: [PredstavitelyComission], akt: AKT?) {
        self.viewModel = viewModel
        self.comissionPeople = comissionPeople
        self.date = date
        self.aktNumber = aktNumber
        self.organizations = organizations
        self.objectCheck = objectCheck
        self.violations = violations
        self.descripUser = descripUser
        self.predstavitely = predstavitely
        self.akt = akt
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        // Очищаем callback при уходе с экрана
        viewModel.templateModel.autoSaveCallback = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Генерация"
        
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // Сначала проверяем, есть ли сохраненные даты
        if let ustran = viewModel.templateModel.ustranenDatePicker, let predos = viewModel.templateModel.predostavlenDatePicker, let utverzd = viewModel.templateModel.utverzdenDatePicker {
            ustranenDatePicker.date = ustran
            predostavlenDatePicker.date = predos
            utverzdenDatePicker.date = utverzd
        } else {
            // Если сохраненных дат нет, устанавливаем даты по умолчанию
            ustranenDateChanged()
        }
        setupNav()
    }
    
    private func setupNav() {
        let goBackButton = UIButton(type: .system)
        goBackButton.setBackgroundImage(UIImage(systemName: "house"), for: .normal)
        let item = UIBarButtonItem(customView: goBackButton)
        goBackButton.snp.makeConstraints { make in
            make.height.width.equalTo(24)
        }
        goBackButton.alpha = 0.5
        self.navigationItem.rightBarButtonItem = item
        goBackButton.addTarget(self, action: #selector(goHome), for: .touchUpInside)
    }
    
    @objc private func goHome() {
        navigationController?.popToRootViewController(animated: true)
    }
    
    let bigIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .large)
        view.backgroundColor = .systemBackground.withAlphaComponent(0.8)
        view.color = .label
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupUI()
        checkOld()
        
        // Добавляем observer для автоматического пересчета дат при изменении даты проверки
        viewModel.templateModel.autoSaveCallback = { [weak self] in
            DispatchQueue.main.async {
                self?.updateDatesFromTemplate()
            }
        }
    }
    
    private func checkOld() {
        if let a = akt {
            ustranenDatePicker.date = a.actustranenDate
            predostavlenDatePicker.date = a.actPredostavlenDate
            utverzdenDatePicker.date = a.actUtverzdenDate
        }
    }

    private func setupUI() {
        let genButton = UIFactory.createButton(title: "Создать акт", color: .systemGreen)
        view.addSubview(genButton)
        genButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.bottom.equalTo(view.snp.centerY).offset(-8)
        }
        genButton.addTarget(self, action: #selector(openAlert), for: .touchUpInside)
        
        let selectButton = UIFactory.createButton(title: "Выбрать шаблон", color: .systemBlue)
        view.addSubview(selectButton)
        selectButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(view.snp.centerY).offset(8)
        }
        selectButton.addTarget(self, action: #selector(selectShab), for: .touchUpInside)
        
        // Кнопка для пересчета дат
        let recalculateButton = UIFactory.createButton(title: "Пересчитать даты", color: .systemOrange)
        view.addSubview(recalculateButton)
        recalculateButton.snp.makeConstraints { make in
            make.left.right.equalToSuperview().inset(16)
            make.height.equalTo(54)
            make.top.equalTo(selectButton.snp.bottom).offset(8)
        }
        recalculateButton.addTarget(self, action: #selector(recalculateDates), for: .touchUpInside)
        
        
        let ustranenDateLabel = UILabel()
        ustranenDateLabel.text = "Дата устранения нарушений:"
        ustranenDateLabel.textColor = .label
        ustranenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(ustranenDateLabel)
        ustranenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(16)
        }
        ustranenDatePicker.datePickerMode = .date
        ustranenDatePicker.locale = .init(identifier: "ru_RU")
   //     ustranenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        view.addSubview(ustranenDatePicker)
        ustranenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(ustranenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
        
        let predostavlenDateLabel = UILabel()
        predostavlenDateLabel.text = "Дата предоставления:"
        predostavlenDateLabel.textColor = .label
        predostavlenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(predostavlenDateLabel)
        predostavlenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(ustranenDatePicker.snp.bottom).offset(12)
        }
        
        
        view.addSubview(predostavlenDatePicker)
        predostavlenDatePicker.datePickerMode = .date
        predostavlenDatePicker.locale = .init(identifier: "ru_RU")
        predostavlenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(predostavlenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
     //   predostavlenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        
        let utverzdenDateLabel = UILabel()
        utverzdenDateLabel.text = "Дата утверждения:"
        utverzdenDateLabel.textColor = .label
        utverzdenDateLabel.font = .systemFont(ofSize: 16, weight: .regular)
        view.addSubview(utverzdenDateLabel)
        utverzdenDateLabel.snp.makeConstraints { make in
            make.left.equalToSuperview().inset(16)
            make.top.equalTo(predostavlenDatePicker.snp.bottom).offset(12)
        }
        
        utverzdenDatePicker.datePickerMode = .date
        utverzdenDatePicker.locale = .init(identifier: "ru_RU")
        view.addSubview(utverzdenDatePicker)
        utverzdenDatePicker.snp.makeConstraints { make in
            make.centerY.equalTo(utverzdenDateLabel)
            make.right.equalToSuperview().inset(16)
            make.left.equalTo(ustranenDateLabel.snp.right).inset(-12)
        }
       // utverzdenDatePicker.addTarget(self, action: #selector(ustranenDateChanged), for: .valueChanged)
        
        view.addSubview(bigIndicator)
        bigIndicator.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        ustranenDateChanged()
    }
    

    
    
    @objc private func ustranenDateChanged() {
        let proverkaDate = date
        
        // Дата устранения = +1 месяц от даты проверки
        if let ustranenDate = Calendar.current.date(byAdding: .month, value: 1, to: proverkaDate) {
            ustranenDatePicker.date = ustranenDate
            
            // Дата предоставления отчета = дата устранения (тоже +1 месяц от даты проверки)
            predostavlenDatePicker.date = ustranenDate
        }
        
        // Дата утверждения = +7 дней от даты проверки
        if let utverzdenDate = Calendar.current.date(byAdding: .day, value: 7, to: proverkaDate) {
            utverzdenDatePicker.date = utverzdenDate
        }
        
        // Сохраняем рассчитанные даты в модель
        viewModel.templateModel.ustranenDatePicker = ustranenDatePicker.date
        viewModel.templateModel.predostavlenDatePicker = predostavlenDatePicker.date
        viewModel.templateModel.utverzdenDatePicker = utverzdenDatePicker.date
        
        print("📅 Даты пересчитаны:")
        print("   Дата проверки: \(proverkaDate)")
        print("   Дата устранения: \(ustranenDatePicker.date)")
        print("   Дата предоставления: \(predostavlenDatePicker.date)")
        print("   Дата утверждения: \(utverzdenDatePicker.date)")
    }
    
    @objc private func recalculateDates() {
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // Пересчитываем даты
        ustranenDateChanged()
        
        // Показываем уведомление пользователю
        let alert = UIAlertController(title: "Даты пересчитаны", message: "Даты обновлены согласно текущей дате проверки", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateDatesFromTemplate() {
        // Обновляем дату проверки из templateModel
        if let templateDate = viewModel.templateModel.date {
            date = templateDate
        }
        
        // Пересчитываем даты только если они не были установлены вручную
        if viewModel.templateModel.ustranenDatePicker == nil || 
           viewModel.templateModel.predostavlenDatePicker == nil || 
           viewModel.templateModel.utverzdenDatePicker == nil {
            ustranenDateChanged()
        }
    }
    
    @objc private func openAlert() {
        let alert = UIAlertController(title: "Внимание!", message: "Проверьте дату устранения нарушений и дату предоставления с датой утверждения акта", preferredStyle: .alert)
        let okaction = UIAlertAction(title: "Все в порядке, спасибо", style: .default) { [weak self] _ in
            self?.create()
        }
        alert.addAction(okaction)
        
        let cancelAlert = UIAlertAction(title: "Проверить", style:  .cancel)
        alert.addAction(cancelAlert)
        
        self.present(alert, animated: true)
    }
    
    @objc private func create() {
        // используем сохранённый ПОЛНЫЙ путь
        
        
        if let filePath = UserDefaults.standard.string(forKey: "ShabPath") {
            let url = URL(fileURLWithPath: filePath)
            
            print("Файл по пути существует? \(FileManager.default.fileExists(atPath: url.path))")

            if FileManager.default.fileExists(atPath: url.path) {
                // Отладочная информация о датах перед генерацией
                print("🔍 Отладочная информация перед генерацией:")
                print("   Дата предоставления: \(predostavlenDatePicker.date)")
                print("   Дата устранения: \(ustranenDatePicker.date)")
                print("   Дата утверждения: \(utverzdenDatePicker.date)")
                
                generateViewModel.generate(
                    url: url,
                    comissionPeople: comissionPeople,
                    date: date,
                    aktNumber: aktNumber,
                    organizations: organizations,
                    objectCheck: objectCheck,
                    violations: violations,
                    descripUser: descripUser,
                    predstav: predstavitely,
                    datePredostavlen: predostavlenDatePicker.date,
                    dateUstranen: ustranenDatePicker.date,
                    utverzdenDate: utverzdenDatePicker.date, escaping: { [weak self] url in
                        guard let self = self else { return }
                        bigIndicator.stopAnimating()
                        if let unwURL = url {
                            // Если это редактирование существующего акта, обновляем его
                            if let existingAkt = self.akt {
                                print("🔄 Редактируем существующий акт №\(existingAkt.number) с ID: \(existingAkt.id)")
                                let updatedAkt = existingAkt.updated(with: unwURL)
                                print("   Обновленный акт с ID: \(updatedAkt.id)")
                                
                                // Сохраняем изменения в редактируемый акт
                                viewModel.saveChangesToEditableAkt(updatedAkt)
                                print("   ✅ Изменения сохранены в редактируемый акт")
                            } else {
                                print("➕ Создаем новый акт №\(aktNumber)")
                                // Если это новый акт, создаем его
                                let act = AKT(
                                    number: aktNumber,
                                    date: date,
                                    comission: comissionPeople,
                                    organization: organizations.first ?? Organization(title: "-"),
                                    objectsCheck: objectCheck,
                                    predstavitelyComission: predstavitely,
                                    violations: violations,
                                    description: descripUser,
                                    actustranenDate: ustranenDatePicker.date,
                                    actPredostavlenDate: predostavlenDatePicker.date,
                                    actUtverzdenDate: utverzdenDatePicker.date,
                                    urlAct: unwURL, realDateCreate: Date.now
                                )
                                print("   Новый акт с ID: \(act.id)")
                                
                                // Создаем новый акт и делаем его редактируемым
                                viewModel.createNewAktAndMakeEditable(act)
                                print("   ✅ Новый акт создан и сделан редактируемым")
                            }
                            
                            openDoc(url: unwURL)
                        }
                    }
                )
            } else {
                print("Файл не найден, вызовем повторный выбор")
                bigIndicator.stopAnimating()
                selectShab()
            }
        } else {
            print("Шаблон не выбран, откроем выбор")
            bigIndicator.stopAnimating()
            selectShab()
        }
    }

    
//    private func opedDoc(url: URL) {
//        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//
//        self.present(activityVC, animated: true, completion: nil)
//    }
    
    private func openDoc(url: URL) {
        // Проверяем существование файла
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ Файл не существует: \(url.path)")
            showAlert(title: "Ошибка", message: "Файл не найден или недоступен")
            return
        }
        
        // Проверяем размер файла
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? NSNumber ?? 0
            if fileSize.intValue == 0 {
                print("❌ Файл пустой: \(url.path)")
                showAlert(title: "Ошибка", message: "Файл пустой или поврежден")
                return
            }
        } catch {
            print("❌ Ошибка при проверке файла: \(error)")
            showAlert(title: "Ошибка", message: "Не удалось проверить файл")
            return
        }
        
        self.documentURL = url
        let previewController = QLPreviewController()
        previewController.dataSource = self
        previewController.delegate = self
        self.present(previewController, animated: true, completion: nil)
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
        return documentURL == nil ? 0 : 1
    }
    
    func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
        return documentURL! as QLPreviewItem
    }
    
    
    @objc private func selectShab() {
        let docxType = UTType(filenameExtension: "docx") ?? .item
        
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [docxType], asCopy: true)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        documentPicker.modalPresentationStyle = .formSheet
        

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let topVC = windowScene.windows.first?.rootViewController {
            topVC.present(documentPicker, animated: true, completion: nil)
        }
    }

}


extension GenerateAktViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let sourceURL = urls.first else { return }

        let fileManager = FileManager.default
        let destinationURL = getDocumentsDirectory().appendingPathComponent(sourceURL.lastPathComponent)

        var success = false

        if sourceURL.startAccessingSecurityScopedResource() {
            success = true
        }

        defer {
            if success {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Файл скопирован в: \(destinationURL.path)")

            // ✅ Сохраняем путь только после успешного копирования
            UserDefaults.standard.set(destinationURL.path, forKey: "ShabPath")

        } catch {
            print("❌ Ошибка при копировании файла: \(error.localizedDescription)")
            // 🔴 Удаляем старое значение, если копирование не удалось
            UserDefaults.standard.removeObject(forKey: "ShabPath")
        }

    }




    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }



    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        print("Отмена выбора документа")
    }
}
