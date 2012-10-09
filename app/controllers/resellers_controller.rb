# -*- encoding : utf-8 -*-
class ResellersController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:settings_change]
  before_filter :check_localization
  before_filter :authorize

  @@settings = [
      [:boolean, "Show_HGC_for_Resellers"],
      [:boolean, "Resellers_Allow_Use_dahdi_Device"],
      [:boolean, "Resellers_Allow_Use_Virtual_Device"],
      [:boolean, "Resellers_can_add_their_own_DIDs"],
      [:boolean, "Resellers_Allow_Assign_DID_To_Trunk"],
  ]

  def settings
    @page_title = _('Settings')
    @page_icon = 'cog.png'
    @settings = @@settings
    @providers = current_user.providers(:conditions => ['hidden=?', 0], :order => "name ASC")
    @servers = Server.where("server_type = 'asterisk'").order("server_id ASC").all
  end

  def settings_change
    @@settings.each { |type, name|
      case type
        when :boolean then
          Confline.set_value(name, params[name.downcase.to_sym].to_i, 0)
      end
    }
    if params[:resellers_server] != Confline.get_value('Resellers_server_id')
      if ccl_active?
        @resellers_and_their_users_devices = Device.select("devices.*").joins("LEFT JOIN users ON (devices.user_id = users.id)").where("(devices.device_type != 'SIP' OR devices.host != 'dynamic') AND (users.owner_id !=0 OR usertype = 'reseller') AND users.hidden = 0").all
        @resellers_and_their_users_devices.each do |dev|
          sql = "UPDATE devices SET server_id = #{params[:resellers_server].to_s} WHERE id = #{dev.id};"
          ActiveRecord::Base.connection.update(sql)
          dev.create_server_devices({params[:resellers_server].to_s => "1"})
        end
      else
        @resellers_and_their_users_devices = Device.select("devices.*").joins("LEFT JOIN users ON (devices.user_id = users.id)").where("(users.owner_id !=0 OR usertype = 'reseller') AND users.hidden = 0").all
        @resellers_and_their_users_devices.each do |dev|
          sql = "UPDATE devices SET server_id = #{params[:resellers_server].to_s} WHERE id = #{dev.id};"
          ActiveRecord::Base.connection.update(sql)
          dev.create_server_devices({params[:resellers_server].to_s => "1"})
        end
      end
      Confline.set_value('Resellers_server_id', params[:resellers_server].to_i)
    end

    Confline.set_value("DID_default_provider_to_resellers", params[:did_provider])
    Confline.set_value('Allow_resellers_change_device_PIN', params[:allow_resellers_change_device_pin].to_i)
    Confline.set_value('Allow_resellers_to_change_extensions_for_their_user_devices', params[:allow_resellers_to_change_extensions_for_their_user_devices].to_i)

    Confline.set_value('disallow_coppy_localization', params[:disallow_coppy_localization].to_i)

    flash[:status] = _('Settings_saved')
    redirect_to :action => 'settings' and return false
  end
end
