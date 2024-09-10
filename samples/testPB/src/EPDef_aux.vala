using ProtocolBus;

public class EPSub: GSub<EndPointDef>
{
    public EPSub(Domain domain,string theChannel) {
        base(domain,theChannel);
    }
    public override void OnDataReceived(EndPointDef myObj) {
        stdout.printf("\t\t\tEP Sub by override %s: Msg received:\n{\n%s}\n",GetChannel(),myObj.to_string("    "));
    }
}

void OnDataReceivedEP(EndPointDef myObj,string ch) {
    stdout.printf("\t\t\tEP Sub by callback %s: Msg received:\n{\n%s}\n",ch,myObj.to_string("    "));
}
