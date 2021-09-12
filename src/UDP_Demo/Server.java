package UDP_Demo;

import java.io.*;
import java.net.*;
import java.nio.charset.StandardCharsets;

public class Server {
    public static int byteToShort(byte[] bytes) {           //byte arr에서 short 값 추출

        int newValue = 0;
        newValue |= (((int) bytes[0]) << 8) & 0xFF00;
        newValue |= (((int) bytes[1])) & 0xFF;

        return newValue;
    }

    public static void main(String[] args) throws IOException{
        String rivoInfo = "Hello";

        DatagramSocket dsSend = new DatagramSocket();
        DatagramSocket dsReceive = new DatagramSocket(6999);
        InetAddress ia = InetAddress.getByName("127.0.0.1");

        byte[] bufferToReceive = new byte[1000];
        DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);        //Client가 보낸 요청 수신
        dsReceive.receive(dpReceive);


        if(bufferToReceive[6] == 0x0){              //설정값 조회 == GET
            byte[] bufferToSend = new byte[1000];
            short bufferlen = (short) rivoInfo.length();

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);
            bufferToSend[6] = 0x0;

            //System.out.println("before arraycopy");

            //bufferToSend[7] 부터 rivoInfo 값 저장 -> arraycopy 함수 이용 (string to byte array)
            System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
            dsSend.send(dpSend);
            System.out.println("Send rivoInfo [" + rivoInfo + "]");
        }
        else if(bufferToReceive[6] == 0x1){         //설정값 변경 == SET
            byte[] bufferToSend = new byte[1000];
            short bufferlen;

            bufferlen = (short) byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
            System.out.println("bufferlen: " + bufferlen);

            //Client에서 전달받은 newRivoInfo 정보를 버퍼에서 뽑아옴 (byte array to string)
            String newRivoInfo = new String(bufferToReceive, 7, bufferlen);

            rivoInfo = newRivoInfo;             //원래의 설정값을 뽑아온 새 설정값으로 변경
            System.out.println("newRivoInfo: " + newRivoInfo);
            System.out.println("rivoInfo: " + rivoInfo);

            bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
            bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);

            System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 7, bufferlen);

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 7000);
            dsSend.send(dpSend);

        }

        //System.out.println(dp.getAddress().getHostAddress() + " > " + new String(dp.getData()).trim());
    }
}
