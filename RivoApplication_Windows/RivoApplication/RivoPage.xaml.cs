using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Diagnostics;
using System.Text;
using System.Threading.Tasks;
using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Devices.Enumeration;
using Windows.Security.Cryptography;
using Windows.Storage.Streams;
using Windows.UI.Core;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Navigation;
using System.Runtime.InteropServices.WindowsRuntime;
using Rivo;

// 빈 페이지 항목 템플릿에 대한 설명은 https://go.microsoft.com/fwlink/?LinkId=234238에 나와 있습니다.

namespace RivoApplication
{
    /// <summary>
    /// 자체적으로 사용하거나 프레임 내에서 탐색할 수 있는 빈 페이지입니다.
    /// </summary>
    
    public sealed partial class RivoPage : Page
    {
        private MainPage rootPage = MainPage.Current;
        public string SelectedBleDeviceId;
        public string SelectedBleDeviceName = "No device selected";
        private ObservableCollection<BluetoothLEDeviceDisplay> KnownDevices = new ObservableCollection<BluetoothLEDeviceDisplay>();

        private List<DeviceInformation> UnknownDevices = new List<DeviceInformation>();

        private GattCharacteristic selectedCharacteristic;
        private GattCharacteristic registered;
        private GattCharacteristic Commander;
        private GattPresentationFormat presentationFormat;

        public static BluetoothLEDevice bluetoothLeDevice = null;

        private DeviceWatcher deviceWatcher;
        #region UI
        public RivoPage()
        {
            this.InitializeComponent();
        }
   
