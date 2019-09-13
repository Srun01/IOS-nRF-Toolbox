//
//  GlucoseMonitorViewController.swift
//  nRF Toolbox
//
//  Created by Nick Kibysh on 06/09/2019.
//  Copyright © 2019 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth

extension Identifier: CaseIterable where Value == GlucoseMonitorViewController {
    static var allCases: [Identifier<GlucoseMonitorViewController>] {
        return [.all, .first, .last]
    }
    
    static let all: Identifier<GlucoseMonitorViewController> = "All"
    static let first: Identifier<GlucoseMonitorViewController> = "First"
    static let last: Identifier<GlucoseMonitorViewController> = "Last"
}

class GlucoseMonitorViewController: PeripheralTableViewController {
    private var bgmSection = BGMSection()
    private var recordAccessControlPoint: CBCharacteristic?
    
    private lazy var actionSection: ActionSection = {
        let refresh = ActionSectionItem(title: "Refresh") {
            self.updateDisplayedItems(.all)
        }
        let clear = ActionSectionItem(title: "Clear") {
            self.bgmSection.clearReadings()
            self.tableView.reloadData()
        }
        let deleteAll = ActionSectionItem(title: "Delete All", style: .destructive) {
            self.bgmSection.clearReadings()
            let data = Data([BGMOpCode.deleteStoredRecords.rawValue, BGMOperator.allRecords.rawValue])
            self.activePeripheral?.writeValue(data, for: self.recordAccessControlPoint!, type: .withResponse)
        }
        
        return ActionSection(id: "Actions", sectionTitle: "Actions", items: [refresh, clear, deleteAll])
    }()
    
    private var selectionSection = OptionSelectioSection<GlucoseMonitorViewController>(id: .selectionResult, sectionTitle: "", items: [OptionSelectioSection.Item(option: "Display Items", selectedCase: "All")])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(cell: BGMTableViewCell.self)
        navigationItem.title = "Glucose Monitoring"
    }
    
    // MARK: Table View Handlers
    override func selected(item: Int, in section: Section) {
        switch section.id {
        case .selectionResult:
            handleOptionSelection()
        default:
            super.selected(item: item, in: section)
        }
    }
    
    override var internalSections: [Section] {
        return [selectionSection, bgmSection, actionSection]
    }
    
    override var profileUUID: CBUUID? {
        return CBUUID.Profile.bloodGlucoseMonitor
    }
    
    override var scanServices: [CBUUID]? {
        return (super.scanServices ?? []) + [CBUUID.Service.bloodGlucoseMonitor]
    }
    
    override func didDiscover(service: CBService, for peripheral: CBPeripheral) {
        switch service.uuid {
        case CBUUID.Service.bloodGlucoseMonitor:
            peripheral.discoverCharacteristics([
                CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurement,
                CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurementContext,
                CBUUID.Characteristics.BloodGlucoseMonitor.recordAccessControlPoint
            ], for: service)
        default:
            super.didDiscover(service: service, for: peripheral)
        }
    }
    
    override func didDiscover(characteristic: CBCharacteristic, for service: CBService, peripheral: CBPeripheral) {
        switch characteristic.uuid {
        case CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurement:
            peripheral.setNotifyValue(true, for: characteristic)
        case CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurementContext:
            peripheral.setNotifyValue(true, for: characteristic)
        case CBUUID.Characteristics.BloodGlucoseMonitor.recordAccessControlPoint:
            peripheral.setNotifyValue(true, for: characteristic)
            recordAccessControlPoint = characteristic
            updateDisplayedItems(.all)
        default:
            super.didDiscover(characteristic: characteristic, for: service, peripheral: peripheral)
        }
    }
    
    override func didUpdateValue(for characteristic: CBCharacteristic) {
        let array = UnsafeMutablePointer<UInt8>(OpaquePointer(((characteristic.value as NSData?)?.bytes)!))
        
        switch characteristic.uuid {
        case CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurement:
            let reading = GlucoseReading(array)
            bgmSection.update(reading: reading)
        case CBUUID.Characteristics.BloodGlucoseMonitor.glucoseMeasurementContext:
            let context = GlucoseReadingContext(array)
            bgmSection.update(context: context)
        case CBUUID.Characteristics.BloodGlucoseMonitor.recordAccessControlPoint:
            handleAccessControlPoint(array: array)
        default:
            super.didUpdateValue(for: characteristic)
        }
    }
}

extension GlucoseMonitorViewController {
    private func handleAccessControlPoint(array: UnsafeMutablePointer<UInt8>) {
        let responseCode = BGMResponseCode(rawValue:array[2])!
        switch responseCode {
        case .success:
            reloadSection(id: .bgmReadings)
        default:
            guard let error = responseCode.error else {
                Log(category: .ble, type: .error).log(message: "Cannot parse error for \(responseCode)")
                return
            }
            Log(category: .ble, type: .error).log(message: "Error access control error: \(error.localizedDescription)")
            AppUtilities.showAlert(title: error.title, andMessage: error.message ?? "", from: self)
        }
    }
    
    private func handleOptionSelection() {
        let cases = Identifier<GlucoseMonitorViewController>.allCases
        
        let selector = SelectionsTableViewController(items: cases, selectedItem: 0) { item in
            let selected = cases[item]
            self.selectionSection.items[0].selectedCase = selected
            self.reloadSection(id: .selectionResult)
            self.updateDisplayedItems(selected)
        }
        selector.navigationItem.title = selectionSection.items.first?.option
        
        self.navigationController?.pushViewController(selector, animated: true)
    }
    
    private func updateDisplayedItems(_ itemsToDisplay: Identifier<GlucoseMonitorViewController>) {
        self.bgmSection.clearReadings()
        
        let bgmOperator: UInt8 = {
            switch itemsToDisplay {
            case .all: return BGMOperator.allRecords.rawValue
            case .first: return BGMOperator.first.rawValue
            case .last: return BGMOperator.last.rawValue
            default: return 0
            }
        }()
        
        let data = Data([BGMOpCode.reportStoredRecords.rawValue, bgmOperator])
        self.activePeripheral?.writeValue(data, for: self.recordAccessControlPoint!, type: .withResponse)
    }
}
