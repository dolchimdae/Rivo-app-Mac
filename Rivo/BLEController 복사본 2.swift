//
//
//  BLEConotroller.swift
//  Rivo
//

import Foundation
import CoreBluetooth

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
}

var myCentral: CBCentralManager!
var selectedPeripheral: CBPeripheral!

class CBController: NSObject, ObservableObject, CBCentralManagerDelegate {
    
    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    @Published var detectedPeripherals: [CBPeripheral] = []
    @Published var isConnected = false
    
    
    @Published var peripheralName: String = ""
    @Published var peripheralVersion: String = "버전 확인버튼을 눌러주세요."
    @Published var recentVersion: String = ""
    
    @Published var deviceInfo : String = "연결 되었습니다. refresh 버튼을 눌러주세요."
    @Published var battery : String = ""
    @Published var upgradeStatus = ""
    @Published var upgrading = false
    
    @Published var Toggle_vibration = false
    @Published var Toggle_sound = false
    
    var UUID_GATT_NUS_SERVICE : CBService?
    
    var UUID_GATT_NUS_COMMAND_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_RESPONSE_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_DATA_ENDPOINT: CBCharacteristic?
    
    var rivoserviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var commandCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    var responseCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    var dataCharacteristicUUID = CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var device = BLEDevice()
    
    var continuationC : CheckedContinuation<(),Never>? = nil //connect
    var continuationD : CheckedContinuation<(),Never>? = nil //disconnect
    
    
    
    override init() {
        super.init()
        myCentral = CBCentralManager(delegate: self, queue: nil)
        myCentral.delegate = self
        
    }
    
    let options: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey:NSNumber(value: true)]
    
    func startScanning () {
        print ("startScanning")
        myCentral.scanForPeripherals (withServices: nil, options: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            self.stopScanning()
        }
    }
    
    func stopScanning () {
        print ("stopScanning")
        myCentral.stopScan()
    }
    
    func findPeripheral (_ count : Int) -> CBPeripheral {
        return detectedPeripherals[count]
    }
    
    func alreadyDetectedPeripheral (_ peripheral: CBPeripheral) -> Bool {
        let services : [CBUUID] = [rivoserviceUUID]
        peripheral.discoverServices(services)
        
        for p in detectedPeripherals {
            //print("alreadyDetectedPeripheral")
            if p.identifier == peripheral.identifier {
                return false
            }
        }
        return true
    }
    
    func connect (_ peripheral: Peripheral) async {
        
        print("connecting")
        selectedPeripheral = findPeripheral(peripheral.id)
        myCentral.connect(selectedPeripheral)
        selectedPeripheral.delegate = self
        print("connected: \(selectedPeripheral!)")
        
        await withCheckedContinuation { continuation in
            self.continuationC = continuation
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        
        let services : [CBUUID] = [rivoserviceUUID]
        
        print("Connected with \(peripheral)")
        isConnected = true
        device.setPeripheral(peripheral: peripheral)
        myCentral.stopScan()
        peripheral.discoverServices(services)
        
        peripheralName = selectedPeripheral.name!
        self.continuationC?.resume()
    }
    
//    func connect2(_ peripheral: Peripheral){
//        //동기적 connect
//        print("connecting")
//        selectedPeripheral = findPeripheral(peripheral.id)
//        myCentral.connect(selectedPeripheral)
//        selectedPeripheral.delegate = self
//        print("connected: \(selectedPeripheral!)")
//    }
//
    
    func disconnect(_ peripheral: Peripheral) async {
        print("disconnecting")
        let selectedPeripheral = findPeripheral(peripheral.id)
        myCentral.cancelPeripheralConnection(selectedPeripheral)
        
        return await withCheckedContinuation {
            continuation in
            
            self.continuationD = continuation
        }
    }
    
    
//    func disconnect2(_ peripheral: Peripheral) {
//        //동기적 disconnect
//        print("disconnecting")
//        let selectedPeripheral = findPeripheral(peripheral.id)
//        myCentral.cancelPeripheralConnection(selectedPeripheral)
//        //myCentral.cancelPeripheralConnection(peripheral)
//    }
     
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print(error)
            return
        }
        print("successfully disconnected")
        self.continuationD?.resume()
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            isSwitchedOn = true
        }
        else {
            isSwitchedOn = false
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        
        let rssi = RSSI.intValue
        
        if isSwitchedOn && alreadyDetectedPeripheral(peripheral) {
            if rssi > -100 && peripheral.name != nil {
                //print(advertisementData)
                let newPeripheral = Peripheral(id: peripherals.count, name: peripheral.name ?? "Unknown", rssi: RSSI.intValue)
                peripheral.delegate = self
                detectedPeripherals.append(peripheral)
                peripherals.append(newPeripheral)
            }
        }
    }
}


