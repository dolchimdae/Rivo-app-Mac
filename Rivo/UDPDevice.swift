//
//  Mac_main.swift
//  mac_protocol
//
//  Created by chaewon Kee on 2022/1/14.
//

import Network
import Foundation
import IOKit
import AppKit

let Timeout : Double = 3

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
                    //print("send data : \(data)")
                    continuation.resume()
                } else {
                    print("NWError : \(NWError!)")
                }
            })))
        }
    }
    
    override func readPacket() async throws -> [UInt8]  {
       
        print("to receive")
        var result : [UInt8] = [0]
        
        return try await withCheckedThrowingContinuation { continuation in
            
            var resumed = false;
            
            //real Task
            self.connection?.receiveMessage { (data, context, isComplete, error) in
                //다른 데서 continuation resume 했으면
                if resumed {
                    return
                }
                if (isComplete){
                    //let backToString = String(decoding: data!, as: UTF8.self)
                    //print("뭘 받았냐면.. \(backToString)")
                    if (data != nil){
                        result = [UInt8](data!)
                        //print("result is 1 \(result)")
                        resumed = true;
                        continuation.resume(returning:result)
                    }
                }
                if error != nil{
                    print("error in receiving: \(error!)")
                    resumed = true;
                    continuation.resume(throwing: defineError.readPacketNWError)
                }
            }
            
            // set timeout. 1초 지났으면 timeout error throw
            let timer = Timer.scheduledTimer(withTimeInterval: Timeout, repeats: false) { _ in
                //다른 데서 continuation resume 했으면
                if resumed {
                    return
                }
                print("timeout!")
                resumed = true
                continuation.resume(throwing: defineError.readPacketTimeout)
                //print("throw timeout 다음")
            }
            RunLoop.main.add(timer, forMode: .common)
            RunLoop.current.run() // add 하고 run 도 해줘야 실행함 *
        }
    }
}
 

