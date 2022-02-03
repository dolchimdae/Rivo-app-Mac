using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
//getmtusize 함수 에뮬레이터로 작동하는지까지 확인하기

namespace Rivo
{




    public abstract class RivoDevice
    {

        int mtu = 20;
        bool mtuconfirmed = false;



        public RivoDevice()
        {

        }

        public static long byteToInt(byte[] bytes)
        {

            long newValue = 0;
            newValue |= (((long)bytes[0]) << 24) & 0xFF000000;
            newValue |= (((long)bytes[1]) << 16) & 0xFF0000;
            newValue |= (((long)bytes[2]) << 8) & 0xFF00;
            newValue |= (((long)bytes[3])) & 0xFF;
            return newValue;

        }


        static ushort CRC16(byte[] data)
        {
            ushort crc = 0xFFFF;

            for (uint i = 0; i < data.Length; i++)
            {
                crc = (ushort)((byte)(crc >> 8) | (crc << 8));
                crc ^= data[i];
                crc ^= (ushort)((byte)(crc & 0xFF) >> 4);
                crc ^= (ushort)((crc << 8) << 4);
                crc ^= (ushort)(((crc & 0xFF) << 4) << 1);
            }
            return crc;
        }


        public static bool CRC16_CHECK(byte[] data)
        {
            if (data[6] == 0x87)
            {
                Console.WriteLine("CRC Error");
                return false;
            }

            int bufferlen = data.Length - 10;

            byte[] realData = new byte[bufferlen];
            Array.Copy(data, 6, realData, 0, bufferlen);
            short crc = (short)CRC16(realData);
            bufferlen += 6;
            short realCrc = 0;

            realCrc |= (short)((data[bufferlen++]) & 0xFF);
            realCrc |= (short)((data[bufferlen++] << 8) & 0xFF00);

            if (crc == realCrc)
            {
                return true;
                Console.WriteLine("CRC Checking == TRUE");
            }
            else
            {
                return false;
                Console.WriteLine("CRC Checking == FALSE");
            }
        }

        public bool recvFrameCheck(byte[] recvFrame, int recvSize, string id)
        {
            byte[] utf8bytes = System.Text.Encoding.UTF8.GetBytes(id);

            if (!(recvFrame[0] == (byte)'a' &&
                          recvFrame[1] == (byte)'t' &&
                          recvFrame[2] == (byte)id[0] &&
                          recvFrame[3] == (byte)id[1] &&
                          recvFrame[recvSize - 2] == 0x0d &&
                          recvFrame[recvSize - 1] == 0x0a))
            {
                return false;
            }
            else
            {
                if (CRC16_CHECK(recvFrame) == true) return true;
                else return false;
            }
        }

        public byte[] composeSendframe(string id, byte[] data)
        {
            byte[] utf8bytes = System.Text.Encoding.UTF8.GetBytes(id);

            int totalLength = data.Length + 10;
            byte[] frame = new byte[totalLength];
            int i = 0;
            frame[i++] = (byte)'A';
            frame[i++] = (byte)'T';
            frame[i++] = (utf8bytes[0]);
            frame[i++] = (utf8bytes[1]);
            frame[i++] = (byte)(data.Length); // assume little endian
            frame[i++] = (byte)(data.Length >> 8);
            data.CopyTo(frame, i);
            i += data.Length;
            ushort crc = CRC16(data);
            frame[i++] = (byte)(crc);
            frame[i++] = (byte)(crc >> 8);
            frame[i++] = 0x0d;
            frame[i++] = 0x0a;
            //totalLength = i;
           
            return frame;
        }



        public abstract Task<byte[]> ReadAndWrite(byte[] sendData); //베이스로직은여기에

        public virtual async Task WritePacket(byte[] sendData)
        {

        }


        //베이스로직은여기에
        public virtual async Task<byte[]> readPacket()
        {
            // byte[] array = null;
            return null;
        }//베이스로직은여기에





        async Task<byte[]> SendAndReceive(string id, byte[] data)
        {

            /*  if (!mtuconfirmed)
              {
                  mtu = await GetMTUSize();//try 
                  mtuconfirmed = true;

              }
              */

            byte[] sendframe = composeSendframe(id, data);
            Debug.WriteLine("hi");
            //int length = recvFrame[4] + recvFrame[5] * 256 - 2;

            int position;
            int framesize;
            int sendSize;
            bool tobreak=false;
            for (int count = 0; count < 3; count++)
            {
                if (tobreak == true)
                    break;
                position = 0;
                framesize = sendframe.Length;


                //todo write 
                mtu = 125;
                Debug.WriteLine(framesize);
                while (position < framesize)
                {


                    sendSize = Math.Min(mtu, framesize - position);
                    byte[] senddata = new byte[100];
                    Array.Copy(sendframe, position, senddata, 0, sendSize);

                    await WritePacket(senddata);//Array.copy()


                    position += sendSize;

                }

                byte[] recvframe = await readPacket();
                int len=1;
                if (recvframe[0] == (byte)'a' && recvframe[1] == (byte)'t')
                {

                    len = recvframe[4] + (recvframe[5]*256)+10;
                    Debug.WriteLine("length: " + len);
                    while (recvframe.Length < len)
                    {
                        byte[] temp = await readPacket();
                        Array.Copy(temp, 0, recvframe, recvframe.Length, temp.Length - 1);

                    }
                }

                int recvSize = recvframe.Length;

                
                if (recvFrameCheck(recvframe, recvSize, id))
                {
                    Debug.WriteLine("Nice frame");
                    //  byte opcode = recvframe[6];
                    byte result = recvframe[7];

                    if (result != 0)
                    {
                        throw new Exception("Result code =" + result);
                    }

                    byte[] temp2 = new byte[recvframe.Length];
                    Debug.WriteLine("recvlength: " + recvframe.Length);
                    Array.Copy(recvframe, 8, temp2, 0, len - 12);
                    tobreak = true;
                    return temp2;
                    
                    
                }

                else {
                    Thread.Sleep(100);
                    Debug.WriteLine("Bad frame"+id );
                }
                

            }

            throw new Exception("Retry failed");
        }

