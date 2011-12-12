module CsvImportDb

  def CsvImportDb.clean_value(value)
    cv = value.to_s.gsub("\"", "")
    cv
  end

  def CsvImportDb.clean_after_import(tname, path = "/tmp/")
    MorLog.my_debug("CSV clean_after_import #{tname}", 1)
    full_file_path = "#{path}#{tname}.csv"
    system("rm -f #{full_file_path}")
    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{tname};")
  end

  def CsvImportDb.log_swap(string)
    system("echo '#{Time.now.to_s(:db)} --- #{string}' >> /tmp/swap_log.txt")
    system("vmstat >> /tmp/swap_log.txt")
  end

  def CsvImportDb.head_of_file(path, n = 1)
    File.open(path) do |f|
      lines = []
      n.times do
        line = f.gets || break
        lines << line
      end
      lines
    end
  end

  def CsvImportDb.save_file(id, file, path = "/tmp/")
    tname = "import_csv_#{id}_#{Time.now.to_i}"
    MorLog.my_debug("CSV save_file #{tname}", 1)
    CsvImportDb.log_swap('save_file')
    full_file_path = "#{path}#{tname}.csv"

    #create file
    File.open(full_file_path, "wb") { |f| f.write(file) }
    yy = YAML::load(File.open("#{RAILS_ROOT}/config/database.yml"))
    if Confline.get_value("Load_CSV_From_Remote_Mysql").to_i == 1 or (!yy['production']['host'].blank? and !yy['production']['host'].include?('localhsot'))
      # move
      cp_cmd = "/usr/bin/scp root@127.0.0.1:#{full_file_path} root@#{yy['production']['host']}:#{full_file_path}"
      MorLog.my_debug(cp_cmd)
      system(cp_cmd)
    end

    MorLog.my_debug(tname)
    return tname
  end

  def CsvImportDb.load_csv_into_db(tname, sep, dec, fl, path = "/tmp/", options = {})
    MorLog.my_debug("CSV load_csv_into_db #{tname}", 1)
    CsvImportDb.log_swap('load')
    path = "/tmp/" if !path
    full_file_path =  options[:xml] ? "#{path}#{tname}.xml" : "#{path}#{tname}.csv"

    #create table

    cols_size = options[:xml] ? 12 : fl.size
    cols = []
    cols_size.times{|num| cols[num]= 'col_' + num.to_s + " VARCHAR(225) default NULL "}

    incr_name = nil
    if options[:colums] and options[:colums].size > 0

      options[:colums].each{|col| z = col[:name].to_s + " " + col[:type].to_s
        z += " default " + col[:default].to_s if !col[:default].to_s.blank?
        z += col[:inscrement].to_s if !col[:inscrement].to_s.blank?
        incr_name = col[:name].to_s if !col[:inscrement].to_s.blank?
        cols << z
      }
    end

    ActiveRecord::Base.connection.execute("DROP TABLE IF EXISTS #{tname};")
    sql = "CREATE TABLE #{tname} ("
    sql += cols.reject{|v| v.nil? or v.empty? }.join(" , ")
    sql += ", PRIMARY KEY  (#{incr_name})" if !incr_name.blank?
    sql += ") ENGINE=InnoDB DEFAULT CHARSET=utf8 ;"
    ActiveRecord::Base.connection.execute(sql)
    
    #load
    # http://bugs.mysql.com/bug.php?id=10195 mysql utf=>latin!!!!
    if options[:xml]
      load = "LOAD XML INFILE '/home/kristina/fifty_rates.xml' IGNORE INTO TABLE #{tname} character set latin1"
      load+= ";"
    else
      load = "LOAD DATA LOCAL INFILE '#{full_file_path}' IGNORE INTO TABLE #{tname} character set latin1"
      load += " FIELDS TERMINATED BY '#{sep}' "
      load += " OPTIONALLY  ENCLOSED BY '\"' "
      load += " lines terminated by '\n' ;"
    end
    ActiveRecord::Base.verify_active_connections!
    ActiveRecord::Base.connection.execute(load)
    MorLog.my_debug load
    return tname
  end
end
