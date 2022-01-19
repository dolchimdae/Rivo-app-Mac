//
//  protocol.swift
//  mac_protocol
// hi
//  Created by chaewon Kee on 2022/1/14.
//

import Network
import Foundation
import IOKit
import AppKit

let Timeout : Double = 1

class UDPDevice : RivoDevice {
    
    var connection: NWConnection?
    var timer : Timer?
    
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
    //시도해볼거리 ... : 쓰레드 두개 만들어서 변수공유(timeout) check 해서 resume 한개로.
    
    /*
    override func readPacket() async throws -> [UInt8]  {
        
        print("to receive")
        
        //var result : [UInt8] = [0]
        
        //let timerAndRead = DispatchQueue(label: "timerAndRead")
        
        try await withThrowingTaskGroup(of: Void.self) { group -> [UInt8] in
            group.addTask{
                try await Task.sleep(nanoseconds: 1000000000)
                //group.cancelAll()
                throw defineError.readPacketTimeout
            }
            group.addTask{
                try Task.checkCancellation()
                return try await withCheckedThrowingContinuation { continuation in
                    print("뀨")
                    //real Task
                    self.connection?.receiveMessage { (data, context, isComplete, error) in
                        if (isComplete){
                            let backToString = String(decoding: data!, as: UTF8.self)
                            print("뭘 받았냐면.. \(backToString)")
                            if (data != nil){
                                // command error checking
                                let result = [UInt8](data!)
                                //print("result is 1 \(result)")
                                continuation.resume(returning : result)
                            }
                        }
                        if error != nil{
                            print("error in receiving: \(error!)")
                            continuation.resume(throwing: defineError.readPacketNWError)
                        }
                    }
                }
            }
            
        }
    }
}
    */
    
    /* 정상 종료가 되긴 되는데 첫번째 receive 자체는 실행됨.
    func `async`<R>(
      timeoutAfter maxDuration: TimeInterval,
      do work: @escaping () async throws -> R
    ) async throws -> R {
      return try await withThrowingTaskGroup(of: R.self) { group in
        // Start actual work.
        group.async {
          return try await work()
        }
        // Start timeout child task.
        group.async {
          await Task.sleep(UInt64(maxDuration * 1_000_000_000))
          try Task.checkCancellation()
          // We’ve reached the timeout.
            throw defineError.readPacketTimeout
        }
        // First finished child task wins, cancel the other task.
        let result = try await group.next()!
        group.cancelAll()
        return result
      }
    }
    
    override func readPacket() async throws -> [UInt8]  {
        
        print("to receive")
        
        var result : [UInt8] = [0]
        result = try await async(timeoutAfter: 0.1) {
            
            return try await withCheckedThrowingContinuation { continuation in
                print("뀨")
                //real Task
                self.connection?.receiveMessage { (data, context, isComplete, error) in
                    if (isComplete){
                        let backToString = String(decoding: data!, as: UTF8.self)
                        print("뭘 받았냐면.. \(backToString)")
                        if (data != nil){
                            result = [UInt8](data!)
                            print("result is 1 \(result)")
                            continuation.resume(returning:result)
                        }
                    }
                    if error != nil{
                        print("error in receiving: \(error!)")
                        continuation.resume(throwing: defineError.readPacketNWError)
                    }
                }
            }
        }
        return result
    }
}

*/
//    func readTimeout()-> Never {
//        fatalError("read timeout!")
//    }
    
// 그냥 둘다 dispatchqueue 나 비동기적 실행하고 종료시킬려니까 timer 나 dispatchqueuq asyncafter 가 throw error 를 못함.
    override func readPacket() async throws -> [UInt8]  {
        
        print("to receive")
        
        var result : [UInt8] = [0]
        
        return try await withUnsafeThrowingContinuation { continuation in
            var resumed = false;
                print("뀨")
                //real Task
                self.connection?.receiveMessage { (data, context, isComplete, error) in
                    if resumed {
                        return;
                    }
                    if (isComplete){
                        let backToString = String(decoding: data!, as: UTF8.self)
                       print("뭘 받았냐면.. \(backToString)")
                        if (data != nil){
                            // command error checking
                            result = [UInt8](data!)
                            print("result is 1 \(result)")
                            resumed = true;
                            continuation.resume(returning:result)
                            print("리턴했는데...")
                            //return
                        }
                    }
                    if error != nil{
                        print("error in receiving: \(error!)")
                        resumed = true;
                        continuation.resume(throwing: defineError.readPacketNWError)
                    }
                }
                print("왜 안될까")
                // set timeout. 1초 지났으면 timeout error throw
            //DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(6000), execute: {
            
            self.timer = Timer.scheduledTimer(withTimeInterval: Timeout, repeats: false) { timer in
                print("timeout!")
                if resumed {
                    return;
                }
                //self.readTimeout()
                resumed = true
                continuation.resume(throwing: defineError.readPacketTimeout)
                //return
                //throw error 하면서 그냥 함수 종료할수없나.. (connection 하는 thread? 까지 )
                //print("RB~")
            }
            RunLoop.current.add(self.timer!, forMode: .default)
           
            //RunLoop.
        }
        //return result
        }
    
    /*
        result = try await withCheckedThrowingContinuation { continuation in
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1000), execute: {
                //Timer.scheduledTimer(withTimeInterval: Timeout, repeats: false) { timer in
                print("timeout!")
                
                continuation.resume(throwing: defineError.readPacketTimeout)
                return
                //self.activeContinuation = nil
                //print("RB~")
            })
            print("뀨")
            //real Task
            self.connection?.receiveMessage { (data, context, isComplete, error) in
                if (isComplete){
                    let backToString = String(decoding: data!, as: UTF8.self)
                   print("뭘 받았냐면.. \(backToString)")
                    if (data != nil){
                        // command error checking
                        result = [UInt8](data!)
                        //print("result is 1 \(result)")
                        continuation.resume(returning:result)
                        return
                    }
                }
                if error != nil{
                    print("error in receiving: \(error!)")
                    continuation.resume(throwing: defineError.readPacketNWError)
                }
            }
            print("왜 안될까")
            // set timeout. 1초 지났으면 timeout error throw
        }
    return result
    }
     */
}
 
 /*
    override func readPacket() async  -> [UInt8]  {
        
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
*/
