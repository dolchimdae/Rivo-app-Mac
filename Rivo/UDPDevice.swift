//
//  protocol.swift
//  mac_protocol
//
//  Created by chaewon Kee on 2022/1/14.
//

import Network
import Foundation
import IOKit

class UDPDevice : RivoDevice {
    
    var connection: NWConnection?
    
    override init() {
        super.init()
            self.connection = NWConnection(host: "127.0.0.1", port: 6999, using: .udp)
            self.connection?.stateUpdateHandler = { (newState) in
            switch (newState) {
            case .ready:
                print("ready")
            case .setup:
                print("setup")
            case .cancelled:
                print("cancelled")
            case .preparing:
                print("Preparing")
            default:
                print("waiting or failed")
            }
        }
        self.connection?.start(queue: .global())
    }
   
    
    override func writePacket(data : [UInt8]) async {
        
        return await withCheckedContinuation { continuation in
            self.connection?.send(content: data, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
                if (NWError == nil){
                    print("send data : \(data)")
                    continuation.resume()
                } else {
                    print("NWError : \(NWError!)")
                }
            })))
        }
    }
    
    override func readPacket() async -> [UInt8]  {
        
        print("to receive")
        
        var result : [UInt8] = [0]
        
        return await withCheckedContinuation { continuation in
            self.connection?.receiveMessage { (data, context, isComplete, error) in
                if (isComplete){
                    let backToString = String(decoding: data!, as: UTF8.self)
                    print("뭘 받았냐면.. \(backToString)")
                    if (data != nil){
                        // command error checking
                        result = [UInt8](data!)
                        print("result is 1 \(result)")
                        continuation.resume(returning:result)
                    }
                }
                if error != nil{
                    print("error in receiving: \(error!)")
                }
            }
        }
    }
 
}



