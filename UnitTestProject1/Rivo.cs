using System;
using System.Text;
using System.Threading.Tasks;
using Windows.Networking.Sockets;
using System.Net;
using System.Net.Sockets;
using System.Threading;
using Windows.Networking;
using Windows.Storage.Streams;
using System.Net.WebSockets;
using UnitTestProject1;
using System.Diagnostics;

//getmtusize 함수 에뮬레이터로 작동하는지까지 확인하기

namespace Rivo
{




    public abstract class RivoDevice
    {

        public int mtu = 20;
        public bool mtuconfirmed = false;



        public RivoDevice()
        {

        }

        public long byteToInt(byte[] bytes)
        {

            long newValue = 0;
            newValue |= (((long)bytes[0]) << 24) & 0xFF000000;
            newValue |= (((long)bytes[1]) << 16) & 0xFF0000;
            newValue |= (((long)bytes[2]) << 8) & 0xFF00;
            newValue |= (((long)bytes[3])) & 0xFF;
            return newValue;

        }


        public ushort CRC16(byte[] data)
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


        public bool CRC16_CHECK(byte[] data)
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
            }
            else
            {
                return false;
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


            var client = new UdpClient();
            client.Connect("127.0.0.1", 6999);
            await client.SendAsync(sendData, sendData.Length);
        }


        //베이스로직은여기에
        public virtual async Task<byte[]> readPacket(IPEndPoint ep)
        {
            

            var client = new UdpClient();
            client.Connect("127.0.0.1", 6999);
            UdpReceiveResult result = await client.ReceiveAsync().ConfigureAwait(false);
            //UdpReceiveResult result = await client.ReceiveAsync();

            return result.Buffer;

          
        }


        //베이스로직은여기에



        
        public async Task<byte[]> SendAndReceive(string id, byte[] data)
        {
            
            if (!mtuconfirmed)
            {
                mtu = await GetMTUSize();//try 
                mtuconfirmed = true;
            }

            byte[] sendframe = composeSendframe(id, data);

            //int length = recvFrame[4] + recvFrame[5] * 256 - 2;


            IPEndPoint groupEP = new IPEndPoint(IPAddress.Parse("127.0.0.1"), 6999);

            int position;
            int framesize;
            int sendSize;
            for (int count = 0; count < 3; count++)
            {
                position = 0;
                framesize = data.Length + 10;


                //todo write 
                while (position < framesize)
                {

                    sendSize = Math.Min(mtu, framesize - position);

                    byte[] senddata = { };
                    Array.Copy(sendframe, position, senddata, 0, position + sendSize - 1);
                    await WritePacket(senddata);//Array.copy()


                    position += sendSize;
                }
                byte[] recvframe = await readPacket(groupEP);
                int len;
                if (recvframe[0] == (byte)'a' && recvframe[1] == (byte)'t')
                {

                    len = recvframe[4] + recvframe[5] << 8 + 10;
                    while (recvframe.Length < len)
                    {
                        byte[] temp = await readPacket(groupEP);
                        Array.Copy(temp, 0, recvframe, recvframe.Length, temp.Length - 1);

                    }
                }

                int recvSize = recvframe.Length;


                if (recvFrameCheck(recvframe, recvSize, id))
                {
                    //  byte opcode = recvframe[6];
                    byte result = recvframe[7];

                    if (result != 0)    
                    {
                        throw new Exception("Result code =" + result);
                    }

                    byte[] temp2 = await readPacket(groupEP);
                    Array.Copy(temp2, 0, recvframe, recvframe.Length, temp2.Length - 1);
                    return temp2;
                }

            }

            throw new Exception("Retry failed");
            
        }


        public async Task<byte[]> SendAndReceive2(string id, byte[] data)
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

            for (int count = 0; count < 3; count++)
            {
                try
                {
                    byte[] recvFrame = await ReadAndWrite(frame);

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

                    int length = recvFrame[4] + recvFrame[5] * 256 - 2; //little endian, exclude opcode & result

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
            }
            throw new Exception("Retry failed");
        }



        //FV,LN,SR,VG,RN,IF,RV,MT

        public async Task<string> GetFirmwareVersion()
        {
            var result = await SendAndReceive2("FV", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        /*
        public async Task<string> SetDateandTime()
        {
            var result = await SendAndReceive("DT", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> SetL3L4Language(string str)
        {
            byte[] StrByte = Encoding.UTF8.GetBytes(str);
            byte[] resByte = { 0x1, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0 };

            Array.Copy(StrByte, 0, resByte, 1, 1);

            var result = await SendAndReceive("LN", resByte);

            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> SetScreenReader()
        {
            var result = await SendAndReceive("SR", new byte[] { 0x1 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> FindMyRivo()
        {
            var result = await SendAndReceive("RV", new byte[] { 0x0, 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        */

        public virtual async Task<UInt16> GetMTUSize()
        {
            for (int count = 0; count < 3; count++)
            {
                //framesize = data.Length + 10;

                byte[] sendframe = composeSendframe("MT", new byte[] { 0x0 });

                await WritePacket(sendframe);

                IPEndPoint groupEP = new IPEndPoint(IPAddress.Parse("127.0.0.1"), 6999);
                byte[] recvframe = await readPacket(groupEP);
                int len;

                int recvSize = recvframe.Length;
                if (recvframe[0] == (byte)'a' && recvframe[1] == (byte)'t')
                {
                    recvFrameCheck(recvframe, recvSize, "MT");
                    len = recvframe[4] + recvframe[5] << 8 + 10;
                    byte[] temp = { };
                    while (recvframe.Length < len)
                    {
                        temp = await readPacket(groupEP);
                        Array.Copy(temp, 0, recvframe, recvframe.Length, temp.Length - 1);

                    }
                    return (UInt16)(temp[8] + temp[9] << 8);
                }

            }
            throw new Exception("exception");
        }




        /*
        public async Task<string> GetRIvoStatus()
        {
            var result = await SendAndReceive("RS", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> SetRIvoName()
        {
            var result = await SendAndReceive("RV", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
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
        */

    }
}
