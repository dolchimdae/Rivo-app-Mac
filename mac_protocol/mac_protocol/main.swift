//
//  main.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/11.
//
import Network
import Foundation
import IOKit
var device = UDPDevice()
// test
Task{
  let data = await device.getFirmwareVersion()
}
dispatchMain()
