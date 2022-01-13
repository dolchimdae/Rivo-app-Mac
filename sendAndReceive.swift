func sendAndReceive(id : String, payload:[UInt8]) async throws -> [UInt8] {
        
        /* Big endian
         var sendFrame = ("AT"+id).utf8.map{ UInt8($0) } // convert string into byte array
         sendFrame.append(UInt8(payload.count>>8))
         sendFrame.append(UInt8(payload.count&0xff))
         sendFrame.append(contentsOf: payload)
         let crc = self.CRC16(data: payload)
         sendFrame.append(UInt8(crc>>8))
         sendFrame.append(UInt8(crc&0xff))
         sendFrame.append(0x0d)
         sendFrame.append(0x0a)
         */
  
        if (!mtuConfirmed) {
            do{
                mtu = try await getMTUSize2() }
            catch {
                print("retry fail!")
                //ui에 다시 연결하라고 뜨도록..
            }
            mtuConfirmed = true
        }
 
        
        //Little endian
        var sendFrame = ("AT"+id).utf8.map{ UInt8($0)}
        sendFrame.append(UInt8(payload.count&0xff))
        sendFrame.append(UInt8((payload.count>>8)&0xff))
        sendFrame.append(contentsOf: payload)
        let crc = self.CRC16(data: payload)
        sendFrame.append(UInt8(crc&0xff))
        sendFrame.append(UInt8((crc>>8)&0xff))
        sendFrame.append(0x0d)
        sendFrame.append(0x0a)
        
        var sendSize : Int
        
        for _ in 0...2 {
            
            var pos = 0
            let frameSize = payload.count + 10
            
            //send frame
            while pos < frameSize {
                
                sendSize = max(mtu,frameSize-pos )
                
                await writePacket(data: Array(sendFrame[pos...pos+sendSize]))
                pos += sendSize
            }
            
            //receive frame
            var receiveFrame : [UInt8]
            
            do {
                receiveFrame = try await readPacket()
            }catch {
                continue
            }
            if (receiveFrame[0] == UInt8(ascii:"a") &&
                receiveFrame[1] == UInt8(ascii:"t")){
                
                let len = Int(receiveFrame[4])<<8 + Int(receiveFrame[5])
                //receive frame 나머지
                while receiveFrame.count < len{
                    //오류-> while문 아웃-> write 다시
                    do{
                        receiveFrame += try await readPacket() //append?
                    }
                    catch{
                        break
                    }
                }
                if rcframeCheck(id: id, frame: receiveFrame) == true {
                    return Array(receiveFrame[6...(len-5)])
                }else{
                    continue
                }
            } else { //at 부터 잘못되었을 경우(다시 send Frame)
                continue
            }
        }
        //for 문을 빠져나오면 무조건 retryFail을 throw
        throw defineError.retryFail
    }

func getMTUSize2() async throws -> Int {
        
        var sendframe = ("AT"+"MT").utf8.map{ UInt8($0) } // convert string into byte array
        sendframe.append(UInt8([0].count&0xff))
        sendframe.append(UInt8(([0].count>>8)&0xff))
        sendframe.append(contentsOf: [0])
        let crc = self.CRC16(data: [0])
        sendframe.append(UInt8(crc&0xff))
        sendframe.append(UInt8((crc>>8)&0xff))
        sendframe.append(0x0d)
        sendframe.append(0x0a)
        
        for _ in 0...2 {
            await writePacket(data: sendframe)
            do {
                let receiveframe = try await readPacket()
                
                if (receiveframe[0] == UInt8(ascii:"a") &&
                    receiveframe[1] == UInt8(ascii:"t") && rcframeCheck(id: "MT", frame: receiveframe)) == true {
                    return Int(receiveframe[8])<<8 + Int(receiveframe[9])
                    
                }else{
                    continue
                }
            }
            catch{
                //retry += 1
                continue
            }
        }
        throw defineError.retryFail
        
    }
