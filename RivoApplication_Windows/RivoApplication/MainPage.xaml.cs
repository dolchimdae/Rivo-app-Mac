using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Foundation;
using Windows.Foundation.Collections;
using Windows.System;
using Windows.UI.Core;
using Windows.UI.Xaml;
using Windows.UI.Xaml.Controls;
using Windows.UI.Xaml.Controls.Primitives;
using Windows.UI.Xaml.Data;
using Windows.UI.Xaml.Input;
using Windows.UI.Xaml.Media;
using Windows.UI.Xaml.Media.Animation;
using Windows.UI.Xaml.Navigation;

using Windows.Devices.Bluetooth;
using Windows.Devices.Bluetooth.Advertisement;
using Windows.Devices.Enumeration;
using Windows.Devices.Bluetooth.GenericAttributeProfile;

// 빈 페이지 항목 템플릿에 대한 설명은 https://go.microsoft.com/fwlink/?LinkId=402352&clcid=0x412에 나와 있습니다.

namespace RivoApplication
{
    
    /// <summary>
    /// 자체적으로 사용하거나 프레임 내에서 탐색할 수 있는 빈 페이지입니다.
    /// </summary>
    public sealed partial class MainPage : Page
    {
        public static string rand = "asdfssss";
        public static BluetoothLEDevice device;
        public static GattCharacteristic writer;
        public static GattCharacteristic reader;
        public void setBLEDevice(BluetoothLEDevice recv) {
            device = recv;
        }
        public BluetoothLEDevice bleDeviceName() {
            return device;

        }
        public void setwriter(GattCharacteristic recv)
        {
            writer = recv;
        }
        public GattCharacteristic writerName()
        {
            return writer;

        }
        public GattCharacteristic readerName() {
            return reader;
        }
        public void setreader(GattCharacteristic recv) {

            reader = recv;

        }
        public static MainPage Current { get; internal set; }
        
        public MainPage()
        {
            this.InitializeComponent();
            Current = this;

        }

        private readonly List<(string Tag, Type Page)> _pages = new List<(string Tag, Type Page)>
        {
            ("battery",typeof(BatteryPage)),
            ("setting", typeof(SettingPage)),
            ("update", typeof(UpdatePage)),
            ("Myrivo", typeof(RivoPage)),
            ("help",typeof(HelpPage))
        };

        private void NavView_ItemInvoked(NavigationView sender, NavigationViewItemInvokedEventArgs args)
        {
            if(args.IsSettingsInvoked==true)
            {
                NavView_Navigate("settings", args.RecommendedNavigationTransitionInfo);
            }
            else if(args.InvokedItemContainer != null)
            {
                var navItemTag = args.InvokedItemContainer.Tag.ToString();
                NavView_Navigate(navItemTag, args.RecommendedNavigationTransitionInfo);
            }
        }

        private void NavView_Navigate(string navItemTag, NavigationTransitionInfo transitionInfo)
        {
            Type _page = null;
            if(navItemTag=="settings")
            {
                _page = typeof(SettingPage);
            }
            else
            {
                var item = _pages.FirstOrDefault(p => p.Tag.Equals(navItemTag));
                _page = item.Page;

            }

            var preNavPageType = ContentFrame.CurrentSourcePageType;
            if(!(_page is null)&&!Type.Equals(preNavPageType, _page))
            {
                ContentFrame.Navigate(_page, null, transitionInfo);
            }
        }
        public void Notify(string message) {
            StatusBorder.Visibility = Visibility.Visible;
            StatusBorder.Background = new SolidColorBrush(Windows.UI.Colors.Green);
            StatusBlock.Text = message;
        }
        public void Denotify() {
            StatusBorder.Visibility = Visibility.Collapsed;
        }
      
    }

}
