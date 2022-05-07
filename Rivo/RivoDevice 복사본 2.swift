//
//  RivoDevice.swift
//  mac_protocol
//
// 코드 관련 문의 => <기채원> flyingchae@g.skku.edu
//

import Network
import Foundation
import IOKit

enum defineError : Error {
    
    case retryFail
    case readPacketTimeout
    case resultNotZero(result : Int)
}

class RivoDevice {
    
    //languageCode
    let Number = 10
    let English = 20
    let Korean = 30
    
    var mtuConfirmed = false
    var mtu = 20
    var idNow = ""
    
    var upgradeStatus = ""
    var upgrading = false
    
    
    //notification 켜고 buffer clear하는 함수
    func getReady(state : Bool){
     //abstract
    }
    
    func CRC16(data: [UInt8]) -> UInt16
    {
        var crc: UInt16 = 0xffff;
        for i in 0...data.count-1 {
            crc = UInt16((crc>>8)&0xff | (crc<<8))
            crc ^= UInt16(data[i])
            crc ^= UInt16(UInt8(crc & 0xff) >> 4)
            crc ^= (crc<<8)<<4
            crc ^= ((crc & 0xff)<<4)<<1
        }
        return crc
    }
    
    func CRC32(data: [UInt8]) -> UInt32
    {
        var crc: UInt32 = 0xffffffff
        for i in 0...data.count-1 {
            crc ^= UInt32(data[i])
            for _ in stride(from: 8, to: 0, by: -1) {
                crc = (crc>>1)^(0xedb88320 & (((crc&1) != 0) ? 0xffffffff : 0))
            }
        }
        return ~crc
    }
    
    func rcframeCheck(id : String, frame: [UInt8]) -> Bool{
        // check without 'a' 't'
        let len = frame.count
        //print("id :", id, [UInt8](id.utf8),frame[2...3] )
        
        if (!((Array(frame[2...3]) == [UInt8](id.utf8)) && frame[len-2] == 0x0d &&
              frame[len-1] == 0x0a)) {
            print("Invalid frame")
            return false
        }
        //crc error checking
        let payload = Array(frame[6...(len-5)])
        let readCRC = UInt16(frame[len-4]) + UInt16(frame[len-3])<<8
        if( self.CRC16(data: payload) != readCRC) {
            print("Data corrupted : CRC error")
            return false
        }
        return true
    }
    
    //abstract
    func writePacket(data : [UInt8], update : Bool) async {}
    func readPacket() async throws -> [UInt8] {
        return [0]
    }
    
    func composeSendframe(id: String, payload : [UInt8]) -> [UInt8]{
        
        /* Big endian
         var sendFrame = ("AT"+id).utf8.map{ UInt8($0) } // convert string into byte array
         sendFrame.append(UInt8(payload.count>>8))
         sendFrame.append(UInt8(payload.count&0xff))
         sendFrame.append(contentsOf: payload)
         let crc = self.CRC16(data: payload)
         sendFrame.append(UInt8(crc>>8))
         sendFrame.append(UInt8(crc&0xff))
         sendFrame.append(0x0d)
         sendFrame.append(0x0a)
         */
        
        // Little endian
        var sendFrame = ("AT"+id).utf8.map{ UInt8($0)}
        
        sendFrame.append(UInt8(payload.count&0xff))
        sendFrame.append(UInt8((payload.count>>8)&0xff))
        sendFrame.append(contentsOf: payload)
        let crc = self.CRC16(data: payload)
        sendFrame.append(UInt8(crc&0xff))
        sendFrame.append(UInt8((crc>>8)&0xff))
        sendFrame.append(0x0d)
        sendFrame.append(0x0a)
        
        return sendFrame
    }
    
    
    func sendAndReceive(id : String, payload:[UInt8]) async throws -> [UInt8] {
        
        if (!mtuConfirmed) {
            mtu = try await getMTUSize() //retry fail error
            mtuConfirmed = true
        }
        let sendFrame = composeSendframe(id: id, payload: payload)
        var sendSize : Int
        idNow = id
        
        for i in 0...3 {
            //print("\(i)번째 sendAndReceive ")
            var pos = 0
            let frameSize = payload.count + 10
            
            getReady(state : true)
            //send frame. 보통 1번만 실행됨
            while pos < frameSize {
                sendSize = min(mtu,frameSize-pos )
                await writePacket(data: Array(sendFrame[pos...pos+sendSize-1]), update: false)
                pos += sendSize
            }
            do{
                //receive frame. 보통 1번만 실행됨
                var receiveFrame : [UInt8]
                receiveFrame = try await readPacket()
                if(receiveFrame.count < 6){
                    continue
                }
                if (receiveFrame[0] == UInt8(ascii:"a") &&
                    receiveFrame[1] == UInt8(ascii:"t")){
                    let len = Int(receiveFrame[4]) + Int(receiveFrame[5]<<8) + 10
                    // 나머지 receive frame. 보통 실행되지않음
                    while receiveFrame.count < len {
                        receiveFrame += try await readPacket()
                    }
                    getReady(state : false)
                    
                    if rcframeCheck(id: id, frame: receiveFrame) {
                        if (receiveFrame[7] != UInt8(0)) {
                            //throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                            print("result is no zero : \(Int(receiveFrame[7]))")
                        }
                        return Array(receiveFrame[6...(len-5)])
                    }//이 밑은 rcframeCheck fail(결국 다시 send Frame)
                } //이 밑은 at 부터 잘못되었을 경우(결국 다시 send Frame)
            }
            catch {
                print("readPacketTimeout !")
                continue
            }
        }
        //for 문을 빠져나오면 무조건 retryFail을 throw
        print("retryFail~")
        throw defineError.retryFail
    }
    
