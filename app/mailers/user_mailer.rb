# -*- encoding : utf-8 -*-
class UserMailer < ActionMailer::Base
require 'smtp_tls' 

  def load_settings
    options={}
    options[:owner] = 0
    smtp_server = Confline.get_value("Email_Smtp_Server",options[:owner].to_i)
    if (domain = Confline.get_value("Email_Domain",options[:owner].to_i).to_s).blank?
      Confline.set_value("Email_Domain", "localhost.localdomain",options[:owner].to_i)
      domain = "localhost.localdomain"
    end
    login = Confline.get_value("Email_Login",options[:owner].to_i)
    psw = Confline.get_value("Email_Password",options[:owner].to_i)
    port = Confline.get_value("Email_port",options[:owner].to_i)
    mail = ""

    login_type = :login
    if login.to_s.length == 0 or psw.to_s.length == 0
      login = nil
      psw = nil
      login_type = nil
    end

    ActionMailer::Base.smtp_settings = {
      :address => smtp_server,
      :port => port,
      :domain => domain,
      :authentication => login_type,
      :user_name => login,
      :password => psw
    }
  end
  
  def sent_my_email(email_to, email_from, email, assigns = {})
    load_settings
    email_builder = ActionView::Base.new(nil,assigns)
    email_from = email_from.blank? ? Confline.get_value("Email_from") : email_from

    mail(:to => email_to, :subject => email.subject,
         :from=> '"' + email_from + '"'+ ' <' + email_from + '>',
         :body=>email_builder.render(
             :inline => nice_body(email.body),
             :locals => assigns),
         :content_type=>"text/#{email.format.to_s}"
    )
  end


=begin rdoc
 Sends email with attachments
 Atachemnt is Array of Hash elements each hash must have 3 elements:
 * +:content_type+ - string representing MIME type of file. "application/pdf" for PDF files, "text/csv" - CSV files.
 * +:file_name+ - name of the file.
 * +:file+ - content of the file.
=end

  def sent_with_attachments(email_to, email_from, email, my_attachments = [], assigns = {})
    load_settings
    email_builder = ActionView::Base.new(nil,assigns)
    email_from = email_from.blank? ? Confline.get_value("Email_from") : email_from
  #  attachments.each {|attach|
   #   attachment :content_type => attach[:content_type], :filename =>attach[:filename] do |a|
   #     a.body = attach[:file]
   #   end
   # }

    if my_attachments and my_attachments.size.to_i > 0
      my_attachments.each {|attach|
        attachments[attach[:filename]] = attach[:file]
      }
    end

    mail(:to => email_to, :subject =>  email.subject,
         :from=> "#{email_from} <#{email_from}>",
         :body=>email_builder.render(
             :inline => nice_body(email.body),
             :locals => assigns),
         :content_type=>"text/#{email.format.to_s}"
    )
  end


  def sent_sms(email_to, number, email_from, email, assigns = {})
    load_settings
    email_builder = ActionView::Base.new(nil,assigns)
    mail(:to => email_to, :subject => number,
         :from=> "#{email_from} <#{email_from}>",
         :body=>email_builder.render(
             :inline => nice_body(email.body),
             :locals => assigns),
         :content_type=>"text/#{email.format.to_s}"
    )
  end

  def nice_body(email_body)
    p = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$')}
    p = p.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    p.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s if Email::ALLOWED_VARIABLES.include?(s.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

  def UserMailer.create_umail(user, type, email,  options={})
    case type
    when 'sms_email_sent'
      tmail = UserMailer.sent_sms(options[:email_to_address], options[:to], options[:from], email, {:body=> options[:message]}).deliver
    when 'send_email'
      tmail = UserMailer.sent_my_email(options[:email_to_address], options[:from], email, options[:assigns]).deliver
    when 'send_email_with_attachment'
      tmail = UserMailer.sent_with_attachments(options[:email_to_address], options[:from], email, options[:attachments], options[:assigns]).deliver
    when 'send_all'
      variables = Email.email_variables(user)
      tmail = UserMailer.sent_my_email(options[:email_to_address], options[:from], email, variables).deliver
    end
    tmail
  end

end
