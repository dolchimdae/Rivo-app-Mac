using System;
using System.Net;
using System.Net.Sockets;

namespace WindowsClient
{
    class Client
    {
        static readonly string udpServerName = "127.0.0.1";
        static readonly int udpServerPort = 6999;
        static readonly bool EMULATOR_MODE = true;
        static readonly int MAX_RETRY = 3;
        static readonly int UDP_TIMEOUT = 3000;




        byte[] send(string id, byte[] data)
        {
            int totalLength = data.Length + 10;
            byte[] frame = new byte[totalLength];
            int i = 0;
            frame[i++] = (byte)'A';
            frame[i++] = (byte)'T';
            frame[i++] = ((byte)id[0]);
            frame[i++] = ((byte)id[1]);
            frame[i++] = (byte)(data.Length);
            frame[i++] = (byte)(data.Length >> 8); // assume little endian
            data.CopyTo(frame, i);
            i += data.Length;
            ushort crc = CRC16(data);
            frame[i++] = (byte)(crc);
            frame[i++] = (byte)(crc >> 8);
            frame[i++] = 0x0d;          
            frame[i++] = 0x0a;

            byte[] recvFrame = null;
            for (int t = 0; t < MAX_RETRY; t++)
            {
                if (EMULATOR_MODE)
                {
                    try
                    {
                        UdpClient c = new();
                        c.Client.SendTimeout = UDP_TIMEOUT;
                        c.Client.ReceiveTimeout = UDP_TIMEOUT;
                        
                        
                        c.Send(frame, totalLength, udpServerName, udpServerPort);

                        IPEndPoint ep = new(IPAddress.Any, 0);
                        recvFrame = c.Receive(ref ep);  // synchronous receive
                        break; // if received, break out of loop
                    }
                    catch (Exception ex)
                    {
                        // print error and retry
                        Console.WriteLine(ex.Message);
                    }

                }
                else
                {
                    // send using BLE GATT
                }
            }
            if (recvFrame == null)
            {
                throw new Exception("Failed to receive data");
            }
            // check recv frame
            int recvSize = recvFrame.Length;
            if (!(recvFrame[0] == (byte)'a' &&
                  recvFrame[1] == (byte)'t' &&
                  recvFrame[2] == ((byte)(id[0])) &&
                  recvFrame[3] == ((byte)(id[1])) &&
                  recvFrame[recvSize - 2] == 0x0d &&
                  recvFrame[recvSize - 1] == 0x0a))         
            {
                //Console.WriteLine(recvSize);
                throw new Exception("Invalid frame");   
            }
            //int length = recvFrame[4] * 256 + recvFrame[5];

            int length = (recvSize - 9) - 1; //여기에 앞에 두바이트를 short로 변환하는 arraybyte to short 로 뒤에는 
            //short[] sdata = new short[(int)Math.Ceiling(recvSize / 2)];
            //Console.WriteLine(length2);

            byte[] recvData = new byte[length];     
            Array.Copy(recvFrame, 6 , recvData, 0, length);

            //CRC16_CHECK(data);// shoud check CRC!!!

            return recvData;
        }

