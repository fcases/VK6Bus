using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus
{ 
    public class DictionaryEntry: Object {
        public string Key;
        public QueueMgr Value;
        public DictionaryEntry(string k, QueueMgr q) {Key=k;Value=q;}
    } 
    //  public errordomain ErrorDomain {
    //      DM
    //  }

    public sealed class Domain: ILogger {
        private AppSync theSync;
        private ArrayList<DictionaryEntry> myRegistry = new ArrayList<DictionaryEntry>();      
        private ArrayList<Transport> myTransports = new ArrayList<Transport>();      
        private int domainId;
        private AppConfig myAppCfg;
        private DomainCfg myDomainCfg;
        private bool bDirectDispacthToSubs = false;
        
        private StreamQueue upstrm;
        private StreamQueue downstrm;

        private signal  void EvMsgReceived(ArrayList<Msg> msgList);

        private bool bHasCipheringKey = false;
        private Ciphering myCipherDevice;

        public Domain(int domain) {
            Initialize(domain, BatchMode.INMEDIATE, 0);
        }

        public Domain.Batch(int domain, int bwt) {
            Initialize(domain, BatchMode.BATCH, bwt);
        }

        private void Initialize(int domain, BatchMode bm, int bwt) {
            try {
                domainId = domain;
                theSync = AppSync.GetInstance();

                myAppCfg=ReadConfigParams();
                if( myAppCfg==null ) { 
                    myTransports.add(new MCastTransp(this,"DefaultMCast"));
                }
                else {
                    InitializeLogTrace();          
                    myDomainCfg=GetDomainCfg();
                    if( myDomainCfg==null ) {
                        myTransports.add(new MCastTransp(this, "DefaultMCast"));
                    }
                    else {
                        ReadCypheringKey();
                        LoadTransports();
                        bDirectDispacthToSubs = myDomainCfg.DirectDispacthToSubs;
                        CreateCrossConnections();
                    }
                    var aux="";
                    if( myDomainCfg!=null ) aux=myDomainCfg.to_string("  ");
                    else aux="  Default values\n";
                    LoggerTrace(TraceLevel.TRACE,
                        Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+
                        "Config file read and loaded:\nDomain {\n"+
                        aux+"}\n");
                }

                if( bDirectDispacthToSubs ) {
                    upstrm = new StreamQueue.Started(this, StreamMode.UP,false);
                    EvMsgReceived.connect(upstrm.DispatchMsg);
                }
                else {
                    upstrm = new StreamQueue(this, StreamMode.UP);
                    EvMsgReceived.connect(upstrm.EnqueueMult);
                }

                if (bm == BatchMode.INMEDIATE)
                    downstrm = new StreamQueue(this, StreamMode.DOWN);
                else
                    downstrm = new StreamQueue.Full(this, StreamMode.DOWN, BatchMode.BATCH, bwt);

            }
            catch (Error err) {
                LoggerTraceWithErr(TraceLevel.ERROR, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+"no catch comment", err);
            }
        }

        public int GetDomainId() {
            return domainId;
        }

        public unowned ArrayList<Transport> GetTransports() {
            return myTransports;
        }

        public unowned ArrayList<DictionaryEntry> GetRegistry() {
            return myRegistry;
        }

        public void RegisterSubscriber(QueueMgr qm, string channel) {
            lock (myRegistry) {
                myRegistry.add(new DictionaryEntry(channel, qm));
            }
        }

        public void UnregisterSuscriber(QueueMgr qm, string channel) {
            lock (myRegistry) {
                myRegistry.foreach( (entry) => {
                    if( entry.Key==channel && entry.Value==qm )
                        myRegistry.remove(entry);
                    return true;
                });
            }
        }

        public void OnMsgReceived(ArrayList<Msg> msgList) {
            lock (upstrm)  {    // to prevent collissionnig of transport receiving threads.
                                // Not in enqueue (owns its lock) but in DispachToListeners.
                EvMsgReceived(msgList);  
            }
        }

        public bool SendMsg(Msg myMsg) {
            downstrm.Enqueue(myMsg);
            return true;
        }

        public void Close() {
            theSync.FinishApp();
        }

        internal AppConfig ReadConfigParams() {
            {
                FileStream stream= FileStream.open ("protocolBus.App.cfg", "r");
                if( stream==null ) return null;
            }
            PBusConfig_load_file_to_parse("protocolBus.App.cfg");
            var theAppCfg=new AppConfigText.from_text();
            
            return theAppCfg;
        }

        internal void InitializeLogTrace() {
            if( myAppCfg!=null )
                if( myAppCfg.ActivateTrace==true ) 
                    LoggerTraceOn(myAppCfg.TraceLevel);
        }

        internal DomainCfg GetDomainCfg() {
            int i = 0; bool found = false;

            foreach(DomainCfg d in myAppCfg.Domain) {
                if (d.Id == domainId) { found = true; break; }
                else i++;
            }
            if( !found ) { 
                // mi jam faris la new se gi donis null
                //  myTransports.add(new MCastTransp(this, "DefaultMCast")); 
                //  return new DomainCfg(); 
                return null; 
            }
            return myAppCfg.Domain.nth_data(i);
        }

        internal void LoadTransports() {
            if( myDomainCfg.ActivateDefaultTransport )
                myTransports.add(new MCastTransp(this,"DefaultMCast"));
            foreach(TransportDef t in myDomainCfg.Transport) {
                switch (t.DllImport) {   
                // "Default": MCast, BCast or UDPStar ////////////////////////////
                case "Default":
                    switch (t.TransportClass) {
                    case "Multicast":
                        myTransports.add(new MCastTransp.Extd(this, t.TransportName, t.MCastParams, t.ReceiveOwnMsgs));
                        break;
                    case "Broadcast":
                        myTransports.add(new BCastTransp(this,t.TransportName,t.BCastParams,t.ReceiveOwnMsgs));
                        break;
                    case "UDPStar":
                        myTransports.add(new UDPStar(this,t.TransportName, t.UDPStarParams, t.ReceiveOwnMsgs));
                        break;
                    case "Default":
                        myTransports.add(new MCastTransp.Extd(this, t.TransportName, t.MCastParams, t.ReceiveOwnMsgs));
                        break;
                    }
                    break;
                // other case: Load the dllimport assembly ////////////////////////////
                default: 
                    try {   
                        stdout.printf("%s",t.DllImport);
                        // The name of the assembly should equal to the namespace of the class.
                        //  Assembly assembly = Assembly.LoadFrom(t.DllImport + ".dll");
                        //  string fullTypeName = t.DllImport + "." + t.TransportClass;
                        //  Object[] aux = new Object[2] { (object)this, t.TransportName };
                        //  Transport AuxT = (Transport)assembly.CreateInstance(
                        //              fullTypeName, false, BindingFlags.CreateInstance,
                        //              null, aux, null, null);
                        //  myTransports.Add(AuxT);
                    }
                    catch (Error ex) {
                        LoggerTraceWithErr(TraceLevel.ERROR, "no catch comment", ex);
                    }
                    break;
                }
            }
        }

        internal void CreateCrossConnections() {
            var tl1=new ArrayList<Transport>();
            var tl2=new ArrayList<Transport>();

            if( myDomainCfg.CrossConnector==null ) return;
            CrossConnectorDef XConn = myDomainCfg.CrossConnector;
            if( XConn.Transport.length()<2 ) return;

            foreach( Transport t in myTransports) {
                foreach( string s in XConn.Transport) {
                    if( s != t.Name ) {
                        tl1.add(t); 
                        tl2.add(t); 
                        break;
                    }
                }   
            }
            //  if( tl1.Count>1 )
            foreach(Transport t1 in tl1)
                foreach(Transport t2 in tl2)
                    if( t1.Name!=t2.Name ) t1.CrossConnect(t2);

            return;
        }

        internal void ReadCypheringKey() {
            //  string pBusKey_path=Environment.GetEnvironmentVariable("PBUS_KEY_PATH");
            if( myDomainCfg.KeyFile == "" ) return;

            string pBusKey_path="./keys/";
            string theKeyFile = pBusKey_path+ myDomainCfg.KeyFile;

            File file = File.new_for_path (theKeyFile);
            if( file.query_exists () != true ) {
                LoggerTrace(TraceLevel.ERROR,Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+
                            "Cipher Key file does not exists, no ciphering will be used");
                return;
            }

            FileStream stream;
            try {
                stream= FileStream.open (theKeyFile, "r");
                stream.seek (0, FileSeek.END);
                var size = stream.tell ();
                uint8[] data = new uint8[size];
                stream.rewind ();
                size_t read = stream.read (data);
    
                var decBuffer=new DecodeBuffer(data);
                KeyRegistry kr=new KeyRegistry.from_data(decBuffer);
    
                myCipherDevice = new Ciphering(kr.AESKey.data,kr.AESIV.data);
                HasCipheringKey = true;

                LoggerTrace(TraceLevel.TRACE,Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+"Cipher Key file loaded");
            } 
            catch(IOError err) {
                LoggerTrace(TraceLevel.ERROR,Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+"No Cipher Key file or error");
                return;
            }

            return;
        }

        public bool HasCipheringKey {
            get { return bHasCipheringKey; }
            set { bHasCipheringKey = value; }
        }

        public Bytes Encrypt(Bytes RedBytes) {
            return myCipherDevice.Encrypt(RedBytes);
        }

        public Bytes Decrypt(Bytes BlackBytes) {
            return myCipherDevice.Decrypt(BlackBytes);
        }
   }
}

