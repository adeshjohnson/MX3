module Cyberplat 
  module Helpers


    def cyberplat_setup(order_id, amount, currency, firstName, lastName, email, shopIP, return_url, options = {})
      MorLog.my_debug("Testas1")
      #data check
      firstName = lastName if firstName.to_s.length < 4
      lastName = firstName if lastName.to_s.length < 4
      # last resort for empty names just to allow Cyberplat payments (ok, that's nasty hack)
      firstName = "John" if firstName.to_s.length < 4
      lastName = "Lock" if lastName.to_s.length < 4
   
      message = ''
      params = {
      }.merge(options)
      params[:language] ? lang = params[:language].to_s : lang = 'en'
      # We accept both, strings and money objects as amount    
      #amount = amount.cents.to_f / 100.0 if amount.respond_to?(:cents)
      #amount = sprintf("%.2f", amount)
      # same for tax
      if params[:tax]
        tax = params[:tax]
        tax = tax.cents.to_f / 100.0 if tax.respond_to?(:cents)
        tax = sprintf("%.2f", tax)
      end
      amount = (amount.to_f * 100).to_s.to_i
      message = "OrderID="+order_id.to_s
      message += "&Amount="+(amount).to_s
      message += "&Currency="+currency.to_s
      message += "&FirstName="+firstName.to_s
      message += "&LastName="+lastName.to_s
      message += "&Email="+email.to_s      
      message += "&ShopIP="+shopIP.to_s
      message += "&return_url="+return_url.to_s
      message += "&Language="+lang
      message += "&PaymentDetails="+params[:paymentdetails].to_s if params[:paymentdetails]
      message += "&CardType="+params[:cardtype].to_s if params[:cardtype]
      message += "&Registered="+params[:registred] if params[:registred]
      checker_tmp = Confline.get_value("Cyberplat_Temporary_Directory", 0)
      File.open("#{checker_tmp}/message.txt", 'w') {|f| f.write(message) }
      
      system("#{Actual_Dir}/lib/cyberplat/checker.exe -s -f #{Actual_Dir}/lib/cyberplat/checker.ini #{checker_tmp}/message2.txt < #{checker_tmp}/message.txt")
      msg = ""
      File.open("#{checker_tmp}/message2.txt", "r") do |infile|
        while (line = infile.gets)
          msg +=line 
        end
      end
      Confline.my_debug(msg)
      system("rm #{checker_tmp}/message.txt")
      system("rm #{checker_tmp}/message2.txt")
      returning button = [] do
        button << tag(:input, :type => 'hidden', :name => 'version', :value => '2.0')
        button << tag(:input, :type => 'hidden', :name => 'сryptotool', :value => "Ipriv")
        #button << tag(:input, :type => 'hidden', :name => 'сryptotool', :value => params[:сryptotool]) if params[:сryptotool]
        button << tag(:input, :type => 'hidden', :name => 'message', :value => msg)
      end.join("\n")
    end
    
  end
end