   /* updateData 용 */
    func sendAndReceive2(id : String, payload:[UInt8]) async throws  {
        /*
         if (!mtuConfirmed) {
         mtu = try await getMTUSize() //retry fail error
         mtuConfirmed = true
         }
         */
        let sendFrame = composeSendframe(id: id, payload: payload)
        
        var sendSize : Int
        idNow = id
        
        var pos = 0
        let frameSize = payload.count + 10
        
        //send frame
        while pos < frameSize {
            sendSize = min(mtu,frameSize-pos )
            await writePacket(data: Array(sendFrame[pos...pos+sendSize-1]), update: true)
            pos += sendSize
        }
    }
    
    /* Version */
    func getFirmwareVersion() async throws -> String? {
        let payload = try await sendAndReceive(id: "FV", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Date And Time */
    func setDateAndTime(type: Int, nowDate : Date) async throws -> String? {
        // setting Data/Time
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        let year = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "MM"
        let mon = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "dd"
        let day = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "HH"
        let hour = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "mm"
        let min = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "ss"
        let sec = Int(formatter.string(from: nowDate))!
        formatter.dateFormat = "SSSS"
        let millisec = Int(formatter.string(from: nowDate))!
        
        var DTdata = [UInt8]()
        DTdata += [UInt8(1),UInt8(type),UInt8(year & 0xff), UInt8((year >> 8) & 0xff),UInt8(mon),UInt8(day)]
        DTdata += [UInt8(hour),UInt8(min),UInt8(sec),UInt8(millisec & 0xff), UInt8((millisec >> 8) & 0xff)]
 
        let payload = try await sendAndReceive(id: "DT", payload: DTdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* L3/L4 Language */
    func getLanguage() async throws -> String? {
        let payload = try await sendAndReceive(id: "LN", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setLanguage(language1: Int, input_method1: Int, language2: Int, input_method2: Int) async throws -> String? {
        var lgcode : String = String(English)
        lgcode.append(",")
        lgcode.append(String(input_method1+English+1))
        lgcode.append(",")
        if(language2 == 0){ // 한글
            lgcode.append(String(Korean))
            lgcode.append(",")
            lgcode.append(String(input_method2+Korean+1))
        }
        else{ // language == 1, 숫자
            lgcode.append(String(Number))
            lgcode.append(",")
            lgcode.append(String(31)) // get해보니 31이랑 짝꿍.
        }
        
        var Ldata = [UInt8]()
        Ldata.append(UInt8(1))
        Ldata += lgcode.utf8.map{UInt8($0)}; //char->byte(UInt8)
        let payload = try await sendAndReceive(id: "LN", payload: Ldata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* OS/Screen reader */
    func getScreenReader() async throws -> String? {
        let payload = try await sendAndReceive(id: "SR", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setScreenReader(OS: Int) async throws -> String? {
        
        var os : String = ""
        var SRdata = [UInt8]()
        SRdata.append(UInt8(1))
        switch OS {
        case 0 : //"IOS"
            os = "11"
        case 1 : //"Android"
            os = "21"
        case 2 : // "watchOS"
            os = "11"
        default:
            break;
        }
        SRdata += Array(os.utf8)
        
        let payload = try await sendAndReceive(id: "SR", payload: SRdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Voice Guidance UI(X) */
    func getVoiceGuidance() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "VG", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setVoiceGuidance(status: Bool) async throws -> String? {
        
        var VGdata = [UInt8]()
        VGdata.append(UInt8(1))
        if(status){
            //ON
            VGdata.append(UInt8(1))
        } else {
            //OFF
            VGdata.append(UInt8(0))
        }
        
        let payload = try await sendAndReceive(id: "VG", payload: VGdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Locale UI(X) */
    func getLocaleList() async throws-> String? {
        
        let payload = try await sendAndReceive(id: "LC", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    /*
     코드 포맷 정의 필요
     
     func deleteLocale(onResponse: @escaping ([UInt8]?) -> ()){
     var DLdata = [UInt8]()
     DLdata.append(UInt8(3))
     let payload = try await sendAndReceive(id:"LC", payload: DLdata)
     return String(bytes: payload, encoding: .utf8)
     }
    
     */
    
    /* Dictionary UI(X) */
    func getDictionaryList() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "DC", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    /*
     코드 포맷 정의 필요
     func deleteDictionary(onResponse: @escaping ([UInt8]?) -> ()){
     var DDdata = [UInt8]()
     DDdata.append(UInt8(3))
     let payload = try await sendAndReceive(id:"DC", payload: DDdata)
     return String(bytes: payload, encoding: .utf8)
     }
     */
    
    /* Name */
    func getRivoName() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "RN", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setRivoName(name: String) async throws -> String? {
        var RNdata = [UInt8]()
        RNdata.append(UInt8(1))
        RNdata += [UInt8](name.utf8)
        
        let payload = try await sendAndReceive(id: "RN", payload: RNdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    func deleteRivoName() async throws -> String? {
        let payload = try await sendAndReceive(id: "RN", payload: [3])
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Device Info */
    func getDeviceInfo() async throws -> String? {
        let payload = try await sendAndReceive(id: "IF", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    // 공장에서만 사용
    func setDeviceInfo(info: String) async throws -> String? {
        var SDIdata = [UInt8]()
        SDIdata.append(UInt8(1))
        SDIdata.append(UInt8(info)!)
        
        let payload = try await sendAndReceive(id: "IF", payload: SDIdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Find my Rivo */
    func findMyRivo(action: Int) async throws -> String? {
        // reserve == 0 setting
        var FMRdata = [UInt8]()
        FMRdata.append(UInt8(0))
        FMRdata.append(UInt8(exactly: action)!)
        FMRdata.append(UInt8(0))
        
        let payload = try await sendAndReceive(id: "RV", payload: FMRdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* result?
     func findMyPhoneAck() async -> String? {
     var FMPdata = [UInt8]()
     FMPdata.append(UInt8(2))
     //result ?
     write(cmd: "RV", data: [0])
     return await withCheckedContinuation { continuation in
     read(sentCmd: "RV", onResponse: {(str) -> () in
     print("data received: ", str!.description)
     continuation.resume(returning: str)
     })
     }
     }
     */
    
    /* MTU size */
    
    func getMTUSize() async throws -> Int {
        
        let sendFrame = composeSendframe(id: "MT", payload: [0])
        let MTUFrameLen = 11
        
        for _ in 0...2 {
            
            getReady(state : true)
            idNow = "MT"
            await writePacket(data: sendFrame, update : false)
            
            var receiveFrame : [UInt8]
            do{
                receiveFrame = try await readPacket()
                
                if (receiveFrame.count < MTUFrameLen){
                    continue
                }
                getReady(state : false)
                
                if (receiveFrame[0] == UInt8(ascii:"a") &&
                    receiveFrame[1] == UInt8(ascii:"t")){
                    if(rcframeCheck(id: "MT", frame: receiveFrame)) {
                        if (receiveFrame[7] != UInt8(0)) {
                            throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                        }
                        print("mtu는 ",Int(receiveFrame[8]) + Int(receiveFrame[9]<<8))
                        return Int(receiveFrame[8]) + Int(receiveFrame[9]<<8)
                    }
                }
            }
            catch defineError.readPacketTimeout{
                print("readPacketTimeout !")
                continue
            }
        }
        print("retryFail")
        throw defineError.retryFail
    }
    
    func setMTUSize(MTUSize: Int) async throws -> String? {
        var SMSdata = [UInt8]()
        SMSdata.append(UInt8(1))
        SMSdata.append(UInt8(MTUSize))
        
        let payload = try await sendAndReceive(id: "MT", payload: SMSdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Rivo Status */
    func getRivoStatus() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "RS", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    /* Update Control */
    func updateCheck() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "UM", payload: [7])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func updateStart(type : Int , totalSize : Int, totalCrc : UInt32, dataInfoSize : Int, dataInfo : [UInt8]) async throws -> String? {
        print("updateStart")
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        //data type(1) + data total size(4) + total crc(4) + data info size(2) + data info(n)
        USdata.append(UInt8(type)) // 2-mcu Main, 3-mcu boot, 4-bt
             
        USdata.append(UInt8(totalSize & 0xff))
        USdata.append(UInt8((totalSize >> 8) & 0xff))
        USdata.append(UInt8((totalSize >> 16) & 0xff))
        USdata.append(UInt8((totalSize >> 24) & 0xff))
         
        USdata.append(UInt8(totalCrc & 0xff))
        USdata.append(UInt8((totalCrc >> 8) & 0xff))
        USdata.append(UInt8((totalCrc >> 16) & 0xff))
        USdata.append(UInt8((totalCrc >> 24) & 0xff))
        
        USdata.append(UInt8(dataInfoSize &  0xff))
        USdata.append(UInt8((dataInfoSize >> 8) &  0xff))
        
        USdata += dataInfo
        
        let payload = try await sendAndReceive(id: "UM", payload: USdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    func updateData(seqNum : Int, dataSize : Int, data : [UInt8]) async throws  {
        print("updateData() \(seqNum)번째")
        var UDdata = [UInt8]()
        UDdata.append(UInt8(1))
        
        UDdata.append(UInt8(seqNum & 0xff))
        UDdata.append(UInt8((seqNum >> 8) &  0xff))
        
        //data crc(2) + data size(2) + data(n)
        let crc = CRC16(data: data)
        UDdata.append(UInt8(crc &  0xff))
        UDdata.append(UInt8((crc >> 8) &  0xff))
        
        UDdata.append(UInt8(dataSize &  0xff))
        UDdata.append(UInt8((dataSize >> 8) &  0xff))
        
        UDdata += data
       
        try await sendAndReceive2(id: "UM", payload: UDdata)
        }
    
    
    func verifyData(totalCrc : UInt32) async throws -> String? {
        
        print("verifyData()")
        var VDdata = [UInt8]()
        VDdata.append(UInt8(2))
        VDdata.append(UInt8(totalCrc & 0xff))
        VDdata.append(UInt8((totalCrc >> 8) & 0xff))
        VDdata.append(UInt8((totalCrc >> 16) & 0xff))
        VDdata.append(UInt8((totalCrc >> 24) & 0xff))
        
        let payload = try await sendAndReceive(id: "UM", payload: VDdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    
    func updateEnd() async throws -> String? {
        print("updateEnd()")
        upgradeStatus = "업그레이드 완료되었습니다."
        var UEdata = [UInt8]()
        UEdata.append(UInt8(3))
        //업그레이드 완료후 동작 action
        UEdata.append(UInt8(3)) //upgrade&reset. soft reset - 1
        let payload = try await sendAndReceive(id: "UM", payload: UEdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    func updateCancel() async throws -> String? {
        let payload = try await sendAndReceive(id: "UM", payload: [4])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func updatePause() async throws -> String? {
        let payload = try await sendAndReceive(id: "UM", payload: [5])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func updateResume(seqNum : Int) async throws -> String? {
        
        var URdata = [UInt8]()
        URdata.append(UInt8(6))
        URdata.append(UInt8(seqNum &  0xff))
        URdata.append(UInt8((seqNum >> 8) &  0xff))
        
        let payload = try await sendAndReceive(id: "UM", payload: URdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
    func fileDownloader(downloadURL : URL, index : Int) async -> URL {
        
        var fileName = "default"
        switch index {
        case 0:
            fileName = "MR3.bin"
        case 1:
            fileName = "MR3boot.bin"
        case 2:
            fileName = "bt.bin"
        default:
            fileName = "default"
        }
        let documentsUrl: URL =  FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first! as URL
        let destinationFileUrl = documentsUrl.appendingPathComponent(fileName)
        let fileURL = downloadURL
        
        let sessionConfig = URLSessionConfiguration.default
        let session = URLSession(configuration: sessionConfig)
        
        let request = URLRequest(url:fileURL)
        return try await withCheckedContinuation { continuation in
            
        let task = session.downloadTask(with: request) { (tempLocalUrl, response, error) in
            if let tempLocalUrl = tempLocalUrl, error == nil {
                // Success
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    print("Successfully downloaded. Status code: \(statusCode)")
                }
                do {
                    try FileManager.default.copyItem(at: tempLocalUrl, to: destinationFileUrl)
                    print("destinationFileUrl :  \(destinationFileUrl)")
                    continuation.resume(returning: destinationFileUrl)
                } catch (let writeError) {
                    print("Error creating a file \(destinationFileUrl) : \(writeError)")
                    continuation.resume(returning: destinationFileUrl)
                }
            } else {
                print("Error took place while downloading a file. Error description: %@", error?.localizedDescription);
            }
        }
            task.resume()
        }
    }
    
    func update(index : Int) async throws {
     
        let fwURL = URL(string: "https://rivo.me/app/MR3.bin")
        //type:2. 보낸다음 action 0 ?
        let blURL = URL(string: "https://rivo.me/app/MR3boot.bin")
        //type :3 data_Info : FW_VER. 보낸다음 action 3
        let btURL = URL(string: "https://rivo.me/app/bt.bin")
        var fileURL : URL
        var type = 0
        switch index {
        case 0:
            fileURL = await fileDownloader(downloadURL: fwURL!,index: index)
            type = 2
        case 1:
            fileURL = await fileDownloader(downloadURL: blURL!,index: index)
            type = 3
        case 2:
            fileURL = await fileDownloader(downloadURL: btURL!,index: index)
            type = 4
        default:
            print("default")
            return
        }
        
        let rawData  = try Data(contentsOf: fileURL)
        let data = [UInt8](rawData)
        let dataInfo = Array("FW_VER".utf8)
        let totalCRC = CRC32(data: data)
        let totalSize = data.count
        var usreceive = try await updateStart(type: type, totalSize: totalSize, totalCrc: totalCRC, dataInfoSize: dataInfo.count, dataInfo: dataInfo)
        //print("usreceive : ",usreceive)
        var sendSize : Int
        var seqNum = 0
        var pos = 0
        //print("totalSize : ", totalSize)
        for i in 0...2 {
            //print("번째냐면 !! ",i)
            upgrading = true
            getReady(state: true)
        while pos <= totalSize-1 {

            sendSize = min(mtu-20,totalSize-pos)
            //print(totalSize)
            try await updateData(seqNum: seqNum, dataSize: sendSize, data: Array(data[pos...pos+sendSize-1]))
            pos += sendSize
            seqNum += 1
            upgradeStatus = "\(Int(Double(pos)/Double(totalSize)*100))%"
            print(upgradeStatus)
        }
            getReady(state: false)
            try await Task.sleep(nanoseconds : UInt64(1) * 1_000_000_000)
            upgrading = false
            let vreceive = try await verifyData(totalCrc: totalCRC)
            print("vreceive", vreceive)
            let uend = try await updateEnd()
            print("uend", uend)
            
        }
    }
}

