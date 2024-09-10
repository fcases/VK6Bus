using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus {
    internal class BCastTransp : MCastTransp {
        public BCastTransp(Domain domain, string name, BCastDefConfig bcd, bool rom) {
            base.Broadcast(domain, name, bcd, rom);
        }
    }

    internal class MCastTransp: Transport {
        private Socket SendingSocket;
        private Socket ListeningSocket;

        private int TTL = 1;
        private int SendBuffer = 134217727;
        private int ReceiveBuffer = 134217727;

        private bool isBroadcast = false;

        private string LocalStrAddr = "Any";
        private InetAddress LocalAddr;
        private InetSocketAddress LocalSoxAddr;
        private int LocalPort= 50000;

        string MCastStrAddr = "239.255.0.1";
        private InetAddress MCastAddr;
        private InetSocketAddress MCastSoxAddr;
        private uint16 MCastPort = 40069;

        public MCastTransp(Domain domain, string name) {
            base(domain,name);
            Initialize();
        }

        public MCastTransp.Extd(Domain domain,string name, MCastDefConfig mcd, bool rom) {
            base(domain, name);
            MCastStrAddr = mcd.MCastAddress;
            MCastPort = (uint16)mcd.Port;
            SendBuffer = mcd.SendBuffer;
            ReceiveBuffer = mcd.ReceiveBuffer;
            TTL = mcd.TTL;
            LocalStrAddr = mcd.LocalAddress;
            ReceiveOwnMessages = rom;
            
            Initialize();
        }

        public MCastTransp.Broadcast(Domain domain,string name, BCastDefConfig bcd, bool rom) {
            base(domain,name);
            MCastStrAddr = bcd.BCastAddress;
            MCastPort = (uint16)bcd.Port;
            SendBuffer = bcd.SendBuffer;
            ReceiveBuffer = bcd.ReceiveBuffer;
            isBroadcast = true;
            LocalStrAddr = bcd.LocalAddress;
            ReceiveOwnMessages = rom;

            Initialize();
        }

        public void Initialize() {
            SendingSocket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
            ListeningSocket = new Socket(SocketFamily.IPV4, SocketType.DATAGRAM, SocketProtocol.UDP);
    
            InitializeSocket(SendingSocket, true);
            InitializeSocket(ListeningSocket, false);

            StartMainLoop();
        }

        public void InitializeSocket(Socket theSocket, bool IsSendingSocket) {
            try {
                uint16 localport;

                MCastAddr=new InetAddress.from_string (MCastStrAddr);
                if (IsSendingSocket) {
                    LocalPort = localport = 50000 + (Posix.getpid() % 14000);
                    MCastSoxAddr=new InetSocketAddress(MCastAddr,MCastPort);
                }
                else
                    localport = MCastPort;

                LocalAddr=GetLocalAddress(LocalStrAddr);
                LocalSoxAddr = new InetSocketAddress(LocalAddr, localport);

                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_RCVBUF,ReceiveBuffer);
                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_SNDBUF,SendBuffer);
                theSocket.set_option(Linux.Socket.SOL_SOCKET,Linux.Socket.SO_REUSEADDR,1);

                theSocket.bind(LocalSoxAddr,true);  
                 // gi devas esti ligita antaŭ ol aliĝi al la grupo
                
                if (!isBroadcast) {
                    theSocket.set_multicast_loopback(true);
                    //  theSocket.multicast_loopback=true;

                    //set multicast flags, sending flags - TimeToLive (TTL)
                    // 0 - LAN, 1 - Single Router Hop, 2 - Two Router Hops...
                    theSocket.set_multicast_ttl(TTL);
                    //  theSocket.multicast_ttl=TTL;

                    theSocket.join_multicast_group(MCastAddr, false, null);
                }
                else
                    theSocket.set_broadcast(true);
            }
            catch (Error ex) {
                LoggerTraceWithErr(TraceLevel.ERROR, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+"no catch comment",ex);
            }
        }

        public override bool SendBytes(Bytes data) {
            if (data.length > 64000) {
                LoggerTrace(TraceLevel.ERROR, "Serialized packet bigger than 60Kb .. dismissed");
                return false;
            }

            try {
                SendingSocket.send_to(MCastSoxAddr,data.get_data());
            }
            catch (Error ex) {
                LoggerTraceWithErr(TraceLevel.ERROR,"Error in SendPck. ",ex);
                return false;
            }

             return true;
        }

        public override  void MainLoop() {
            isStarted = true;
            LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+" Transp. Mainloop started -"+this.get_type().name());
            var kancel= new Cancellable();

            var ctx=new MainContext();
            var loop=new GLib.MainLoop(ctx);

            Thread<void> aux=new Thread<void>("ML_aux_"+Name, 
                ()=> {
                    theSync.GetFinishedWH().Wait();
                    LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+" Transp. auxLoop finished -"+this.get_type().name());
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
        }

        private void Receive(Cancellable k) {
            SocketAddress aux;
            uint8[] bytes=new uint8[64000];
            uint64 BytesRead;

            try {
                BytesRead=ListeningSocket.receive_from(out aux,bytes,k);
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
            }
            catch (IOError err) {
                LoggerTraceWithErr(TraceLevel.ERROR, 
                                    Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                                    "error or cancelled",err);
            }
        }
    }
}

