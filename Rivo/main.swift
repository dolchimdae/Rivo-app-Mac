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

Task{
    //print("HEllO WORLD")
    let data = await device.getFirmwareVersion()
    //-await device.getLanguage()
    //await device.setLanguage(language1: 10, input_method1: 21, language2: 30, input_method2: 32)
    //await device.getScreenReader()
    //await device.getVoiceGuidance()
    //let name = await device.getRivoName()
    //await device.getDeviceInfo()
    //-await device.findMyRivo(action: 1)
    
    print("firmware version \(data) ")
}
dispatchMain()

