namespace ProtocolBus {
    const string str_pattern="\\[|\\]|#.*|[0-9a-zA-Z_'.'@](?>[0-9a-zA-Z_'.'@+-]*)|\\{|\\}";
    Regex pattern;  
    string int_text;
    MatchInfo my_match ; 
    string value;
    string token;

    bool PBusConfig_load_file_to_parse(string file) {
        token = value = int_text = "";
        FileStream fich= FileStream.open (file, "r");
        var local_int_str="";
        if( fich != null) {
            while( !fich.eof() )  {
                local_int_str += fich.read_line()+"\n";
            }
        }
        int_text=PBusConfig_remove_comments(local_int_str);
        pattern=new Regex(str_pattern);                   
        pattern.match(int_text,0,out my_match);

        if( my_match==null ) return false;
        return true;
    }

    void PBusConfig_load_text(string teksto) {
        token = value = int_text = "";
        int_text=PBusConfig_remove_comments(teksto);
        pattern=new Regex(str_pattern);                    
        pattern.match(int_text,0,out my_match);
    }

    string PBusConfig_remove_comments(string teksto) {
        Regex komentoj = new Regex("#.*", 0);
        var fina_teksto= komentoj.replace(teksto,teksto.length,0, "");
        return fina_teksto;
    }

    public class AppConfigText : AppConfig {

        public AppConfigText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "ActivateTrace":
                    bool.try_parse(value, out this.ActivateTrace);
                    break;
                case "TraceLevel":
                    try {
                        this.TraceLevel=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "Domain":
                    my_match.next();
                    var domain = new DomainCfgText.from_text();
                    this.Domain.append(domain);
                    break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino) my_match.next();
            }
        }
    }

    public class DomainCfgText : DomainCfg {

        public DomainCfgText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "Id":
                    try {
                        this.Id=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "ActivateDefaultTransport":
                    bool.try_parse(value, out this.ActivateDefaultTransport);
                    break;
                case "DirectDispacthToSubs":
                    bool.try_parse(value, out this.DirectDispacthToSubs);
                    break;
                case "KeyFile":
                    this.KeyFile=value.dup();
                    break;
                case "Transport":
                    my_match.next();    
                    var transport=new TransportDefText.from_text();
                    this.Transport.append(transport);
                    break;
                case "CrossConnector":
                    my_match.next();    
                    var cross = new CrossConnectorDefText.from_text();
                    this.CrossConnector=cross;
                    break;
                case "}":
                    fino=true;
                    break;
                }
                
                if( !fino) my_match.next();
            }
        }
    }

    public class TransportDefText : TransportDef {

        public TransportDefText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "TransportName":
                    this.TransportName=value.dup();
                    break;
                case "DllImport":
                    this.DllImport=value.dup();
                    break;
                case "TransportClass":
                    this.TransportClass=value.dup();
                    break;
                case "ReceiveOwnMsgs":
                    bool.try_parse(value, out this.ReceiveOwnMsgs);
                    break;
                case "MCastParams":
                    my_match.next();
                    var mcast = new MCastDefConfigText.from_text();
                    this.MCastParams=mcast;
                    break;
                case "BCastParams":
                    my_match.next();
                    var bcast = new BCastDefConfigText.from_text();
                    this.BCastParams=bcast;
                    break;
                case "UDPStarParams":
                    my_match.next();
                    var start = new UDPStarDefConfigText.from_text();
                    this.UDPStarParams=start;
                    break;
                case "[":
                    my_match.next(); my_match.next(); my_match.next();
                    new ExtensionText.from_text();
                    break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino) my_match.next();
            }
        }
    }

    public class MCastDefConfigText : MCastDefConfig {

        public MCastDefConfigText.from_text(string teksto="") {

            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "LocalAddress":
                    this.LocalAddress=value.dup();
                    break;
                case "MCastAddress":
                    this.MCastAddress=value.dup();
                    break;
                case "Port":
                    try {
                        this.Port=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "TTL":
                    try {
                        this.TTL=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "ReceiveBuffer":
                    try {
                        this.ReceiveBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "SendBuffer":
                    try {
                        this.SendBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino ) my_match.next();
            }
        }
    }

    public class BCastDefConfigText : BCastDefConfig {

        public BCastDefConfigText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "LocalAddress":
                    this.LocalAddress=value.dup();
                    break;
                case "BCastAddress":
                    this.BCastAddress=value.dup();
                    break;
                case "Port":
                    try {
                        this.Port=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "ReceiveBuffer":
                    try {
                        this.ReceiveBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "SendBuffer":
                    try {
                        this.SendBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino ) my_match.next();
            }
        }
    }

    public class UDPStarDefConfigText : UDPStarDefConfig {

        public UDPStarDefConfigText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "LocalAddress":
                    this.LocalAddress=value.dup();
                    break;
                case "Port":
                    try {
                        this.Port=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "ReceiveBuffer":
                    try {
                        this.ReceiveBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "SendBuffer":
                    try {
                        this.SendBuffer=int.parse(value);
                    } catch(Error err) { } // default value
                    break;
                case "EndPoint":
                    my_match.next();
                    var end = new EndPointDefText.from_text();
                    this.EndPoint.append(end);
                    break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino ) my_match.next();
            }
        }
    }

    public class EndPointDefText : EndPointDef {

        public EndPointDefText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "Host":
                    this.Host=value.dup();;
                break;
                case "Port":
                    try {
                        this.Port=int.parse(value);
                    } catch(Error err) { } // default value
                break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino ) my_match.next();
            }
        }
    }

    public class CrossConnectorDefText : CrossConnectorDef {

        public CrossConnectorDefText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "Transport":
                    this.Transport.append(value.dup());
                break;
                case "}":
                    fino=true;
                    break;
                }

                if( !fino ) my_match.next();
            }

        }
    }

    public class ExtensionText: Object {

        public ExtensionText.from_text(string teksto="") {
            bool fino=false;
            if( teksto!="" ) PBusConfig_load_text(teksto);

            while( my_match.matches() && !fino ) {
                token = my_match.fetch(0);
                if( token !="}" ) my_match.next();    
                value = my_match.fetch(0);

                switch( token ) {
                case "}":
                    fino=true;
                    break;
                default:
                    if( value == "{" ) {
                        my_match.next();
                        new ExtensionText.from_text();
                    } 
                break;
                }

                if( !fino ) my_match.next();
            }

        }
    }
}

