# -*- encoding : utf-8 -*-
class Server < ActiveRecord::Base
  has_many :serverproviders
  has_many :providers
  has_one :gateway
  has_many :activecalls
  has_many :server_devices
  has_many :devices, :through => :server_devices

  require 'rami'

  before_destroy :check_if_no_devices_own_server
  before_destroy :check_if_server_is_resellers_server
  before_save :check_server_device

  def check_if_no_devices_own_server
    if Device.count(:conditions => ["server_id = ?", self.id]).to_i > 0
      errors.add(:server_id, _("Server_Has_Devices"))
      return false
    end
  end

  def check_if_server_is_resellers_server
    if Confline.get_value("Resellers_server_id") == self.id
      errors.add(:server_id, _("Server_is_default_resellers_server"))
      return false
    end
  end

  def check_server_device
    unless self.server_device
      self.create_server_device
    end
  end

  def serverprovider
    Serverprovider.find(:all, :conditions => ["provider_id=?", self.id])
  end

  def providers
    Provider.find_by_sql("SELECT providers.* FROM providers, serverproviders WHERE serverproviders.server_id = '#{self.server_id.to_s}' AND serverproviders.provider_id = providers.id  AND providers.hidden = 0 ORDER BY providers.id;")
  end


  #deletes realtime device from cache
  def prune_peer(device_name, reload = 1)
    if self.active == 1

      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console =1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      # changed from device.username, hope it works
      device_username = device_name

      t = client.command("sip prune realtime peer " + device_username)
      
      if (defined?(AST_18) and AST_18.to_i == 1)
        #AST18 does not use this command, user ir pruned with 'sip prune realtime peer NAME'
      else
        t = client.command("sip prune realtime user " + device_username)
      end
      
      if (defined?(AST_18) and AST_18.to_i == 1)
        # AST18 do not care about user/peer to prune it
        t = client.command("iax2 prune realtime " + device_username)
      else
        t = client.command("iax2 prune realtime user " + device_username)
        t = client.command("iax2 prune realtime peer " + device_username)        
      end


      if reload == 1
        t = client.command("sip show peer " + device_username + " load")
        t = client.command("iax2 show peer " + device_username + " load")
        t = client.command("sip show user " + device_username + " load")
        
        if (defined?(AST_18) and AST_18.to_i == 1)
          #AST18 does not use this command, user is loaded with 'iax2 show peer NAME load'
        else
          t = client.command("iax2 show user " + device_username + " load")        
        end

      end 

      client.stop

    end

  end

  def reload(check_active = 1)
    if (self.active == 1 and check_active == 1) or (check_active == 0)
      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console =1
      server.event_cache = 100
      server.run

      client = Rami::Client.new(server)
      client.timeout = 3

      client.command("sip reload")
      client.command("iax2 reload")

      client.stop
    end
  end


  def ami_cmd(cmd)
    if self.active == 1
      server = Rami::Server.new({'host' => self.server_ip, 'username' => self.ami_username, 'secret' => self.ami_secret})
      server.console =1
      server.event_cache = 100
      server.run
      client = Rami::Client.new(server)
      client.timeout = 3
      client.command(cmd)
      client.stop
    end
  end

  def create_server_device
    dev = Device.new
    dev.name = "mor_server_" + server_id.to_s
    dev.fromuser = dev.name
    dev.host = hostname
    dev.secret = "" #random_password(10)
    dev.context = "mor_direct"
    dev.ipaddr = server_ip
    dev.device_type = "SIP" #IAX2 sux
    dev.port = 5060 #make dynamic later
    dev.extension = dev.name
    dev.username = dev.name
    dev.user_id = 0
    dev.allow = "all"
    dev.nat = "no"
    dev.canreinvite = "no"
    dev.server_id = server_id
    dev.description = 'DO NOT EDIT'
    dev.save
  end

  def server_device
    Device.find(:first, :conditions => "name = 'mor_server_#{server_id.to_s}'")
  end
end
