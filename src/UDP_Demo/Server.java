package UDP_Demo;

import java.io.*;
import java.net.*;

public class Server {
    public static void main(String[] args) throws IOException{
        String setting = new String("Original");
        DatagramSocket ds = new DatagramSocket(6999);
        byte[] buffer = new byte[1000];



        DatagramPacket dp = new DatagramPacket(buffer, buffer.length);
        ds.receive(dp);
        System.out.println(dp.getAddress().getHostAddress() + " > " + new String(dp.getData()).trim());
    }
}
