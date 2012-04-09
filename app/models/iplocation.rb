class Iplocation < ActiveRecord::Base
  require 'net/http'
  require 'uri'

  validates_presence_of :latitude, :longitude, :ip

  def Iplocation::get_location_from_hostip(ip, loc)
    if check_ip(ip) == true
      loc.ip = ip
      begin
        mas = Net::HTTP.get_response("api.hostip.info", "/get_html.php?ip=#{ip}&position=true").body
        if mas and mas.length > 0
          mas = mas.split("\n")
          loc.country=mas[0].to_s.split(":")[1].to_s.split("(")[0].to_s.strip.titlecase if mas[0].split(":")[1].to_s.strip.size > 0
          loc.city = mas[1].to_s.split(":")[1].to_s.strip.titlecase if mas[1].split(":")[1].strip.size > 0
          loc.latitude = mas[2].split(":")[1].to_f
          loc.longitude = mas[3].split(":")[1].to_f
        else
          Iplocation::reset_location(loc)
        end
      rescue Exception => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        Iplocation::reset_location(loc)
      end
    end
    return loc
  end

  def Iplocation::get_location_from_whatismyipaddress(ip, loc)
    if check_ip(ip) == true
      loc.ip = ip
      begin
        url = URI.parse('http://whatismyipaddress.com/ip/'+ip.to_s)
        # build the params string
        req = Net::HTTP::Get.new(url.path)
        req.add_field("user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.83 Safari/535.11")
        res1 = Net::HTTP.new(url.host, url.port).start do |http|
          http.request(req)
        end
        res = res1.body

        if res and res.length > 0
          lat = res.match(/<tr><th>Latitude:<\/th><td>(.*)<\/td><\/tr>/)
          lon = res.match(/<tr><th>Longitude:<\/th><td>(.*)<\/td><\/tr>/)
          cit = res.match(/<tr><th>City:<\/th><td>(.*)<\/td><\/tr>/)
          cou = res.match(/<tr><th>Country:<\/th><td>(.*)<\/td><\/tr>/)
          loc.longitude = lon[1].to_f if lon
          loc.latitude = lat[1].to_f if lat
          loc.city = cit[1].to_s.strip.titlecase if cit
          loc.country = cou[1].to_s.gsub(/<img.*>/, "").strip.titlecase if cou
        else
          Iplocation::reset_location(loc)
        end
      rescue Exception => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        Iplocation::reset_location(loc)
      end
    end
    return loc
  end

  def Iplocation::get_location_from_ip_address(ip, loc)
    if check_ip(ip) == true
      loc.ip = ip
      begin
        url = URI.parse('http://www.ip-adress.com/ip_tracer/'+ip.to_s)
        # build the params string
        req = Net::HTTP::Get.new(url.path)
        req.add_field("user-agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/535.11 (KHTML, like Gecko) Chrome/17.0.963.83 Safari/535.11")
        res1 = Net::HTTP.new(url.host, url.port).start do |http|
          http.request(req)
        end
        res = res1.body

        if res and res.length > 0
          cou = res.match(/<th>My IP address country:<\/th>.*\n.*<td>.*\n(.*)<\/td>.*\n.*<\/tr>/)
          cit = res.match(/<th>My IP address city:<\/th>.*\n.*<td>.*\n(.*)<\/td>.*\n.*<\/tr>/)
          lat = res.match(/<th>My IP address latitude:<\/th>.*\n.*<td>.*\n(.*)<\/td>.*\n.*<\/tr>/)
          lon = res.match(/<th>My IP address longitude:<\/th>.*\n.*<td>.*\n(.*)<\/td>.*\n.*<\/tr>/)
          loc.country = cou[1].gsub(/<img.*>/, "").strip.titlecase if cou
          loc.city = cit[1].strip.titlecase if cit
          loc.longitude = lon[1].strip.to_f if lon
          loc.latitude = lat[1].strip.to_f if lat
        else
          Iplocation::reset_location(loc)
        end
      rescue Exception => exc
        MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
        Iplocation::reset_location(loc)
      end
    end
    return loc
  end

  def Iplocation::get_location_from_google_geo(dst, dir, loc, prefix)
    if dst == "" and dir == ""
      return loc
    end
    begin
      if dst != ""
        address = dir+" "+dst
        res = Net::HTTP.get_response(URI.parse("http://maps.google.com/maps/geo?q=#{address.gsub(" ", "+")}&output=csv&sensor=false")).body.to_s.split(",")
      end

      if dst == "" or res[0] != "200"
        res = Net::HTTP.get_response(URI.parse("http://maps.google.com/maps/geo?q=#{dir.gsub(" ", "+")}&output=csv&key=sensor=false")).body.split(",")
        dst = ""
      end

      if dir == "Georgia"
        loc.ip = prefix
        loc.latitude = 42
        loc.longitude = 44
        loc.city = ""
        loc.country = "Georgia"
      else
        if res[0] == "200"
          loc.ip = prefix
          loc.latitude = res[2].to_f
          loc.longitude = res[3].to_f
          loc.city = ""
          loc.city = dst.lstrip if dst and dst != ""
          loc.country = dir.lstrip
        end
      end
    rescue Exception => exc
      MorLog.my_debug("IpLocation error: #{exc.to_yaml}")
      loc.ip = prefix
      Iplocation::reset_location(loc)
    end
    return loc
  end

  def Iplocation::get_location(ip, prefix = nil)
    loc = Iplocation.where(["ip = ?", ip]).first
    return loc if loc
    loc = Iplocation.new()
    if ip.to_s == ""
      loc.latitude = 0
      loc.longitude = 0
      return loc
    end

    if prefix == nil
      loc.latitude = 0
      loc.longitude = 0

      if loc.latitude == 0 and loc.longitude == 0
        loc = Iplocation.get_location_from_whatismyipaddress(ip, loc)
        MorLog.my_debug("from whatismyipaddress")
        MorLog.my_debug(loc.to_yaml)
      end

      if loc.latitude == 0 and loc.longitude == 0
        loc = Iplocation.get_location_from_ip_address(ip, loc)
        MorLog.my_debug("from ip_address")
        MorLog.my_debug(loc.to_yaml)
      end

#      ###NEVEIKIA!!!###
#      if loc.latitude == 0 and loc.longitude == 0
#        loc = Iplocation.get_location_from_hostip(ip, loc)
#        MorLog.my_debug("from hostip")
#        MorLog.my_debug(loc.to_yaml)
#      end

    else
      dst = Destination.where(["prefix = ?", ip]).first
      if dst
        direction = dst.direction
        direction ? dir = direction.name.to_s : dir = ""
        dst = dst.name.to_s
        loc = get_location_from_google_geo(dst, dir, loc, ip)
      end
    end
    loc.save
    return loc
  end

  def check_ip
    return Iplocation::check_ip(self.ip)
  end

  def Iplocation::check_ip(ip)
    if ip and ip.size>0
      digits = ip.split(".")
      if digits.size == 4
        for digit in digits do
          if digit.to_i.to_s != digit or digit.to_i > 255 or digit.to_i < 0
            return false
          end
        end
        return true
      else
        return false
      end
    else
      return false
    end
  end

  private

  def Iplocation::reset_location(loc)
    loc.country = ""
    loc.city = ""
    loc.latitude = 0
    loc.longitude = 0
  end
end