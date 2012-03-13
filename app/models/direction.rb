# -*- encoding : utf-8 -*-
class Direction < ActiveRecord::Base
  has_many :destinations, :finder_sql => 'SELECT * FROM destinations WHERE direction_code = \'#{code}\' ORDER BY prefix'

  validates_uniqueness_of :name, :code
  validates_presence_of :name, :code

  def dest_count
    sql = "SELECT COUNT(*) FROM destinations WHERE direction_code = '#{self.code}'"
    ActiveRecord::Base.connection.select_value(sql)
  end

  def destroy_everything
    for dest in self.destinations
      dest.destroy
    end
    self.destroy    
  end
  
  def Direction::get_direction_by_country(country)
    dir = Direction.find(:first, :conditions => "name = '#{country}'")
    if dir
      return dir.id.to_i
    else 
      return Confline.get_value("Default_Country_ID")
    end
    
  end
    
  
  def hangup(date_start, date_end)
    hangup = Hangupcausecode.find_by_sql("SELECT hangupcausecodes.* FROM hangupcausecodes, calls, destinations WHERE calls.prefix = destinations.prefix AND destinations.direction_code ='#{self.code}' AND hangupcausecodes.code = calls.hangupcause AND calls.calldate BETWEEN '#{date_start}' AND '#{date_end}' ORDER BY hangupcausecodes.id;")
  end

  def destinations_with_groups
    Destination.find_by_sql ["SELECT *,destinations.id as id, destinationgroups.id as dg_id, destinations.name as name, destinationgroups.name as dg_name FROM destinations LEFT JOIN destinationgroups ON destinations.destinationgroup_id = destinationgroups.id WHERE destinations.direction_code = ? ORDER BY destinations.prefix", code]
  end

  def Direction.name_by_prefix(prefix)

    if dest = Destination.find(
        :first,
        :select => "directions.name",
        :joins => "LEFT JOIN directions ON (directions.code = destinations.direction_code)",
        :conditions => ["destinations.prefix = ?", prefix.to_s]
      )
      dest["name"]
    else
      ""
    end
  end

  def Direction.get_calls_for_graph(options={})

    cond = []
    var = []


    cond << "calls.calldate BETWEEN ? AND ?"
    var += ["#{options[:a1]} 00:00:00", "#{options[:a2]} 23:23:59"]

    cond << 'directions.code = ?'; var << options[:code]
    if options[:destination]
      cond << 'destinations.prefix = ?'; var << options[:destination]
    end

    calls_all = Call.count(:all,
      :conditions=>[cond.join(' AND ').to_s] + var,
      :joins=>'LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN directions ON (directions.code = destinations.direction_code)')

    calls = Call.find(:all,
      :conditions=>[cond.join(' AND ').to_s] + var,
      :select=>"COUNT(*) AS 'calls', disposition , ((COUNT(*)/#{calls_all.size.to_i}) * 100) AS asr_c",
      :joins=>'LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN directions ON (directions.code = destinations.direction_code)',
      :group=>'calls.disposition',
      :order=>'calls.disposition ASC')
      
    ca =[nil,nil,nil,nil]
    for c in calls
      case c.disposition
      when 'ANSWERED'
        ca[0] = c;
      when 'NO ANSWER'
        ca[1] = c;
      when 'BUSY'
        ca[2] = c;
      when 'FAILED'
        ca[3] = c;
      end
    end

        #===== Graph =====================

    calls_graph = "\""
    if calls_all and calls_all.to_f > 0
      calls_graph +=  _('ANSWERED') +";" + (ca[0] ? ca[0].calls : 0).to_s + ";"  + "false" + "\\n"
      calls_graph += _('NO_ANSWER') +";"  + (ca[1] ? ca[1].calls : 0).to_s + ";"  + "false" + "\\n"
      calls_graph += _('BUSY') +";"  + (ca[2] ? ca[2].calls : 0).to_s + ";"  + "false" + "\\n"
      calls_graph += _('FAILED') +";"  + (ca[3] ? ca[3].calls : 0).to_s + ";"  + "false" + "\\n"
      calls_graph += "\""
    else
      calls_graph = "\"No result" + ";" + "1" + ";" + "false" + "\\n\""
    end



      return calls_all.to_i, calls_graph, *ca
  end
  
end
