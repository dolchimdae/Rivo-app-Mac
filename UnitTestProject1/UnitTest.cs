using System;
using Microsoft.VisualStudio.TestTools.UnitTesting;
using Rivo;
using System.Threading.Tasks;
using System.Diagnostics;

namespace UnitTestProject1
{
    [TestClass]         
    public class UnitTest1
    {
        [TestMethod]
        public async Task TestMethod1()
        { 
            var device = new UDPDevice("127.0.0.1", 6999);
            var firmwareVersion = await device.GetFirmwareVersion();
            Assert.AreEqual("Rivo 3.0.5,BL 3.0.5,BT 3.0.5", firmwareVersion);

        }
        /*
        [TestMethod]
        public async Task TestMethod2()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var l3l4language = await device.GetL3L4Language();
            Assert.AreEqual("20,21,30,31", l3l4language);


        }
     
        [TestMethod]
        public async Task TestMethod2_2()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var l3l4language = await device.SetL3L4Language("10,22,20,32");
            Assert.AreEqual("", l3l4language);
                
        }
        

        [TestMethod]
        public async Task TestMethod4()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var screenreader = await device.SetScreenReader();
            Assert.AreEqual("3,11,11,iOS VoiceOver,21,Android TalkBack,12,watchOS", screenreader);


        }

        [TestMethod]
        public async Task TestMethod5_2()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var Rivostatus = await device.GetRIvoStatus();
            Assert.AreEqual(1, Rivostatus);
        }

        [TestMethod]
        public async Task TestMethod7()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var findmyrivo = await device.FindMyRivo();
        }
        */

        [TestMethod]
            public async Task TestMethod8()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var mtusize = await device.GetMTUSize();
            
        }

        
       

        /*
        [TestMethod]
        public async Task TestMethod9()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var updatestart = await device.UpdateStart();
            Assert.AreEqual("", updatestart);
        }

        [TestMethod]
        public async Task TestMethod10()
        {   
            var device = new UDPDevice("127.0.0.1", 6999);
            var verify = await device.VerifyData();
            Assert.AreEqual("", verify);
        }

        [TestMethod]
        public async Task TestMethod11()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var updateend = await device.UpdateEnd();
            Assert.AreEqual("", updateend);
        }
        
        [TestMethod]
        public async Task TestMethod12()
        {
            var device = new UDPDevice("127.0.0.1", 6999);
            var updatedata = await device.UpdateData();
            Assert.AreEqual("", updatedata);
        }
        */
    }
}       