extension CBController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        
        if let error = error {
            print("Error discovering services: %s", error.localizedDescription)
            return
        }
        
        for service in peripheral.services! {
            
            if(service.uuid == rivoserviceUUID){
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        
        device.connection = selectedPeripheral
        //print("didDiscoverCharacteristicsFor")
        
        for characteristic in service.characteristics! {
            
            if characteristic.uuid == commandCharacteristicUUID {
                UUID_GATT_NUS_COMMAND_ENDPOINT = characteristic
                device.setWrite(datapath: characteristic)
            }
            if characteristic.uuid == responseCharacteristicUUID{
                device.setRead(datapath: characteristic)
            }
            if characteristic.uuid == dataCharacteristicUUID{
                device.UUID_GATT_NUS_DATA_ENDPOINT = characteristic
            }
        }
    }
    
    //writeValue 를 withResponse 타입으로 실행했을 때 불리는 함수
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        //print("didWriteValueFor")
        if let error = error {
            print(error)
        }
        else{
            //print("success")
            device.continuationW!.resume()
        }
    }
    
    // peripheral 로부터 데이터를 전송받으면 콜백 호출
    //didupdatefor 에서 한 프레임이 완성됐는지 판단. buffer 통해 모은 경우도 결국 sendAndReceive에서 체크되어 걸러짐
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
    
        print("didupdatevaluefor")
        if let error = error {
            print("error \(characteristic.uuid): ",error)
            return
        }
        if(device.upgrading){ // 업그레이드 % ui 반영
            //print(device.upgradeStatus)
            upgradeStatus = device.upgradeStatus
            upgrading = device.upgrading
            return
        }
        else{
            upgrading = device.upgrading
        }
        
        //readPacket에서 await 하고 있을 때.
        if device.continuationR != nil {
            let data = characteristic.value
            if (data == nil) {
                //print("read data is nil")
                return
            }
            else {
                device.receiveFrame += [UInt8](data!)
                
                if(device.receiveFrame.count < 2){
                    //print("< 2")
                    device.buffer += [UInt8](characteristic.value!)
                    //print(device.buffer)
                    return
                }
                if (device.receiveFrame[0] == UInt8(ascii:"a") &&
                    device.receiveFrame[1] == UInt8(ascii:"t")){
                    if(device.receiveFrame.count < 6) {
                        //print("6보다 작다니, 더 올 게 있나본데.")
                        device.buffer += [UInt8](characteristic.value!)
                        //print(device.buffer)
                        return
                    }
                    let len = Int(device.receiveFrame[4]) + Int(device.receiveFrame[5]<<8) + 10
                    // 나머지 receive frame
                    if device.receiveFrame.count < len {
                        device.buffer += [UInt8](characteristic.value!)
                        //print(device.buffer)
                        //print("len보다 작아서 return")
                        return
                    }
                    if device.rcframeCheck(id: device.idNow, frame: device.receiveFrame){
//                        if (device.receiveFrame[7] != UInt8(0)) {
//                            print("result is not zero")
//                            return
//                        }
                        print("continuation return")
                        device.continuationR?.resume(returning: device.receiveFrame)
                    }
                    return
                }
                else{
                    //print("잘못된 패킷이 왔네.")
                    return
                }
            }
        }
        else {
            // readPacket 이 안기다릴때 연달아 불린 경우.
            //print("continuation nil")
            device.buffer += [UInt8](characteristic.value!)
            print(device.buffer)
            return
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state:\(error.localizedDescription)")
            return
        }
       
        if characteristic.isNotifying {
            //print("Notification began on", characteristic)
        } else {
            //print("Notification stopped on \(characteristic). Disconnecting" )
        }
    }
}

