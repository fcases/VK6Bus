using ProtocolBus;


public class DPSub: GSub<DataPck>
{
    public DPSub(Domain domain,string theChannel) {
        base(domain,theChannel);
    }
    public override void OnDataReceived(DataPck myObj) {
        stdout.printf("\t\t\tDP Sub by override %s: Msg received:\n{\n%s}\n",GetChannel(),myObj.to_string("    "));
    }
}

void OnDataReceivedDP(DataPck myObj,string ch) {
    stdout.printf("\t\t\tDP Sub by callback %s: Msg received:\n{\n%s}\n",ch,myObj.to_string("    "));
}
