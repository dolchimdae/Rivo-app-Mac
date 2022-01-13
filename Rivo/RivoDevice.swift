//
//  RivoDevice.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/07.
// chaewon kee 's 220113 ver

import Network
import Foundation
import IOKit

enum defineError : Error {
    
    case retryFail
    case readPacketFail
    case resultNotZero(result : Int)
}

class RivoDevice {
    
    var mtuConfirmed = false
    var mtu = 20
    
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
    
    func rcframeCheck(id : String, frame: [UInt8]) -> Bool{ //witihout at
        // command error checking
        let len = frame.count
        //let bytes = [UInt8](frame);
        if (!(Array(frame[2...3]) == [UInt8](id.utf8) &&
              frame[len-2] == 0x0d &&
              frame[len-1] == 0x0a)) {
            // error
            print("Invalid frame")
            return false
        }
        //crc error checking
        let payload = Array(frame[6...(len-5)])
        let readCRC = UInt16(frame[len-4]) + UInt16(frame[len-3])<<8
        if( self.CRC16(data: payload) != readCRC) {
            print("Data corrupted")
            return false
        }
        return true
    }
    
    // getMTU 를 mtu 로 생성자 async 하게 하거나(1) sendandreceive함수안에서 mtu confirmed bool 변수 안됐을 때 (2)
    // 다만 getMTU 함수는 sendAndReceive 부르지않도록...(무한)
    //super clasee rivo class
    //read write api timeout 설정잇는지..없으면 타이머 기능으로 다시 써야함
    //sendandreceive timeout
    //send and receive 묶어서 receive 잘못됐으면 다시 쓰기
    
    // Get MTU async 하게 부르나? 기본 20 - 처음 무조건 한번 불러 사용하기
    //익셉션 처리... ui 에 나타나게
    //재전송 타임아웃
    
    func writePacket(data : [UInt8]) {}
    func readPacket(onResponse: @escaping ([UInt8]) -> ()) {
        //do nothing. onResponse([UInt8])로 구현 in subclass
    }
    
    func sendAndReceive(id : String, payload:[UInt8]) async throws -> [UInt8] {
        
        print("sendAndReceive 시작")
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
        
        if (!mtuConfirmed) {
            do{
                mtu = try await getMTUSize2()
                print("mtu는 \(mtu)")
            }
            catch defineError.retryFail {
                print("getMTUSize retry fail")
                throw defineError.retryFail //ui에 다시 연결하라고 뜨도록..
            }
            catch defineError.resultNotZero(let result) {
                print("result code : \(result)")
            }
            catch {
                print("Unexpected error: \(error).")
            }
            mtuConfirmed = true
        }
        
        //Little endian
        var sendFrame = ("AT"+id).utf8.map{ UInt8($0)}
        sendFrame.append(UInt8(payload.count&0xff))
        sendFrame.append(UInt8((payload.count>>8)&0xff))
        sendFrame.append(contentsOf: payload)
        let crc = self.CRC16(data: payload)
        sendFrame.append(UInt8(crc&0xff))
        sendFrame.append(UInt8((crc>>8)&0xff))
        sendFrame.append(0x0d)
        sendFrame.append(0x0a)
        
        var sendSize : Int
        
        for _ in 0...2 {
            var pos = 0
            let frameSize = payload.count + 10
            
            //send frame
            while pos < frameSize {
                sendSize = min(mtu,frameSize-pos )
                writePacket(data: Array(sendFrame[pos...pos+sendSize-1]))
                pos += sendSize
            }
            
            //receive frame
            var receiveFrame : [UInt8]
            receiveFrame = await withCheckedContinuation { continuation in
                readPacket(onResponse: {(bytes) -> () in
                    print("data received: \(bytes)")
                    continuation.resume(returning: bytes)
                })
            }
            
            if (receiveFrame[0] == UInt8(ascii:"a") &&
                receiveFrame[1] == UInt8(ascii:"t")){
                
                let len = Int(receiveFrame[4]) + Int(receiveFrame[5]<<8)+10
                //receive frame 나머지
                print("rcc \(receiveFrame.count) len \(len)")
                while receiveFrame.count < len {
                    //오류-> while문 아웃-> write 다시
                    receiveFrame += await withCheckedContinuation { continuation in
                        readPacket(onResponse: {(bytes) -> () in
                            print("data received: \(bytes)")
                            continuation.resume(returning: bytes)
                        })
                    }
                }
                if rcframeCheck(id: id, frame: receiveFrame) {
                    if (receiveFrame[7] != UInt8(0)) {
                        throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                    }
                    print("return 은 됐어")
                    return Array(receiveFrame[6...(len-5)])
                }else{
                    continue
                }
            } else { //at 부터 잘못되었을 경우(다시 send Frame)
                continue
            }
        }
        //for 문을 빠져나오면 무조건 retryFail을 throw
        throw defineError.retryFail
    }
    
