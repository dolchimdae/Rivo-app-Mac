using System;
using System.Diagnostics;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using Windows.Networking;
using Windows.Networking.Sockets;
using Windows.Storage.Streams;

namespace Rivo
{
    public class UDPDevice : RivoDevice
    {
        UdpClient udp = new UdpClient();
        String hostname = "127.0.0.1";
        int port = 7000;
        public UDPDevice(String hostname, int port)
        {
            this.hostname = hostname;
            this.port = port;
        }


        public override async Task WritePacket(byte[] sendData)
        {
            /*
            var tcs = new TaskCompletionSource<byte[]>();
            var socket = new DatagramSocket();

            var ostream = await socket.GetOutputStreamAsync(new HostName(hostname), port.ToString());
            var writer = new DataWriter(ostream);
            writer.WriteBytes(sendData);
            await writer.StoreAsync();
            // XXX TODO create receive timer
            //return tcs.Task.Result;
            */



         
            
            udp.Connect("127.0.0.1", 6999);
            await udp.SendAsync(sendData, sendData.Length);
        }

        public override async Task<byte[]> readPacket()
        {
            /*
            var tcs = new TaskCompletionSource<byte[]>();
            var socket = new DatagramSocket();
            socket.MessageReceived += (sender, eventArgs) =>
            {
                uint len = eventArgs.GetDataReader().UnconsumedBufferLength;
                byte[] buffer = new byte[len];
                eventArgs.GetDataReader().ReadBytes(buffer);
                socket.Dispose();
                tcs.TrySetResult(buffer);
            };
            */

            IPEndPoint RemoteIpEndPoint = new IPEndPoint(IPAddress.Any,7000);
            Byte[] receiveBytes = udp.Receive(ref RemoteIpEndPoint);
            string returnData = Encoding.ASCII.GetString(receiveBytes);

            Debug.WriteLine(returnData);
            byte[] buffer= { 0x1};
           

            return receiveBytes;
        }

        public override async Task<byte[]> ReadAndWrite(byte[] sendData)
        {
            {
                var tcs = new TaskCompletionSource<byte[]>();
                var socket = new DatagramSocket();
                socket.MessageReceived += (sender, eventArgs) =>
                {
                    uint len = eventArgs.GetDataReader().UnconsumedBufferLength;
                    byte[] buffer = new byte[len];
                    eventArgs.GetDataReader().ReadBytes(buffer);
                    socket.Dispose();
                    tcs.TrySetResult(buffer);
                };

                var ostream = await socket.GetOutputStreamAsync(new HostName(hostname), port.ToString());
                var writer = new DataWriter(ostream);
                writer.WriteBytes(sendData);
                await writer.StoreAsync();
                // XXX TODO create receive timer
                return tcs.Task.Result;
            }
        }
    }
}
