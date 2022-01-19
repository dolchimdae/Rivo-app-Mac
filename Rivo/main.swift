//
//  main.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/11.
//
import Network
import Foundation
import IOKit
import Cocoa


var device = UDPDevice()
// test
print("HELLO@@")
//유닛 테스트
Task{
    //print("HEllO WORLD")
    do{
        let data = try await device.getFirmwareVersion()
        let name = try await device.getRivoName()
        print("firmware version \(data!) rivoname \(name!)")
    }
    catch {
        print("error~")
        return
    }
    //-await device.getLanguage()
    //await device.setLanguage(language1: 10, input_method1: 21, language2: 30, input_method2: 32)
    //await device.getScreenReader()
    //await device.getVoiceGuidance()

    //await device.getDeviceInfo()
    //-await device.findMyRivo(action: 1)
    
}
dispatchMain()

