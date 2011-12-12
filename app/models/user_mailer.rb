class UserMailer < ActionMailer::Base
  
  #require 'pdf/writer'
  
  def sent(email_to, email_from, email, assigns = {})
    #MorLog.my_debug " #{email_to}, #{email_from}, #{email}, #{assigns}"    
    email_builder = ActionView::Base.new(nil,assigns)
    email_from = Confline.get_value("Email_from") if email_from.blank?
    recipients email_to
    subject    email.subject 
    from       "#{email_from} <#{email_from}>"
    content_type "text/#{email.format.to_s}"
    body email_builder.render(
      :inline => nice_body(email.body),
      :locals => assigns
    )
  end

  def nice_body(email_body)
    p = email_body.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s.gsub(/<%=/, '??!!@proc#@').gsub(/%>/, '??!!@proc#$')}
    p = p.gsub(/<%=|<%|%>/, '').gsub('??!!@proc#@', '<%=').gsub('??!!@proc#$', '%>')
    p.gsub(/(<%=?\s*\S+\s*%>)/) { |s| s if Email::ALLOWED_VARIABLES.include?(s.match(/<%=?\s*(\S+)\s*%>/)[1]) }
  end

=begin rdoc
 Sends email with attachments
 Atachemnt is Array of Hash elements each hash must have 3 elements:
 * +:content_type+ - string representing MIME type of file. "application/pdf" for PDF files, "text/csv" - CSV files.
 * +:file_name+ - name of the file.
 * +:file+ - content of the file.
=end

  def sent_with_attachments(email_to, email_from, email, attachments = [], assigns = {})
    email_builder = ActionView::Base.new(nil,assigns)

    recipients email_to
    subject    email.subject
    from       "#{email_from} <#{email_from}>"
    content_type "text/#{email.format.to_s}"
    body email_builder.render(
      :inline => nice_body(email.body),
      :locals => assigns
    )
    attachments.each {|attach|
      attachment :content_type => attach[:content_type], :filename =>attach[:filename] do |a|
        a.body = attach[:file]
      end
    }
  end
  
  
  def sent_sms(email_to, number, email_from, email, assigns = {})
    #    MorLog.my_debug("email_to = #{email_to}, number = #{number}, email_from = #{email_from}, email = #{email.id}, assigns = #{assigns.to_yaml}")
    email_builder = ActionView::Base.new(nil,assigns)
    #    email_from = Confline.get_value("Email_from")
    recipients email_to
    subject    number
    from       "#{email_from} <#{email_from}>"
    content_type "text/#{email.format.to_s}"
    body email_builder.render(
      :inline => nice_body(email.body),
      :locals => assigns
    )
    
    
  end
  

  def UserMailer.create_umail(user, type, email,  options={})
    case type
    when 'sms_email_sent'
      tmail = UserMailer.create_sent_sms(options[:email_to_address], options[:to], options[:from], email, {:body=> options[:message]})
    when 'send_email'
      tmail = UserMailer.create_sent(options[:email_to_address], options[:from], email, options[:assigns])
    when 'send_email_with_attachment'
      tmail = UserMailer.create_sent_with_attachments(options[:email_to_address], options[:from], email, options[:attachments], options[:assigns])     
    when 'send_all'
      variables = Email.email_variables(user)
      tmail = UserMailer.create_sent(options[:email_to_address], options[:from], email, variables)
    end
    tmail
  end

  def my_debug(msg)
    File.open(Debug_File, "a") { |f|
      f << msg.to_s
      f << "\n"
    }
  end 
  
end
