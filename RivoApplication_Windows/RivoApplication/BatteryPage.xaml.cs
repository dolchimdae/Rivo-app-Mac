using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using System.Text;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;

// 빈 페이지 항목 템플릿에 대한 설명은 https://go.microsoft.com/fwlink/?LinkId=234238에 나와 있습니다.

namespace RivoApplication
{
    /// <summary>
    /// 자체적으로 사용하거나 프레임 내에서 탐색할 수 있는 빈 페이지입니다.
    /// </summary>
    public sealed partial class BatteryPage : Page
    {
        private DispatcherTimer dispatcherTimer;

        public BatteryPage()
        {
            this.InitializeComponent();
            dispatcherTimer = new DispatcherTimer();
            
            dispatcherTimer.Interval = new TimeSpan(0, 0, 2);
            dispatcherTimer.Tick += new EventHandler<Object>(dispatcherTimer_Tick);
        }

        private void dispatcherTimer_Tick(object sender,object e)
        {
            MainPage root = MainPage.Current;
            root.Denotify();
            dispatcherTimer.Stop();

            
        }

        private void Battery_ValueChanged(object sender, RangeBaseValueChangedEventArgs e)
        {

        }

        private void TextBox_TextChanged(object sender, TextChangedEventArgs e)
        {

        }

        private async void TextBlock_SelectionChanged(object sender, RoutedEventArgs e)
        {
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
             await device.FindMyRivo();


        }

        private async void ToggleSwitch_Toggled(object sender, RoutedEventArgs e)
        {
            if (Vibration.IsOn==true)
            {
                GattCharacteristic writer = MainPage.Current.writerName();
                GattCharacteristic reader = MainPage.Current.readerName();
                BLEDevice device = new BLEDevice(writer, reader);
                var result = await device.FindMyRivo();
                MainPage root = MainPage.Current;
                root.Notify("Success");
                dispatcherTimer.Start();
                Debug.WriteLine("result: " + result.GetValue(7));
            }
        }

        private async void Button_Click(object sender, RoutedEventArgs e)
        {
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
            var result = await device.GetRivoStatus();
            MainPage root = MainPage.Current;
           
          
            var real=System.Text.Encoding.UTF8.GetString(result);
            root.Notify("Success: " +real);
            int start = 1;
            int end =1;
            for (int a = 0; a < real.Length; a++) {
                if (real[a] == ':')
                {
                    start = a;
                    break;
                }
                        }
            for (int a = 0; a < real.Length; a++)
            {
                if (real[a] == ',')
                {
                    end = a;
                    break;
                }
            }
            var batt=real.Substring(start+1,end-start-1);
            Battery.Text = batt;
            dispatcherTimer.Start();
            
            Debug.WriteLine("result: " + result.GetValue(7));
        }

        private async void Button_Click_1(object sender, RoutedEventArgs e)
        {
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
            String name = Namebox.Text;
            Debug.WriteLine("Name: "+name);
            byte[] namebytes = Encoding.UTF8.GetBytes(name);
            byte[] topass = new byte[namebytes.Length+1];
            topass[0] = 0x1;
            Array.Copy(namebytes,0,topass,1,namebytes.Length);
            var result = await device.SetRivoName(topass);
            MainPage root = MainPage.Current;
            root.Notify("Namechange Success");
            dispatcherTimer.Start();
        }

        private async void Button_Click_2(object sender, RoutedEventArgs e)
        {
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
            MainPage root = MainPage.Current;
            var result=await device.GetRivoInfo();
            var real = System.Text.Encoding.UTF8.GetString(result);
            int version = -1;
            int versionend = -1;
            int serial = -1;
            for(int a=0; a<real.Length; a++)
            {
                if (real[a] == ',') {
                    version = a;
                    break;
                }
            }
            for (int a = 0; a < real.Length; a++)
            {
                if (real[a] == ',')
                {
                    serial = a;
                    break;
                }
            }
            string present = real.Substring(0,version);
            string serialn = real.Substring(version, serial);
          

            root.Notify("Success:"+real);
            Name.Text = present;
            Version.Text = serialn;
            dispatcherTimer.Start();

        }
    }
}
