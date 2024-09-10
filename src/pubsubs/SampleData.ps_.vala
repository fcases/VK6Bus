using Gee;
using Protobuf;
using ProtocolBus;

namespace SampleData
{
	public class DSubs: QueueMgr {
		Domain myDomain;
		string myChannel;
		uint64[] mytpesH64;

		public DSubs(Domain domain, string theChannel) {
			base("SubscriberDER");

			myDomain = domain;
			myChannel = theChannel;
			myDomain.RegisterSubscriber(this, myChannel);
			mytpesH64 = new uint64[] {
					Ciphering.GetHashCode(myDomain.GetDomainId() + "/SampleData.DataPck"),
					Ciphering.GetHashCode(myDomain.GetDomainId() + "/SampleData.KEndPointDef")};
		}

		override public void DispatchMsg(ArrayList<Msg> msgList) {
			foreach (Msg myMsg in msgList)
			{
				if (myMsg.msg_type == mytpesH64[0]) {
					var decBuffer=new DecodeBuffer(myMsg.payLoad.data);
					var myDataPck = new DataPck.from_data(decBuffer);
					OnDataReceived_DataPck(myDataPck);
					continue;
				}
				if (myMsg.msg_type == mytpesH64[1]) {
					var decBuffer=new DecodeBuffer(myMsg.payLoad.data);
					var myKEndPointDef = new KEndPointDef.from_data(decBuffer);
					OnDataReceived_KEndPointDef(myKEndPointDef);
					continue;
				}
			}
			return;
		}

		public string GetChannel() {
			return myChannel;
		}

		virtual public void OnDataReceived_DataPck(DataPck myType) {}
		virtual public void OnDataReceived_KEndPointDef(KEndPointDef myType) {}
	}

	public class DPubl {
		Domain myDomain;
		public DPubl(Domain domain) {
			myDomain = domain;
		}

		public void SendMsg_DataPck(String[] channels, DataPck  myObj){
			Msg.Builder mb = Msg.CreateBuilder();
			for(int i=0;i<channels.Length;i++)
				mb.AddChannels(channels[i]);
			mb.MsgType=Ciphering.GetHash64(myDomain.GetDomainId()+"/"+myObj.GetType().FullName);
			mb.SetPayLoad(myObj.ToByteString());
			myDomain.SendMsg(mb.Build());
		}

		public void SendMsg_DataPck(String channel, DataPck myObj){
			Msg.Builder mb = Msg.CreateBuilder();
			mb.AddChannels(channel);
			mb.MsgType=Ciphering.GetHash64(myDomain.GetDomainId()+"/"+myObj.GetType().FullName);
			mb.SetPayLoad(myObj.ToByteString());
			myDomain.SendMsg(mb.Build());
		}

		public void SendMsg_KEndPointDef(String[] channels, KEndPointDef  myObj){
			Msg.Builder mb = Msg.CreateBuilder();
			for(int i=0;i<channels.Length;i++)
				mb.AddChannels(channels[i]);
			mb.MsgType=Ciphering.GetHash64(myDomain.GetDomainId()+"/"+myObj.GetType().FullName);
			mb.SetPayLoad(myObj.ToByteString());
			myDomain.SendMsg(mb.Build());
		}

		public void SendMsg_KEndPointDef(String channel, KEndPointDef myObj){
			Msg.Builder mb = Msg.CreateBuilder();
			mb.AddChannels(channel);
			mb.MsgType=Ciphering.GetHash64(myDomain.GetDomainId()+"/"+myObj.GetType().FullName);
			mb.SetPayLoad(myObj.ToByteString());
			myDomain.SendMsg(mb.Build());
		}

	}
}
