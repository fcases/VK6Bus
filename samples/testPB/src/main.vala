using ProtocolBus;

int main (string[] args) {
    // Dominio
    var miaDom=new Domain(0);

    // Datos
    // Datos DataPck
    var miaData1=new DataPck();
    miaData1.a="_.::._";
    // Datos EndPointDef
    var miaData2=new EndPointDef(); 
    miaData2.Host="__localhost__";
    miaData2.Port=31;

    // Publicadores                                                                     
    var miaDataPkgPub=new GPub<DataPck>(miaDom);
    var miaEndPointPub=new GPub<EndPointDef>(miaDom);

    // Subscriptores ...
    // ... por derivacion
    var miaDPSubDerv=new DPSub(miaDom,"hola1");
    var miaEPSubDerv=new EPSub(miaDom,"hola1");
    // ... por callback
    var miaDPSubCbck=new GSub<DataPck>(miaDom,"hola2",OnDataReceivedDP);
    var miaEPSubCbck=new GSub<EndPointDef>(miaDom,"hola2",OnDataReceivedEP);

    var aux=""; var i=0;
    //  string[] channels={"hola1","hola2"};
    while( (aux=stdin.read_line() )!="q") {
        if(aux=="m") {
            uint8[] datoj1= {i++,2,3,4,5};
            miaData1.Data=new ByteArray.take(datoj1); 
            //  miaDataPkgPub.SendMsg("hola1",miaData1);
            //  miaDataPkgPub.SendMsg("hola2",miaData1);
            //  miaDataPkgPub.SendMsgToChannels(channels, miaData1);
            miaDataPkgPub.SendMsgToChannels({"hola1","hola2"}, miaData1);

            miaData2.Port++;
            //  miaEndPointPub.SendMsg("hola1",miaData2);
            //  miaEndPointPub.SendMsg("hola2",miaData2);
            //  miaEndPointPub.SendMsgToChannels(channels,miaData2);
            miaEndPointPub.SendMsgToChannels({"hola1","hola2"},miaData2);
        }
    };
    miaDom.Close();

    stdout.printf("fin...\n");
    return 0;
}
