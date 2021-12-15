using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Storage.Streams;


namespace Rivo
{
    public class BLEDevice : RivoDevice
    {

        
        public BLEDevice()
        {
                
        }

        public override async Task<byte[]> SendAndReceive(byte[] sendData)
        {

            BluetoothLEAdvertisementWatcher BleWatcher = new BluetoothLEAdvertisementWatcher
            {
                ScanningMode = BluetoothLEScanningMode.Active
            };
            BleWatcher.Start();

            BleWatcher.Received += async (w, btAdv) => {
                var device = await BluetoothLEDevice.FromBluetoothAddressAsync(btAdv.BluetoothAddress);
                Debug.WriteLine($"BLEWATCHER Found: {device.Name}");

                // SERVICES!!
                var gatt = await device.GetGattServicesAsync();
                Debug.WriteLine($"{device.Name} Services: {gatt.Services.Count}, {gatt.Status}, {gatt.ProtocolError}");

                // CHARACTERISTICS!!
                var characs = await gatt.Services.Single(s => s.Uuid == 0x6e400001b5a3f393e0a9e50e24dcca9e).GetCharacteristicsAsync();
                var charac = characs.Single(c => c.Uuid == 0x6e400001b5a3f393e0a9e50e24dcca9e);
                await charac.WriteValueAsync(sendData);
            };

            // XXX TODO create receive timer

        }

    }
}
