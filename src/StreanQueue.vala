using Gee;
using ProtocolBus;


namespace ProtocolBus
{
    public enum StreamMode { UP, DOWN }

    internal class StreamQueue : QueueMgr {
        ArrayList<DictionaryEntry> myObjsSubs;
        ArrayList<Transport> myObjsTrans;
        Domain myDomain;

        private StreamMode streamMode;
        private AppSync theSync = AppSync.GetInstance();

        private signal void DoDispatchMsg(ArrayList<Msg> msgList);

        public StreamQueue(Domain domain, StreamMode streammode) {
            InitializeStream(domain, streammode,true);
        }

        public StreamQueue.Started(Domain domain, StreamMode streammode, bool bBeginStarted) {
            InitializeStream(domain, streammode, bBeginStarted);
        }

        public StreamQueue.Full(Domain domain, StreamMode streammode, BatchMode bm, int bwt) {
            base.Extd(bm,bwt);
            InitializeStream(domain,streammode,true);
        }

        private void InitializeStream(Domain domain, StreamMode streammode, bool bBeginStarted) {
            streamMode = streammode;
            if( streamMode==StreamMode.UP ) {
                Name="UP_SQ";
                myObjsSubs = domain.GetRegistry();
                DoDispatchMsg.connect(DispatchMsgToListeners);
            }
            else {
                Name="DOWN_SQ";
                myObjsTrans = domain.GetTransports();
                DoDispatchMsg.connect(DispatchMsgToTransports);
            }
            myDomain=domain;

            if( bBeginStarted ) StartMainLoop();
        }

        public override void DispatchMsg(ArrayList<Msg> msgList) {
            DoDispatchMsg(msgList);
        }

        public void DispatchMsgToTransports(ArrayList<Msg> msgList) {
            Packet myPck=new Packet();

            foreach(Msg msg in msgList) myPck.messages.append(msg);

            LoggerTrace(TraceLevel.TRACE, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                            "Ready to send to Transports - "+this.get_type().name()+
                            "\t\t"+msgList.size.to_string());

            foreach(Transport tp in myObjsTrans) tp.SendPck(myPck);
        }

        public void DispatchMsgToListeners(ArrayList<Msg> msgList) {
            LoggerTrace(TraceLevel.TRACE, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+
                            "Ready to send to Listeners - "+this.get_type().name()+
                            "\t\t"+msgList.size.to_string());

            foreach(Msg msg in msgList) {
                uint size = msg.channels.length();

                for(int i=0; i<size; i++) {
                    string OneChannel = msg.channels.nth_data(i);
                    foreach(DictionaryEntry de in myObjsSubs) {
                        if( de.Key == OneChannel )
                            de.Value.Enqueue(msg);
                    }
                }
                if( theSync.IsFinished() ) return;
            }
        }
    }
}

