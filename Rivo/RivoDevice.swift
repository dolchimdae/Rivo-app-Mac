//
//  RivoDevice.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/07.
//  Reborn by chaewon kee on 2022/01/14

//  개선 사항 : 불필요한 else continue 삭제, compose send frame() 추가, write/reaedPAcket 내부로 continuation 삽입 - 둘다 async 로 수정
//   에러 처리 다 propagate 되도록 수정 (각종 함수들)

/*
 서버
 추가 작업 (예정)

 타임 아웃 추가 : udp/ble 소켓에서 set 하는 경우 Or 혹시 없으면 함수 내부에서 처리하거나 (타임아웃(숫자 상수처리. 뜬금없이 숫자 있으면 안좋음) 처리 찾아보기
 
 ble device read/write packet 구현 , 연결 및 동작 확인
 update control 파트 구현
 익셉션 처리 ->  ui 에 나타나게, unit test 구성
 */

import Network
import Foundation
import IOKit

enum defineError : Error {
    
    case retryFail
    case readPacketNWError
    case readPacketTimeout
    case resultNotZero(result : Int)
}

class RivoDevice {
    
    
    var mtuConfirmed = false
    var mtu = 20
    /*
    func RivoDevice(){
        mtu = try await getMTUSize2()
    }
    */
    
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
    
    func rcframeCheck(id : String, frame: [UInt8]) -> Bool{ // check without at
        // command error checking
        let len = frame.count
        
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
    
    //abstract
    func writePacket(data : [UInt8]) async {}
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
        
        print("sendAndReceive 시작")
        
        if (!mtuConfirmed) {
            mtu = try await getMTUSize2() //retry fail error
            mtuConfirmed = true
        }
        
        let sendFrame = composeSendframe(id: id, payload: payload)
        
        var sendSize : Int
        
        for _ in 0...2 {
            
            var pos = 0
            let frameSize = payload.count + 10
           
            // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { // Change `2.0` to the desired number of seconds.
            // Code you want to be delayed}
            
            //send frame
            while pos < frameSize {
                sendSize = min(mtu,frameSize-pos )
                await writePacket(data: Array(sendFrame[pos...pos+sendSize-1]))
                pos += sendSize
            }
            
            //receive frame
            var receiveFrame : [UInt8]
            //receiveFrame = DispatchQueue.main.asyncAfter(deadline: <#T##DispatchTime#>, execute: <#T##DispatchWorkItem#>)
            receiveFrame = try await readPacket()
            
            if (receiveFrame[0] == UInt8(ascii:"a") &&
                receiveFrame[1] == UInt8(ascii:"t")){
                
                let len = Int(receiveFrame[4]) + Int(receiveFrame[5]<<8) + 10
                // 나머지 receive frame
                //print("rcc \(receiveFrame.count) len \(len)")
                while receiveFrame.count < len {
                    receiveFrame += try await readPacket()
                }
                
                if rcframeCheck(id: id, frame: receiveFrame) {
                    if (receiveFrame[7] != UInt8(0)) {
                        throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                    }
                    return Array(receiveFrame[6...(len-5)])
                }//이 밑은 rcframeCheck fail(결국 다시 send Frame)
            } //이 밑은 at 부터 잘못되었을 경우(결국 다시 send Frame)
        }
        //for 문을 빠져나오면 무조건 retryFail을 throw
        throw defineError.retryFail
    }
    
