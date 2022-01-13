func sendAndReceive(id : String, payload:[UInt8]) async -> String? {
        /* Big endian
         var sendFrame = ("AT"+id).utf8.map{ UInt8($0) } // convert string into byte array
         sendFrame.append(UInt8(payload.count>>8))
         sendFrame.append(UInt8(payload.count&0xff))
         sendFrame.append(contentsOf: payload)
         let crc = self.CRC16(data: payload)
         sendFrame.append(UInt8(crc>>8))
         sendFrame.append(UInt8(crc&0xff))
         sendFrame.append(0x0d)
         sendFrame.append(0x0a)   */
    
        //Little endian
        //sendFrame index 총 n+10
        
        if mtuConfirmed == false {
            do{
                mtu = try await getMTUSize2() }
            catch {
                print("retry fail!")
                //ui에 다시 연결하라고 뜨도록..
            }
            mtuConfirmed = true
        }
        
        var sendFrame = ("AT"+id).utf8.map{ UInt8($0)}
        sendFrame.append(UInt8(payload.count&0xff))
        sendFrame.append(UInt8((payload.count>>8)&0xff))
        sendFrame.append(contentsOf: payload)
        let crc = self.CRC16(data: payload)
        sendFrame.append(UInt8(crc&0xff))
        sendFrame.append(UInt8((crc>>8)&0xff))
        sendFrame.append(0x0d)
        sendFrame.append(0x0a)
        
        var retry = 0
        var sendSize : Int
        
        
        while retry < 3 {
            
            var pos = 0
            let frameSize = payload.count + 10
            
            //send frame
            while pos < frameSize {
                
                sendSize = max(mtu,frameSize-pos )
                // getMTU 를 mtu 로 생성자 async 하게 하거나(1) sendandreceive함수안에서 mtu confirmed bool 변수 안됐을 때 (2)
                // 다만 getMTU 함수는 sendAndReceive 부르지않도록...(무한)
                await writePacket(data: Array(sendFrame[pos...pos+sendSize]))
                pos += sendSize
            }
            
            //receive frame
            var receiveFrame : [UInt8]
            //var len : Int
            do {
                receiveFrame = await
                withCheckedContinuation {
                    continuation in
                readPacket(onResponse: {(bytes)-> ()
                    in
                    print("data received: ", bytes.description)
                    continuation.resume(returning: bytes)
                })
                } //append?
            }catch {
                retry += 1
                continue
            }
            //at 맞는지 확인하는 방향
            let len = Int(receiveFrame[4])<<8 + Int(receiveFrame[5])
            
            if receiveFrame.count < len {
                repeat {
                    //오류-> while문 아웃-> write 다시
                    do{
                        receiveFrame += try await readPacket(onResponse: {(bytes)-> ()
                            in
                            print("data received: ", bytes.description)
                            continuation.resume(returning: bytes)
                        }) //append?
                    }
                    catch{
                        break
                    }
                } while receiveFrame.count < len
            }
            
            //receive frame crc 검사
            //제대로 rceive frame 받았으면 해당 payload 형태로 반환하기
            retry += 1
        }
        //if retry >= 3 이면 ui 에서 frame 단위 읽쓰 실패 뜨게하기 - 익셉션사용
    }
