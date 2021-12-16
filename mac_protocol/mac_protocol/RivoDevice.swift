//
//  RivoDevice.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/07.
//
import Network
import Foundation
import IOKit

class RivoDevice {
        
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
             for j in stride(from: 8, to: 0, by: -1) {
                 crc = (crc>>1)^(0xedb88320 & (((crc&1) != 0) ? 0xffffffff : 0))
             }
         }
         return ~crc
     }
     
    func write(cmd: String, data: [UInt8]) {
        // do nothing
        
    }
    func read(sentCmd: String, onResponse: @escaping (String?) -> ()){
        // do nothing
    }
    
    /* Version */
    func getFirmwareVersion() async -> String? {
        write(cmd: "FV", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "FV", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Date and time */
    func setDateAndTime(type: Int) async -> String? {
        // setting Data/Time
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        let year = formatter.string(from: Date())
        formatter.dateFormat = "MM"
        let mon = formatter.string(from: Date())
        formatter.dateFormat = "dd"
        let day = formatter.string(from: Date())
        formatter.dateFormat = "HH"
        let hour = formatter.string(from: Date())
        formatter.dateFormat = "mm"
        let min = formatter.string(from: Date())
        formatter.dateFormat = "ss"
        let sec = formatter.string(from: Date())
        formatter.dateFormat = "SSSS"
        let millisec = formatter.string(from: Date())
        
        let yearInt = Int(year)!
        let monInt = Int(mon)!
        let dayInt = Int(day)!
        let hourInt = Int(hour)!
        let minInt = Int(min)!
        let secInt = Int(sec)!
        let millisecInt = Int(millisec)!
        
        var DTdata = [UInt8]()
        DTdata.append(UInt8(1))
        DTdata.append(UInt8(type))
        DTdata.append(UInt8(yearInt/100))
        DTdata.append(UInt8(yearInt%100))
        DTdata.append(UInt8(monInt))
        DTdata.append(UInt8(dayInt))
        DTdata.append(UInt8(hourInt))
        DTdata.append(UInt8(minInt))
        DTdata.append(UInt8(secInt))
        DTdata.append(UInt8(millisecInt/100))
        DTdata.append(UInt8(millisecInt%100))
        
        write(cmd: "DT", data: DTdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "DT", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* L3/L4 Language */
    func getLanguage() async -> String? {
        write(cmd: "LN", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "LN", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
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
        SLdata += lgcode.utf8.map{UInt8($0)};
        
        write(cmd: "LN", data: SLdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "LN", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* OS/Screen reader */
    func getScreenReader() async -> String? {
        write(cmd: "SR", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "SR", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
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
        
        write(cmd: "SR", data: SSdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "SR", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Voice Guidance */
    func getVoiceGuidance() async -> String? {
        write(cmd: "VG", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "VG", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
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
        write(cmd: "VG", data: SVGdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "VG", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Locale */
    func getLocaleList() async -> String? {
        write(cmd: "LC", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "LC", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* 코드 포맷 정의 필요
    func deleteLocale(onResponse: @escaping ([UInt8]?) -> ()){
        var DLdata = [UInt8]()
        DLdata.append(UInt8(3))
        write(cmd: "LC", data: [0])
        read(sentCmd: "LC", onResponse: onResponse)
    }
    */
    
    /* Dictionary */
    func getDictionaryList() async -> String? {
        write(cmd: "DC", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "DC", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
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
        write(cmd: "RN", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RN", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    func setRivoName(name: String) async -> String? {
        var SRNdata = [UInt8]()
        SRNdata.append(UInt8(1))
        SRNdata.append(UInt8(name)!)
        write(cmd: "RN", data: SRNdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RN", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    func deleteRivoName() async -> String? {
        write(cmd: "RN", data: [3])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RN", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Device Info */
    func getDeviceInfo() async -> String? {
        write(cmd: "IF", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "IF", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    // 공장에서만 사용
    func setDeviceInfo(info: String) async -> String? {
        var SDIdata = [UInt8]()
        SDIdata.append(UInt8(1))
        SDIdata.append(UInt8(info)!)
        write(cmd: "IF", data: SDIdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "IF", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Find my Rivo */
    func findMyRivo(action: Int) async -> String? {
        // reserve == 0 setting
        var FMRdata = [UInt8]()
        FMRdata.append(UInt8(0))
        FMRdata.append(UInt8(exactly: action)!)
        FMRdata.append(UInt8(0))
        write(cmd: "RV", data: FMRdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RV", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    /* result?
    func findMyPhoneAck() async -> String? {
        var FMPdata = [UInt8]()
        FMPdata.append(UInt8(2))
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
    func getMTUSize() async -> String? {
        write(cmd: "MT", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "MT", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    func setMTUSize(MTUSize: Int) async -> String? {
        var SMSdata = [UInt8]()
        SMSdata.append(UInt8(1))
        SMSdata.append(UInt8(MTUSize))
        write(cmd: "MT", data: SMSdata)
        return await withCheckedContinuation { continuation in
            read(sentCmd: "MT", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Rivo Status */
    func getRivoStatus() async -> String? {
        write(cmd: "RS", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RS", onResponse:{(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    func setRivoStatus() async -> String? {
        write(cmd: "RS", data: [0])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "RS", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /* Update Control */
    func updateCheck() async -> String? {
        write(cmd: "UM", data: [7])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "UM", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
    
    /*
    func updateStart() async -> String? {
        var USdata = [UInt8]()
        USdata.append(UInt8(0))
        write(cmd: "UM", data: [])
        return await withCheckedContinuation { continuation in
            read(sentCmd: "UM", onResponse: {(str) -> () in
                print("data received: ", str!.description)
                continuation.resume(returning: str)
            })
        }
    }
     */
     
}
