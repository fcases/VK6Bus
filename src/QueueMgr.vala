using Gee;
using  ProtocolBus;

namespace ProtocolBus {
    //  public errordomain ErrorMainLoop {
    //      ML
    //  }

    public enum BatchMode { INMEDIATE, BATCH }

    public abstract class QueueMgr : ILogger {
        private AsyncQueue<Msg> myQueue = new AsyncQueue<Msg>();

        private bool isStarted = false;
        private Thread<void> myThread;
        private AppSync theSync = AppSync.GetInstance();
        private ManualResetEvent theFinishedAppEvt = AppSync.GetInstance().GetFinishedWH();
        private ManualResetEvent elemsOnQueueEvt = new ManualResetEvent();

        public WaitHandle[] ContinueWH;

        BatchMode batchMode = BatchMode.INMEDIATE;
        int batchWaitTime = 0;
        protected string Name="_";

        protected QueueMgr(string nomo="_") {
            InitializeQueue(nomo);
        }

        protected QueueMgr.Extd(BatchMode bm, int bwt,string nomo="_") {
            InitializeQueue(nomo);
            if( bm==BatchMode.BATCH ) {
                batchMode = BatchMode.BATCH;
                batchWaitTime = bwt;
            }
        }

        protected QueueMgr.Started(bool bBeginStarted,string nomo="_") {
            InitializeQueue(nomo);
            batchMode = BatchMode.INMEDIATE;
            if( bBeginStarted ) StartMainLoop();
        }

        protected QueueMgr.Full(bool bBeginStarted, BatchMode bm, int bwt,string nomo="_") {
            InitializeQueue(nomo);
            if( bm==BatchMode.BATCH ) {
                batchMode = BatchMode.BATCH;
                batchWaitTime = bwt;
            }
            if( bBeginStarted ) StartMainLoop();
        }
        
        protected void InitializeQueue(string nomo) {
            Name=nomo;
            ContinueWH = new WaitHandle[] { theFinishedAppEvt, elemsOnQueueEvt };
        }

        public void StartMainLoop() {
            if( !isStarted ) {
                myThread = new Thread<void>(Name+"ML", MainLoop);
                theSync.RegisterThread(myThread);
            }
        }

        public void Enqueue(Msg myMsg) {
            if( !isStarted ) return; // Don't let subscribers to enqueue unless 
                                     // start_main_loop has been called.
            lock(myQueue) {
                myQueue.push(myMsg);
            }
            elemsOnQueueEvt.Set();
        }

        public void EnqueueMult(ArrayList<Msg> msgList) {
            if( !isStarted ) return; // Don't let subscribers to enqueue unless 
                                     // start_main_loop has been called.
            lock(myQueue) {
                foreach (Msg msg in msgList) {
                    myQueue.push(msg);
                }
            }
            elemsOnQueueEvt.Set();
        }

        private void MainLoop() {
            isStarted = true;
            var myMsgList = new ArrayList<Msg>();

            LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+"Start Mainloop-"+this.get_type().name());

            while( WaitHandle.WaitAny(ContinueWH)==1 ) { 
                int i = 0;                              // Wait returns 0 or 1, depending on the signal
                lock(myQueue) {                         // 0: theFinishedAppEvent; 1: ElementsOnQueue
                    while (myQueue.length() > 0 && i < 500) {
                        var aux=myQueue.pop();
                        myMsgList.add(aux);
                        myQueue.remove(aux);
                        i++;
                    }
                    if (myQueue.length() == 0)  elemsOnQueueEvt.Reset();
                }

                DispatchMsg(myMsgList);
                myMsgList.clear();
                LoggerTrace(TraceLevel.TRACE, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+"Message dispached - "+this.get_type().name());

                if( batchMode == BatchMode.BATCH && !theSync.IsFinished() ) {
                    theFinishedAppEvt.WaitTime(batchWaitTime);
                }
            }
            isStarted = false;

            LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+Name+": "+"Thread finished - "+this.get_type().name());
        }

        public abstract void DispatchMsg(ArrayList<Msg> msgList);
    }
}