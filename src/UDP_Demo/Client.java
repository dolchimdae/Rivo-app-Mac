package UDP_Demo;

import java.io.*;
import java.net.*;
import java.util.*;

public class Client {
    public static void main(String[] args) throws IOException{
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        DatagramSocket ds = new DatagramSocket();

        System.out.println("Select Mode(1. Check    2. Modify)");
        int mode;
        Scanner sc = new Scanner(System.in);
        mode = sc.nextInt();

        if(mode == 1){              //설정값 조회 - 요청 보내고, 답변 받고, 출력

        }
        else if(mode == 2){         //설정값 변경 - 요청 보내고, 변경된 값으로 답변 받고, 출력

        }




        /*
        System.out.print("Input to send: ");
        String msg = in.readLine();
        InetAddress ia = InetAddress.getByName("127.0.0.1");

        DatagramPacket dp = new DatagramPacket(msg.getBytes(), msg.getBytes().length, ia, 6999);
        ds.send(dp);
         */

        System.out.println("Successfully Sended");
    }
}

