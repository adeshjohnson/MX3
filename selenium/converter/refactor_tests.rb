class Refactor

  def self.read_file(file)
    content = []
    file = File.open(file, "r")
    file.each { |line| content << line }
    file.close
    content = content.join("")
    return content

  end

  def self.remove_notice(file)
    content = Refactor.read_file(file)
    content.gsub!(/<td>(verify|assert)Text<\/td>\n\s*<td>(notice|status)<\/td>\n\s*<td>(.*)<\/td>/) { |a| "<td>#{$1}TextPresent</td>\n\t<td>#{$3}</td>\n\t<td></td>" }
    Refactor.write(file, content)
  end

  def self.write(file, content)
    file = File.open(file, "w")
    file.puts(content)
    file.close
  end
end

ARGV.each_with_index do |a, i|
  Refactor.remove_notice(a) if a and a != ""
end
