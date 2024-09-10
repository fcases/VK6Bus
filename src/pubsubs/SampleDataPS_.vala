using Gee;
using Protobuf;
using ProtocolBus;

namespace Samples
{
	public class DSubs: QueueMgr {
		Domain myDomain;
		string myChannel;
		ulong[] mytpesH64;

		protected DSubs(Domain domain,string theChannel) {
			base("SubscriberDER");

			myDomain=domain;
			myChannel=theChannel;
			myDomain.RegisterSubscriber(this,myChannel);
			//  mytpesH64 = new ulong[] {
			//  	Hash64.GetHashCode(myDomain.GetDomainId()+ "/Positions.Pos3D")};
			mytpesH64 = new ulong[] { 3};
		}

		public override void DispatchMsg(ArrayList<Msg> msgList) {
			foreach(Msg myMsg in msgList)
			{
				if( myMsg.msgType==mytpesH64[0] )  // en DSub puede haber mas tipos
				{
		            var decBuffer=new DecodeBuffer(myMsg.payLoad.data);
		            var mySampleData=new DataPck.from_data(decBuffer);
					OnDataReceived(mySampleData);
					continue; // si hubiese mas tipos habría mas if, si ya encontrado sigue el while
				}
			}
						
			return;
		}

		public string GetChannel() {
			return myChannel;
		}

		public virtual void OnDataReceived(DataPck myType) {}
	}

	public class DPubl
	{
		Domain myDomain;
		public DPubl(Domain domain)
		{
			myDomain = domain;
		}

		public void SendMsgManyChannels(string[] channels, DataPck  myObj)
		{
			var myMsg=new Msg();
			foreach(string ch in channels)
				myMsg.channels.append(ch);
			myMsg.msgType=3;
			var encBuffer = new EncodeBuffer();
			myObj.encode (encBuffer);
			myMsg.payLoad= new ByteArray.take(encBuffer.data);
			myDomain.SendMsg(myMsg);
		}

		public void SendMsg(string channel, DataPck myObj)
		{
			string[] chs={channel};
			SendMsgManyChannels(chs,myObj);
		}
	}


	public sealed class GSubs : Sub<DataPck> {
		public GSubs(Domain theDomain, string theChannel,DataReceivedDelg<DataPck> fnDataReceive) {
			base(theDomain, theChannel,fnDataReceive);
            //  myTypeName = Ciphering.GetHash64(myDomain.GetDomainId() + "/" + typeof(theType).FullName);
		}

		protected override void CallTheCallback(uint8[] ba){
			var decBuffer=new DecodeBuffer(ba);
			var mySampleData=new DataPck.from_data(decBuffer);
			theCallback(mySampleData,GetChannel());
		}
	}

	public sealed class GPubl : Pub<DataPck> {
		public GPubl(Domain theDomain) {
			base(theDomain);
		}
	}

}