    func write(cmd: String, data: [UInt8]) {
        // do nothing
    }
    func read(sentCmd: String, onResponse: @escaping (String?) -> ()){
    }
    
    /* Version */
    func getFirmwareVersion() async -> String? {
        do{
            let payload = try await sendAndReceive(id: "FV", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "get firmware version fail.."
    }
    
    
    func setDateAndTime(type: Int, nowDate : Date) async -> String? {
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
        DTdata += [UInt8(1),UInt8(type),UInt8(year/100),UInt8(year%100),UInt8(mon),UInt8(day)]
        DTdata += [UInt8(hour),UInt8(min),UInt8(sec),UInt8(millisec/100), UInt8(millisec%100)]
        
        do{
            let payload = try await sendAndReceive(id: "DT", payload: DTdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    
    /* L3/L4 Language */
    func getLanguage() async -> String? {
        do{
            let payload = try await sendAndReceive(id: "LN", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func setLanguage(language1: Int, input_method1: Int, language2: Int, input_method2: Int) async -> String? {
        var lgcode : String = String(language1)
        lgcode.append(",")
        lgcode.append(String(input_method1))
        lgcode.append(",")
        lgcode.append(String(language2))
        lgcode.append(",")
        lgcode.append(String(input_method2))
        
        var SLdata = [UInt8]()
        SLdata.append(UInt8(1))
        SLdata += lgcode.utf8.map{UInt8($0)}; //char->byte(UInt8)
        
        do{
            let payload = try await sendAndReceive(id: "LN", payload: SLdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* OS/Screen reader */
    func getScreenReader() async -> String? {
        do{
            let payload = try await sendAndReceive(id: "SR", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func setScreenReader(OS: String) async -> String? {
        var SSdata = [UInt8]()
        SSdata.append(UInt8(1))
        switch OS {
        case "IOS":
            SSdata.append(UInt8(11))
        case "watchOS":
            SSdata.append(UInt8(12))
        case "Android":
            SSdata.append(UInt8(21))
        default:
            break;
        }
        
        do{
            let payload = try await sendAndReceive(id: "SR", payload: SSdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Voice Guidance */
    func getVoiceGuidance() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "VG", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func setVoiceGuidance(status: Bool) async -> String? {
        var SVGdata = [UInt8]()
        SVGdata.append(UInt8(1))
        if(status){
            //ON
            SVGdata.append(UInt8(1))
        } else {
            //OFF
            SVGdata.append(UInt8(0))
        }
        
        do{
            let payload = try await sendAndReceive(id: "VG", payload: SVGdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Locale */
    func getLocaleList() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "LC", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* 코드 포맷 정의 필요
     func deleteLocale(onResponse: @escaping ([UInt8]?) -> ()){
     var DLdata = [UInt8]()
     DLdata.append(UInt8(3))
     write(cmd: "LC", data: [0])
     read(sentCmd: "LC", onResponse: onResponse)
     }
     
     // result?
     func deleteLocaleAck() async -> String? {
     var DLAdata = [UInt8]()
     DLAdata.append(UInt8(3))
     
     //   DLAdata.append(UInt8(1))
     write(cmd: "LC", data: DLAdata)
     return await withCheckedContinuation { continuation in
     read(sentCmd: "LC", onResponse: {(str) -> () in
     print("data received: ", str!.description)
     continuation.resume(returning: str)
     })
     }
     }
     */
    
    /* Dictionary */
    func getDictionaryList() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "DC", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* 코드 포맷 정의 필요
     func deleteDictionary(onResponse: @escaping ([UInt8]?) -> ()){
     var DDdata = [UInt8]()
     DDdata.append(UInt8(3))
     write(cmd: "DC", data: [0])
     read(sentCmd: "DC", onResponse: onResponse)
     }
     */
    
    /* Name */
    func getRivoName() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "RN", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func setRivoName(name: String) async -> String? {
        var SRNdata = [UInt8]()
        SRNdata.append(UInt8(1))
        SRNdata.append(UInt8(name)!)
        
        do{
            let payload = try await sendAndReceive(id: "RN", payload: SRNdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func deleteRivoName() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "RN", payload: [3])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Device Info */
    func getDeviceInfo() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "IF", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    // 공장에서만 사용
    func setDeviceInfo(info: String) async -> String? {
        var SDIdata = [UInt8]()
        SDIdata.append(UInt8(1))
        SDIdata.append(UInt8(info)!)
        
        do{
            let payload = try await sendAndReceive(id: "IF", payload: SDIdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Find my Rivo */
    func findMyRivo(action: Int) async -> String? {
        // reserve == 0 setting
        var FMRdata = [UInt8]()
        FMRdata.append(UInt8(0))
        FMRdata.append(UInt8(exactly: action)!)
        FMRdata.append(UInt8(0))
        
        do{
            let payload = try await sendAndReceive(id: "RV", payload: FMRdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
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
    /*
    func getMTUSize() async -> String? {
        write(cmd: "MT", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "MT", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
     */
    func getMTUSize2() async throws -> Int {
        
        var sendFrame = ("AT"+"MT").utf8.map{ UInt8($0) } // convert string into byte array
        sendFrame.append(UInt8([0].count&0xff))
        sendFrame.append(UInt8(([0].count>>8)&0xff))
        sendFrame.append(contentsOf: [0])
        let crc = self.CRC16(data: [0])
        sendFrame.append(UInt8(crc&0xff))
        sendFrame.append(UInt8((crc>>8)&0xff))
        sendFrame.append(0x0d)
        sendFrame.append(0x0a)
        
        for _ in 0...2 {
            writePacket(data: sendFrame)
            var receiveFrame : [UInt8]
            receiveFrame = await withCheckedContinuation { continuation in
                readPacket(onResponse: {(bytes) -> () in
                    print("data received: \(bytes)")
                    continuation.resume(returning: bytes)
                })
            }
            print("receiveFrame ~:! \(receiveFrame)")
            if (receiveFrame[0] == UInt8(ascii:"a") && receiveFrame[1] == UInt8(ascii:"t")
                && rcframeCheck(id: "MT", frame: receiveFrame)) == true {
                if (receiveFrame[7] != UInt8(0)) {
                    throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                }
                print("뀨")
                return Int(receiveFrame[8]) + Int(receiveFrame[9]<<8)
            }else{
                continue
            }
        }
        throw defineError.retryFail
    }
    
    func setMTUSize(MTUSize: Int) async -> String? {
        var SMSdata = [UInt8]()
        SMSdata.append(UInt8(1))
        SMSdata.append(UInt8(MTUSize))
        
        do{
            let payload = try await sendAndReceive(id: "MT", payload: SMSdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Rivo Status */
    func getRivoStatus() async -> String? {
        do{
            let payload = try await sendAndReceive(id: "RS", payload: [0])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /* Update Control */
    func updateCheck() async -> String? {
        do{
            let payload = try await sendAndReceive(id: "UM", payload: [7])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    // 작 성 중
    func updateStart() async -> String? {
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        //data type(1) + data total size(4) + total crc(4) + data info size(2) + data info(n)
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: USdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    func updateStart2() async -> String? {
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        //data type(1) + data total size(4) + total crc(4) + data info size(2) + data info(n)
        var data_info_size : CShort
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: USdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    /*
     // firmware file 잘라서 보내는 함수 ?
     func updateData(seqNum : Int) async -> String? {
     var UDdata = [UInt8]()
     UDdata.append(UInt8(1))
     UDdata.append(UInt8(seqNum))
     //data crc(2) + data size(2) + data(n)
     write(cmd: "UM", data: UDdata)
     return await withCheckedContinuation { continuation in
     read(sentCmd: "UM", onResponse: {(str) -> () in
     print("data received: ", str!.description)
     continuation.resume(returning: str)
     })
     }
     }
     */
    
    func verifyData(totalCRC : Int) async -> String? {
        var VDdata = [UInt8]()
        VDdata.append(UInt8(2))
        VDdata.append(UInt8(totalCRC))
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: VDdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    
    func updateEnd() async -> String? {
        var UEdata = [UInt8]()
        UEdata.append(UInt8(3))
        
        //업그레이드 완료후 동작 action
        UEdata.append(UInt8(1))
    
        do{
            let payload = try await sendAndReceive(id: "UM", payload: UEdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func updateCancel() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: [4])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func updatePause() async -> String? {
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: [5])
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
    func updateResume(seqNum : Int) async -> String? {
        var URdata = [UInt8]()
        URdata.append(UInt8(6))
        URdata.append(UInt8(seqNum))
        
        do{
            let payload = try await sendAndReceive(id: "UM", payload: URdata)
            return String(bytes: payload, encoding: .utf8)
        }
        catch defineError.retryFail {
            print("sendAndReceive retry fail")
        }
        catch defineError.resultNotZero(let result) {
            print("result code : \(result)")
        }
        catch {
            print("Unexpected error: \(error).")
        }
        return "Default"
    }
    
}
