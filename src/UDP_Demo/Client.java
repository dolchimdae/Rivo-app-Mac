package UDP_Demo;


import jdk.jfr.Unsigned;

import java.beans.beancontext.BeanContext;
import java.io.*;
import java.lang.reflect.Array;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class Client {
    static int MAX_BUFFER_SIZE = 512;

    public static int byteToShort(byte[] bytes) {

        int newValue = 0;
        newValue |= (((int) bytes[0]) << 8) & 0xFF00;
        newValue |= (((int) bytes[1])) & 0xFF;

        return newValue;
    }

    public static short crc16_compute(byte[] data){
        short crc = (short) 0xffff;
        for(int i=0; i<data.length; i++) {
            crc = (short)((crc >>> 8) & 0xff | (crc << 8));
            crc ^= data[i] & 0xff;
            crc ^= (crc & 0xff) >>> 4;
            crc ^= (crc << 8) << 4;
            crc ^= ((crc & 0xff) << 4) << 1;
        }
        return crc;
    }

    public static void crc16_check(byte[] data){             //data == bufferToReceive
        //length 뽑아서 6 + length 한 곳 부터 2byte 읽고 실제 값이랑 비교
        if(data[7] == (byte) 0x87){
            System.out.println("CRC Error!!!");
            return;
        }
        short bufferlen = (short) byteToShort(new byte[]{data[5], data[4]});
        byte[] realData = Arrays.copyOfRange(data, 6, bufferlen + 6);         //crc 뺀 data로 계산해야 함
        short crc = crc16_compute(realData);
        bufferlen += 6;                 //STX, ID, length 6byte 더해줘야 실제 crc 시작 인덱스
        short realCrc = 0;
        realCrc |= (short) (data[bufferlen++]) & 0xFF;          //패킷으로 담겨 넘어온 crc 추출
        realCrc |= (short) (data[bufferlen++] << 8) & 0xFF00;

        System.out.println("received crc: " + realCrc);
        System.out.println("computed crc: " + crc);

        

        if(crc == realCrc){
            System.out.println("CRC Checking == TRUE");
        }else{
            System.out.println("CRC Checking == FALSE");
        }
    }

    public static byte[] getRequest(char id_1, char id_2) throws IOException {

        byte[] bufferToSend = new byte[1000];
        int bufferlen;

        bufferToSend[0] = 'A';
        bufferToSend[1] = 'T';
        bufferToSend[2] = (byte) id_1;
        bufferToSend[3] = (byte) id_2;
        bufferToSend[6] = 0x0;

        bufferlen = 1;

        bufferToSend[4] = (byte) (bufferlen & 0xFF);
        bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

        int offset = bufferlen + 6;
        short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
        bufferToSend[offset++] = (byte) (crc & 0xFF);
        bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);

        bufferToSend[offset++] = 0x0D;
        bufferToSend[offset++] = 0x0A;

        return bufferToSend;

    }

    public static byte[] setRequest(byte[] bufferToSend, char id_1, char id_2, int bufferlen){
        bufferToSend[0] = 'A';
        bufferToSend[1] = 'T';
        bufferToSend[2] = (byte) id_1;
        bufferToSend[3] = (byte) id_2;
        bufferToSend[6] = 0x1;

        bufferToSend[4] = (byte) (bufferlen & 0xFF);
        bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

        int offset = bufferlen + 6;
        short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
        bufferToSend[offset++] = (byte) (crc & 0xFF);
        bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);

        bufferToSend[offset++] = 0x0D;
        bufferToSend[offset++] = 0x0A;

        return bufferToSend;
    }



    public static void main(String[] args) throws IOException{
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        DatagramSocket ds = new DatagramSocket();

        InetAddress ia = InetAddress.getByName("127.0.0.1");

        System.out.println("Select Mode(1. Check    2. Modify)");
        int mode;
        Scanner sc = new Scanner(System.in);
        mode = sc.nextInt();
        sc.nextLine();              //앞에서 생긴 개행문자 버려서 뒤의 nextline 스킵되는거 방지.





/*


        if(mode == 1){              //설정값 조회 - 요청 보내고, 답변 받고, 출력
            byte[] bufferToSend = new byte[1000];           //보낼 정보 저장하는 버퍼
            bufferToSend[0] = 'A';
            bufferToSend[1] = 'T';
            bufferToSend[2] = 'L';
            bufferToSend[3] = 'N';

            byte[] bufferToReceive = new byte[1000];        //값 받아올 버퍼

            short bufferlen = 1;
            bufferToSend[6] = (byte)0x0;      //STX, ID, length 크기 제외하고 7부터 payload 시작

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.out.println(bufferToSend[4] + " " + bufferToSend[5]);


            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);


            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);

            String rivoInfo = new String(bufferToReceive, 7, byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]}));
            System.out.println("rivoInfo : " + rivoInfo);

        }
        else if(mode == 2){         //설정값 변경 - 요청 보내고, 변경된 값으로 답변 받고, 출력
            byte[] bufferToSend = new byte[1000];           //보낼 정보 저장하는 버퍼
            bufferToSend[0] = 'A';
            bufferToSend[1] = 'T';
            bufferToSend[2] = 'L';
            bufferToSend[3] = 'N';
            bufferToSend[6] = (byte)0x1;      //STX, ID, length 크기 제외하고 7부터 payload 시작

            byte[] bufferToReceive = new byte[1000];        //값 받아올 버퍼
            short bufferlen;
            String newRivoInfo;
            System.out.print("Enter new rivoInfo: ");
            newRivoInfo = sc.nextLine();                         //수정할 값 입력받음

            bufferlen = (short) (newRivoInfo.length() + 1);

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅 (short to byte array)
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.out.println("bufferlen: " + bufferlen);

            System.arraycopy(newRivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen - 1);

            int offset = bufferlen + 6;             //bufferlen + 6 == STX, ID, length, payload 까지 포함한 크기
            short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));        //CRC Setting (payload만 사용)
            System.out.println("computed crc: " + crc);
            bufferToSend[offset++] = (byte) (crc & 0xFF);
            bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);            //요청 패킷 전송

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);

            crc16_check(bufferToReceive);

            //변경된 설정값 Server로부터 다시 받아서 저장
            System.out.println(bufferToReceive[4] + " " + bufferToReceive[5]);        //[4] = 5, [5] = 0
            String rivoInfo = new String(bufferToReceive, 7, byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]}));
            System.out.println("rivoInfo has been successfully changed to [" + rivoInfo + "]");

        }*/


        if(mode == 210){            //Version GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('F', 'V');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            String firmVer = new String(bufferToReceive, 8, recvBufferlen - 2);
            System.out.println("Firmware Version " + firmVer);
        }
        
        else if(mode == 221){           //Date/Time SET

        }
        else if(mode == 230){           //Language GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('L', 'N');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            String language = new String(bufferToReceive, 8, recvBufferlen - 2);
            System.out.println("Language Info: " + language);
        }
        else  if(mode == 231){          //Language SET
            byte[] bufferToSend = new byte[1000];
            byte[] bufferToReceive = new byte[1000];
            String language;
            int bufferlen;
            System.out.print("Enter new Language Setting : ");
            language = sc.nextLine();

            bufferlen = (short) (language.length() + 1);

            System.arraycopy(language.getBytes(), 0, bufferToSend, 7, bufferlen - 1);
            bufferToSend = setRequest(bufferToSend, 'L', 'N', bufferlen);

            System.out.println(new String(bufferToSend, 7, bufferlen - 1));

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);
            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);

            crc16_check(bufferToReceive);
            if(bufferToReceive[7] == 0x00){
                System.out.println("Language Setting has been successfully changed to [" + language + "]");
            }
        }
        else if(mode == 240){           //Screen Reader GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('S', 'R');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            String screenReader = new String(bufferToReceive, 8, recvBufferlen - 2);
            System.out.println("Screen reader Info: " + screenReader);
        }
        else if(mode == 250){           //Voice Guidance GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('V', 'G');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            byte voiceGuidance = bufferToReceive[8];
            System.out.println("Voice Guidance Info:  "  + voiceGuidance);
        }
        else if(mode == 290){           //Device Info GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('I', 'F');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            String rivoInfo = new String(bufferToReceive, 8, recvBufferlen - 2);
            System.out.println("Device Info:  " + rivoInfo);
        }
        else if(mode == 2100){          //Find My Rivo
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('R', 'V');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);
        }
        else if(mode == 2110){          //MTU Size GET
            byte[] bufferToSend;
            byte[] bufferToReceive = new byte[1000];
            bufferToSend = getRequest('M', 'T');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            crc16_check(bufferToReceive);

            int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            short MTU_Size = (short) byteToShort(new byte[]{bufferToReceive[9], bufferToReceive[8]});
            System.out.println("Device Info:  " + MTU_Size);
        }
        else if(mode == 500){           //File Send
            byte[] bufferToSend;
            bufferToSend = getRequest('U', 'M');
            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);

            String fileName;
            System.out.print("Enter File Name: ");
            fileName = sc.nextLine();
            File fileToSend = new File("./" + fileName);
            if(!fileToSend.exists()){           //File Not exist
                System.out.println("File Not Exist");
            }
            int fileSize = (int) fileToSend.length();
            int totalReadBytes = 0;

            

            /*

            try{
                String str = "start";

                dpSend = new DatagramPacket(str.getBytes(), str.getBytes().length, ia, 6999);
                ds.send(dpSend);
                dpSend = new DatagramPacket(fileName.getBytes(), fileName.getBytes().length, ia, 6999);
                ds.send(dpSend);

                FileInputStream fis = new FileInputStream(fileName);
                byte[] buffer = new byte[MAX_BUFFER_SIZE];              //파일 담을 버퍼
                while(true){            //512 bytes 씩 쪼개서 전송
                    int readBytes = fis.read(buffer, 0, buffer.length);
                    if(readBytes == -1) break;

                    dpSend = new DatagramPacket(buffer, readBytes, ia, 6999);
                    ds.send(dpSend);
                    totalReadBytes += readBytes;

                }

                str = "end";
                dpSend = new DatagramPacket(str.getBytes(), str.getBytes().length, ia, 6999);
                ds.send(dpSend);
                System.out.println("Complete!");
                fis.close();


            } catch (Exception e){
                System.out.println(e.getMessage());
            }
            */



        }


    }
}



