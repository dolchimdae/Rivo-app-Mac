import Foundation
import CoreBluetooth

//let rivoCharacteristic = CBUUID(string: "3FD0DA8D-74C2-461C-9963-B6F6EFB8BC13")
//ui ) 이미 등록됐으면 등록 버튼 비활성화

struct Peripheral: Identifiable {
    let id: Int
    let name: String
    let rssi: Int
    
}

var myCentral: CBCentralManager!
var selectedPeripheral: CBPeripheral!

class CBController: NSObject, ObservableObject, CBCentralManagerDelegate{

    @Published var isSwitchedOn = false
    @Published var peripherals = [Peripheral]()
    @Published var detectedPeripherals: [CBPeripheral] = []
    @Published var isConnected = false
    
 
    
    //var rivoServiceUUID = CBUUID(string: "00001100-D102-11E1-9B23-00025B00A5A5")
    //var rivoCharacteristicUUID = CBUUID(string: "00001101-D102-11E1-9B23-00025B00A5A5")
    //let transferUUID = CBUUID(string: "00001102-D102-11E1-9B23-00025B00A5A5")
    
    @Published var peripheralName: String = "Not Connected"
    @Published var peripheralversion: String = ""

    var UUID_GATT_NUS_SERVICE : CBService?

    var UUID_GATT_NUS_COMMAND_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_RESPONSE_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_DATA_ENDPOINT: CBCharacteristic?
   
    var rivoserviceUUID = CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E")

    var commandCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    var responseCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")
    var dataCharacteristicUUID = CBUUID(string: "6E400004-B5A3-F393-E0A9-E50E24DCCA9E")
    
    var device = BLEDevice()
    

    /// connectedPeripheral은 연결에 성공된 기기를 의미합니다. 기기와 통신을 시작하게되면 이 객체를 이용하게됩니다.
    var connectedPeripheral : CBPeripheral?
    
    var peripheralManager: CBPeripheralManager!
    
 
    
    var ID: String = ""
    var isCheck: Bool = false
    var payloadlen = 0
    var temp : [UInt8] = []
    var payloadvalue : [UInt8] = []
    var totallen = 0

    
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
        print("findPeripheral: \(count) 개 있네그려~")
        return detectedPeripherals[count]
    }

    func alreadyDetectedPeripheral (_ peripheral: CBPeripheral) -> Bool {
        let hi : [CBUUID] = [rivoserviceUUID]
        peripheral.discoverServices(hi)
        
        //peripheral.discoverCharacteristics(nil, for: UUID_GATT_NUS_SERVICE)
        for p in detectedPeripherals {
            print("alreadyDetectedPeripheral")
            if p.identifier == peripheral.identifier{
                return false
            }
        }
        return true
    }
    
    func connect(_ peripheral: Peripheral){
        print("connecting")
        selectedPeripheral = findPeripheral(peripheral.id)
        myCentral.connect(selectedPeripheral)
        selectedPeripheral.delegate = self
        print("connected: \(selectedPeripheral!)")
        
        //device.setPeripheral(peripheral: selectedPeripheral)
    }
    
    func disconnect(_ peripheral: Peripheral) {
        print("disconnecting")
        let selectedPeripheral = findPeripheral(peripheral.id)
        myCentral.cancelPeripheralConnection(selectedPeripheral)
        //myCentral.cancelPeripheralConnection(peripheral)
    }
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            // Handle error
            print(error)
            return
        }
        // Successfully disconnected
        print("successfully disconnected")
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
                //print(peripheral)
                let newPeripheral = Peripheral(id: peripherals.count, name: peripheral.name ?? "Unkown", rssi: RSSI.intValue)
                peripheral.delegate = self
                detectedPeripherals.append(peripheral)
                //print(newPeripheral)
                peripherals.append(newPeripheral)
            }
        }
        
    }
   
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected with \(peripheral)")
        isConnected = true
        selectedPeripheral = peripheral
        myCentral.stopScan()
        peripheral.discoverServices(nil)
        peripheralName = selectedPeripheral.name!
    }
}

