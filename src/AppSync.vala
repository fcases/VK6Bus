using ProtocolBus;

namespace ProtocolBus {
    //////////////////////////////////////
    //  class WaitHandle
    //////////////////////////////////////
    public abstract class WaitHandle: Object {
        protected Cond miaKond;
        protected GLib.Mutex miaMut;
        protected bool estasSignalita;
        public static AppSync theSync = AppSync.GetInstance();

        private WaitHandle() {
            miaKond =Cond();
            miaMut= GLib.Mutex();
            estasSignalita=false;
        }

        public void Wait() {
            miaMut.lock();
                while(!estasSignalita) miaKond.wait(miaMut);
                //  estasSignalita=false;   // estas malautomata rekomencanta evento, ne automata!
            miaMut.unlock();
        }

        public bool WaitTime(int msec) {
            bool rezulto = false;
            miaMut.lock();
                if(!estasSignalita) 
                {
                    var end_time=get_monotonic_time() + msec*1000;
                    if( miaKond.wait_until(miaMut,end_time) )
                        rezulto=true;       // signalita
                    else 
                        rezulto=false;     // end_time
                } else rezulto=true;
            miaMut.unlock();

            return rezulto; 
        }

        public bool IsSignaled() {
            var aux=false;
            miaMut.lock();
                aux=estasSignalita;
            miaMut.unlock();
            return aux;
        }

        public static uint WaitAny(WaitHandle[] whs) {
            int rezulto = -1;
            var sync=whs[0];
            var aux=false;

            while( !( aux=sync.IsSignaled() ) ){
                if( whs[1].WaitTime(50) ) {
                    rezulto=1;
                    break;
                };
            }
            if(aux) rezulto=0;
            return rezulto;
        }
    }

    //////////////////////////////////////
    //  class ManualResetEvent
    //////////////////////////////////////
    public class ManualResetEvent: WaitHandle {
        public ManualResetEvent(){
            base();
        }

        public void Set() {
            miaMut.lock();
                estasSignalita=true;
                //  miaKond.@signal();
                miaKond.broadcast();
            miaMut.unlock();
        }

        public void Reset() {
            miaMut.lock();
                estasSignalita=false;
            miaMut.unlock();
        }

        public void Kill() {
            estasSignalita=true;
        }
    }

    //////////////////////////////////////
    //  class AppSync
    //////////////////////////////////////
    public class AppSync: ILogger {  // usa solo una unica traza, no hace falta derivar de ILogger, 
                                     // lo dejo de momento para debug, 
                                     // quitarlo, y si acaso usar GLib.Log.debug
        private static AppSync theSync;
        private ManualResetEvent appFinished = new ManualResetEvent();
        private bool finished = false;
        private List<Thread<void>> miListaT=new List<Thread<void>>(); 

        public static unowned AppSync GetInstance() {
            if( theSync==null ) 
                theSync= new AppSync();
            return theSync;
        }

        public ManualResetEvent GetFinishedWH() {
            return appFinished;
        }

        public void FinishApp() {
            LoggerTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD+"-->"+"Signaling the FINISH!!!!\n");
            finished = true;
            appFinished.Set();
            miListaT.reverse();
            foreach (Thread<void> t in miListaT) {
                t.join();
                miListaT.remove(t);
            }
            FinishLog();
        }

        public bool IsFinished() {
            return finished;
        }

        public void RegisterThread(Thread<void> t) {
            miListaT.append(t);
        }
    }
}



