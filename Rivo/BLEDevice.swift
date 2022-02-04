
import Network
import Foundation
import IOKit
import CoreBluetooth
 
    //notification on
    
/*
 22.02.04
 
 timeout 구현할 필요 없을 듯
 readvalue 부르면 update~ 무조건 호출되는데
 값 문제있으면 다시 send할거고(sendAndReceive에서)
 결국 retryfail 됨. retryfail에 대해서만 ui올리는 걸로.
 
 &
 
 mtu가 거의 120~ 이고 일반 함수 경우 절대 안넘으니 (펌웨어 예외. 얘는 maybe 따로 구현)
 제대로 안 온 경우(쪼개서 연속으로 보내는 경우-update control 2번연속-이 대부분)
 그냥 frame 단위로 쓰고 읽어도 될 듯
 제대로 안왔으면 그냥 또 write 하는(retry)
 read를 통해 readValue 불러봤자 값 변화 없기 때문.
 write 를 다시해야 updateValue가 호출되고, 결국 readPacket 으로 읽을수있게됨.
 
 마찬가지 이유로 sendFrame 에서도 쪼개서 보낼 필요 없어 보임.
 해당 sendframe 로직은 update control 파트에서 쓸듯.
 
 */
let Timeout : Double = 0.001

class BLEDevice : RivoDevice {
    
    var connection: CBPeripheral!
    var continuationW : CheckedContinuation<(), Never>? = nil
    var continuationR : CheckedContinuation<[UInt8], Error>? = nil

   
    var UUID_GATT_NUS_COMMAND_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_RESPONSE_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_DATA_ENDPOINT: CBCharacteristic?
    
    var ID: String = ""
    var isCheck: Bool = false
    var payloadlen = 0
    var temp : [UInt8] = []
    var payloadvalue : [UInt8] = []
    var totallen = 0
    var writeType: CBCharacteristicWriteType = .withResponse
    
    override init(){
        super.init()
        
    }
    
    init(_ peripheral : CBPeripheral, _ commandCharacteristic : CBCharacteristic) {
       
        self.connection = peripheral
        self.UUID_GATT_NUS_COMMAND_ENDPOINT = commandCharacteristic
    }
    func setPeripheral(peripheral : CBPeripheral){
        self.connection = peripheral
    }
    func setRead(datapath: CBCharacteristic){
        self.UUID_GATT_NUS_RESPONSE_ENDPOINT = datapath
    }
    func setWrite(datapath: CBCharacteristic){
        self.UUID_GATT_NUS_COMMAND_ENDPOINT =
        datapath
    }
    var receiveFrame : [UInt8] = []
    
    override func getReady(state: Bool) {
        //true : notification on, buffer clear
        if(state){
            connection.setNotifyValue(true, for: self.UUID_GATT_NUS_RESPONSE_ENDPOINT!)
            receiveFrame = []
        }
        else{
            //false : notification off
            connection.setNotifyValue(false, for: self.UUID_GATT_NUS_RESPONSE_ENDPOINT!)
        }
    }
    
    /// 데이터 Array를 Byte형식으로 주변기기에 전송합니다.
    override func writePacket(data: [UInt8]) async {
        
        print("to write~ \(String(describing: self.UUID_GATT_NUS_COMMAND_ENDPOINT))")
        print("write : \(data)")
        let data = Data(data) // convert byte array to Data
       
        return await withCheckedContinuation { continuation in
            connection.writeValue(data, for: self.UUID_GATT_NUS_COMMAND_ENDPOINT!, type: writeType)
            self.continuationW = continuation
        }
    }
    
    var resumed : Bool = false
    
    override func readPacket() async throws -> [UInt8] {
            
        print("to read~")
        var result : [UInt8] = [0]
        //update wait
        result = try await withCheckedThrowingContinuation {
            continuation in
            resumed = false
            self.continuationR = continuation
        //timeout
            let timer = Timer.scheduledTimer(withTimeInterval: Timeout, repeats: false) {
                _ in
                //다른 데서 continuation resume 했으면
                if self.resumed {
                    return
                }
                print("timeout!")
                self.resumed = true
                continuation.resume(throwing: defineError.readPacketTimeout)
            }
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.current.run()
        }
        continuationR = nil //readPacket에서 await 하고 있지않은데 resume 될까봐.
        print("readpacket의 result는" ,result)
        return result
    }
    

    /*
     func updateWaiter() async throws {
         
         return try await withCheckedThrowingContinuation {
             continuation in
             self.continuationU = continuation
             
         }
     }

   */
    }




