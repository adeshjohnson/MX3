# -*- encoding : utf-8 -*-
require 'application_helper'
include ApplicationHelper


module CsvFileMor

  @@path = '/tmp/'
  @@exct = ".csv"

=begin rdoc
 Generates header for Tariff.generate_provider_rates_pdf

 *Params*

 +file+ - Csv file
 +i+ - current possition
 +options+ - pdf options hash.

 *Returns*

 +file_name_array+ - Return file names array
=end

  def CsvFileMor.save_splite_files(file, options={})
    i=0
    file_id = 0
    file_name_array = []
    file_split = File.new(@@path.to_s + options[:cdr_import_file_name]+"_#{file_id.to_i}#{@@exct}", 'w')
    file_name_array << {:f_name=>options[:cdr_import_file_name]+"_#{file_id.to_i}#{@@exct}", :f_used=>0 }
    file.each_line { |line|
      if i < 10000
        file_split << line
      else
        i=0
        file_id +=1
        file_split.close
        file_split = File.new(@@path.to_s + options[:cdr_import_file_name]+"_#{file_id.to_i}#{@@exct}", 'w')
        file_name_array << {:f_name=>options[:cdr_import_file_name]+"_#{file_id.to_i}#{@@exct}", :f_used=>0 }
      end
      i+=1
    }
    file_split.close
    

    return file_name_array
  end

=begin rdoc
 Generates header for Tariff.generate_provider_rates_pdf

 *Params*

 +file_hash+ - Csv file from file_name_array
 +id+ - which file load from array
 +options+ - pdf options hash.
 +remove_flags+ - all files marked as not used

 *Returns*

 +file+ - Return file
 +file_name_array+ - Return file array
=end


  def CsvFileMor.load_file(file_hash, options={})
#    if options[:remove_flags]
#      file_hash.each{|f| f[:f_used] = 0}
#    end
MorLog.my_debug @@path+file_hash[:f_name]
    file = nil
    file = File.open(@@path+file_hash[:f_name], 'r').read if File.exist?(@@path+file_hash[:f_name])
 MorLog.my_debug file
    return file
  end

  def CsvFileMor.delete_file(array)
    for a in array
      File.delete(@@path+a[:f_name]) if File.exist?(@@path+a[:f_name])
    end

  end

end