        protected override void OnNavigatedFrom(NavigationEventArgs e)
        {
            StopBleDeviceWatcher();

            var bleDeviceDisplay = ResultsListView.SelectedItem as BluetoothLEDeviceDisplay;
            Debug.WriteLine("BLE DEVICE : " + ResultsListView.SelectedItem);
            if (bleDeviceDisplay != null)
            {
               
                SelectedBleDeviceId = bleDeviceDisplay.Id;
                SelectedBleDeviceName = bleDeviceDisplay.Name;
            }
            //var success = await ClearBluetoothLEDeviceAsync();
            //if(!success)
            //{
            //    Console.WriteLine("Error: unable to reset app state");
            //}
        }
        public void Listview_SelectionChanged(object sender, SelectionChangedEventArgs args) {
            
            var bleDeviceDisplay = ResultsListView.SelectedItem as BluetoothLEDeviceDisplay;
            if (bleDeviceDisplay != null)
            {
                
                SelectedBleDeviceId = bleDeviceDisplay.Id;
                SelectedBleDeviceName = bleDeviceDisplay.Name;
                Debug.WriteLine("connect to:"+SelectedBleDeviceId + SelectedBleDeviceName);
            }

        }
        private async void ConnectButton_Click(object sender, RoutedEventArgs e)
        {
            ConnectButton.IsEnabled = false;

       

            try
            {
                // BT_Code: BluetoothLEDevice.FromIdAsync must be called from a UI thread because it may prompt for consent.
                
               
                Debug.WriteLine("Device: " + SelectedBleDeviceId);
                bluetoothLeDevice = await BluetoothLEDevice.FromIdAsync(SelectedBleDeviceId);
                MainPage.Current.setBLEDevice(bluetoothLeDevice);
                if (bluetoothLeDevice == null)
                {
                    Debug.WriteLine("Failed to connect to device.");
                }
            }
            catch (Exception ex) when (ex.HResult == E_DEVICE_NOT_AVAILABLE)
            {
                Debug.WriteLine("Bluetooth radio is not on.");
            }

            if (bluetoothLeDevice != null)
            {
                Debug.WriteLine("Connected");
                // Note: BluetoothLEDevice.GattServices property will return an empty list for unpaired devices. For all uses we recommend using the GetGattServicesAsync method.
                // BT_Code: GetGattServicesAsync returns a list of all the supported services of the device (even if it's not paired to the system).
                // If the services supported by the device are expected to change during BT usage, subscribe to the GattServicesChanged event.
                GattDeviceServicesResult result = await bluetoothLeDevice.GetGattServicesAsync(BluetoothCacheMode.Uncached);
                var serviceuuid = "6e400001-b5a3-f393-e0a9-e50e24dcca9e";
                var readuuid = "6e400003-b5a3-f393-e0a9-e50e24dcca9e";
                var writeuuid = "6e400002-b5a3-f393-e0a9-e50e24dcca9e";
            

                if (result.Status == GattCommunicationStatus.Success)
                {
                    var services = result.Services;
                    Debug.WriteLine(String.Format("Found {0} services", services.Count));
                    foreach (var service in services)
                    {
                        Debug.WriteLine(DisplayHelpers.GetServiceName(service));
                        ServiceList.Items.Add(new ComboBoxItem { Content = DisplayHelpers.GetServiceName(service), Tag = service });
                        if (DisplayHelpers.GetServiceName(service) == serviceuuid) {
                            Debug.WriteLine("Matching service found");
                            
                            var accessStatus = await service.RequestAccessAsync();
                            if (accessStatus == DeviceAccessStatus.Allowed)
                            {
                                Debug.WriteLine("Success");
                                var characteristicsResult = await service.GetCharacteristicsAsync(BluetoothCacheMode.Uncached);
                                IReadOnlyList<GattCharacteristic> characteristics = null;
                                 characteristics = characteristicsResult.Characteristics;
                                foreach (GattCharacteristic c in characteristics)
                                {
                                   Debug.WriteLine( c.Uuid);
                                    if (DisplayHelpers.GetCharacteristicName(c) == readuuid)
                                    {
                                        Debug.WriteLine("Characteristic");
                                        MainPage.Current.setreader(c);
                                        selectedCharacteristic = c;
                                    }
                                    if (DisplayHelpers.GetCharacteristicName(c) == writeuuid)
                                    {
                                        Debug.WriteLine("Writer");
                                        MainPage.Current.setwriter(c);
                                        Commander = c;
                                    }

                                }
                                selectedCharacteristic.ValueChanged += Characteristic_ValueChanged;
                                byte[] writebuffer = new byte[11];
                                writebuffer[0] = 0x41;
                                writebuffer[1] = 0x54;
                                writebuffer[2] = 0x4d;
                                writebuffer[3] = 0x54;
                                writebuffer[4] = 0x01;
                                writebuffer[5] = 0x00;
                                writebuffer[6] = 0x00;
                                writebuffer[7] = 0xF0;
                                writebuffer[8] = 0xE1;
                                writebuffer[9] = 0x0D;
                                writebuffer[10] =0x0A;
                                

                                
                              
                                IBuffer buffer = writebuffer.AsBuffer();

                                var results = await Commander.WriteValueWithResultAsync(buffer);

                                Debug.WriteLine("what happened"+results.Status);



                            }
                        }
                    }
                    ConnectButton.Visibility = Visibility.Collapsed;
                    ResultsListView.Visibility = Visibility.Visible;
                }
                else
                {
                    Debug.WriteLine("Device unreachable");
                }
            }
            ConnectButton.IsEnabled = true;

        }




        private void Search_Click()
        {
            
            if (deviceWatcher == null)
            {
                StartBleDeviceWatcher();
                Search.Content = "검색 중지";
            }
            else
            {
                StopBleDeviceWatcher();
                Search.Content = "검색";
            }

        }
        private bool Not(bool value) => !value;

#endregion

        #region deviceWatcher
        private void StartBleDeviceWatcher()
        {
            string[] requestedProperties = { "System.Devices.Aep.DeviceAddress", "System.Devices.Aep.IsConnected", "System.Devices.Aep.Bluetooth.Le.IsConnectable" };

            string aqsAllBluetoothLEDevices = "(System.Devices.Aep.ProtocolId:=\"{bb7bb05e-5972-42b5-94fc-76eaa7084d49}\")";

            deviceWatcher =
                    DeviceInformation.CreateWatcher(
                        aqsAllBluetoothLEDevices,
                        requestedProperties,
                        DeviceInformationKind.AssociationEndpoint);

            deviceWatcher.Added += DeviceWatcher_Added;
            deviceWatcher.Updated += DeviceWatcher_Updated;
            deviceWatcher.Removed += DeviceWatcher_Removed;
            deviceWatcher.EnumerationCompleted += DeviceWatcher_EnumerationCompleted;
            deviceWatcher.Stopped += DeviceWatcher_Stopped;

            KnownDevices.Clear();

            deviceWatcher.Start();

        }

