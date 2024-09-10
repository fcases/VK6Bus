using  ProtocolBus;

namespace ProtocolBus {

    public enum TraceLevel { 
        ERROR =0,
        WARNING, 
        INFO,
        TRACE, 
    }

    //////////////////////////////////////
    //  class Pair
    //////////////////////////////////////
    public class Pair {
        public TraceLevel tl;
        public string trace;

        public Pair(TraceLevel atl, string atrace) {
            tl = atl;
            trace = atrace;
        }
    }

    //////////////////////////////////////
    //  class ILogger
    //////////////////////////////////////
    public abstract class ILogger: Object {

        public void LoggerTrace(TraceLevel tl, string trace) {
            var aux_trace=ProcessTrace(trace);
            Logger.Trace(tl, aux_trace);
        }

        public void LoggerTraceWithErr(TraceLevel tl, string trace, GLib.Error ex) {
            var aux_trace = ProcessTrace(trace);
            Logger.TraceWithErr(tl, aux_trace, ex);
        }

        private string ProcessTrace(string trace){
            //  var aux_trace = this.get_type().name() + "\n\t" + trace;
            string[] aux;
            var aux_trace="";
            if( trace.contains("-->") ) {
                aux=trace.split("-->");
                aux_trace = aux[0] + "\n\t" + aux[1];
            }
            else aux_trace = trace;
    
            return aux_trace;
        }

        public static void LoggerTraceOn(TraceLevel tl) {
            Logger.TraceOn(tl);
        } 

        public static void FinishLog() {
            Logger.FinnishLog();
            return;
        }

    }

    //////////////////////////////////////
    //  class Logger
    //////////////////////////////////////
    internal sealed class Logger: Object {
        private static Logger instance = null;
        private string fileName = new DateTime.now_local().format("%Y-%m-%d_%H_%M_%S") + ".log";
        private AsyncQueue<Pair> myQueue = new AsyncQueue<Pair>();
        private FileStream arch;
        private TraceLevel theTL = TraceLevel.ERROR;

        private bool isStarted = false;
        private Thread<void> myThread;
        private ManualResetEvent theFinishedAppEvt = new ManualResetEvent();
        private ManualResetEvent elemsOnQueueEvt = new ManualResetEvent();

        private bool isOwnTrace = false;

        public WaitHandle[] ContinueWH;

        internal static void TraceOn(TraceLevel tl) {
            if (instance == null) {
                instance = new Logger(tl);
                instance.isOwnTrace = true;
                instance.DoTrace(TraceLevel.INFO, instance.PrepareTrace(TraceLevel.TRACE, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD + "\n\tLogger started"));

                if (!instance.isStarted) {
                    instance.myThread = new Thread<void>("ML_Logger", instance.MainLloop);
                }
            }
        }

        ~Logger() {
        }

        private Logger(TraceLevel tl) {
            arch = FileStream.open(fileName, "w");

            //  Environment.set_variable ("G_MESSAGES_DEBUG", "LEVEL_DEBUG", true);
            //  Log.set_default_handler(
            //      (domain, level, message) => {
            //          domain = "My.Domain";
            //          string [] aux_level=level.to_string().split("_");
            //          //  level = GLib.LogLevelFlags.LEVEL_INFO;
            //          arch.printf("%s:\t%s\n\t\t%s\n", 
            //                  aux_level[3], new DateTime.now_local().format("D %Y-%m-%d - T %H:%M:%S.%f"), 
            //                  ProcessTrace(message));
            //      }
            //  );


            if (tl != TraceLevel.TRACE && tl != TraceLevel.INFO && tl != TraceLevel.WARNING && tl != TraceLevel.ERROR) {
                theTL = TraceLevel.ERROR;
            } else {
                theTL = tl;
            }
            
            ContinueWH = new WaitHandle[] { theFinishedAppEvt, elemsOnQueueEvt };
        }

        //  public string ProcessTrace(string trace){
        //      //  var aux_trace = this.get_type().name() + "\n\t" + trace;
        //      string[] aux;
        //      var aux_trace="";
        //      if( trace.contains("-->") ) {
        //          aux=trace.split("-->");
        //          aux_trace = aux[0] + "\n\t\t" + aux[1];
        //      }
        //      else
        //          aux_trace =  trace;
            
        //      return aux_trace;
        //  }

        private void MainLloop() {
            isStarted = true;
            isOwnTrace = true;
            DoTrace(TraceLevel.INFO, PrepareTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD + "\n\tMainLoop started"));

            while( WaitHandle.WaitAny(ContinueWH) == 1 ) // Wait returns 0 or 1, depending on the signal
            {                                            // 0: theFinishedAppEvt; 1: elemsOnQueueEvt
                lock(myQueue) {
                    int len=myQueue.length();
                    while( len>0 ) {
                        var aux = myQueue.pop();
                        DoTrace(aux.tl, aux.trace);
                        myQueue.remove(aux);
                        len=myQueue.length();
                    }
                    if( len==0 ) elemsOnQueueEvt.Reset();
                }
                arch.flush();
            }
            isStarted = false;

            DoTrace(TraceLevel.INFO, PrepareTrace(TraceLevel.INFO, Log.FILE+", L-"+Log.LINE.to_string()+": "+Log.METHOD + "\n\tLogger: Thread finished - "+this.get_type().name()));
            //  stdout.printf("Logger: Thread finished - logger\n");
        }