extension CBController: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: %s", error.localizedDescription)
            return
        }
        
        for service in peripheral.services! {
            print(service)
            if(service.uuid == rivoserviceUUID){
                print("yeah!")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        
        guard let characteristics = service.characteristics else { return }
        print("didDiscoverCharacteristicsFor")
        for characteristic in service.characteristics! {
            //print(characteristic)
            if characteristic.uuid == commandCharacteristicUUID {
                UUID_GATT_NUS_COMMAND_ENDPOINT = characteristic
                device = BLEDevice(selectedPeripheral, UUID_GATT_NUS_COMMAND_ENDPOINT!)
            }
            if characteristic.uuid == responseCharacteristicUUID{
                print("responseCharacter은 정해졌다!!!!!!")
                device.setRead(datapath: characteristic)
                device.connection.setNotifyValue(true, for: characteristic)
            }
            if characteristic.uuid == dataCharacteristicUUID{
                device.UUID_GATT_NUS_DATA_ENDPOINT = characteristic
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        
        print("didWriteValueFor")
        if let error = error {
            print(error)
        }
        else{
            print("success")
            device.continuationW!.resume()
        }
    }
    
    // peripheral으로부터 데이터를 전송받으면 호출되는 메서드
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        //peripheral이 새로운 데이터를 보낼 때 마다 콜백 호출
        print("didupdatevaluefor")
        
        if let error = error {
            print("error \(characteristic.uuid): ",error)
            //return
        }
        if(!(device.receivedComplete)){
            print("received inComplete")
            
            if (!device.calledReadPacket) {
                print("안불렀는데 불렸네",[UInt8](device.UUID_GATT_NUS_RESPONSE_ENDPOINT!.value!))
                return
            }
            
            let str = String(bytes: characteristic.value!, encoding : .utf8)
            if(str == nil){
                print("value str is NULL") //str이 nil 이어도 value 값 있음
            }
            else{
                //print("\(characteristic.uuid): \(characteristic.value!.count) bytes")
                print("value는 뭐냐면 \(str)")
            }
            device.continuationU?.resume()
            device.calledReadPacket = false
        }
        else {
            print("received Complete")
            return
        }
        
    }
    
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("Error changing notification state:\(error.localizedDescription)")
            return
        }
        //guard characteristic.uuid == TransferService.characteristicUUID else { return }
        if characteristic.isNotifying {
            print("Notification began on", characteristic)
            
        } else {
            print("Notification stopped on \(characteristic). Disconnecting" )
        }
    }

    func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        print("Peripheral is ready, send data")
    }
    
    
    /*
    func sendprotocolRV(){
        //let name: [UInt8] = Array(rivoName.utf8)
        //let len : Int = name.count
        //MYRIVO 6 +  op 1 = len -> 7
        let data: [UInt8] = [0x41, 0x54, 0x52, 0x56,0x07, 0x00,0x01, 0x4d, 0x59, 0x52, 0x49, 0x56, 0x4f,  0xF0, 0x1E, 0x0D, 0x0A]

        let Ndata = NSData(bytes: data, length: data.count)
        print("SET_RIVO_NAME_ACK")
        print(selectedPeripheral!)
        print(UUID_GATT_NUS_COMMAND_ENDPOINT)
        selectedPeripheral!.writeValue(getfirmdata as Data, for: UUID_GATT_NUS_COMMAND_ENDPOINT, type: CBCharacteristicWriteType.withResponse)
    }
    */
    func sendprotocolFV(){
        let data: [UInt8] = [0x41, 0x54, 0x46, 0x56, 0x01, 0x00, 0x00, 0xF0, 0x1E, 0x0D, 0x0A]
        let Ndata = NSData(bytes: data, length: data.count)
        print("GET_FIRMWARE_VERSION")
        print(selectedPeripheral!)
        print(UUID_GATT_NUS_COMMAND_ENDPOINT as Any)
        selectedPeripheral!.writeValue(Ndata as Data, for: UUID_GATT_NUS_COMMAND_ENDPOINT!, type: CBCharacteristicWriteType.withResponse)
    }
    
    func sendprotocolIF(){
        let data: [UInt8] = [0x41, 0x54, 0x49, 0x46, 0x01, 0x00, 0x00, 0xF0, 0x1E, 0x0D, 0x0A]
        let Ndata = NSData(bytes: data, length: data.count)
        print("GET_DEVICE_INFO")
        print(selectedPeripheral!)
        print(UUID_GATT_NUS_COMMAND_ENDPOINT as Any)
        selectedPeripheral!.writeValue(Ndata as Data, for: UUID_GATT_NUS_COMMAND_ENDPOINT!, type: CBCharacteristicWriteType.withResponse)
    }

    
}

