//
//  protocol.swift
//  mac_protocol
//
//  Created by sunwoo Kim on 2021/11/07.
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
   
    // return type string ?
    override func write(cmd: String, data: [UInt8]) {
        /* Big endian
        var sendframe = ("AT"+cmd).utf8.map{ UInt8($0) } // convert string into byte array
        sendframe.append(UInt8(data.count>>8))
        sendframe.append(UInt8(data.count&0xff))
        sendframe.append(contentsOf: data)
        let crc = self.CRC16(data: data)
        sendframe.append(UInt8(crc>>8))
        sendframe.append(UInt8(crc&0xff))
        sendframe.append(0x0d)
        sendframe.append(0x0a)
        */
        
        //Little endian
       var sendframe = ("AT"+cmd).utf8.map{ UInt8($0) } // convert string into byte array
        sendframe.append(UInt8(data.count&0xff))
        sendframe.append(UInt8((data.count>>8)&0xff))
        sendframe.append(contentsOf: data)
        let crc = self.CRC16(data: data)
        sendframe.append(UInt8(crc&0xff))
        sendframe.append(UInt8((crc>>8)&0xff))
        sendframe.append(0x0d)
        sendframe.append(0x0a)
        
        // in emulation mode
        self.connection?.send(content: sendframe, completion: NWConnection.SendCompletion.contentProcessed(({ (NWError) in
            print(NWError?.debugDescription ?? "sent OK")
            print(sendframe);
        })))
    }

    override func read(sentCmd: String, onResponse: @escaping (String?) -> ())
    {
        print("to receive")
        self.connection?.receiveMessage { (data, context, isComplete, error) in
            if (isComplete){
                print("Received it") //
                if (data != nil){
                    print("sent cmd was " + sentCmd) // should be compared to received data
                    
                    // command error checking
                    let len = data!.count
                    let bytes = [UInt8](data!);
                    
                    if (!(bytes[0] == UInt8(ascii:"a") &&
                          bytes[1] == UInt8(ascii:"t") &&
                          data![2...3] == sentCmd.data(using: String.Encoding.utf8) &&
                          bytes[len-2] == 0x0d &&
                          bytes[len-1] == 0x0a)) {
                        // error
                        print("Invalid frame")
                        return
                    }
                    
                    //crc error checking
                    let payload = [UInt8](data![6...(len-5)])
                    let readCRC = UInt16(bytes[len-4]) + UInt16(bytes[len-3])<<8
                    if( self.CRC16(data: payload) != readCRC) {
                        print("Data corrupted")
                        return
                    }
                    
                    //convert data -> String
                    let str = String(bytes: [UInt8](payload), encoding: String.Encoding.utf8)
                    onResponse(str)
                    
                } else {
                    print("Data == nil")
                    return
                }
            
            }
        }
    }
}
