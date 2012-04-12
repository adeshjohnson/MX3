# -*- encoding : utf-8 -*-
class ValidationController < ApplicationController

  def validate
    user_stats = validate_users
    device_stats = validate_devices
    provider_stats = validate_providers
    resellers_emails_stats = validate_resellers_emails
    Action.new(:user_id => 0, :date => Time.now.to_s(:db), :action => "system_validated").save
    render :text => "Users:\n#{user_stats}\n\nDevices:\n#{device_stats}\n\nProviders:\n#{provider_stats}\n\nResellers_emails:\n#{resellers_emails_stats}"
  end

  private
  def validate_users
    @users = User.find(:all, :include => [:address])
    @total_users = @users.size
    @validated_users = 0
    @still_invalid = 0
    @users.each { |user|
      unless user.save
        MorLog.my_debug("")
        MorLog.my_debug("INVALID USER: #{user.id}")

        if !user.address
          MorLog.my_debug("FIXING USER: #{user.id} User has no address")
          user.create_address
        end

        if user.address.email and user.address.email.to_s.length > 0 and !Email.address_validation(user.address.email)
          Action.new(:user_id => user.id, :date => Time.now.to_s(:db), :action => "user_validated", :data => "email_deleted", :data2 => user.address.email).save
          MorLog.my_debug("FIXING USER: #{user.id} Wrong address.email: #{user.address.email}")
          user.address.email = ""
          user.address.save
        end

        if user.recordings_email.to_s.length > 0 and !Email.address_validation(user.recordings_email)
          Action.new(:user_id => user.id, :date => Time.now.to_s(:db), :action => "user_validated", :data => "recordings_email_deleted", :data2 => user.recordings_email).save
          MorLog.my_debug("FIXING USER: #{user.id} Wrong recordings_email")
          user.recordings_email = ""
        end

        if user.save
          MorLog.my_debug("VALIDATED USER: #{user.id}")
          @validated_users += 1
        else
          str = ""
          user.errors.each { |key, value| str += " " + value.to_s }
          Action.add_error(user.id, ("User_still_invalid. " + str)[0..255])
          MorLog.my_debug("NOT VALIDATED USER: #{user.id}")
          @still_invalid += 1
        end
      end
    }
    return "  Total users: #{@total_users}\n  Validated users: #{@validated_users}\n  Still invalid: #{@still_invalid}"
  end

  def validate_devices
    @devices = Device.find(:all)
    @total_devices = @devices.size
    @still_invalid = 0
    @devices.each { |device|
      unless device.save
        MorLog.my_debug("")
        MorLog.my_debug("INVALID DEVICE: #{device.id}")
        if device.save
          MorLog.my_debug("VALIDATED DEVICE: #{device.id}")
        else
          str = ""
          device.errors.each { |key, value| str += " " + value.to_s }
          Action.new(:date => Time.now.to_s(:db), :target_id => device.id, :target_type => "device", :action => "error", :data => ("Device_still_invalid. " + str)[0..255], :processed => 0).save
          MorLog.my_debug("NOT VALIDATED DEVICE: #{device.id}")
          @still_invalid += 1
        end
      end
    }
    return "  Total devices: #{@total_devices}\n  Still invalid: #{@still_invalid}"
  end

  def validate_providers
    @providers = Provider.find(:all)
    @total_providers = @providers.size
    @validated_providers = 0
    @still_invalid = 0
    @providers.each { |provider|
      unless provider.save
        MorLog.my_debug("")
        MorLog.my_debug("INVALID PROVIDER: #{provider.id}")
        provider.errors.each { |key, value|
          if key.to_s == "server_ip"
            MorLog.my_debug("FIXING PROVIDER: #{provider.id} Wrong server_ip: #{provider.server_ip}")
            Action.new(:target_id => provider.id, :target_type => "provider", :date => Time.now.to_s(:db), :action => "provider_validated", :data => "server_ip_changer", :data2 => provider.server_ip, :data3 => "0.0.0.0").save
            provider.server_ip = "0.0.0.0"
          end
          if provider.name == ""
            MorLog.my_debug("FIXING PROVIDER: #{provider.id} Missing name")
            Action.new(:target_id => provider.id, :target_type => "provider", :date => Time.now.to_s(:db), :action => "provider_validated", :data => "creating_provider_name", :data2 => "Provider_#{provider.id}").save
            provider.name = "Provider_#{provider.id}"
          end
          if key.to_s == "port"
            MorLog.my_debug("FIXING PROVIDER: #{provider.id} Wrong port: #{provider.port}")
            Action.new(:target_id => provider.id, :target_type => "provider", :date => Time.now.to_s(:db), :action => "provider_validated", :data => "cleaning_port", :data2 => provider.port, :data3 => provider.port.to_s.gsub(/[^0-9]/, "")).save
            provider.port = provider.port.to_s.gsub(/[^0-9]/, "")
          end
        }
        if provider.save
          MorLog.my_debug("VALIDATED PROVIDER: #{provider.id}")
          @validated_providers += 1
        else
          str = ""
          provider.errors.each { |key, value| str += " " + value.to_s }
          Action.new(:date => Time.now.to_s(:db), :target_id => provider.id, :target_type => "provider", :action => "error", :data => ("Provider_still_invalid. " + str)[0..255], :processed => 0).save
          MorLog.my_debug("NON VALIDATED PROVIDER: #{provider.id}")
          @still_invalid += 1
        end
      end

    }
    return "  Total providers: #{@total_providers}\n  Validated providers: #{@validated_providers}\n  Still invalid: #{@still_invalid}"
  end

  def validate_resellers_emails
    @emails = Email.count(:all, :conditions => "owner_id = 0 AND template = 1")
    @em_s = @emails.to_i - 2
    @resellers = User.find(:all,
                           :select => "users.* , COUNT(emails.id) as 'em_size'",
                           :conditions => "usertype = 'reseller' AND template = 1",
                           :joins => "JOIN emails ON (emails.owner_id = users.id)",
                           :group => "users.id")

    @total_resellers = @resellers.size
    @validated_resellers = 0
    @still_invalid = 0
    @resellers.each { |reseller|

      if reseller.em_size.to_i != @em_s.to_i
        reseller.check_reseller_emails
        @validated_resellers +=1
      end
    }
    return "  Total Resellers: #{@total_resellers}\n  Validated resellers: #{@validated_resellers}\n  Still invalid: #{@still_invalid}"
  end
end

