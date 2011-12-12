class CcInvoice < ActiveRecord::Base
  belongs_to :payment
  belongs_to :ccorder

=begin rdoc
 Finds and returns User that is owner of this invoice.
=end

  def owner
    User.find(:first, :conditions => ["id = ?", owner_id])
  end

=begin rdoc
 Creates CcInvoice from order details.
=end

  def CcInvoice.invoice_from_order(order, payment = nil)
    if !payment
      payment = Payment.find(:first, :conditions => ["transaction_id = ?", order.transaction_id])
    end
    invoice = CcInvoice.new
    invoice.ccorder = order
    invoice.paid_date = payment.date_added
    invoice.number = self.get_next_number(payment.owner_id)
    if payment
      invoice.payment = payment
      invoice.paid = 1
    else
      invoice.payment = nil
      invoice.paid = 0
    end
    invoice.save
  end

=begin rdoc
 Returns next invoice number for owner.

 *Params*

 owner_id - user_id that issued invoice.

 *Returns*

 invoice_number - string that represents next invoice number.
=end

  def CcInvoice.get_next_number(owner_id)
    start = Confline.get_value("Calling_Card_Invoice_Number_Start", owner_id)
    length = Confline.get_value("Calling_Card_Invoice_Number_Length", owner_id).to_i
    invoice = CcInvoice.find(:first,:select => "number", :conditions => "owner_id = #{owner_id} AND number REGEXP '#{start.to_i}[[:digit:]]{#{length.to_i}}'", :order => "number DESC")
    if invoice
      num = invoice.number.gsub(start, "").to_i+1
    else
      num = 1
    end
    invoice_number = start
    zl = length - num.to_s.length
    zl.times {
      invoice_number+= "0"
    }
    invoice_number+= num.to_s
    invoice_number
  end
end