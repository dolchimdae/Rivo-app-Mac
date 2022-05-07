//
//  BLEDevice.swift
//  Rivo
//

import Network
import Foundation
import IOKit
import CoreBluetooth
import AppKit

let Timeout : Double = 1.5

class BLEDevice : RivoDevice {
    
    var connection: CBPeripheral!
    var continuationW : CheckedContinuation<(), Never>? = nil
    var continuationR : CheckedContinuation<[UInt8], Error>? = nil
   
    var UUID_GATT_NUS_COMMAND_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_RESPONSE_ENDPOINT: CBCharacteristic?
    var UUID_GATT_NUS_DATA_ENDPOINT: CBCharacteristic?
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
    
    override func writePacket(data: [UInt8], update : Bool) async {
        
        print("write : \(data)")
        let data = Data(data) // convert byte array to Data
        buffer = []
        var destination = self.UUID_GATT_NUS_COMMAND_ENDPOINT!
        if(update){
            //updateData() 중에만.
            destination = self.UUID_GATT_NUS_DATA_ENDPOINT!
            writeType = .withoutResponse
            connection.writeValue(data, for: destination, type: writeType)
            return
        }else{
            writeType = .withResponse
            return await withCheckedContinuation { continuation in
                connection.writeValue(data, for: destination, type: writeType)
                self.continuationW = continuation
            }
        }
    }
    
    var buffer : [UInt8] = []
    
    override func readPacket() async throws -> [UInt8] {
        
        return try await withThrowingTaskGroup(of: [UInt8].self) {
            group in
            group.addTask{
                if self.buffer != [] {
                    return self.buffer
                }
                return try await withCheckedThrowingContinuation {
                    continuation in
                    self.continuationR = continuation
                }
            }
            // 현재 타임아웃 시 throw error 가 처리되지않음. 문서참조
            group.addTask {
                //print("buffer", self.buffer)
                try await Task.sleep(nanoseconds : UInt64(Timeout) * 1_000_000_000)
                try Task.checkCancellation()
                print("timeout!")
                throw defineError.readPacketTimeout
            }
        
            let result = try await group.next()!
            self.continuationR = nil
            group.cancelAll()
            print("readpacket result:" ,result)
            return result
        }
    }
}




