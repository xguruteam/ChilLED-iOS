//
//  ViewController.swift
//  ChilLED
//
//  Created by Guru on 1/20/19.
//  Copyright © 2019 Guru. All rights reserved.
//

import UIKit
import CoreBluetooth
import Toast_Swift
import MKProgress

class ViewController: UIViewController {

    let SERVICE_FFE5 = CBUUID(string: "0000FFE5-0000-1000-8000-00805F9B34FB")
    let CHAR_FFE9 = CBUUID(string: "0000FFE9-0000-1000-8000-00805F9B34FB")
    let SERVICE_FFE0 = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
    let CHAR_FFE4 = CBUUID(string: "0000FFE4-0000-1000-8000-00805F9B34FB")
    
    let MTU = 200
    
    var device: CBPeripheral!

    var centralManager: CBCentralManager!
    
    var writeChar: CBCharacteristic!
    
    var mTimer: Timer?
    
    var mTotalSent = 0
    var mTotalReceived = 0
    var mStartTime = 0.0
    var mTotalErrors = 0
    var mReceived = 0
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        title = device.name
        
        navigationController?.navigationBar.prefersLargeTitles = true

        MKProgress.show()
        centralManager.delegate = self
        centralManager.connect(device, options: nil)
        
        Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] (_) in

            DispatchQueue.main.async {
                MKProgress.hide()
                
                guard let _ = self?.writeChar else {
                    return
                }
                
                self?.start()
            }
        }
    }
    
    func disconnect() {
        centralManager.delegate = nil
        centralManager.cancelPeripheralConnection(device)
    }

    func finishView() {
        self.view.makeToast("Unknown Error")
        disconnect()
//        self.dismiss(animated: true, completion: nil)
    }
    
    override func willMove(toParent parent: UIViewController?) {
        if parent == nil {
            stop()
            disconnect()
        }
    }
    
}

extension ViewController: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
//            self.view.makeToast("Bluetooth has been turned off")
            finishView()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
//        self.view.makeToast("Failed To Connect")
        finishView()
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.delegate = self
        peripheral.discoverServices([SERVICE_FFE5, SERVICE_FFE0])
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
//        self.view.makeToast("Unknown Error")
        finishView()
    }
    
}

extension ViewController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
//            self.view.makeToast("Unknown Error")
            finishView()
            return
        }
        
        for service in services {
            if service.uuid == SERVICE_FFE5 {
                peripheral.discoverCharacteristics(nil, for: service)
            }
            
            if service.uuid == SERVICE_FFE0 {
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else {
            finishView()
            return
        }
        
        for char in chars {
            if char.uuid == CHAR_FFE9 {
                writeChar = char
                break
            }
            
            if char.uuid == CHAR_FFE4 {
                peripheral.setNotifyValue(true, for: char)
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print((error?.localizedDescription)!)
            return
        }
        
        if characteristic.isNotifying {
            print("start subscribing from - \(characteristic.uuid.uuidString)")
        }
        else {
            print("end subscribing from - \(characteristic.uuid.uuidString)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            print((error?.localizedDescription)!)
            return
        }
        
//        let response = characteristic.value?.hexadecimal
//        print("response : \(response)")
        
        guard let response = characteristic.value else {
            return
        }
        
        addReceived(response)
    }
}


extension ViewController {
    
    func start() {
        print("start")
        mStartTime = Date().timeIntervalSince1970
        writeOnePacket()
    }
    
    func stop() {
        print("stop")
        mTimer?.invalidate()
        mTimer = nil
    }
    
    func writeOnePacket() {
        let hexMTU = String(format: "%02X", MTU - 1)
        let asciiMTU = hexMTU.ascii.map {
            String(format: "%02X", $0)
        }
        .joined()
        let command = "2A\(asciiMTU)303132333435363738394142434445460D"
//        print("command : \(command)")
        
        mReceived = 0
        mTotalSent += 20
        device.writeValue(command.hexadecimal!, for: writeChar, type: .withoutResponse)
        
        mTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: false, block: { [weak self] (_) in
            self?.mTotalErrors += 1
            self?.update()
            self?.writeOnePacket()
        })
    }
    
    func addReceived(_ data: Data) {
        mReceived += data.count
        
        if mReceived == MTU {
            mTotalReceived += mReceived
            update()
            mTimer?.invalidate()
            mTimer = nil
            writeOnePacket()
        }
    }
    
    func update() {
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }

}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "parameterCell")
        
        let time = Date().timeIntervalSince1970
        
        switch indexPath.row {
        case 0:
            cell?.textLabel?.text = "Total Sent"
            cell?.detailTextLabel?.text = "\(mTotalSent)"
        case 1:
            cell?.textLabel?.text = "Sennding Speed"
            let speed = NSNumber(value: (Double)(mTotalSent) / (time - mStartTime))
            cell?.detailTextLabel?.text = "\(speed) B/S"
        case 2:
            cell?.textLabel?.text = "Total Received"
            cell?.detailTextLabel?.text = "\(mTotalReceived)"
        case 3:
            cell?.textLabel?.text = "Receving Speed"
            let speed = NSNumber(value: (Double)(mTotalReceived) / (time - mStartTime))
            cell?.detailTextLabel?.text = "\(speed) B/S"
        default:
            cell?.textLabel?.text = "Error Packets"
            cell?.detailTextLabel?.text = "\(mTotalErrors)"
        }
        
        return cell!
    }
}

extension String {
    
    /// Create `Data` from hexadecimal string representation
    ///
    /// This creates a `Data` object from hex string. Note, if the string has any spaces or non-hex characters (e.g. starts with '<' and with a '>'), those are ignored and only hex characters are processed.
    ///
    /// - returns: Data represented by this hexadecimal string.
    
    var hexadecimal: Data? {
        var data = Data(capacity: characters.count / 2)
        
        let regex = try! NSRegularExpression(pattern: "[0-9a-f]{1,2}", options: .caseInsensitive)
        regex.enumerateMatches(in: self, range: NSRange(startIndex..., in: self)) { match, _, _ in
            let byteString = (self as NSString).substring(with: match!.range)
            let num = UInt8(byteString, radix: 16)!
            data.append(num)
        }
        
        guard data.count > 0 else { return nil }
        
        return data
    }
    
}

extension Data {
    
    /// Hexadecimal string representation of `Data` object.
    
    var hexadecimal: String {
        return map { String(format: "%02x", $0) }
            .joined()
    }
}

extension Character {
    var isAscii: Bool {
        return unicodeScalars.first?.isASCII == true
    }
    var ascii: UInt32? {
        return isAscii ? unicodeScalars.first?.value : nil
    }
}

extension StringProtocol {
    var ascii: [UInt32] {
        return compactMap { $0.ascii }
    }
}

extension NSNumber {
    override open var description: String {
        switch self {
        case is Int, is Float:
            return self.stringValue
        default:
            let new = round(self.doubleValue * 100) / 100
            return String(new)
        }
    }
}
