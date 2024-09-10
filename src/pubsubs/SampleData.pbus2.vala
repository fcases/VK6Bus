using Gee;
using Protobuf;
using ProtocolBus;

namespace Samples
{
    namespace DataPck {


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




