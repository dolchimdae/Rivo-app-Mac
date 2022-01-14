package UDP_Demo;

import javax.print.MultiDocPrintService;
import java.awt.image.BaseMultiResolutionImage;
import java.io.*;
import java.lang.invoke.MutableCallSite;
import java.lang.reflect.Array;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.zip.CRC32;
import com.sun.jdi.event.ExceptionEvent;
import jdk.jfr.Unsigned;

import javax.swing.*;
import javax.swing.plaf.basic.BasicSeparatorUI;
import javax.swing.text.AbstractDocument;
import java.beans.beancontext.BeanContext;
import java.io.*;
import java.lang.reflect.Array;
import java.net.*;
import java.nio.charset.StandardCharsets;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.*;
import java.util.zip.CRC32;




public class Server {

    static short MAX_BUFFER_SIZE = 512;
    static String firmVer = "Rivo 3.0.5,BL 3.0.5,BT 3.0.5";
    static String language = "20,21,30,31";
    static String screenReader = "3,11,11,iOS VoiceOver,21,Android TalkBack,12,watchOS";        //갯수, 선택ID, ID1, 이름1, ID2, 이름2, ID3, 이름3
    static boolean voiceGuidance = true;
    static String rivoName = "Rivo 3.0.5";
    static String rivoInfo = "ver:Rivo 3.0.5,sn:2233,etc:xxxx";             //콤마로 분리된 string
    static int MTU_Size = 30;
    static File file;
    static short totaldatasize=0;
    static int datapackets=0;
    public static long checksumInputStream(File fileToSend) throws IOException
    {
       InputStream in = new FileInputStream(fileToSend);
       CRC32 crc = new CRC32();

       int c;
       while ((c = in.read()) != -1)
          crc.update(c);
       System.out.println(crc.getValue());
       return crc.getValue();
    }
    public static short byteToShort(byte[] bytes) {           //byte arr에서 short 값 추출 (little endian)

        short newValue = 0;

        newValue |= bytes[0] & 0xff;
        newValue |= (bytes[1] << 8) & 0xff00;

        return newValue;
    }

    public static int byteToInt(byte[] bytes){
        int newValue = 0;

        newValue |= bytes[0] & 0xff;
        newValue |= (bytes[1] << 8) & 0xff00;
        newValue |= (bytes[2] << 16) & 0xff0000;
        newValue |= (bytes[3] << 24) & 0xff000000;

        return newValue;
    }


    public static int getUInt16(int i){
        return i & 0x0000ffff;
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

    //CRC 체크해서 맞으면 true, 틀리면 false return
    public static boolean crc16_check(byte[] data){             //data == bufferToReceive
        //length 뽑아서 6 + length 한 곳 부터 2byte 읽고 실제 값이랑 비교
        short bufferlen = byteToShort(Arrays.copyOfRange(data, 4, 6));
        byte[] realData = Arrays.copyOfRange(data, 6, bufferlen + 6);         //crc 뺀 data로 계산해야 함
        short crc = crc16_compute(realData);

        int crc_i = getUInt16((int) crc);


        bufferlen += 6;                 //STX, ID, length 6byte 더해줘야 실제 crc 시작 인덱스
        short realCrc = 0;
        realCrc |= (short) (data[bufferlen++]) & 0xFF;          //패킷으로 담겨 넘어온 crc 추출
        realCrc |= (short) (data[bufferlen++] << 8) & 0xFF00;

        int realCrc_i = getUInt16((int) realCrc);

        System.out.println("computed crc: " + crc);
        System.out.println("received crc: " + realCrc);

        if(crc == realCrc){
            return true;
        }else{
            return false;
        }
    }
    public static boolean data_crc16_check(byte[] data){   //data == bufferToReceive
    	System.out.println(data);
        //length 뽑아서 6 + length 한 곳 부터 2byte 읽고 실제 값이랑 비교
        short bufferlen = byteToShort(Arrays.copyOfRange(data,11, 13));
        System.out.println("bufferlength: "+bufferlen);
        byte[] realData = Arrays.copyOfRange(data, 13, bufferlen + 13);//crc 뺀 data로 계산해야 함
        System.out.println(realData);
        short crc = crc16_compute(realData);

        int crc_i = getUInt16((int) crc);


                        
        short realCrc = 0;
        realCrc |= (short) (data[9]) & 0xFF;          //패킷으로 담겨 넘어온 crc 추출
        realCrc |= (short) (data[10] << 8) & 0xFF00;

        int realCrc_i = getUInt16((int) realCrc);

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
        int offset = bufferlen + 6;
        bufferToSend[offset++] = (byte) (crc & 0xFF);
        bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);
        bufferToSend[offset++] = 0x0D;
        bufferToSend[offset++] = 0x0A;

        return bufferToSend;
    }


