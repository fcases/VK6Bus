using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus
{
    internal class UDPStar : Transport {
        //Socket creation, regular UDP socket
        private Socket SendingSocket;
        private Socket ListeningSocket;

        private int SendBuffer = 1048576;
        private int ReceiveBuffer = 1048576;

        private string LocalStrAddr = "Any";
        private InetAddress LocalAddr;
        private InetSocketAddress LocalSoxAddr;
        private uint16 LocalPort= 50000;
        private uint16 SendingPort= 40000;

        private ArrayList<InetSocketAddress> IPDestList = new ArrayList<InetSocketAddress>();

        public UDPStar(Domain domain,string name,UDPStarDefConfig usc,bool rom) {
            base(domain,name);

            SendingSocket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            ListeningSocket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);

            LocalStrAddr = usc.LocalAddress;
            LocalPort = (uint16)usc.Port;
            ReceiveOwnMessages = rom;

            foreach( ProtocolBus.EndPointDef ep in usc.EndPoint)
                IPDestList.add(new InetSocketAddress(GetLocalAddress(ep.Host), (uint16)ep.Port));

            InitializeSocket(SendingSocket, true);
            InitializeSocket(ListeningSocket, false);

            StartMainLoop();
        }

        public void InitializeSocket(Socket theSocket, bool IsSendingSocket) {
            try {
                uint16 localport;

                if (IsSendingSocket) 
                    localport = SendingPort = 50000 + (Posix.getpid() % 14000);
                else
                    localport = LocalPort;

                LocalAddr=GetLocalAddress(LocalStrAddr);
                LocalSoxAddr = new InetSocketAddress(LocalAddr, localport);

                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_RCVBUF,ReceiveBuffer);
                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_SNDBUF,SendBuffer);
                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_REUSEADDR,1);

                theSocket.bind(LocalSoxAddr,true);  
            }
            catch (Error err) {
                LoggerTraceWithErr(TraceLevel.ERROR, 
                                    Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                                    "no catch comment",err);
            }
        }

        public override bool SendBytes(Bytes data) {
            if (data.length > 64000) {
                LoggerTrace(TraceLevel.ERROR, 
                            Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                            "Serialized packet bigger than 60Kb .. dismissed");
                return false;
            }

            try {
                foreach(InetSocketAddress insa in IPDestList) 
                    SendingSocket.send_to(insa,data.get_data());
            } 
            catch (Error err) {
                LoggerTraceWithErr(TraceLevel.ERROR,
                                    Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                                    "Error in SendPck. ",err);
                return false;
            }

            return true;
        }

        public override  void MainLoop() {
            isStarted = true;
            LoggerTrace(TraceLevel.INFO, 
                        Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                        "Transp. Mainloop started -"+this.get_type().name());
            var kancel= new Cancellable();

            var ctx=new MainContext();
            var loop=new GLib.MainLoop(ctx);

            Thread<void> aux=new Thread<void>("ML_aux_"+Name, 
                ()=> {
                    theSync.GetFinishedWH().Wait();
                    LoggerTrace(TraceLevel.INFO,
                                Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                                "Transp. auxLoop finished -"+this.get_type().name());
                    //  stdout.printf("\n%s: inner_auxLoop Thread finished - ",this.get_type().name());
                    kancel.cancel();
                    loop.quit();
                });

            var source = ListeningSocket.create_source (IOCondition.IN);
            source.set_callback ((s, cond) => {
                Receive(kancel);
                return true;
            });
            source.attach (ctx);

            loop.run ();

            LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+" Transp. Mainloop finished -"+this.get_type().name());
            //  stdout.printf("\n%s\n",myName+": "+"Thread finished - "+this.get_type().name());
        }

        private void Receive(Cancellable k) {
            SocketAddress aux;
            uint8[] bytes=new uint8[64000];
            uint64 BytesRead;

            try {
                BytesRead=ListeningSocket.receive_from(out aux,bytes,k);
                //  stdout.printf("...%s ...\n",BytesRead.to_string());
                if( BytesRead>0 ) {
                    var aux2=(InetSocketAddress)aux;
                    if( (LocalPort == (aux2.port) && !ReceiveOwnMessages) )
                        LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"
                            +Name+": "+" Dissmissing own message on port "+aux2.port.to_string()+" "
                            +this.get_type().name());
                    else {
                        ParseAndEnqueue(new Bytes.take(bytes[0:BytesRead]));
                    }
                }
                //  stdout.printf("\n%s\nReceive: Thread finished - "+this.get_type().name());
            }
            catch (IOError err) {
                LoggerTraceWithErr(TraceLevel.ERROR, 
                                    Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                                    "error or cancelled",err);
            }
        }
    }
}
