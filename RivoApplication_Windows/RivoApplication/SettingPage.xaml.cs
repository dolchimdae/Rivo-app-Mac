using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Navigation;
using Rivo;
using Windows.Devices.Bluetooth.GenericAttributeProfile;
using Windows.Storage.Streams;
using System.Text;

// 빈 페이지 항목 템플릿에 대한 설명은 https://go.microsoft.com/fwlink/?LinkId=234238에 나와 있습니다.

namespace RivoApplication
{
    /// <summary>
    /// 자체적으로 사용하거나 프레임 내에서 탐색할 수 있는 빈 페이지입니다.
    /// </summary>
    public sealed partial class SettingPage : Page
    {
        static int screenreader = -1;
        private DispatcherTimer dispatcherTimer;
        int L3=0;
        int L4 = 0;
        int L3method = 0;
        int L4method = 0;
        public SettingPage()
        {
            this.InitializeComponent();
            dispatcherTimer = new DispatcherTimer();

            dispatcherTimer.Interval = new TimeSpan(0, 0, 2);
            dispatcherTimer.Tick += new EventHandler<Object>(dispatcherTimer_Tick);

        }
        private void dispatcherTimer_Tick(object sender, object e)
        {
            MainPage root = MainPage.Current;
            root.Denotify();
            dispatcherTimer.Stop();


        }
        private void Language_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            string text = (e.AddedItems[0] as ComboBoxItem).Content as string;
            if (text == "영어")
                L4 = 20;
            if (text == "숫자")
                L4 = 10;
            if (text == "한글")
                L4 = 30;
            MainPage page = MainPage.Current;
            page.Notify(text);

        }

        private async void Button_Click(object sender, RoutedEventArgs e)
        {
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
            string passer = screenreader.ToString();
            byte[] topass1 = Encoding.UTF8.GetBytes(passer);
            byte[] topass = new byte[3];
            topass[0] = 0x1;
            Array.Copy(topass1, 0, topass, 1, topass1.Length);
           var result=await device.SetScreenReader(topass);
            MainPage page = MainPage.Current;
            page.Notify("Success");
            dispatcherTimer.Start();

        }

        private void RadioButton_Checked(object sender, RoutedEventArgs e)
        {
            screenreader = 11;
            MainPage page = MainPage.Current;
            page.Notify("screen");

        }

        private void RadioButton_Checked_1(object sender, RoutedEventArgs e)
        {
            screenreader = 21;
        }

        private void RadioButton_Checked_2(object sender, RoutedEventArgs e)
        {
            screenreader = 12;
        }

        private async void Button_Click2(object sender, RoutedEventArgs e)
        {
            Debug.WriteLine("now to connect" + MainPage.Current.bleDeviceName().DeviceId);
            GattCharacteristic writer = MainPage.Current.writerName();
            GattCharacteristic reader = MainPage.Current.readerName();
            BLEDevice device = new BLEDevice(writer, reader);
            string passer = L3.ToString()+","+L3method.ToString()+","+L4.ToString()+","+L4method.ToString();

            byte[] topass = new byte[passer.Length+1];
            topass[0] = 0x1;
            Debug.WriteLine("language:"+topass.Length);
            byte[] topass1 = Encoding.UTF8.GetBytes(passer);
            Array.Copy(topass1, 0, topass, 1, topass1.Length);
            for (int i = 0; i < topass.Length; i++)
                Debug.WriteLine("passing:"+topass[i] + "  ");
            string result = await device.SetL3L4Language(topass);

            Debug.WriteLine("For real: " + result);
        }

        private void ComboBox_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            string text = (e.AddedItems[0] as ComboBoxItem).Content as string;
            if (text == "영어")
                L3 = 20;
            if (text == "숫자")
                L3 = 10;
            if (text == "한글")
                L3 = 30;
            MainPage page = MainPage.Current;
            page.Notify(text);
        }

        private void L3Type_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            string text = (e.AddedItems[0] as ComboBoxItem).Content as string;
            if (text == "리보")
                L3method = 31;
            if (text == "천지인")
                L3method = 32;
            if (text == "나랏글")
                L3method = 33;
            if (text == "ABC")
                L3method = 22;
            if (text == "EWQ")
                L3method = 21;
            MainPage page = MainPage.Current;
            page.Notify(text);
        }

   

        private void L4Type_SelectionChanged(object sender, SelectionChangedEventArgs e)
        {
            string text = (e.AddedItems[0] as ComboBoxItem).Content as string;
            if (text == "리보")
                L4method = 31;
            if (text == "천지인")
                L4method = 32;
            if (text == "나랏글")
                L4method = 33;
            if (text == "ABC")
                L4method = 22;
            if (text == "EWQ")
                L4method = 21;
            MainPage page = MainPage.Current;
            page.Notify(text);
        }
    }

 



}
