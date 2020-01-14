//
//  UARTViewController1.swift
//  nRF Toolbox
//
//  Created by Nick Kibish on 30.12.2019.
//  Copyright © 2019 Nordic Semiconductor. All rights reserved.
//

import UIKit
import CoreBluetooth

class UARTViewController1: UIViewController {

    let btManager = BluetoothManager()
    
    private lazy var connectBtn = UIBarButtonItem(title: "Connect", style: .done, target: self, action: #selector(openConnectorViewController))
    
    @IBOutlet private var collectionView: UICollectionView!
    private var commands: [UARTCommandModel] = Array.init(repeating: EmptyModel(), count: 9)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        btManager.delegate = self
        btManager.logger = self
        navigationItem.rightBarButtonItem = connectBtn
        
        commands[5] = TextCommand(text: "Play", imageName: "Play")
        let data = "ay".data(using: .ascii)!
        commands[7] = DataCommand(data: data, imageName: "Pause")
        
        let nib = UINib(nibName: "UARTActionCollectionViewCell", bundle: .main)
        collectionView.register(nib, forCellWithReuseIdentifier: "UARTActionCollectionViewCell")
    }
    
    @objc func openConnectorViewController() {
        let scanner = PeripheralScanner(services: nil)
        let connectionController = ConnectionViewController(scanner: scanner)
        connectionController.delegate = self

        let nc = UINavigationController.nordicBranded(rootViewController: connectionController)
        nc.modalPresentationStyle = .formSheet

        self.present(nc, animated: true, completion: nil)
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension UARTViewController1: ConnectionViewControllerDelegate {
    func connected(to peripheral: Peripheral) {
        btManager.connectPeripheral(peripheral: peripheral.peripheral)
    }
}

extension UARTViewController1: BluetoothManagerDelegate {
    
    func didConnectPeripheral(deviceName aName: String?) {
        guard let presented = presentedViewController,
            let scannerNC = presented as? UINavigationController,
            let scanner = scannerNC.viewControllers.first as? ConnectionViewController else {
            return
        }
        
        scanner.dismiss(animated: true, completion: nil)
        navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func didDisconnectPeripheral() {
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    func peripheralReady() {
        
    }
    
    func peripheralNotSupported() {
        navigationItem.rightBarButtonItem?.isEnabled = true
    }
    
    override var shouldAutorotate: Bool {
        return false
    }
    
    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)
        collectionView.collectionViewLayout.invalidateLayout()
    }
}

extension UARTViewController1: Logger {
    func log(level aLevel: LOGLevel, message aMessage: String) {
        Log(category: .ble, type: .debug).log(message: aMessage)
    }
}

extension UARTViewController1: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let side = collectionView.frame.size.width / 3 - 2
        return CGSize(width: side, height: side)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        3
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        3
    }
}

extension UARTViewController1: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return commands.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let command = commands[indexPath.item]
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "UARTActionCollectionViewCell", for: indexPath) as! UARTActionCollectionViewCell
        cell.apply(command: command)
        if #available(iOS 13.0, *) {
            cell.contentView.backgroundColor = .systemGroupedBackground
        } else {
            cell.contentView.backgroundColor = .lightGray
        }
        return cell
    }
    
    
}