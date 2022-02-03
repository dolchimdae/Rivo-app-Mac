 using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;
using Rivo;
using System.Diagnostics;
using Windows.Security.Cryptography;
using System.Runtime.InteropServices.WindowsRuntime;

namespace RivoApplication
    {
    public class BLEDevice : RivoDevice
       {
        GattCharacteristic reader;
        GattCharacteristic writer;
        public BLEDevice(GattCharacteristic writer, GattCharacteristic reader) {
            this.reader = reader;
            this.writer = writer;
        }
        public BLEDevice() { }


        public override async Task WritePacket(byte[] sendData)
        {
            IBuffer buffer = sendData.AsBuffer();
            var result=await  writer.WriteValueWithResultAsync(buffer);
            Debug.WriteLine("IDK Man:"+result.Status);
        }

        public override async Task<byte[]> readPacket()
        {
           GattReadResult buffer= await reader.ReadValueAsync();
            Debug.WriteLine(buffer.Value);
            byte[] data;
            Debug.WriteLine("this");
            CryptographicBuffer.CopyToByteArray(buffer.Value, out data);
            
            var readata = Encoding.UTF8.GetString(data);
            Debug.WriteLine("Data Length:" + readata.Length + "bytedata:" + data);
            for (int i = 0; i < data.Length; i++)
            {
                var a = data.GetValue(i);
                char b = Convert.ToChar(a);
                Debug.WriteLine("read" + i + "th character: " + a + "converted to " + b);
            }
            Debug.WriteLine("memE:"+data);
            return data;
        }

        public override Task<byte[]> ReadAndWrite(byte[] sendData)
        {
            throw new NotImplementedException();
        }
    }

}
