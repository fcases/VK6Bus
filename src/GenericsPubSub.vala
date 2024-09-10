using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus {


	public class GSub<theType>: QueueMgr {
		static int n=0;
		string myChannel;
        private uint64 myTypeName;
        private Domain myDomain;

		private HFunc<theType,string> theCallback;
		
		public  GSub(Domain theDomain, string theChannel, HFunc<theType,string> fnDataReceive=()=>{},bool started=true)  {
		//  public  GSub(Domain theDomain, string theChannel, HFunc<theType,string>? fnDataReceive=null,bool started=true)  {
			base.Started(started,typeof(theType).name()+"_S"+(n++).to_string());

            myDomain = theDomain;
            myChannel = theChannel;
            myDomain.RegisterSubscriber(this, myChannel);
			myTypeName = Ciphering.GetHash64(
				theDomain.GetDomainId().to_string() +
				"//" + typeof(theType).name()
			);
			theCallback=fnDataReceive;
		}

		public override void DispatchMsg(ArrayList<Msg> msgList) {
			foreach(Msg	myMsg in msgList)  {
                if( myMsg.msgType==myTypeName )   {
					var decBuffer=new DecodeBuffer(myMsg.payLoad.data);
					theType myDataObj=(theType) Object.new(typeof(theType));
					(myDataObj as Protobuf.Message).decode(decBuffer);

					//  if( theCallback!=null) theCallback(myDataObj,GetChannel());
					theCallback(myDataObj,GetChannel());
					OnDataReceived(myDataObj);
				}
            }
            return;
        }

		public string GetChannel() {
			return myChannel;
		}

		public virtual void OnDataReceived(theType myObj) {}
	}

    public class GPub<theType> {
        Domain myDomain;
        protected uint64 myTypeName;

        public GPub(Domain theDomain) {
            myDomain = theDomain;
			myTypeName = Ciphering.GetHash64(
				theDomain.GetDomainId().to_string() +
				"//" + typeof(theType).name()
			);
        }

		public void SendMsgToChannels(string[] channels, theType  myObj)  {
			var myMsg=new Msg();
			foreach(string ch in channels)
				myMsg.channels.append(ch);
			myMsg.msgType=myTypeName;
			var encBuffer = new EncodeBuffer();
            var aux=myObj as Protobuf.Message;
            aux.encode (encBuffer);
			myMsg.payLoad= new ByteArray.take(encBuffer.data);
			myDomain.SendMsg(myMsg);
		}

		public void SendMsg(string channel, theType myObj) {
			string[] chs={channel};
			SendMsgToChannels(chs,myObj);
		}
    }
}
