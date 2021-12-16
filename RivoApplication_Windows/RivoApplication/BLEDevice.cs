 //using System;
//using System.Collections.Generic;
//using System.Linq;
//using System.Runtime.InteropServices;
//using System.Text;
//using System.Threading.Tasks;
//using Windows.Devices.Bluetooth.Advertisement;
//using Windows.Devices.Bluetooth.GenericAttributeProfile;
//using Windows.Storage.Streams;

//namespace RivoApplication
//{
//    public class BLEDevice : RivoDevice
//    {
//        string[] serviceString = { "6E400002-B5A3-F393-E0A9-E50E24DCCA9E", " 6E400003-B5A3-F393-E0A9-E50E24DCCA9E", "6E400004-B5A3-F393-E0A9-E50E24DCCA9E" };
//        GattCharacteristicsResult result = await service.GetCharacteristicsAsync();
//        GattCharacteristicProperties properties = characteristic.CharacteristicProperties;

//        public async void initBLE(BluetoothLEAdvertisementDataTypes id)
//        {

//        }

//        public override async Task<byte[]> SendAndReceive(byte[] data)
//        {
//            byte[] buffer = new byte[256];
//            byte[] frame = new byte[256];
//            var reader = new DataReader();
//            var numRead = 0;
//            var totalRead = 0;
//            var totalSize = 99999;
//            var readHeader = false;
//            var payloadSize = 0;

//            do
//            {
//                numRead = await reader.LoadAsync(512);
//                reader.ReadBytes(buffer);
//                Array.Copy(buffer, 0, frame, numRead, totalRead);
//                totalRead += numRead;
//                if (!readHeader && totalRead >= 6)
//                {
//                    payloadSize = frame[4] + frame[5] * 256;
//                    totalSize = payloadSize;
//                    readHeader = true;
//                }

//            } while (totalRead < totalSize);


//        }
//    }

//}
