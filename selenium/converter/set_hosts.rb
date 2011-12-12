require 'find'
class Refactor

  def self.read_file(file)
    content = []
    file = File.open(file, "r")
    file.each {|line| content << line }
    file.close
    content = content.join("")
    return content

  end

  def self.remove_notice(file)
    content = Refactor.read_file(file)
    content.gsub!(/<link rel="selenium.base" href=".*" \/>/){|a| "<link rel=\"selenium.base\" href=\"http://trunk\" />"}
    Refactor.write(file, content)
  end

  def self.write(file, content)
    file = File.open(file, "w")
    file.puts(content)
    file.close
  end
end
puts File.dirname(__FILE__)
Find.find(File.dirname(__FILE__)+"/../tests/") do |path|
  if path =~ /\.case\z/
    puts path
    Refactor.remove_notice(path)
  end
end
