using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus {

	public class Sub<theType>: QueueMgr {
        string myChannel;
        protected uint64 myTypeName;
        protected Domain myDomain;

        public delegate void DataReceivedDelg<theType>(theType myObj, string chan="");
		protected DataReceivedDelg theCallback;

		public Sub(Domain theDomain, string theChannel,DataReceivedDelg fnDataReceive) {
            base("SubscriberGEN");

            myDomain = theDomain;
            //  myTypeName = Ciphering.GetHash64(myDomain.GetDomainId() + "/" + typeof(theType).FullName);
            myTypeName = 3;
            myChannel = theChannel;
            myDomain.RegisterSubscriber(this, myChannel);

			theCallback=fnDataReceive;
		}

		public override void DispatchMsg(ArrayList<Msg> msgList) {
			foreach(Msg	myMsg in msgList)  {
                if( myMsg.msgType==myTypeName ) {  // En GSub sólo hay un tipo
                    //  var decBuffer=new DecodeBuffer(myMsg.payLoad.data);
		            //  var mySampleData=new iTypeMsg.from_data(decBuffer);
					//  theCallback(mySampleData,myChannel);
					CallTheCallback(myMsg.payLoad.data);
                }
            }

            return;
        }

		public string GetChannel() {
			return myChannel;
		}

		public virtual void CallTheCallback(uint8[] ba){}
	}

    public class Pub<theType> 
    {
        string myChannel;
        Domain myDomain;

        public Pub(Domain theDomain) {
            myDomain = theDomain;
        }

		public void SendMsgManyChannels(string[] channels, theType  myObj)  {
			var myMsg=new Msg();
			foreach(string ch in channels)
				myMsg.channels.append(ch);
			myMsg.msgType=3;
			var encBuffer = new EncodeBuffer();
            //  var aux=myObj as ProtocolBus.Msg;
            var aux=myObj as Protobuf.Message;
            aux.encode (encBuffer);
			myMsg.payLoad= new ByteArray.take(encBuffer.data);
			myDomain.SendMsg(myMsg);
		}

		public void SendMsg(string channel, theType myObj) {
			string[] chs={channel};
			SendMsgManyChannels(chs,myObj);
		}
    }

}
