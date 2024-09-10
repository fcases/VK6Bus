[indent=4]

init 
    source_directory: string = args[1]     
    destination_directory: string = args[2] 
    namespace: string = "ProtocolBus"  

    encapsulate_files(source_directory, destination_directory, namespace)


def encapsulate_files(source_dir: string, destination_dir: string, namespace: string)
    try
        var source_folder = File.new_for_path(source_dir)
        var dest_folder = File.new_for_path(destination_dir)
        
        // Verifica si el directorio de destino existe; si no, lo crea
        if !dest_folder.query_exists (null)
            dest_folder.make_directory_with_parents(null)

        // Lee los archivos .vala del directorio fuente
        var enumerator = source_folder.enumerate_children("standard::name", FileQueryInfoFlags.NONE, null)
        file_info: FileInfo?=null

        while (file_info = enumerator.next_file(null)) != null
            filename: string = file_info.get_name()

            if filename.has_suffix("pb.vala")
                stdout.printf("Procesando archivo: %s\n", filename)
                var fich_in= FileStream.open (source_folder.get_path()+"/"+filename, "r")
                var fich_out=FileStream.open (dest_folder.get_path()+"/"+filename.replace(".pb",""), "w")
                var line="";
                fich_out.printf("namespace %s {",namespace)
                if( fich_in != null) 
                    while( !fich_in.eof() )  
                        line = "\t"+fich_in.read_line()+"\n"
                        fich_out.printf("%s",line)
                    fich_out.printf("}")
                
                stdout.printf("Guardado en: %s\n", dest_folder.get_path())
                
    except e: GLib.Error
        stderr.printf("Error: %s\n", e.message)

    //  def static main(argc: int, argv: array of string) : int
        //  return 0

