using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using Windows.Networking;
using Windows.Networking.Sockets;
using Windows.Storage.Streams;

namespace Rivo
{
    public class UDPDevice : RivoDevice
    {
        UdpClient udp = new UdpClient(7000);
        String hostname = "127.0.0.1";
        int port = 7000;
        public UDPDevice(String hostname, int port)
        {
            this.hostname = hostname;
            this.port = port;
        }


        public override async Task WritePacket(byte[] sendData)
        {

            udp.Connect("127.0.0.1", 6999);
            await udp.SendAsync(sendData, sendData.Length);
        }

        public override async Task<byte[]> readPacket()
        {
            IPEndPoint RemoteIpEndPoint = new IPEndPoint(IPAddress.Any, 7000);


            //var timeToWait = TimeSpan.FromSeconds(1000);
            try
            {

                udp.Client.ReceiveTimeout = 5000;

                Byte[] receiveBytes = udp.Receive(ref RemoteIpEndPoint);
                string returnData = Encoding.ASCII.GetString(receiveBytes);

                Debug.WriteLine(returnData);

               // Thread.Sleep(40);
               return receiveBytes;
            }
            catch
            {
                throw new Exception("Exception");
            }
           
        }
            
    }
}