    /* Version */
    func getFirmwareVersion() async throws -> String? {
        let payload = try await sendAndReceive(id: "FV", payload: [0])
        return String(bytes: payload, encoding: .utf8)
        //return "get firmware version fail.."
    }
    
    
    func setDateAndTime(type: Int, nowDate : Date) async throws -> String? {
        // setting Data/Time
        let formatter = DateFormatter() //더 간단한 방법?
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
 
        let payload = try await sendAndReceive(id: "DT", payload: DTdata)
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    
    /* L3/L4 Language */
    func getLanguage() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "LN", payload: [0])
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    func setLanguage(language1: Int, input_method1: Int, language2: Int, input_method2: Int) async throws -> String? {
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
        
        let payload = try await sendAndReceive(id: "LN", payload: SLdata)
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    /* OS/Screen reader */
    func getScreenReader() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "SR", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setScreenReader(OS: String) async throws -> String? {
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
        
        let payload = try await sendAndReceive(id: "SR", payload: SSdata)
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    /* Voice Guidance */
    func getVoiceGuidance() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "VG", payload: [0])
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    func setVoiceGuidance(status: Bool) async throws -> String? {
        var SVGdata = [UInt8]()
        SVGdata.append(UInt8(1))
        if(status){
            //ON
            SVGdata.append(UInt8(1))
        } else {
            //OFF
            SVGdata.append(UInt8(0))
        }
        
        let payload = try await sendAndReceive(id: "VG", payload: SVGdata)
        return String(bytes: payload, encoding: .utf8)

    }
    
    /* Locale */
    func getLocaleList() async throws-> String? {
        
        let payload = try await sendAndReceive(id: "LC", payload: [0])
        return String(bytes: payload, encoding: .utf8)
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
    func getDictionaryList() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "DC", payload: [0])
        return String(bytes: payload, encoding: .utf8)
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
    func getRivoName() async throws -> String? {
        
        let payload = try await sendAndReceive(id: "RN", payload: [0])
        return String(bytes: payload, encoding: .utf8)
    }
    
    func setRivoName(name: String) async throws -> String? {
        var SRNdata = [UInt8]()
        SRNdata.append(UInt8(1))
        SRNdata.append(UInt8(name)!)
        
        let payload = try await sendAndReceive(id: "RN", payload: SRNdata)
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
        
        let sendFrame = composeSendframe(id: "MT", payload: [0])
        
        for _ in 0...2 {
            await writePacket(data: sendFrame)
            var receiveFrame : [UInt8]
            receiveFrame = try await readPacket()
            
            print("receiveFrame ~:! \(receiveFrame)")
            if (receiveFrame[0] == UInt8(ascii:"a") && receiveFrame[1] == UInt8(ascii:"t")
                && rcframeCheck(id: "MT", frame: receiveFrame)) == true {
                if (receiveFrame[7] != UInt8(0)) {
                    throw defineError.resultNotZero(result: Int(receiveFrame[7]))
                }
                return Int(receiveFrame[8]) + Int(receiveFrame[9]<<8)
            }
        }
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
    
    // 작 성 중
    func updateStart() async throws -> String? {
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        //data type(1) + data total size(4) + total crc(4) + data info size(2) + data info(n)
        
        let payload = try await sendAndReceive(id: "UM", payload: USdata)
        return String(bytes: payload, encoding: .utf8)
        
    }
    func updateStart2() async throws -> String? {
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        //data type(1) + data total size(4) + total crc(4) + data info size(2) + data info(n)
        var data_info_size : CShort
        
        let payload = try await sendAndReceive(id: "UM", payload: USdata)
        return String(bytes: payload, encoding: .utf8)
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
    
    func verifyData(totalCRC : Int) async throws -> String? {
        var VDdata = [UInt8]()
        VDdata.append(UInt8(2))
        VDdata.append(UInt8(totalCRC))
        
        let payload = try await sendAndReceive(id: "UM", payload: VDdata)
        return String(bytes: payload, encoding: .utf8)
        
    }
    
    
    func updateEnd() async throws -> String? {
        var UEdata = [UInt8]()
        UEdata.append(UInt8(3))
        
        //업그레이드 완료후 동작 action
        UEdata.append(UInt8(1))
        
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
        URdata.append(UInt8(seqNum))
        
        
        let payload = try await sendAndReceive(id: "UM", payload: URdata)
        return String(bytes: payload, encoding: .utf8)
    }
    
}
