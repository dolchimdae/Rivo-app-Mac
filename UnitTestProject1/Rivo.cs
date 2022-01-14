using System;
using System.Text;
using System.Threading.Tasks;

#define min(a, b)(((a) < (b)) ? (a) : (b))

namespace Rivo
{

    public abstract class RivoDevice
    {
        public RivoDevice()
        {

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

        public int recvFrameCheck(byte[] recvFrame, int recvSize, byte[] id)
        {
            if (!(recvFrame[0] == (byte)'a' &&
                          recvFrame[1] == (byte)'t' &&
                          recvFrame[2] == ((byte)(id[0])) &&
                          recvFrame[3] == ((byte)(id[1])) &&
                          recvFrame[recvSize - 2] == 0x0d &&
                          recvFrame[recvSize - 1] == 0x0a))
            {
                return 0;
            }
            else
            {
                if (CRC16_CHECK(recvFrame) == true) return 1;
                else return 0;
            }
        }

        public void sendframe(byte[] data, byte[] id)
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
        }

            
        
        public abstract Task<byte[]> writePacket(byte[] sendData); //베이스로직은여기에
        public abstract Task<byte[]> readPacket(byte[] sendData); //베이스로직은여기에




        async Task<byte[]> SendAndReceive(string id, byte[] data, byte[] recvFrame)
        {   
            

            int position = 0;

            for (int count = 0; count < 3; count++)
            {
                try
                {
                
                //todo write 
                while (position < data.Length+10)
                {
                        int sendSize = int.MinValue(mtu, frameSize - pos);
                        writePacket(data: Array(sendFrame[pos...pos + sendSize - 1]));
                        position += sendSize;
                }

                int recvSize = recvFrame.Length;
                id = id.ToCharArray;
                if(recvFrameCheck(recvFrame,recvSize,id) == 1)
                {
                        byte opcode = recvFrame[6];
                        byte result = recvFrame[7];

                        if (result != 0)
                        {
                            throw new Exception("Result code =" + result);
                        }

                        int length = recvFrame[4] + recvFrame[5] * 256 - 2; //little endian, exclude opcode & result

                        byte[] recvData = new byte[length];

                        while (recvFrame.count < len)
                        {
                            readPacket(recvFrame);
                        }

                }


                    // CRC16_CHECK(recvFrame);// shoud check CRC!!!


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
            var result = await SendAndReceive("FV", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
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

        public async Task<UInt16> GetMTUSize()
        {
            var result = await SendAndReceive("MT", new byte[] { 0x0 });
            return (UInt16)(result[0] + result[1] * 256);
        }

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


    }
}
