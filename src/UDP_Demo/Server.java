package UDP_Demo;

import java.awt.image.BaseMultiResolutionImage;
import java.io.*;
import java.lang.invoke.MutableCallSite;
import java.lang.reflect.Array;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;

public class Server {


    static String firmVer = "Rivo 3.0.5,BL 3.0.5,BT 3.0.5";
    static String language = "20,21,30,31";
    static String screenReader = "3,11,11,iOS VoiceOver,21,Android TalkBack,12,watchOS";        //갯수, 선택ID, ID1, 이름1, ID2, 이름2, ID3, 이름3
    static boolean voiceGuidance = true;
    static String rivoName = "Rivo 3.0.5";
    static String rivoInfo = "ver:Rivo 3.0.5,sn:2233,etc:xxxx";             //콤마로 분리된 string
    static short MTU_Size = 100;


    public static int byteToShort(byte[] bytes) {           //byte arr에서 short 값 추출

        int newValue = 0;
        newValue |= (((int) bytes[0]) << 8) & 0xFF00;
        newValue |= (((int) bytes[1])) & 0xFF;

        return newValue;
    }

    public static short crc16_compute(byte[] data){
        short crc = (short) 0xFFFF;

        for (int i = 0; i<data.length; i++)
        {
            crc  = (short) ((byte)(crc >> 8) | (crc << 8));
            crc ^= data[i];
            crc ^= (short) ((byte)(crc & 0xFF) >> 4);
            crc ^= (short) ((crc << 8) << 4);
            crc ^= (short) (((crc & 0xFF) << 4) << 1);
        }
        return crc;
    }

    //CRC 체크해서 맞으면 true, 틀리면 false return
    public static boolean crc16_check(byte[] data){             //data == bufferToReceive
        //length 뽑아서 6 + length 한 곳 부터 2byte 읽고 실제 값이랑 비교
        short bufferlen = (short) byteToShort(new byte[]{data[5], data[4]});
        byte[] realData = Arrays.copyOfRange(data, 6, bufferlen + 6);         //crc 뺀 data로 계산해야 함
        short crc = crc16_compute(realData);
        bufferlen += 6;                 //STX, ID, length 6byte 더해줘야 실제 crc 시작 인덱스
        short realCrc = 0;
        realCrc |= (short) (data[bufferlen++]) & 0xFF;          //패킷으로 담겨 넘어온 crc 추출
        realCrc |= (short) (data[bufferlen++] << 8) & 0xFF00;

        System.out.println("computed crc: " + crc);
        System.out.println("received crc: " + realCrc);

        if(crc == realCrc){
            return true;
        }else{
            return false;
        }
    }

    public static byte[] basicSetting(byte[] bufferToSend, int bufferlen, byte RESULT_CODE){
        bufferToSend[4] = (byte) (bufferlen & 0xFF);
        bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);
        bufferToSend[7] = RESULT_CODE;
        short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
        bufferToSend[bufferlen + 6] = (byte) (crc & 0xFF);
        bufferToSend[bufferlen + 7] = (byte) ((crc >> 8)& 0xFF);

