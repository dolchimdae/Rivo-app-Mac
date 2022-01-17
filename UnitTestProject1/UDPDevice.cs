    using System;
    using System.Net;
    using System.Net.Sockets;
    using System.Threading.Tasks;
    using Windows.Networking;
    using Windows.Networking.Sockets;
    using Windows.Storage.Streams;

    namespace Rivo
    {
        public class UDPDevice : RivoDevice
        {
            String hostname = "127.0.0.1";
            int port = 6999;
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



                var client = new UdpClient();
                client.Connect("127.0.0.1", 6999);
                await client.SendAsync(sendData, sendData.Length);
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

                var client = new UdpClient();
                var receiveDatagram = await client.ReceiveAsync();

                byte[] buffer;
                buffer = receiveDatagram.Buffer;

                return buffer;
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
