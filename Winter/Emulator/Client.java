package UDP_Demo;


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

public class Client {
    static short MAX_BUFFER_SIZE = 100;
    static int MTU=30;

    public static int byteToShort(byte[] bytes) {

        int newValue = 0;
        newValue |= (((int) bytes[0]) << 8) & 0xFF00;
        newValue |= (((int) bytes[1])) & 0xFF;

        return newValue;
    }
    public static int byteToInt(byte[] bytes) {
    	
    	 int newValue = 0;
         newValue |= (((int) bytes[0]) << 24) & 0xFF000000;
         newValue |= (((int) bytes[1]) << 16) & 0xFF0000;
         newValue |= (((int) bytes[2]) << 8) & 0xFF00;
         newValue |= (((int) bytes[3])) & 0xFF;
         return newValue;
    	
    	
    	
    }
    
 
    public static float byteArrayToFloat(byte[] bytes) {
        int intBits = bytes[0] << 24
                        | (bytes[1] & 0xFF) << 16
                        | (bytes[2] & 0xFF) << 8
                        | (bytes[3] & 0xFF);
        return Float.intBitsToFloat(intBits);
    }
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
    public static byte[] basicSetting(byte[] bufferToSend, int bufferlen, byte OP_CODE){
    	bufferToSend[0]='A';
    	bufferToSend[1]='T';
    	bufferToSend[2]='U';
    	bufferToSend[3]='M';
        bufferToSend[4] = (byte) (bufferlen & 0xFF);
        bufferToSend[5] = (byte) ((bufferlen >> 8 )& 0xFF);
        bufferToSend[6] = OP_CODE;
        short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
        int offset = bufferlen + 6;
        bufferToSend[offset++] = (byte) (crc & 0xFF);
        bufferToSend[offset++] = (byte) ((crc >> 8)& 0xFF);
        bufferToSend[offset++] = 0x0D;
        bufferToSend[offset++] = 0x0A;

        return bufferToSend;
    }
    public static byte[] intToFrame(byte[] bufferToSend,int index,int value) {
    	bufferToSend[index]=(byte)(value & 0xff);
    	bufferToSend[index+1]=(byte)((value>>8)&0xff);
    	bufferToSend[index+2]=(byte)((value>>16)&0xff);
    	bufferToSend[index+3]=(byte)((value>>24)&0xff);
    	
    	return bufferToSend;
    }
    public static byte[] shortToFrame(byte[] bufferToSend,int index,short value) {
    	bufferToSend[index]=(byte)(value & 0xff);
    	bufferToSend[index+1]=(byte)((value>>8)&0xff);
    
    	
    	return bufferToSend;
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



    public static void main(String[] args) throws IOException, InterruptedException {	//file transfer 는 mode 500 이므로 그부분을 중심으로 코드 참고 바람
        BufferedReader in = new BufferedReader(new InputStreamReader(System.in));
        DatagramSocket ds = new DatagramSocket(7000);
        
        InetAddress ia = InetAddress.getByName("127.0.0.1");

        System.out.println("Select Mode(1. Check    2. Modify)");
        int mode;
        Scanner sc = new Scanner(System.in);
        mode = sc.nextInt();
        sc.nextLine(); //앞에서 생긴 개행문자 버려서 뒤의 nextline 스킵되는거 방지.
      
        byte[] Info=new byte[100];
        DatagramPacket dpReceives=new DatagramPacket(Info,Info.length,ia,6999);
        ds.receive(dpReceives);
        
        
        
        
        float errorpercentagereceive=(float) 0.01;
        errorpercentagereceive=byteArrayToFloat(Arrays.copyOfRange(Info, 4, 8));
        MTU=byteToInt(Arrays.copyOfRange(Info, 0, 4));
        System.out.println(errorpercentagereceive + "   "+ MTU);
        
        int errorpercentage=(int) (errorpercentagereceive*(100));
        System.out.println(errorpercentage);
      


     

        if(mode == 1){              //name get
        	 byte[] bufferToSend;
             byte[] bufferToReceive = new byte[1000];
             bufferToSend = getRequest('R', 'N');
             DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
             ds.send(dpSend);
             
             DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
             ds.receive(dpReceive);
             crc16_check(bufferToReceive);

             int recvBufferlen = byteToShort(new byte[]{bufferToReceive[5], bufferToReceive[4]});
             String rivoName = new String(bufferToReceive, 8, recvBufferlen - 2);
             System.out.println("RivoName " + rivoName);
        }
        else if(mode == 2){         //설정값 변경 - 요청 보내고, 변경된 값으로 답변 받고, 출력
        	byte[] bufferToSend = new byte[1000];
            byte[] bufferToReceive = new byte[1000];
            String newName;
            int bufferlen;
            System.out.print("Enter new Rivo Name: ");
            newName = sc.nextLine();

            bufferlen = (short) (newName.length() + 1);

            System.arraycopy(newName.getBytes(), 0, bufferToSend, 7, bufferlen - 1);
            bufferToSend = setRequest(bufferToSend, 'R', 'N', bufferlen);

            System.out.println(new String(bufferToSend, 7, bufferlen - 1));

            DatagramPacket dpSend = new DatagramPacket(bufferToSend, bufferToSend.length, ia, 6999);
            ds.send(dpSend);
            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);

            crc16_check(bufferToReceive);
            if(bufferToReceive[7] == 0x00){
                System.out.println("New Name has been successfully changed to [" + newName + "]");
        }
        }


        else if(mode == 210){            //Version GET
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
            MTU = (short) byteToShort(new byte[]{bufferToReceive[9], bufferToReceive[8]});
            System.out.println("Device Info:  " + MTU);
        }
        else if(mode == 500){           //File Send
            byte[] bufferToSend = new byte[1000];
            byte[] bufferToReceive = new byte[100];
            short data_info_size;           //filename, firmware version . . .
            int data_total_size;
            String data_info;
            int bufferlen;
            bufferToSend[7] = 0x00;         //data_type = locale
            System.out.print("Enter File Name: ");
            data_info = sc.nextLine();              //data_info: file name
            String dir = System.getProperty("user.dir");
            File fileToSend = new File(dir+"/src/UDP_Demo/"+data_info);
            long filecrc=checksumInputStream(fileToSend);
            int filecrcInt=(int) filecrc;
            System.out.println("Int converted crc: "+filecrcInt);
            if(!fileToSend.exists()){           //File Not exist
                System.out.println("File Not Exist");
            }
            if(fileToSend.exists()){           //File Not exist
                System.out.println("File Exist");
            }
            data_info_size = (short) data_info.length();
            data_total_size = (int) fileToSend.length();
            System.out.println("datatotalsize: "+data_total_size);
            bufferToSend=intToFrame(bufferToSend,8,data_total_size);
            bufferToSend=intToFrame(bufferToSend,12,filecrcInt);
            bufferToSend=shortToFrame(bufferToSend,16,data_info_size);
            System.arraycopy(data_info.getBytes(), 0, bufferToSend, 18, data_info_size);
            bufferlen = data_info_size + 12;
            int offset = bufferlen + 10;
            short crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
            bufferToSend=basicSetting(bufferToSend,bufferlen,(byte)0x00);	//request packet
            int requestbytessent=0;
            DatagramPacket dpSend;
            while(requestbytessent<offset) { // 보낸 byte의 갯수가 총 프레임의 크기를 넘지 않을떄 까지 mtu 만큼의 byte를 전송한다. 
                dpSend = new DatagramPacket(bufferToSend, requestbytessent,MTU, ia, 6999);
                ds.send(dpSend);
                requestbytessent+=MTU;	//보낸 byte에 mtu를 더해준다.
                }
            DatagramPacket dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            System.out.println("File Transfer Start!");

            
            Arrays.fill(bufferToSend, (byte) 0x0);	//start of data packets
            Arrays.fill(bufferToReceive, (byte) 0x0);	
            short seq_num = 1;
            FileInputStream fis = new FileInputStream(fileToSend);
            int totalRead = 0;
            while(true){
            	System.out.println("==========new frame==============");
            	System.out.println("totalRead: " + totalRead + "data_total_size: "+ data_total_size);
                if(totalRead >= data_total_size) break;
                bufferToSend=shortToFrame(bufferToSend,7,seq_num);
                byte[] buffer = new byte[MAX_BUFFER_SIZE];
                int readBytes;
                readBytes = fis.read(buffer, 0, MAX_BUFFER_SIZE);
                totalRead += readBytes;
                short data_size = (short) readBytes;
                System.arraycopy(buffer, 0, bufferToSend, 13, data_size);
                short filedatacrc=crc16_compute(Arrays.copyOfRange(bufferToSend, 13, 13+data_size));
                System.out.println(filedatacrc);
                bufferToSend=shortToFrame(bufferToSend,9,filedatacrc);
                bufferToSend=shortToFrame(bufferToSend,11,data_size);
                bufferlen = readBytes + 7;
              
                byte[] realdata=Arrays.copyOfRange(bufferToSend,13,13+data_size);
                
                offset = 17 + data_size;
                short data_crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, offset));
                bufferToSend=basicSetting(bufferToSend,bufferlen,(byte)0x01);	//data packet
                int framebytessent=0;
                while(framebytessent<offset) { // 보낸 byte의 갯수가 총 프레임의 크기를 넘지 않을떄 까지 mtu 만큼의 byte를 전송한다. 
                	dpSend = new DatagramPacket(bufferToSend, framebytessent,MTU, ia, 6999);
                	ds.send(dpSend);
                	framebytessent+=MTU;	//보낸 byte에 mtu를 더해준다.
                }
                System.out.println(seq_num);
                seq_num++;
                while(true)
                {
                	short recseq=-1;
                	try {
                		dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
                		//from here on program will check whether the data received is good or bad.
                		ds.setSoTimeout(5000);	//timeout을 5초로 설정한다.
                		ds.receive(dpReceive);
                		System.out.println("ACK packet received");
                		recseq = (short) byteToShort(Arrays.copyOfRange(bufferToReceive, 8, 10));
                		System.out.println("seqnum : " +recseq);

                	}
                	catch(SocketTimeoutException e){ //예외 발생시 전체프레임을 다시 발송한다. 

                		System.out.println("exception occured; sending frame again");
                		framebytessent=0;
                		while(framebytessent<offset) {
                			dpSend = new DatagramPacket(bufferToSend, framebytessent,MTU, ia, 6999);
                			Random rand=new Random();
                			int random=rand.nextInt(100)+1;
                			if(random>errorpercentage)
                				ds.send(dpSend);
                			framebytessent+=MTU;
                		}
                		System.out.println("exception occured; sent frame again");
                	}finally {

                		if(bufferToReceive[7]==0 && recseq==seq_num-1) //패킷을 받았고, crc 가 맞는경우
                		{
                			System.out.println("CRC,SEQ Match");
                			break;
                		}
                		else if(bufferToReceive[7]==(byte)0x87) {	//패킷을 받았고, crc가 틀린경우 (구현 미완성)
                			System.out.println("CRC Miss");
                		}
                		else {
                			System.out.println("SEQ NUM Miss");
                		}
                		System.out.println("======================="); 	
                	}

                }
            }

            
            Arrays.fill(bufferToSend, (byte) 0x0);
            Arrays.fill(bufferToReceive, (byte) 0x0); 	//start of verification packet
            bufferlen = 5;
            bufferToSend=intToFrame(bufferToSend,7,data_total_size);
            crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, 11));
            bufferToSend=basicSetting(bufferToSend,bufferlen,(byte)0x02); //verification packet
            dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, 6999);
            ds.send(dpSend);
            dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            System.out.println("Verifying. . .");
            
            Arrays.fill(bufferToSend, (byte) 0x0);	//start of End Packet
            Arrays.fill(bufferToReceive, (byte) 0x0);
            bufferlen = 2;
            bufferToSend[7] = 0x1;           //Action ??
            crc = crc16_compute(Arrays.copyOfRange(bufferToSend, 6, bufferlen + 6));
            bufferToSend=basicSetting(bufferToSend,bufferlen,(byte)0x03);	// ending packet
            dpSend = new DatagramPacket(bufferToSend, bufferlen + 10, ia, 6999);
            ds.send(dpSend);
            dpReceive = new DatagramPacket(bufferToReceive, bufferToReceive.length);
            ds.receive(dpReceive);
            System.out.println("File Transfer Complete!");
        }
    }
}