    /*
    public static byte[] setReply(){
    }
    */


    public static void main(String[] args) throws IOException, InterruptedException {
    	
    	int errorps=Integer.valueOf(args[0]);
    	System.out.println("Command Line Argument" + errorps);
        DatagramSocket ds = new DatagramSocket(6999);
        InetAddress ia = InetAddress.getByName("127.0.0.1");
        int data_total_size;
        short data_info_size;
        int total_crc = 0;
        String data_info = "";
        float errorp=0;
        Scanner sc=new Scanner(System.in);
        System.out.println("Enter MTU Size: ");
        MTU_Size=sc.nextShort();
        sc.nextLine();
        System.out.println("Enter Error Percentage: ");
        errorp=sc.nextFloat();
        sc.nextLine();
        byte[] NetworkInfo=new byte[100];
        int errorper=Float.floatToIntBits(errorp);
        NetworkInfo[0]=(byte)(MTU_Size>>24&0xFF);
        NetworkInfo[1]=(byte) ((MTU_Size >>16) &0xFF);
        NetworkInfo[2]=(byte)((MTU_Size >>8)&0xFF);
        NetworkInfo[3]=(byte)((MTU_Size )&0xFF);
        NetworkInfo[7]=(byte)(errorper&0xFF);
        NetworkInfo[6]=(byte) ((errorper >>8) &0xFF);
        NetworkInfo[5]=(byte)((errorper >>16)&0xFF);
        NetworkInfo[4]=(byte)((errorper >>24)&0xFF);
        
        
            
        
		DatagramPacket dpSends = new DatagramPacket(NetworkInfo, 100, ia,7000);
        ds.send(dpSends);
        
        
        
        
        
        
        
        
        
        
        

        while (true) {
            System.out.println("========================================================");

            byte[] bufferToReceive = new byte[10000];
            byte RESULT_CODE = 0x00;
            int index=0;
            short packetlength=1;
         
            DatagramPacket dpReceive;
            while(true) { // while 문 안에서 frame 하나가 올때까지 반복한다.
            	System.out.println("New Packet Arrival!");
            	dpReceive= new DatagramPacket(bufferToReceive,index, MTU_Size);        //Client가 보낸 요청 수신 mtu 사이트만큼 receive 한다.
            	ds.receive(dpReceive);
            	System.out.println(packetlength +" "+ index);
            	if(bufferToReceive[index]=='A' && bufferToReceive[index+1]=='T'){			//프레임 패킷중 일부가 소실된채 클라이언트에서 프레임을 다시보내기 시작하면 프레임을 초기화후 받기 시작한다 length 만큼 읽는다 처음시작할때만 AT를 기다리는 로직

            		System.out.println("New Frame Start");

            		packetlength = (short) byteToShort(Arrays.copyOfRange(bufferToReceive, index+4, index+6));
            		packetlength= (short) (packetlength + (short)0x0A);

            		byte[] temp=new byte[1000];
            		Arrays.fill(temp, (byte)0x0);
            		temp=Arrays.copyOfRange(bufferToReceive, index, index+ dpReceive.getLength());

            		bufferToReceive=Arrays.copyOfRange(temp, 0, 1000);

            		index=0;

            	}



            	index=index+dpReceive.getLength(); //받은 byte 수만큼 index 에 더한다.
            	System.out.println(packetlength +" "+ index);

            	if(bufferToReceive[packetlength-1]==0x0A && bufferToReceive[packetlength-2]==0x0D) //만약 frame 길이의 index 가 0xA 0xD 로 끝나면 프레임의 끝을 의미하기 때문에 반복문을 깬다.
            	{
            		System.out.println("End Of Packet");
            		break;

            	}
            
            
            }
         
            


            char[] charID = {(char) bufferToReceive[2], (char) bufferToReceive[3]}; //ID 세팅
            String ID = new String(charID);
            System.out.println(ID);
            int recvBufferlen = (short) byteToShort(Arrays.copyOfRange(bufferToReceive, 4, 6));

            byte opcode = bufferToReceive[6];                                           //opcode 세팅

            //보낼 data 기본세팅
            byte[] bufferToSend = new byte[1000];
            bufferToSend[0] = 'a';
            bufferToSend[1] = 't';
            bufferToSend[2] = bufferToReceive[2];
            bufferToSend[3] = bufferToReceive[3];
            bufferToSend[6] = bufferToReceive[6];


            switch (ID) {
                case "FV":
                    if (opcode == 0x0) {          //Version GET   +2
                        int bufferlen = firmVer.length() + 2;
                        System.arraycopy(firmVer.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);


                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Firmware Version [" + firmVer + "]");
                    }
                    break;
                case "DT":

                case "LN":
                    if (opcode == 0x0) {          //Language GET  +2
                        int bufferlen = language.length() + 2;
                        System.arraycopy(language.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Language Info [" + language + "]");
                    } else if (opcode == 0x1) {     //Language SET
                        System.out.println("Language SET MODE start");

                        short bufferlen;
                        bufferlen = (short) byteToShort(Arrays.copyOfRange(bufferToReceive, 4, 6));
                        System.out.println(bufferlen);
                        String newLanguage = new String(bufferToReceive, 7, bufferlen - 1);

                        language = newLanguage;             //원래의 설정값을 뽑아온 새 설정값으로 변경
                        System.out.println("New Language Setting: " + newLanguage);


                        bufferlen = 2;
                        bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
                        bufferToSend[5] = (byte) ((bufferlen >> 8) & 0xFF);
                        bufferToSend[7] = RESULT_CODE;

                        int offset = bufferlen + 6;
                        short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
                        bufferToSend[offset++] = (byte) (crc & 0xFF);
                        bufferToSend[offset++] = (byte) ((crc >> 8) & 0xFF);
                        bufferToSend[offset++] = 0x0d;
                        bufferToSend[offset++] = 0x0a;

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                    }
                    break;

                case "SR":
                    if (opcode == 0x0) {          //OS/Screen Reader GET  +2
                        int bufferlen = screenReader.length() + 2;
                        System.arraycopy(screenReader.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Screen Reader Info [" + screenReader + "]");
                    } else if (opcode == 0x1) {     //OS/Screen Reader SET

                    }
                    break;

                case "VG":
                    if (opcode == 0x0) {          //OS/Screen Reader GET  3
                        int bufferlen = 3;
                        bufferToSend[8] = (byte) (voiceGuidance ? 1 : 0);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Voice Guidance Info [" + (voiceGuidance ? "ON" : "OFF") + "]");
                    } else if (opcode == 0x1) {     //OS/Screen Reader SET

                    }
                    break;

                case "LC":
                case "DC":

                case "RN":
                    if (opcode == 0x0) {          //Name GET  +2
                        int bufferlen = rivoName.length() + 2;
                        System.arraycopy(rivoName.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Rivo Name [" + rivoName + "]");
                    } else if (opcode == 0x1) {    //Name SET
                    	 System.out.println("Rivo Name change mode start");

                         short bufferlen;
                         bufferlen = (short) byteToShort(Arrays.copyOfRange(bufferToReceive, 4, 6));
                         System.out.println(bufferlen);
                         String newName = new String(bufferToReceive, 7, bufferlen - 1);

                              rivoName=newName;     //원래의 설정값을 뽑아온 새 설정값으로 변경
                         System.out.println("New Name: " + newName);


                         bufferlen = 2;
                         bufferToSend[4] = (byte) (bufferlen & 0xFF);    //4, 5 index에 length 정보 세팅
                         bufferToSend[5] = (byte) ((bufferlen >> 8) & 0xFF);
                         bufferToSend[7] = RESULT_CODE;

                         int offset = bufferlen + 6;
                         short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
                         bufferToSend[offset++] = (byte) (crc & 0xFF);
                         bufferToSend[offset++] = (byte) ((crc >> 8) & 0xFF);
                         bufferToSend[offset++] = 0x0d;
                         bufferToSend[offset++] = 0x0a;

                         DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                         ds.send(dpSend);
                    }
                    break;

                case "IF":
                    if (opcode == 0x0) {          //Device Info GET  +2
                        int bufferlen = rivoInfo.length() + 2;
                        System.arraycopy(rivoInfo.getBytes(), 0, bufferToSend, 8, bufferlen - 2);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send Rivo Info [" + rivoInfo + "]");
                    }
                    //Device Info는 SET 없음
                    break;

                case "RV":
                    if (opcode == 0x0) {          //Find My Rivo - 0x0 == 진동, 0x1 == 소리, 0x2 == LED   2
                        switch (bufferToReceive[7]) {
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

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                    } else if (opcode == 0x2) {     //IND??

                    }
                    break;

                case "MT":
                    if (opcode == 0x0) {          //MTU Size GET     4
                        int bufferlen = 4;

                        bufferToSend[8] = (byte) (MTU_Size & 0xFF);
                        bufferToSend[9] = (byte) ((MTU_Size >> 8) & 0xFF);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);

                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Send MTU Size Info [" + MTU_Size + "]");
                    }
                    break;
                case "RS":
                case "LG":
                case "MI":
                case "FM":

                //Server(Rivo) 에서 받은 파일은 C:\Rivo_Storage\ 위치에 동일한 파일 이름으로 저장됨.
                case "UM":
                	
                    if (opcode == 0x0) {          //START
                        data_total_size = byteToInt(Arrays.copyOfRange(bufferToReceive, 8, 12));
                        total_crc = byteToInt(Arrays.copyOfRange(bufferToReceive, 12, 16));
                        data_info_size = byteToShort(Arrays.copyOfRange(bufferToReceive, 16, 18));
                        data_info = new String(bufferToReceive, 18, data_info_size);
                        
                        System.out.println("data_info: " + data_info);
                        System.out.println("data_info_size: " + data_info_size);
                        System.out.println("data_total_size: " + data_total_size);
                        file = new File("C:\\Rivo_Storage\\" + data_info);

                        int bufferlen = 2;
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);
                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("File Transfer START!!!");
                        break;
                    }
                    else if(opcode == 0x1) {      //DATA
                        short seq_num = byteToShort(Arrays.copyOfRange(bufferToReceive, 7, 9));
                     
                        short data_size = byteToShort(Arrays.copyOfRange(bufferToReceive, 11, 13));
                        totaldatasize+=data_size;
                        int bufferlen = 4;
                        //this is where crc data and crc packet must be checked
                        if(data_crc16_check(bufferToReceive)) {
                        	System.out.println("Data CRC Match");
                        	FileOutputStream fos = new FileOutputStream(file, true);
                            System.out.println("data_size: " + data_size);
                            byte[] buffer = Arrays.copyOfRange(bufferToReceive, 13, 13 + data_size);
                            fos.write(buffer);
                            fos.close();
                        	RESULT_CODE=(byte) 0x0;
                       }
                        else {
                        	System.out.println("Data CRC Miss");
                        	RESULT_CODE=(byte) 0x87;
                        }
                        System.out.println("Received [" + seq_num + "] DATA packets");

                        bufferToSend[9] = (byte) (seq_num & 0xff);
                        bufferToSend[8] = (byte) ((seq_num >> 8) & 0xff);
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);
                        bufferToSend[6]=(byte)0x01;
                       
                        
                        System.out.println("Sending Back");
                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        datapackets++;
                        System.out.println("DataPackets:"+datapackets);
                        
                        break;
                    }
                    else if(opcode == 0x2){       //VERIFY
                    	
                    	System.out.println("start verification");
                        int bufferlen = 2;
                        long filecrc=checksumInputStream(file);
                        int filecrcInt=(int) filecrc;
                        if(filecrcInt != total_crc) {
                        	System.out.println("FILE CRC Miss");
                        	RESULT_CODE=(byte)0x87;
                        }
                        else
                        	System.out.println("Total CRC Match");
                        
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);
                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("Verifying total CRC. . .");
                        break;
                    }
                    else if(opcode == 0x3) {       //END
                        int bufferlen = 2;
                        bufferToSend = basicSetting(bufferToSend, bufferlen, RESULT_CODE);
                        DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, dpReceive.getPort());
                        ds.send(dpSend);
                        System.out.println("File Transfer FINISH!!! " + totaldatasize);
                        break;
                    }

            }
            if (crc16_check(bufferToReceive)) {
                System.out.println("CRC Checking == true");
            } else {
                System.out.println("CRC Checking == false");
                RESULT_CODE = (byte) 0x87;               //CRC Error
            }
            System.out.println("Done");
        }
    }

}
