package UDP_Demo;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class Client {
    public static int byteToShort(byte[] bytes) {

        int newValue = 0;
        newValue |= (((int) bytes[0]) << 8) & 0xFF00;
        newValue |= (((int) bytes[1])) & 0xFF;

        return newValue;
    }

    public static void main(String[] args) throws IOException{
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        DatagramSocket dsSend = new DatagramSocket();
        DatagramSocket dsReceive = new DatagramSocket(7000);

        InetAddress ia = InetAddress.getByName("127.0.0.1");

        System.out.println("Select Mode(1. Check    2. Modify)");
        int mode;
        Scanner sc = new Scanner(System.in);
        mode = sc.nextInt();
        sc.nextLine();              //앞에서 생긴 개행문자 버려서 뒤의 nextline 스킵되는거 방지.

        byte[] bufferToSend = new byte[1000];           //보낼 정보 저장하는 버퍼
        bufferToSend[0] = 'A';
        bufferToSend[1] = 'T';
        bufferToSend[2] = 'L';
        bufferToSend[3] = 'N';


        if(mode == 1){              //설정값 조회 - 요청 보내고, 답변 받고, 출력
            byte[] bufferToReceive = new byte[1000];        //값 받아올 버퍼

            short bufferlen = 7;
            bufferToSend[6] = (byte)0x0;      //STX, ID, length 크기 제외하고 7부터 payload 시작

            bufferlen -= 6;
            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.out.println(bufferToSend[4] + " " + bufferToSend[5]);


            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            dsSend.send(dpSend);


            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            dsReceive.receive(dpReceive);

            String rivoInfo = new String(bufferToReceive, 7, byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]}));
            System.out.println("rivoInfo : " + rivoInfo);

        }
        else if(mode == 2){         //설정값 변경 - 요청 보내고, 변경된 값으로 답변 받고, 출력
            byte[] bufferToReceive = new byte[1000];        //값 받아올 버퍼
            short bufferlen;
            String newRivoInfo;
            System.out.print("Enter new rivoInfo: ");
            newRivoInfo = sc.nextLine();                         //수정할 값 입력받음

            bufferlen = (short) newRivoInfo.length();
            bufferToSend[6] = (byte)0x1;      //STX, ID, length 크기 제외하고 7부터 payload 시작

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅 (short to byte array)
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.out.println("bufferlen: " + bufferlen);

            System.arraycopy(newRivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            dsSend.send(dpSend);            //요청 패킷 전송

            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            dsReceive.receive(dpReceive);

            //변경된 설정값 Server로부터 다시 받아서 저장
            System.out.println(bufferToReceive[4] + " " + bufferToReceive[5]);        //[4] = 5, [5] = 0
            String rivoInfo = new String(bufferToReceive, 7, byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]}));
            System.out.println("rivoInfo has been successfully changed to [" + rivoInfo + "]");

        }

    }
}