        async Task<byte[]> SendAndReceive2(string id, byte[] data)
        {
            int totalLength = data.Length + 10;
            byte[] frame = new byte[totalLength];
            int i = 0;
            frame[i++] = (byte)'A';
            frame[i++] = (byte)'T';
            frame[i++] = ((byte)id[0]);
            frame[i++] = ((byte)id[1]);
            frame[i++] = (byte)(data.Length); // assume little endian
            frame[i++] = (byte)(data.Length >> 8);
            data.CopyTo(frame, i);
            i += data.Length;
            ushort crc = CRC16(data);
            frame[i++] = (byte)(crc);
            frame[i++] = (byte)(crc >> 8);
            frame[i++] = 0x0d;
            frame[i++] = 0x0a;
            totalLength = i;

           
                try
                {
                    byte[] recvFrame = await readPacket();

                    // parse recvFrame 
                    int recvSize = recvFrame.Length;
                    if (!(recvFrame[0] == (byte)'a' &&
                          recvFrame[1] == (byte)'t' &&
                          recvFrame[2] == ((byte)(id[0])) &&
                          recvFrame[3] == ((byte)(id[1])) &&
                          recvFrame[recvSize - 2] == 0x0d &&
                          recvFrame[recvSize - 1] == 0x0a))
                    {
                        throw new Exception("Invalid frame");
                    }
                    byte opcode = recvFrame[6];
                    byte result = recvFrame[7];

                    if (result != 0)
                    {
                        throw new Exception("Result code =" + result);
                    }

                    int length = recvFrame[4] + recvFrame[5] * 256 - 12; //little endian, exclude opcode & result

                    byte[] recvData = new byte[length];


                    CRC16_CHECK(recvFrame);// shoud check CRC!!!


                    Array.Copy(recvFrame, 8, recvData, 0, length);
                    // shoud check CRC!!!
                    return recvData;
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex.Message);

                }
            
            throw new Exception("Retry failed");
        }



        //FV,LN,SR,VG,RN,IF,RV,MT

        public async Task<byte[]> GetFirmwareVersion()
        {
            var result = await SendAndReceive("FV", new byte[] { 0x0 });
            return result;
        }
        public async Task<string> SetDateandTime()
        {
            var result = await SendAndReceive("DT", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> SetL3L4Language(byte[] passed)
        {
            string str="asdf";
            byte[] StrByte = Encoding.UTF8.GetBytes(str);
            byte[] resByte = { 0x1,0x0, 0x0, 0x0, 0x0};

            Array.Copy(StrByte, 0, resByte, 0, 4);

            var result = await SendAndReceive("LN", passed);

            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<byte[]> SetScreenReader(byte[] passer)
        {
            var result = await SendAndReceive("SR", passer);
            return result;
        }
        public async Task<byte[]> FindMyRivo()
        {
            byte[] result = await SendAndReceive("RV", new byte[] { 0x0, 0x0 });
         
            return result;
        }

        public async Task<UInt16> GetMTUSize()
        {

            int framesize;
            for (int count = 0; count < 3; count++)
            {
                //framesize = data.Length + 10;

                byte[] sendframe = composeSendframe("MT", new byte[] { 0x0 });

                await WritePacket(sendframe);
                var client = new UdpClient();


                byte[] recvframe = await readPacket();

                int len;

                int recvSize = recvframe.Length;
                if (recvframe[0] == (byte)'a' && recvframe[1] == (byte)'t')
                {
                    recvFrameCheck(recvframe, recvSize, "MT");
                    len = recvframe[4] + recvframe[5] * 256 + 10;
                    Debug.WriteLine(recvframe[4] + " " + recvframe[5]);
                    byte[] temp = { };
                    Debug.WriteLine(recvframe.Length + "len: " + len);
                    while (recvframe.Length < len)
                    {

                        temp = await readPacket();
                        Array.Copy(temp, 0, recvframe, recvframe.Length, temp.Length - 1);

                    }
                    int mtu = recvframe[8] + recvframe[9] * 256;
                    Debug.WriteLine(recvframe[8] + recvframe[9] * 256);
                    return (UInt16)mtu;
                }

            }
            throw new Exception("exception");
        }

        public async Task<byte[]> GetRivoInfo()
        {
            var result = await SendAndReceive("IF", new byte[] { 0x0 });
            return result;
        }



        public async Task<byte[]> GetRivoStatus()
        {
            var result = await SendAndReceive("RS", new byte[] { 0x0 });
            return result;
        }
        public async Task<byte[]> GetRivoName()
        {
            var result = await SendAndReceive("RN", new byte[] { 0x0 } );
            return result;
        }
        public async Task<byte[]> SetRivoName(byte[] newname)
        {
            var result = await SendAndReceive("RN", newname);
            return result;
        }




        public async Task<string> UpdateStart()
        {
            var result = await SendAndReceive("UM", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<UInt16> UpdateData()
        {
            var result = await SendAndReceive("UM", new byte[] { 0x1 });
            return (UInt16)(result[0] + result[1] * 256);
        }
        public async Task<string> VerifyData()
        {
            var result = await SendAndReceive("UM", new byte[] { 0x2 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> UpdateEnd()
        {
            var result = await SendAndReceive("UM", new byte[] { 0x3 });
            return System.Text.Encoding.Default.GetString(result);
        }


    }

}