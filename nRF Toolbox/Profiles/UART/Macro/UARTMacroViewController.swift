//
//  UARTMacroViewController.swift
//  nRF Toolbox
//
//  Created by Nick Kibysh on 17/01/2020.
//  Copyright © 2020 Nordic Semiconductor. All rights reserved.
//

import UIKit

class UARTMacroViewController: UIViewController, AlertPresenter {
    private let btManager: BluetoothManager

    @IBOutlet private var rootStackView: UIStackView!
    @IBOutlet var commandListCollectionView: UARTCommandListCollectionView!
    @IBOutlet var commandOrderTableView: UITableView!
    @IBOutlet var timeStepper: UIStepper!
    @IBOutlet var playBtn: NordicButton!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var nameTextField: UITextField!
    
    private let preset: UARTPreset
    private var macros: [UARTCommandModel] = []
    private var fileUrl: URL?
    
    private lazy var dispatchSource = DispatchSource.makeTimerSource(queue: .main)
    
    init(bluetoothManager: BluetoothManager, preset: UARTPreset, macroUrl: URL? = nil) {
        self.btManager = bluetoothManager
        self.preset = preset
        self.fileUrl = macroUrl
        super.init(nibName: "UARTMacroViewController", bundle: .main)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        commandOrderTableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        commandListCollectionView.preset = preset
        commandListCollectionView.commandListDelegate = self
        
        commandOrderTableView.isEditing = true
        
        playBtn.style = .mainAction
        navigationItem.title = "Create new Macro"
        
        let saveBtn = UIBarButtonItem(barButtonSystemItem: .save, target: self, action: #selector(save))
        
        navigationItem.rightBarButtonItem = saveBtn
        
        commandListCollectionView.backgroundColor = .white
        
        self.fileUrl.flatMap(preloadMacro(_:))
        
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
        }
    }
    
    @IBAction func play() {
        let macro = UARTMacro(name: nameTextField.text ?? "", delay: Int(timeStepper.value), commands: macros)
        btManager.send(macro: macro)
    }
    
    @IBAction func timeStep(sender: UIStepper) {
        timeLabel.text = "\(Int(sender.value)) ms"
    }
    
    @objc private func save() {
        guard let name = nameTextField.text, !name.isEmpty else {
            displayErrorAlert(error: QuickError(message: "Enter marco's name"))
            return
        }
        
        fileUrl.flatMap {
            do {
                try FileManager.default.removeItem(at: $0)
            } catch let error {
                displayErrorAlert(error: error)
            }
        }
        
        saveMacros(name)
    }
    
    @objc private func closeAction() {
        self.dismiss(animated: true)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        rootStackView.axis = view.frame.width < 550 ? .vertical : .horizontal
    }

}

extension UARTMacroViewController {
    private func preloadMacro(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let macro = try JSONDecoder().decode(UARTMacro.self, from: data)
            nameTextField.text = macro.name
            macros = macro.commands
            timeStepper.value = Double(macro.delay)
            timeLabel.text = "\(macro.delay) ms"
            navigationItem.title = "Edit Macros"
        } catch let error {
            displayErrorAlert(error: error)
        }
    }
    
    private func saveMacros(_ name: String) {
        let fileManager = FileManager.default
        do {
            let macro = UARTMacro(name: name, delay: Int(timeStepper.value), commands: macros)
            let data = try JSONEncoder().encode(macro)
            let documentDirectory = try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("macros")
            try fileManager.createDirectory(at: documentDirectory, withIntermediateDirectories: true, attributes: nil)
            let fileUrl = documentDirectory
                .appendingPathComponent(name)
                .appendingPathExtension("json")
            
            guard !fileManager.fileExists(atPath: fileUrl.absoluteString) else {
                throw QuickError(message: "Macro with that name already exists")
            }
            
            try data.write(to: fileUrl)
            self.dismiss(animated: true, completion: nil)
        } catch let error {
            displayErrorAlert(error: error)
        }
    }
}

extension UARTMacroViewController: UARTCommandListDelegate {
    func selectedCommand(_ command: UARTCommandModel, at index: Int) {
        guard !(command is EmptyModel) else { return }
        macros.append(command)
        commandOrderTableView.insertRows(at: [IndexPath(row: macros.count - 1, section: 0)], with: .automatic)
    }
    
    func longTapAtCommand(_ command: UARTCommandModel, at index: Int) {
        
    }
}

extension UARTMacroViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        macros.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let command = macros[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")
        cell?.textLabel?.text = command.title
        cell?.imageView?.image = command.image.image?.withRenderingMode(.alwaysTemplate)
        cell?.imageView?.tintColor = .nordicBlue
        return cell!
    }
}

extension UARTMacroViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        switch editingStyle {
        case .delete:
            macros.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        default:
            break
        }
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        let delete = UITableViewRowAction(style: .destructive, title: "Delete") { (action, ip) in
            self.macros.remove(at: ip.row)
            tableView.deleteRows(at: [ip], with: .automatic)
        }
        
        return [delete]
    }
    
    func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }
    
    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .delete
    }
    
    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let item = macros[sourceIndexPath.row]
        macros.remove(at: sourceIndexPath.row)
        macros.insert(item, at: destinationIndexPath.row)
    }
}

extension UARTMacroViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
    }
}
