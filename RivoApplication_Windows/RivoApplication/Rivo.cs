using System;
using System.Threading.Tasks;

namespace RivoApplication
{
    public abstract class RivoDevice
    {
        public RivoDevice()
        {
        }

        public abstract Task<byte[]> SendAndReceive(byte[] sendData);

        async Task<byte[]> SendAsync(string id, byte[] data)
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
                    byte[] recvFrame = await SendAndReceive(frame);

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


        public static void CRC16_CHECK(byte[] data)
        {
            if (data[6] == 0x87)
            {
                Console.WriteLine("CRC Error");
                return;
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
                Console.WriteLine("CRC Checking == TRUE");
            }
            else
            {
                Console.WriteLine("CRC Checking == FALSE");
            }
        }
        //FV,LN,SR,VG,RN,IF,RV,MT
        public async Task<string> GetFirmwareVersion()
        {
            var result = await SendAsync("FV", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> GetL3L4Language()
        {
            var result = await SendAsync("LN", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> SetL3L4Language()
        {
            var result = await SendAsync("LN", new byte[] { 0x1 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<string> GetScreenReader()
        {
            var result = await SendAsync("SR", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }/*
        public async Task<string> SetScreenReader()
        {
            var result = await SendAsync("SR", new byte[] { 0x1 });
            return System.Text.Encoding.Default.GetString(result);
        }*/
        public async Task<int> GetVoiceGuidance()
        {
            var result = await SendAsync("VG", new byte[] { 0x0 });
            return result[0];
        }/*
        public async Task<string> SetVoiceGuidance()
        {
            var result = await SendAsync("VG", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }*/
        public async Task<string> GetRivoName()
        {
            var result = await SendAsync("RN", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }/*
        public async Task<string> SetRivoName()
        {
            var result = await SendAsync("VG", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }*/
        public async Task<string> GetDeviceInfo()
        {
            var result = await SendAsync("IF", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }/*
        public async Task<string> SetDeviceInfo()
        {
            var result = await SendAsync("IF", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }*/
        public async Task<string> FindMyRivo()
        {
            var result = await SendAsync("RV", new byte[] { 0x0 });
            return System.Text.Encoding.Default.GetString(result);
        }
        public async Task<UInt16> GetMTUSize()
        {
            var result = await SendAsync("MT", new byte[] { 0x0 });
            return (UInt16)(result[0] + result[1] * 256);
        }


    }
}