        return bufferToSend;
    }

    /*
    public static byte[] setReply(){

    }
    */


    public static void main(String[] args) throws IOException{

        DatagramSocket dsSend = new DatagramSocket();
        DatagramSocket dsReceive = new DatagramSocket(6999);
        InetAddress ia = InetAddress.getByName("127.0.0.1");

        byte[] bufferToReceive = new byte[1000];
        byte RESULT_CODE = 0x00;
        DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);        //Client가 보낸 요청 수신
        dsReceive.receive(dpReceive);

        if(crc16_check(bufferToReceive)){
            System.out.println("CRC Checking == true");
        }
        else{
            System.out.println("CRC Checking == false");
            RESULT_CODE = (byte) 0x87;               //CRC Error
        }


        char[] charID = {(char) bufferToReceive[2], (char) bufferToReceive[3]};     //ID 세팅
        String ID = new String(charID);

        int recvBufferlen = (short) byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});

        byte opcode = bufferToReceive[6];                                           //opcode 세팅

        System.out.println("ID: " + ID);

        //보낼 data 기본세팅
        byte[] bufferToSend = new byte[1000];
        bufferToSend[0] = 'a';
        bufferToSend[1] = 't';
        bufferToSend[2] = bufferToReceive[2];
        bufferToSend[3] = bufferToReceive[3];
        bufferToSend[6] = bufferToReceive[6];



        switch (ID){
            case "FV":
                if(opcode == 0x0){          //Version GET   +2
                    int bufferlen = firmVer.length() + 2;
                    System.arraycopy(firmVer.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Firmware Version [" + firmVer + "]");
                }
                break;

            case "LN":
                if(opcode == 0x0){          //Language GET  +2
                    int bufferlen = language.length () + 2;
                    System.arraycopy(language.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Language Info [" + language + "]");
                }
                else if(opcode == 0x1){     //Language SET

                }
                break;

            case "SR":
                if(opcode == 0x0){          //OS/Screen Reader GET  +2
                    int bufferlen = screenReader.length () + 2;
                    System.arraycopy(screenReader.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Screen Reader Info [" + screenReader + "]");
                }
                else if(opcode == 0x1){     //OS/Screen Reader SET

                }
                break;

            case "VG":
                if(opcode == 0x0){          //OS/Screen Reader GET  3
                    int bufferlen = 3;
                    bufferToSend[8] = (byte) (voiceGuidance ? 1 : 0);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Voice Guidance Info [" + (voiceGuidance ? "ON" : "OFF") + "]");
                }
                else if(opcode == 0x1){     //OS/Screen Reader SET

                }
                break;

            case "LC":
            case "DC":

            case "RN":
                if(opcode == 0x0){          //Name GET  +2
                    int bufferlen = rivoName.length () + 2;
                    System.arraycopy(rivoName.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Rivo Name [" + rivoName + "]");
                }
                else if(opcode == 0x1){     //OS/Screen Reader SET

                }
                break;

            case "IF":
                if(opcode == 0x0){          //Device Info GET  +2
                    int bufferlen = rivoInfo.length () + 2;
                    System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send Rivo Info [" + rivoInfo + "]");
                }
                //Device Info는 SET 없음
                break;

            case "RV":
                if(opcode == 0x0){          //Find My Rivo - 0x0 == 진동, 0x1 == 소리, 0x2 == LED   2
                    switch (bufferToReceive[7]){
                        case 0x0:
                            System.out.println("Vibration ON . . .");
                            break;
                        case 0x1:
                            System.out.println("Sound ON . . .");
                            break;
                        case 0x2:
                            System.out.println("LED ON . . .");
                            break;
                    }
                    int bufferlen = 2;
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                }
                else if(opcode == 0x2){     //IND??

                }
                break;

            case "MT":
                if(opcode == 0x0) {          //MTU Size GET     4
                    int bufferlen = 4;

                    bufferToSend[8] = (byte) (MTU_Size & 0xFF);
                    bufferToSend[9] = (byte) ((MTU_Size >> 8)& 0xFF);
                    bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                    DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
                    dsSend.send(dpSend);
                    System.out.println("Send MTU Size Info [" + MTU_Size + "]");
                }

        }


        /*
        if(bufferToReceive[6] == 0x0){              //설정값 조회 == GET
            System.out.println("GET MODE start");

            byte[] bufferToSend = new byte[1000];
            short bufferlen = (short) (rivoInfo.length() + 1);

            bufferToSend[0] = 'a';
            bufferToSend[1] = 't';
            bufferToSend[2] = 'L';
            bufferToSend[3] = 'N';
            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);
            bufferToSend[6] = 0x0;



            //bufferToSend[7] 부터 rivoInfo 값 저장 -> arraycopy 함수 이용 (string to byte array)
            System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen - 1);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
            dsSend.send(dpSend);
            System.out.println("Send rivoInfo [" + rivoInfo + "]");
        }
        else if(bufferToReceive[6] == 0x1){         //설정값 변경 == SET
            System.out.println("SET MODE start");

            byte[] bufferToSend = new byte[1000];
            bufferToSend[0] = 'a';
            bufferToSend[1] = 't';
            bufferToSend[2] = 'L';
            bufferToSend[3] = 'N';

            short bufferlen;

            bufferlen = (short) byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});

            //Client에서 전달받은 newRivoInfo 정보를 버퍼에서 뽑아옴 (byte array to string)
            String newRivoInfo = new String(bufferToReceive, 7, bufferlen - 1);

            rivoInfo = newRivoInfo;             //원래의 설정값을 뽑아온 새 설정값으로 변경
            System.out.println("newRivoInfo: " + newRivoInfo);
            System.out.println("rivoInfo: " + rivoInfo);

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen - 1);

            int offset = bufferlen + 6;
            short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
            bufferToSend[offset++] = (byte) (crc & 0xFF);
            bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
            dsSend.send(dpSend);
        }*/


    }
}