        internal static void Trace(TraceLevel tl, string trace) {
            if (instance != null) {
                var aux_trace = instance.PrepareTrace(tl, trace);
                var p = new Pair(tl, aux_trace);
                lock(instance.myQueue) {
                    instance.myQueue.push(p);
                }
                instance.elemsOnQueueEvt.Set();
            }
        }

        public static void TraceWithErr(TraceLevel tl, string trace, GLib.Error ex) {
            if (instance != null) {
                var aux_trace = instance.PrepareTraceWithErr(tl, trace,ex);
                var p = new Pair(tl, aux_trace);
                lock(instance.myQueue) {
                    instance.myQueue.push(p);
                }
                instance.elemsOnQueueEvt.Set();
            }
        }

        private void DoTrace(TraceLevel tl, string trace) {
            switch (tl) {
            case TraceLevel.TRACE:
                if( TraceLevel.TRACE <= theTL ) {
                    arch.puts("TRACE:\t" + trace + "\n");
                }
                break;
            case TraceLevel.INFO:
                if( TraceLevel.INFO <= theTL ) {
                    arch.puts("INFO:\t" + trace + "\n");
                }
                break;
            case TraceLevel.WARNING:
                if( TraceLevel.WARNING <= theTL ) {
                    arch.puts("WARN:\t" + trace + "\n");
                }
                break;
            case TraceLevel.ERROR:
                if(TraceLevel.ERROR <= theTL ) {
                    arch.puts("ERROR:\t" + trace + "\n");
                }
                break;
            }
            arch.flush();
        }

        private string PrepareTrace(TraceLevel tl, string trace) {
            //  var stack_trace = new StackTrace(null);
            //  var stack_frames = stack_trace.get_frames();
            //  var call_stack = stack_frames[isOwnTrace ? 1 : 3].get_method_name();
            //  isOwnTrace = false;
            //  string aux = "";
            string the_trace = "";

            switch (tl) {
                case TraceLevel.TRACE:
                    //  the_trace += (call_stack + " --> " + trace);
                    the_trace += trace;
                    break;
                case TraceLevel.INFO:
                    //  the_trace += (call_stack + " --> " + trace);
                    the_trace += trace;
                    break;
                case TraceLevel.WARNING:
                    //  the_trace += (call_stack + " --> " + trace);
                    the_trace += trace;
                    break;
                case TraceLevel.ERROR:
                    //  foreach (var stack_frame in stack_frames) {
                    //      aux += stack_frame.get_method_name();
                    //  }
                    //  the_trace += (call_stack + " --> " + trace + "\n\n\t" + aux);
                    the_trace +=  trace + "\n\n\t";
                    break;
            }
            //  the_trace = new DateTime.now_utc().format("%s") + "\n\t" + Environment.get_prgname() + "_" + Thread.self().get_id() + " - " + the_trace;
            string log_timestamp = new DateTime.now_local().format("%Y-%m-%d T %H:%M:%S.%f") ;
            the_trace = log_timestamp + "\n\t" +  the_trace;
            return the_trace;
        }

        private string PrepareTraceWithErr(TraceLevel tl, string trace, GLib.Error ex) {
            //  var stack_trace = new StackTrace(null);
            //  var stack_frames = stack_trace.get_frames();
            //  var call_stack = stack_frames[isOwnTrace ? 1 : 3].get_method_name();
            //  isOwnTrace = false;
            string the_trace = "";

            if (ex == null) {
                return PrepareTraceWithErr(tl, trace,ex);
            }

            switch (tl) {
                case TraceLevel.TRACE:
                    //  the_trace += (call_stack + " --> " + trace);
                    the_trace += ( trace+ "\n\n\t" + ex.message);
                    break;
                case TraceLevel.INFO:
                    //  the_trace += (call_stack + " --> " + trace);
                    the_trace += ( trace+ "\n\n\t" + ex.message);
                    break;
                case TraceLevel.WARNING:
                    //  the_trace += (call_stack + " --> " + trace + "\n\n\t" + ex.message);
                    the_trace += ( trace + "\n\n\t" + ex.message);
                    break;
                case TraceLevel.ERROR:
                    //  the_trace += (call_stack + " --> " + trace + "\n\t" + ex.message + "\n\t" + ex.stack_trace);
                    the_trace += ( trace + "\n\t" + ex.message + "\n\t" + ex.message);
                    break;
            }
            //  the_trace = new DateTime.now_utc().format("%s") + "\n\t" + Environment.get_prgname() + "_" + Thread.self().get_id() + " - " + the_trace;
            string log_timestamp = new DateTime.now_local().format("%Y-%m-%d T %H:%M:%S.%f") ;
            the_trace = log_timestamp + "\n\t" +  the_trace;
            return the_trace;
        }

        internal static void FinnishLog() {
            if (instance != null) {
                int a=0;
                while( instance.myQueue.length() >0 && (a++)<50 ) {
                    instance.elemsOnQueueEvt.Set();
                    Thread.usleep(50000);
                }
                instance.theFinishedAppEvt.Set();
                Thread.usleep(150000);
            }
            return;
        }
    }
}