        string GetFirmwareVersion()
        {
            return System.Text.Encoding.Default.GetString(send("FV", new byte[] { 0x0 }));
        }
        string SetDateandTime()
        {
            return System.Text.Encoding.Default.GetString(send("DT", new byte[] { 10 }));
        }
        string Get_L3L4_Language()
        {
            return System.Text.Encoding.Default.GetString(send("LN", new byte[] { 0x0 }));
        }
        string Set_L3L4_Language()
        {
            return System.Text.Encoding.Default.GetString(send("LN", new byte[] { 0x1 }));
        }
        string GetScreenReader()
        {
            return System.Text.Encoding.Default.GetString(send("SR", new byte[] { 0x0 }));
        }
        string SetScreenReader()
        {
            return System.Text.Encoding.Default.GetString(send("SR", new byte[] { 0x1 }));
        }
        string GetVoiceGuidance()
        {
            return System.Text.Encoding.Default.GetString(send("VG", new byte[] { 0x0 }));
        }
        string SetVoiceGuidance()
        {
            return System.Text.Encoding.Default.GetString(send("VG", new byte[] { 0x1 }));
        }
        string GetLocaleList()
        {
            return System.Text.Encoding.Default.GetString(send("LC", new byte[] { 1 }));
        }
        string DeleteLocale()
        {
            return System.Text.Encoding.Default.GetString(send("LC", new byte[] { 1 /*+ n*/ }));
        }
        string GetDictionaryList()
        {
            return System.Text.Encoding.Default.GetString(send("DC", new byte[] { 1 }));
        }
        string DeleteDictionary()
        {
            return System.Text.Encoding.Default.GetString(send("DC", new byte[] { 1 /*+ n*/ }));
        }
        string GetRivoName()
        {
            return System.Text.Encoding.Default.GetString(send("RN", new byte[] { 0x0 }));
        }
        string SetRivoName()
        {
            return System.Text.Encoding.Default.GetString(send("RV", new byte[] { 0x1 }));
        }
        string DeleteRivoName()
        {
            return System.Text.Encoding.Default.GetString(send("RV", new byte[] { 1 /*+ n*/ }));
        }
        string GetDeviceInfo()
        {
            return System.Text.Encoding.Default.GetString(send("IF", new byte[] { 0x0 }));
        }
        string SetDeviceInfo()
        {
            return System.Text.Encoding.Default.GetString(send("IF", new byte[] { 0x1 /*+ n*/ }));
        }
        string FindMyRivo()
        {
            return System.Text.Encoding.Default.GetString(send("RV", new byte[] { 0x0 }));
        }
        string FindMyPhone()
        {
            return System.Text.Encoding.Default.GetString(send("RV", new byte[] { 0x2 }));
        }
        string GetMTUSize()
        {
            return System.Text.Encoding.Default.GetString(send("MT", new byte[] { 0x0 }));
        }
        string SetMTUSize()
        {
            return System.Text.Encoding.Default.GetString(send("MT", new byte[] { 3 }));
        }
        string GetRivoStatus()
        {
            return System.Text.Encoding.Default.GetString(send("RS", new byte[] { 1 }));
        }
        string GetLog()
        {
            return System.Text.Encoding.Default.GetString(send("LG", new byte[] { 1 }));
        }
        string SetLog()
        {
            return System.Text.Encoding.Default.GetString(send("LG", new byte[] { 10 }));
        }
        string ModifyLog()
        {
            return System.Text.Encoding.Default.GetString(send("LG", new byte[] { 3 }));
        }
        static  ushort CRC16(byte[] data)
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

        static uint CRC32(byte[] data)
        {
            uint crc = 0xFFFF;

            for (uint i = 0; i < data.Length; i++)
            {
                //crc = (ushort)((byte)(crc >> 8) | (crc << 8));
                crc ^= data[i];
                for(uint j=8; j>0; j--) 
                {
                    crc = (crc>>1)^(0xEDB88320U & ((crc == 1)?0xFFFFFFFF : 0));
                }
            }
            return ~crc;
        }


        public static void CRC16_CHECK(byte[] data)
        {
            if (data[7] == 0x87)
            {
                Console.WriteLine("CRC Error");
                return;
            }
            short bufferlen = Convert.ToInt16(new byte[] { data[5], data[4] });
            byte[] realData = new byte[bufferlen];
            Array.Copy(data, 6, realData, 0, bufferlen);
            short crc = (short)CRC16(realData);
            bufferlen += 6;
            short realCrc = 0;

            realCrc |= (short)((data[bufferlen++]) & 0xFF);
            realCrc |= (short)((data[bufferlen++] << 8) & 0xFF00);

            if (crc == realCrc)
            {
                Console.WriteLine("CRC Checking == TRUE");
            }
            else
            {
                Console.WriteLine("CRC Checking == FALSE");
            }
        }



        static void Main(string[] args)
        {
            Client c = new();
            //Console.WriteLine(c.GetFirmwareVersion());
            //Console.WriteLine(c.GetScreenReader());
            //Console.WriteLine(c.SetVoiceGuidance());
            //Console.WriteLine(c.GetMTUSize());

            Console.WriteLine(c.GetVoiceGuidance());

            //Console.WriteLine(c.Get_L3L4_Language());
            //Console.WriteLine(c.FindMyRivo());

        }
    }
}