using Gee;
using Protobuf;
using ProtocolBus;

namespace ProtocolBus
{
    public abstract class Transport: ILogger {
        protected Domain myDomain;
        protected string myName;
        protected Thread<void> myThread;
        protected bool isStarted = false;
        protected AppSync theSync = AppSync.GetInstance();
        protected bool ReceiveOwnMessages = false;

        public signal Bytes Encrypt(Bytes bytes);
        public signal Bytes Decrypt(Bytes bytes);
        public signal bool SendPckToXConnectedTransports(Packet myPck);

        protected Transport(Domain domain,string name) {
            myDomain = domain;
            myName = name;
            if( myDomain.HasCipheringKey ) {
                Encrypt.connect(myDomain.Encrypt);
                Decrypt.connect(myDomain.Decrypt);
            }
            else{
                Encrypt.connect( (b) => {return b;} );
                Decrypt.connect( (b) => {return b;} );
            }

        }

        public bool IsStarted {
            get{ return isStarted; }
            set{ isStarted=value;  }
        }

        public string Name {
            get { return myName; }
            set { myName = value; }
        }

        public void StartMainLoop() {
            if( !isStarted )
                myThread = new Thread<void>("ML_"+Name, MainLoop);
            isStarted = true;
            theSync.RegisterThread(myThread);
        }

        protected bool ParseAndEnqueue(Bytes data) {
            Bytes RedBytes = Decrypt(data);

            try {
                var decBuffer=new DecodeBuffer(RedBytes.get_data());
                var myPacket=new Packet.from_data(decBuffer,data.length);
                SendPckToXConnectedTransports(myPacket);
                var msgList = new ArrayList<Msg>();
                myPacket.messages.foreach ((msg) => {
                    msgList.add(msg);
                    myPacket.messages.remove(msg);
                });                
                LoggerTrace(TraceLevel.TRACE, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                    "Recive from wire - "+this.get_type().name()+
                    msgList.size.to_string());
                myDomain.OnMsgReceived(msgList);
            }
            catch (IOError e) {
                LoggerTraceWithErr(TraceLevel.ERROR, Log.FILE+": "+Log.LINE.to_string()+", "+Log.METHOD+"-->"+ e.message,e);
                return false;
            }
            return true;
        }

        public bool SendPck(Packet myPck) {
            Bytes BlackBytes;

			var encBuffer = new EncodeBuffer();
			myPck.encode (encBuffer);
            BlackBytes = Encrypt(new Bytes.take(encBuffer.data));

            return SendBytes(BlackBytes);
        }

        public void CrossConnect(Transport t) {
            SendPckToXConnectedTransports.connect(t.SendPck);
            // por eviti senfinan buklon:
            ReceiveOwnMessages=false;
        }

        public abstract bool SendBytes(Bytes data);
        public abstract void MainLoop();
        
        public bool is4NumericAddress(string texto) {
            // difini la ŝablonon (patrón) regex: ^[0-9.]+$
            GLib.Regex regex = new GLib.Regex("^[0-9.]+$");
            
            // Kontrolu ĉu la teksto kongruas kun la ŝablono
            return regex.match(texto, 0);
        }

        public InetAddress GetLocalAddress(string localaddres) {
            InetAddress aux;
            switch(localaddres) {
                case "Any": case "any":
                    aux = new InetAddress.from_string ("0.0.0.0");
                    break;
                case "Loopback": case "loopback":
                    aux = new InetAddress.from_string ("127.0.0.1");
                    break;
                default:
                    if( is4NumericAddress(localaddres) ) {
                        aux = new InetAddress.from_string (localaddres);
                    }
                    else {
                        Resolver resolver = Resolver.get_default ();
                        GLib.List<InetAddress> addresses = resolver.lookup_by_name (localaddres, null);
                        aux=addresses.nth_data(0);
                    }
                    break;
            }
            return aux;
       }
    }
}
