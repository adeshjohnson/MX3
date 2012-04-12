#!/usr/bin/ruby

require 'rubygems'
require 'active_record'
require 'optparse'

options = {}
optparse = OptionParser.new do |opts|
  # Define the options, and what they do
  options[:path] = nil
  opts.on('-p', '--path PATH', "tests path , default '/home/mor/selenium/tests/'") do |n|
    options[:path] = n
  end

  opts.on('-h', '--help', 'Display this screen') do
    puts opts
    exit
  end
end

optparse.parse!

#----------------  SET default params --------------------------------
path = options[:path].to_s.empty? ? '/home/mor/selenium/tests/' : options[:path]

bads = []
erros = []

i = 0
[path.to_s+'*', path.to_s+'*/*'].each { |versija|
  files = Dir.glob(versija)

  for file in files
    #puts file
    if !File.directory?(file)
      html = ''
      #read
      File.open(file, 'r+') do |f|
        err = []
        ii = 0
        while (!f.eof?)
          line = f.readline
          ['tr[', 'td['].each { |string|
            if line.include?(string) and !line.include?('@id=')
              bads[i] = file
              err << ii.to_s + ': ' + line.strip
            end
          }
          ii = ii + 1
        end
        erros[i] = err.uniq if bads[i]
        i= i + 1
      end
    end
  end
}
if bads and bads.size > 0
  bads.each_with_index { |ff, index|
    puts '***************' + ff.to_s + ":" if ff
    puts erros[index].join('
                           ').to_s if ff
  }
end
