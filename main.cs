using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Rivo;
using System.Threading.Tasks;
using System.Diagnostics;

namespace UnitTestProject1
{
    public class main
    {
        public  async Task<int> @Main()
        {
            Debug.WriteLine("aaaas");

            var device = new UDPDevice("127.0.0.1", 6999);
            var mtusize = await device.GetMTUSize();
            var rivoname = await device.GetFirmwareVersion();
            Debug.WriteLine(mtusize);
            Debug.WriteLine(rivoname);

            //Console.WriteLine(mtusize);
            //Console.WriteLine(rivoname);
            return 0;
        }

    }
}
