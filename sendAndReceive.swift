func sendAndReceive(id : String, payload:[UInt8]) async -> String? {
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
         sendFrame.append(0x0a)   */
        
        if mtuConfirmed == false {
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
        
        var retry = 0
        var sendSize : Int
        var rcpayload : [UInt8]
        
        while retry < 3 {
            
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
                retry += 1
                continue
            }
            if (receiveFrame[0] == UInt8(ascii:"a") &&
                receiveFrame[1] == UInt8(ascii:"t")){
                
                let len = Int(receiveFrame[4])<<8 + Int(receiveFrame[5])
                //receive frame 전체
                while receiveFrame.count < len{
                    //오류-> while문 아웃-> write 다시
                    do{
                        receiveFrame += try await readPacket() //append?
                    }
                    catch{
                        break
                    }
                }
                if rcframeCheck(id: id, frame: receiveFrame) == false {
                    retry += 1
                    continue
                }else{
                    rcpayload = Array(receiveFrame[6...(len-5)])
                    break
                }
            } else { //at 부터 잘못되었을 경우(다시 send Frame)
                retry += 1
                continue
            }
        }
        if retry >= 3 { //if retry >= 3 이면 ui 에서 frame 단위 읽쓰 실패 뜨게하기 - 익셉션사용
            throw defineError.retryFail
        } else{
            return rcpayload  // < 여기서 Variable 'rcpayload' used before being initialized 에러 뜸
        }
    }