        private void StopBleDeviceWatcher()
        {
            if (deviceWatcher != null)
            {
                // Unregister the event handlers.
                deviceWatcher.Added -= DeviceWatcher_Added;
                deviceWatcher.Updated -= DeviceWatcher_Updated;
                deviceWatcher.Removed -= DeviceWatcher_Removed;
                deviceWatcher.EnumerationCompleted -= DeviceWatcher_EnumerationCompleted;
                deviceWatcher.Stopped -= DeviceWatcher_Stopped;

                // Stop the watcher.
                deviceWatcher.Stop();
                deviceWatcher = null;
            }

        }

        private BluetoothLEDeviceDisplay FindBluetoothLEDeviceDisplay(string id)
        {
            foreach (BluetoothLEDeviceDisplay bleDeviceDisplay in KnownDevices)
            {
                if (bleDeviceDisplay.Id == id)
                {
                    return bleDeviceDisplay;
                }
            }
            return null;
        }

        private DeviceInformation FindUnknownDevices(string id)
        {
            foreach (DeviceInformation bleDeviceInfo in UnknownDevices)
            {
                if (bleDeviceInfo.Id == id)
                {
                    return bleDeviceInfo;
                }
            }
            return null;
        }

        private async void DeviceWatcher_Added(DeviceWatcher sender, DeviceInformation deviceInfo)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                lock (this)
                {
                   

                    // Protect against race condition if the task runs after the app stopped the deviceWatcher.
                    if (sender == deviceWatcher)
                    {
                        // Make sure device isn't already present in the list.
                        if (FindBluetoothLEDeviceDisplay(deviceInfo.Id) == null)
                        {
                            if (deviceInfo.Name != string.Empty)
                            {
                                // If device has a friendly name display it immediately.
                                KnownDevices.Add(new BluetoothLEDeviceDisplay(deviceInfo));
                            }
                            else
                            {
                                // Add it to a list in case the name gets updated later. 
                                UnknownDevices.Add(deviceInfo);
                            }
                        }

                    }
                }
            });
        }

        private async void DeviceWatcher_Updated(DeviceWatcher sender, DeviceInformationUpdate deviceInfoUpdate)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                lock (this)
                {
                   

                    // Protect against race condition if the task runs after the app stopped the deviceWatcher.
                    if (sender == deviceWatcher)
                    {
                        BluetoothLEDeviceDisplay bleDeviceDisplay = FindBluetoothLEDeviceDisplay(deviceInfoUpdate.Id);
                        if (bleDeviceDisplay != null)
                        {
                            // Device is already being displayed - update UX.
                            bleDeviceDisplay.Update(deviceInfoUpdate);
                            return;
                        }

                        DeviceInformation deviceInfo = FindUnknownDevices(deviceInfoUpdate.Id);
                        if (deviceInfo != null)
                        {
                            deviceInfo.Update(deviceInfoUpdate);
                            // If device has been updated with a friendly name it's no longer unknown.
                            if (deviceInfo.Name != String.Empty)
                            {
                                KnownDevices.Add(new BluetoothLEDeviceDisplay(deviceInfo));
                                UnknownDevices.Remove(deviceInfo);
                            }
                        }
                    }
                }
            });
        }

        private async void DeviceWatcher_EnumerationCompleted(DeviceWatcher sender, object e)
        {
            // We must update the collection on the UI thread because the collection is databound to a UI element.
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                // Protect against race condition if the task runs after the app stopped the deviceWatcher.
                if (sender == deviceWatcher)
                {

                }
            });
        }

        private async void DeviceWatcher_Removed(DeviceWatcher sender, DeviceInformationUpdate deviceInfoUpdate)
        {
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                lock (this)
                {
                   

                    // Protect against race condition if the task runs after the app stopped the deviceWatcher.
                    if (sender == deviceWatcher)
                    {
                        // Find the corresponding DeviceInformation in the collection and remove it.
                        BluetoothLEDeviceDisplay bleDeviceDisplay = FindBluetoothLEDeviceDisplay(deviceInfoUpdate.Id);
                        if (bleDeviceDisplay != null)
                        {
                            KnownDevices.Remove(bleDeviceDisplay);
                        }

                        DeviceInformation deviceInfo = FindUnknownDevices(deviceInfoUpdate.Id);
                        if (deviceInfo != null)
                        {
                            UnknownDevices.Remove(deviceInfo);
                        }
                    }
                }
            });

        }

        private async void DeviceWatcher_Stopped(DeviceWatcher sender, object e)
        {
            // We must update the collection on the UI thread because the collection is databound to a UI element.
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal, () =>
            {
                // Protect against race condition if the task runs after the app stopped the deviceWatcher.
                if (sender == deviceWatcher)
                {

                }
            });
        }

        #endregion
        #region pairing

        private bool isBusy = false;

        public int E_DEVICE_NOT_AVAILABLE { get; private set; }
       

        private async void Pair_Click()
        {
            if(isBusy)
            {
                return;
            }

            isBusy = true;

            var bleDeviceDisplay = ResultsListView.SelectedItem as BluetoothLEDeviceDisplay;
            DevicePairingResult result = await bleDeviceDisplay.DeviceInformation.Pairing.PairAsync();

            isBusy = false;
        }
        private async void Characteristic_ValueChanged(GattCharacteristic sender, GattValueChangedEventArgs args)
        {
            // BT_Code: An Indicate or Notify reported that the value has changed.
            // Display the new value with a timestamp.
            
            var message = $"Value at {DateTime.Now:hh:mm:ss.FFF}: {"Notification"}";
            var buffer=new byte[100];
            await Dispatcher.RunAsync(CoreDispatcherPriority.Normal,() => Debug.WriteLine(message));
            GattReadResult result = await selectedCharacteristic.ReadValueAsync();
            
            byte[] data;
                CryptographicBuffer.CopyToByteArray(result.Value, out data);
            var readata=Encoding.UTF8.GetString(data);
            Debug.WriteLine("Data:"+data);
                Debug.WriteLine("READ:"+ result.Status);
             result = await selectedCharacteristic.ReadValueAsync();

           
            CryptographicBuffer.CopyToByteArray(result.Value, out data);
             readata = Encoding.UTF8.GetString(data);
            Debug.WriteLine("Data Length:" + readata.Length+"bytedata:"+data);
            for (int i = 0; i < data.Length; i++)
            {
                var a = data.GetValue(i);
                char b = Convert.ToChar(a);
                Debug.WriteLine("read"+i+"th character: "+a+"converted to "+b);
            }
            RivoDevice device = new BLEDevice();
            bool Frame=device.recvFrameCheck(data,data.Length,"MT");
            Debug.WriteLine("READ:" + result.Status+"GOOD FRame:"+Frame);
        }

        #endregion

        #region discover character

        //private async Task<bool> ClearBluetoothLEDeviceAsync()
        //{
        //    if (subscribedForNotifications)
        //    {
        //        // Need to clear the CCCD from the remote device so we stop receiving notifications
        //        var result = await registered.WriteClientCharacteristicConfigurationDescriptorAsync(GattClientCharacteristicConfigurationDescriptorValue.None);
        //        if (result != GattCommunicationStatus.Success)
        //        {
        //            return false;
        //        }
        //        else
        //        {
        //            selectedCharacteristic.ValueChanged -= Characteristic_ValueChanged;
        //            subscribedForNotifications = false;
        //        }
        //    }
        //    bluetoothLeDevice?.Dispose();
        //    bluetoothLeDevice = null;
        //    return true;
        //}
        #endregion


    }
}