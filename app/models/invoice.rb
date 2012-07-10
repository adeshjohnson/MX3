# -*- encoding : utf-8 -*-
class Invoice < ActiveRecord::Base
  belongs_to :user
  belongs_to :payment
  has_many :invoicedetails
  belongs_to :tax, :dependent => :destroy

  before_destroy :check_send

  after_destroy :increase_user_balance

  include SqlExport
  include UniversalHelpers


  def check_send
    if invoice_was_send?
      errors.add(:send, _("Cannot_delete_Invoice_that_was_send"))
      return false
    end
  end

  def increase_user_balance
    # we should _decrease_ user's balance by payments amount, because it is deleted and user should owe more (because there are no payment)
    user = self.user
    payment = self.payment
    if payment
      user.balance -= payment.amount
      user.save
      payment.destroy
    end
    Action.add_action(User.current, "invoice_deleted", user.id.to_s)
  end

  def invoice_was_send?
    (sent_email == 1 or sent_manually == 1) and Confline.get_value("Invoice_allow_recalculate_after_send").to_i == 0
  end

  def price_with_tax(options = {})
    if options[:ex]
      if tax
        tax.apply_tax(converted_price(options[:ex]), options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f", converted_price_with_vat(options[:ex])).to_f
        else
          converted_price_with_vat(options[:ex])
        end
      end

    else
      if tax
        tax.apply_tax(price, options)
      else
        if options[:precision]
          format("%.#{options[:precision].to_i}f", price_with_vat).to_f
        else
          price_with_vat
        end
      end
    end
  end

  def tax_amount(options ={})
    if options[:ex]
      tax.count_tax_amount(converted_price(options[:ex]), options)
    else
      tax.count_tax_amount(price, options)
    end
  end

  def calls_price
    price = 0.0
    for invd in self.invoicedetails
      price += invd.price if invd.invdet_type == 0
    end
    price
  end

  def Invoice.filename(user, type, long_name, file_type)
    temp = (type == "prepaid" ? "Prepaid_" : "")
    use_short = Confline.get_value("#{temp}Invoice_Short_File_Name", user.owner_id).to_i
    use_short == 1 ? "#{user.first_name}_#{user.last_name}.#{file_type}" : "#{long_name}.#{file_type}"
  end

  def paid?;
    paid == 1;
  end

  # converted attributes for user in current user currency
  def price
    b = read_attribute(:price)
    b.to_f * User.current.currency.exchange_rate.to_f
  end

  def price_with_vat
    b = read_attribute(:price_with_vat)
    b.to_f * User.current.currency.exchange_rate.to_f
  end

  # converted attributes for user in given currency exrate
  def converted_price(exr)
    b = read_attribute(:price)
    b.to_f * exr.to_f
  end


  # converted attributes for user in given currency exrate
  def converted_price_with_vat(exr)
    b = read_attribute(:price_with_vat)
    b.to_f * exr.to_f
  end

=begin
  List of invoice financial data grouped by tryer status. should not be coding 
  application logic to query(IF(paid=...)), but since i dont like db structure the way it is..

  *Params*
  +owner_id+ owner of users that the user is interested in, but might be nil if 
     current user if ordinary user
  +user_id+ user that has invoices generated for him, might be nil if admin, 
     reseller or accountatn is not interested i certain user, but interested in all his users.
     BUT IF we are generating financial statemens for ordinary users, they cannot see other users
     information and must supply theyr own id
  +status+ valid status parameter would be 'paid' 'unpaid' or 'all', might be nil
     in that case all statuses would be selected
  +from_date, till_date+ dates as strings
  +ordinary_user+ if user is of type 'user' there is no need to join users table, but user_id mus
     be specified.

  *Returns*
  +invoices+ array or smht iterable of Invoice instances, that has count, price,
   price_with_vat and paid methods
=end
  def self.financial_statements(owner_id, user_id, status, from_date, till_date, ordinary_user=true)
    #if user not is of type 'user' he must supply user_id. or else invalid params are supplied
    if ordinary_user and not user_id
      raise "invalid parameters, 'user' must supply his own id"
    end

    condition = ["issue_date BETWEEN '#{from_date}' AND '#{till_date}'"]
    join = "JOIN taxes ON taxes.id = invoices.tax_id "
    if not ordinary_user
      join << "JOIN users ON users.id = invoices.user_id"
      condition << "owner_id = #{owner_id}"
    end
    condition << "user_id = #{user_id}" if user_id and user_id != 'all'
    if status != 'all' and ['paid', 'unpaid'].include? status
      condition << "paid = #{status == 'paid' ? 1 : 0}"
    end

    Struct.new('We', :count, :price, :price_with_vat, :status)
    paid = Struct::We.new(0, 0, 0, 'paid')
    unpaid = Struct::We.new(0, 0, 0, 'unpaid')

    invoices = Invoice.find(:all, :joins => join, :conditions => condition.join(" AND "))
    if invoices.size > 0
      invoices.each do |invoice|
        if invoice.paid?
          paid.price_with_vat += invoice.price_with_tax
          paid.price += invoice.price
          paid.count += 1
        else
          unpaid.price_with_vat += invoice.price_with_tax
          unpaid.price += invoice.price
          unpaid.count += 1
        end
      end
    end
    return paid, unpaid

    invoices = Invoice.find_by_sql(query)
  end


  #================================== PDF generation ===================================================================

  def generate_simple_pdf(current_user, dc, ex, nc, cde, gde, testing_mode = false)
    user = self.user
    prepaid, prep = self.new_invoice_type(user)
    type = (user.postpaid.to_i == 1 or self.user.owner_id != 0) ? "postpaid" : "prepaid"
    limit = Confline.get_value("#{type}Invoice_page_limit", user.owner).to_i
    company = Confline.get_value("Company", user.owner_id)

    idetails = self.invoicedetails

    nice_number_hash = {:change_decimal => cde, :global_decimal => gde, :nc => nc}

    options = self.genereate_options(current_user, ex)
    #    begin
    #
    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, company, current_user.currency.name)
    items = []
    idetails.each do |item|
      items << [
          item.nice_inv_name,
          item.quantity,
          {:text => self.nice_invoice_number(item.converted_price(ex), nice_number_hash).to_s, :align => :right},
          {:text => self.nice_invoice_number(((item.invdet_type > 0 and item.name != 'Calls') ? item.quantity * item.converted_price(ex) : item.converted_price(ex)), nice_number_hash).to_s, :align => :right}
      ]
    end

    n = 15 - items.size.to_i
    n.times { items << [' ', '', '', ''] } if n > 0

    items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 3, :align => :right, :borders => [:top]}, {:text => self.nice_invoice_number(user.converted_minimal_charge(ex).to_f, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}] if user.minimal_charge_enabled?
    items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 3, :align => :right, :borders => [:top]}, {:text => self.nice_invoice_number(self.converted_price(ex).to_f, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]

    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 1, dc)
    items += items_t
    items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 3, :align => :right, :border_width => 0}, {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]

    pdf.table(items,
              :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
              :font_size => 10,
              :headers => [_('Service'), _('Quantity'), _('Price') + " (#{current_user.currency.name})", _('Total') + " (#{current_user.currency.name})"],
              :align_headers => {0 => :left, 1 => :right, 2 => :right, 3 => :right},
              :column_widths => {0 => 300}) do
      column(0).style(:align => :left, :height => 15, :width => 450)
      column(1).style(:align => :right, :height => 15)
      column(2).style(:align => :right, :height => 15)
      column(3).style(:align => :right, :height => 15)
    end

    #    if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
    #      #        pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id), {:page=>page+1, :pages=>pages})
    #    end

    pdf.bounding_box([0, pdf.cursor + up_string],
                     :width => 450) do
      pdf = PdfGen::Generate.invoice_footer_pdf(pdf, self, {:show_end_title => true})
    end

    pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 12], :width => pdf.bounds.width do
      pdf.text Confline.get_value("#{prepaid}Invoice_End_Title", user.owner), :size => 12, :align => :center
    end


    pdf = pdf_end(pdf, options)


    test_return = testing_mode ? items : []
    return pdf, test_return
  end

  def generate_invoice_detailed_pdf(current_user, dc, ex, nc, cde, gde, show_avg_rate, testing_mode = false)
    nice_number_hash = {:change_decimal => cde, :global_decimal => gde, :nc => nc}

    options = self.genereate_options(current_user, ex)
    user = options[:user]
    #    begin
    #
    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, options[:company], current_user.currency.name)
    items = []

    total_time = 0
    total_price = 0
    total_calls = 0

    invoicedetails.map do |item|
      if item.invdet_type > 0 and item.name != 'Calls'
        ii = []
        ii << item.nice_inv_name
        ii << ' '
        ii << item.quantity
        ii << ' '
        if options[:show_avg_rate] == 1
          ii << ' '
        end
        ii << {:text => self.nice_invoice_number((item.quantity * item.converted_price(ex)), nice_number_hash).to_s, :align => :right}
        items << ii
      end
    end
    dgids = []

    calls, r_calls = self.direction_calls(options)
    calls.each do |item|
      ii = []
      ii << item['dg_name']
      ii << item['dg_type']
      ii << item['calls']
      ii <<{:text => nice_time(item['billsec'], options[:min_type]).to_s, :align => :center}
      if options[:show_avg_rate] == 1
        ii << {:text => nice_invoice_number((item["price"].to_f / (item["billsec"].to_f / 60).to_f)).to_s, :align => :center}
      end
      ii << {:text => nice_invoice_number(item['price'], nice_number_hash).to_s, :align => :right}

      items << ii
      dgids << [item["dgid"], item["user_rate"]] if !dgids.include?([item["dgid"], item["user_rate"]])
      total_time += item['billsec']
      total_price += item['price']
      total_calls += item['calls']
    end

    if user.usertype == "reseller"
      r_calls.each do |item|
        ii = []
        ii << item['dg_name']
        ii << item['dg_type']
        ii << item['calls']
        ii << {:text => nice_time(item['billsec'], options[:min_type]).to_s, :align => :center}
        if options[:show_avg_rate] == 1
          ii << {:text => nice_invoice_number((item["price"].to_f / (item["billsec"].to_f / 60).to_f)).to_s, :align => :center}
        end
        ii << {:text => nice_invoice_number(item['price'], nice_number_hash).to_s, :align => :right}
        items << ii
        dgids << [item["dgid"], item["user_rate"]] if !dgids.include?([item["dgid"], item["user_rate"]])
        total_time += item['billsec']
        total_price += item['price']
        total_calls += item['calls']
      end
    end


    n = 15 - dgids.size.to_i

    if options[:show_avg_rate] == 1
      n.times { items << [' ', '', '', '', '', ''] } if n > 0
      items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(user.converted_minimal_charge(ex).to_f))] if user.minimal_charge_enabled?
      items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(self.converted_price(ex)))]
    else
      n.times { items << [' ', '', '', '', ''] } if n > 0
      items << [{:text => _('Minimal_Charge_for_Calls') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(user.converted_minimal_charge(ex).to_f))] if user.minimal_charge_enabled?
      items << [{:text => _('SUBTOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :borders => [:top]}, nice_cell(' '), nice_cell(' '), nice_cell(self.nice_invoice_number(self.converted_price(ex)))]
    end
    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 2, dc, options[:show_avg_rate])

    items += items_t

    if options[:show_avg_rate] == 1
      items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :border_width => 0}, nice_cell(total_calls), nice_cell(nice_time(total_time, options[:min_type])), nice_cell(' '), {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    else
      items << [{:text => _('TOTAL') + " (#{dc})", :background_color => "FFFFFF", :colspan => 2, :align => :right, :border_width => 0}, nice_cell(total_calls), nice_cell(nice_time(total_time, options[:min_type])), {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all}]
    end

    if options[:show_avg_rate] == 0
      pdf.table(items,
                :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
                :font_size => 10,
                :headers => [_('Direction'), ' ', _('Calls'), _('Time'), _('Total') + " (#{current_user.currency.name})"],
                :align_headers => {0 => :left, 1 => :center, 2 => :right, 3 => :center, 4 => :right},
                :column_widths => {0 => 300}) do
        column(0).style(:align => :left, :height => 15)
        column(1).style(:align => :center, :height => 15)
        column(2).style(:align => :right, :height => 15)
        column(3).style(:align => :center, :height => 15)
        column(4).style(:align => :right, :height => 15)
      end
    else
      pdf.table(items,
                :row_colors => ["FFFFFF", "DDDDDD"], :width => 550,
                :font_size => 10,
                :headers => [_('Direction'), ' ', _('Calls'), _('Time'), _('Avg_rate'), _('Total') + " (#{current_user.currency.name})"],
                :align_headers => {0 => :left, 1 => :center, 2 => :right, 3 => :center, 4 => :right, 5 => :right},
                :column_widths => {0 => 300}) do
        column(0).style(:align => :left, :height => 15)
        column(1).style(:align => :center, :height => 15)
        column(2).style(:align => :right, :height => 15)
        column(3).style(:align => :center, :height => 15)
        column(4).style(:align => :right, :height => 15)
        column(5).style(:align => :right, :height => 15)
      end
    end

    #    if Confline.get_value("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id).to_i == 1
    #      #        pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{prepaid}Invoice_show_additional_details_on_separate_page",user.owner_id), {:page=>page+1, :pages=>pages})
    #    end

    pdf.bounding_box([0, pdf.cursor + up_string],
                     :width => 450) do
      pdf = PdfGen::Generate.invoice_footer_pdf(pdf, self, {:show_end_title => true})
    end

    pdf.bounding_box [pdf.bounds.left, pdf.bounds.bottom + 12], :width => pdf.bounds.width do
      pdf.text Confline.get_value("#{options[:prepaid]}Invoice_End_Title", user.owner), :size => 12, :align => :center
    end

    has_calls = 0
    for invd in invoicedetails
      has_calls = 1 if invd.invdet_type == 0
    end

    if Confline.get_value("#{options[:prepaid]}Invoice_Show_Calls_In_Detailed", user.owner_id).to_i == 1 and has_calls == 1

      items2 = []
      logger.fatal dgids.size
      dgids.each { |dca|
        calls2, rcalls = self.direction_calls_by_direction(current_user, dca[0], dca[1], options)
        tcalls = 0
        tprice = 0
        if calls2.size > 0 or (user.usertype == "reseller" and rcalls.size > 0)
          if (calls2.size > 0)
            items2 << [{:text => calls2[0]["dg_name"].to_s + " " + calls2[0]["dg_type"].to_s}, '', '', ''] if options[:tariff_purpose] == "user"
            items2 << [{:text => calls2[0]["dg_name"].to_s + " " + calls2[0]["prefix"].to_s + " " + calls2[0]["dg_type"].to_s}, '', '', ''] if options[:tariff_purpose] != "user"
            items2 << [_('Calldate'), _('Billsec'), _('Destination'), _('Price') + " (#{dc})"]
            calls2.each do |item|
              items2 << [
                  item['calldate'],
                  item["#{options[:billsec_cond]}"],
                  item['dst'].to_s.strip,
                  nice_invoice_number(item["user_price"].to_f, nice_number_hash).to_s
              ]
              tprice += item["user_price"].to_f
              tcalls += calls2.size.to_i
            end
          end
        end
        if (user.usertype == "reseller" and rcalls.size > 0)
          if (rcalls.size > 0)

            items2 << [{:text => rcalls[0]["dg_name"].to_s + " " + rcalls[0]["dg_type"].to_s}, '', '', ''] if options[:tariff_purpose] == "user"
            items2 << [{:text => rcalls[0]["dg_name"].to_s + " " + rcalls[0]["prefix"].to_s + " " + rcalls[0]["dg_type"].to_s}, '', '', ''] if options[:tariff_purpose] != "user"
            items2 << [_('Calldate'), _('Billsec'), _('Destination'), _('Price') + " (#{dc})"]
            rcalls.each do |item|
              items2 << [
                  item['calldate'],
                  item["#{options[:billsec_cond]}"],
                  item['dst'].to_s.strip,
                  nice_invoice_number(item["reseller_price"].to_f, nice_number_hash).to_s
              ]
              tprice += item["reseller_price"].to_f
              tcalls += rcalls.size.to_i
            end

          end
        end
        items2 << [_('Total_calls_invoice') + ": " + tcalls.size.to_s + ", " + _('price_invoice') + ": " + nice_invoice_number(tprice).to_s + " (" + nice_invoice_number(user.get_tax.count_tax_amount(tprice)).to_s + ")"]
        items2 << [' ', '', '', '']
      }

      pdf.table(items2,
                :width => 550,
                :font_size => 5, :border_width => 0, :vertical_padding => 1,
                :align => {0 => :left, 1 => :right, 2 => :left, 3 => :right})


    end

    pdf = pdf_end(pdf, options)
    test_return = testing_mode ? items : []
    return pdf, test_return
  end

  def genereate_options(current_user, ex)
    owner = self.user.owner
    prepaid = (invoice_type.to_s == 'prepaid' and self.user.owner == 0) ? "Prepaid_" : ""
    user = self.user
    up, rp, pp = user.get_price_calculation_sqls
    opt = {
        :user => user,
        :tariff_purpose => user.tariff.purpose,
        :format => Confline.get_value('Date_format', current_user.owner_id).gsub('M', 'i'),
        :user_price => SqlExport.replace_price(up, {:ex => ex}),
        :reseller_price => SqlExport.replace_price(rp, {:ex => ex}),
        :did_price => SqlExport.replace_price('calls.did_price', {:ex => ex, :reference => 'did_price'}),
        :did_sql_price => SqlExport.replace_price('calls.did_price', {:ex => ex, :reference => 'did_price'}),
        :did_inc_sql_price => SqlExport.replace_price('calls.did_inc_price', {:ex => ex, :reference => 'did_inc_price'}),
        :selfcost => SqlExport.replace_price(pp, {:ex => ex, :reference => 'selfcost'}),
        :user_rate => SqlExport.replace_price('calls.user_rate', {:ex => ex, :reference => 'user_rate'}),
        :zero_calls_sql => user.invoice_zero_calls.to_i == 0 ? " AND calls.user_price > 0 " : "",
        :owner => owner,
        :prepaid => prepaid,
        :limit => Confline.get_value("#{prepaid}Invoice_page_limit", owner).to_i,
        :min_type => (Confline.get_value("#{prepaid}Invoice_Show_Time_in_Minutes", owner).to_i == 1) ? 1 : 0,
        :show_avg_rate => (Confline.get_value("#{prepaid}Invoice_Add_Average_rate", owner).to_i == 1) ? 1 : 0,
        :billsec_cond => Confline.get_value("#{prepaid}Invoice_user_billsec_show", owner).to_i == 1 ? 'user_billsec' : 'billsec',
        :company => Confline.get_value("Company", user.owner_id)
    }
  end

  def direction_calls(options={})

    if options[:tariff_purpose] == "user"

      sql = "SELECT destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{options[:user_price]}) as 'price', #{options[:user_rate]}, #{options[:did_price]}  " +
          "FROM calls "+
          "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) "+
          "JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql}
          WHERE calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
          " AND card_id = 0 AND (devices.user_id = '#{options[:user].id}' ) #{options[:zero_calls_sql]}" +
          "GROUP BY destinationgroups.id , calls.user_rate "+
          "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"

      if options[:user].usertype == "reseller"
        sql2 = "SELECT destinationgroups.id as 'dgid', destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type',  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{options[:reseller_price]}) as 'price', #{options[:user_rate]}, #{options[:did_price]}  " +
            "FROM calls "+
            "LEFT JOIN destinations ON (destinations.prefix = calls.prefix) JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} "+
            "WHERE calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' " +
            " AND card_id = 0 AND (calls.reseller_id = '#{options[:user].id}' ) #{options[:zero_calls_sql]}" +
            "GROUP BY destinationgroups.id, calls.user_rate "+
            "ORDER BY destinationgroups.name ASC, destinationgroups.desttype ASC"
      end
    else
      #wholesale

      sql = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type',  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{options[:user_price]}) as 'price', #{options[:did_price]}  FROM calls 	JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix) 	JOIN directions  ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED'  AND card_id = 0 AND (devices.user_id =  '#{options[:user].id}' ) #{options[:zero_calls_sql]} GROUP BY destinations.id, calls.user_rate ORDER BY destinations.name ASC, destinations.subcode ASC"

      if options[:user].usertype == "reseller"
        sql2 = "SELECT calls.user_rate as 'user_rate', destinations.id as 'dgid',  directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type',  COUNT(*) as 'calls', SUM(#{options[:billsec_cond]}) as 'billsec', #{options[:selfcost]}, SUM(#{options[:reseller_price]}) as 'price', #{options[:did_price]}  FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id)  LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN directions  ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59'  AND calls.disposition = 'ANSWERED'  AND card_id = 0 AND (calls.reseller_id =  '#{options[:user].id}' )  #{options[:zero_calls_sql]} GROUP BY destinations.id, calls.user_rate ORDER BY destinations.name ASC, destinations.subcode ASC"
      end
    end


    res = ActiveRecord::Base.connection.select_all(sql)

    if options[:user].usertype == "reseller"
      res2 = ActiveRecord::Base.connection.select_all(sql2)
    end

    return res, res2
  end

  def tax_items(ex, nc, nice_number_hash, type, dc, show_avg_rate = 0)
    items = []
    tax = self.tax

    tax = self.user.get_tax unless tax
    logger.fatal tax.to_yaml
    tax_amount = 0
    up_string = 60
    font = 6
    colspain = type == 1 ? 3 : 2
    if self.tax
      taxes = tax.applied_tax_list(self.converted_price(ex), :precision => nc)
      logger.fatal taxes.to_yaml
      taxes.each { |tax_hash|
        if tax.get_tax_count > 0
          up_string += 10
          aa = []
          aa << nice_cell(' ', font) if type == 3
          aa << nice_cell(' ', font) if type == 3
          aa << {:text => tax_hash[:name].to_s+ ": " + tax_hash[:value].to_s + " %", :background_color => "FFFFFF", :colspan => colspain, :align => :right, :border_width => 0, :font_size => font}
          aa << nice_cell(' ', font) if type == 2
          aa << nice_cell(' ', font) if type == 2
          if show_avg_rate == 1
            aa << nice_cell(' ', font) if type == 2
          end
          aa << {:text => self.nice_invoice_number(tax_hash[:tax], nice_number_hash).to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all, :font_size => font}
          aa << {:text => dc} if type == 3
          items << aa
        end
        tax_amount += self.nice_invoice_number(tax_hash[:tax], nice_number_hash.merge({:no_repl => 1})).to_f

      }
      price_with_tax = self.nice_invoice_number(self.converted_price(ex), nice_number_hash.merge({:no_repl => 1})).to_f+tax_amount.to_f
    else
      price_with_tax = self.nice_invoice_number(self.converted_price_with_vat(ex), nice_number_hash.merge({:no_repl => 1})).to_f
      tax_amount = price_with_tax - self.converted_price(ex)
    end

    return items, up_string, tax_amount, price_with_tax
  end


  def direction_calls_by_direction(current_user, dgid, user_rate_s, options = {})

    logger.fatal dgid
    dst = options[:email_or_not] ? hide_dst_for_user_sql(options[:user], "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"}) : hide_dst_for_user_sql(current_user, "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"})

    calldate = SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => options[:format], :tz => current_user.time_zone}), "calldate")

    if options[:tariff_purpose] == "user"

      sql = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type', #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id = #{dgid}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s}) ORDER BY calls.calldate ASC"

      if options[:user].usertype == "reseller"
        sql2 = "SELECT destinationgroups.id, destinationgroups.flag as 'dg_flag', destinationgroups.name as 'dg_name', destinationgroups.desttype as 'dg_type', #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  JOIN destinationgroups ON (destinations.destinationgroup_id = destinationgroups.id AND destinationgroups.id = #{dgid}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (calls.reseller_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s} ) ORDER BY calls.calldate ASC"
      end

    else
      sql = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type', #{calldate}, calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls 	JOIN devices ON (calls.src_device_id = devices.id OR calls.dst_device_id = devices.id) LEFT JOIN destinations ON (destinations.prefix = calls.prefix)  	JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id = #{dgid}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (devices.user_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s}) ORDER BY calls.calldate ASC"
      if options[:user].usertype == "reseller"
        sql2 = "SELECT destinations.id, directions.name as 'dg_name', destinations.prefix, destinations.subcode as 'dg_type', #{calldate},  calls.#{options[:billsec_cond]}, #{options[:user_price]} as user_price, #{options[:reseller_price]} as reseller_price, #{dst}  FROM calls   LEFT JOIN destinations ON (destinations.prefix = calls.prefix)    JOIN directions  ON (destinations.direction_code = directions.code AND destinations.id = #{dgid}) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.calldate BETWEEN '#{ period_start} 00:00:00' AND '#{ period_end} 23:59:59'  AND calls.disposition = 'ANSWERED' AND card_id = 0  AND (calls.reseller_id = #{ options[:user].id} AND calls.user_rate = #{user_rate_s}) ORDER BY calls.calldate ASC"
      end
    end

    res = ActiveRecord::Base.connection.select_all(sql)

    if options[:user].usertype == "reseller"
      res2 = ActiveRecord::Base.connection.select_all(sql2)
    end

    return res, res2
  end

  def generate_invoice_by_cid_pdf(current_user, dc, ex, nc, cde, gde, testing_mode = false)
    nice_number_hash = {:change_decimal => cde, :global_decimal => gde, :nc => nc}

    options = self.genereate_options(current_user, ex)
    user = options[:user]

    sql = "SELECT calls.src, #{options[:did_sql_price]}, #{options[:did_inc_sql_price]} FROM calls JOIN devices ON (calls.src_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{options[:zero_calls_sql]} GROUP BY calls.src;"

    cids = ActiveRecord::Base.connection.select_all(sql)
    items = []
    dst = options[:email_or_not] ? hide_dst_for_user_sql(options[:user], "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"}) : hide_dst_for_user_sql(current_user, "pdf", SqlExport.column_escape_null("calls.localized_dst"), {:as => "dst"})
    calldate = SqlExport.column_escape_null(SqlExport.nice_date('calls.calldate', {:format => options[:format], :tz => current_user.time_zone}), "calldate")
    ttp = 0
    for cid in cids
      src = cid["src"]
      if cid["did_price"].to_f == 0.to_f and cid["did_inc_price"].to_f == 0.to_f
        sql = "SELECT #{dst}, #{calldate}, #{options[:billsec_cond]} as billsec, #{options[:did_inc_sql_price]}, #{options[:did_sql_price]}, #{options[:user_rate]}, #{options[:user_price]} as 'user_price', directions.name as 'direction' FROM calls #{SqlExport.left_join_reseler_providers_to_calls_sql} LEFT JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND calls.disposition = 'ANSWERED'  AND billsec > 0 AND card_id = 0  AND calls.src = '#{src}' #{options[:zero_calls_sql]} ORDER BY calls.calldate ASC"
      else
        sql = "SELECT #{dst}, #{calldate}, #{options[:billsec_cond]} as billsec, #{options[:did_sql_price]}, #{options[:did_inc_sql_price]}, #{options[:user_rate]}, #{options[:user_price]} as 'user_price', directions.name as 'direction' FROM calls #{SqlExport.left_join_reseler_providers_to_calls_sql} JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_inc_price > 0 AND calls.src = '#{src}' ORDER BY calls.calldate ASC;"
      end
      calls = ActiveRecord::Base.connection.select_all(sql)

      items << [_('Client_number') + ": ", src, '', '', '', '']
      items << [' ', '', '', '', '', '']

      items << [_('Number'), _('Date'), _('Duration'), _('Rate'), _('Price') + " (#{dc})", _('Destination')]

      calls.each do |item|
        items << [
            item['dst'],
            item["calldate"],
            nice_time(item["billsec"], options[:min_type]),
            nice_invoice_number(item["user_rate"], nice_number_hash),
            nice_invoice_number(item["user_price"], nice_number_hash),
            item["direction"].to_s
        ]
      end


      if cid["did_price"].to_f == 0.to_f and cid["did_inc_price"].to_f == 0.to_f
        sql = "SELECT directions.name as 'direction', SUM(#{options[:user_price]}) as 'price', COUNT(calls.src) as 'calls' FROM calls LEFT JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND card_id = 0  AND calls.src = '#{src}' GROUP BY directions.name ORDER BY directions.name ASC"
      else
        sql = "SELECT directions.name as 'direction', SUM(#{options[:user_price]}) as 'price', COUNT(calls.src) as 'calls' FROM calls JOIN devices ON (calls.src_device_id = devices.id) LEFT JOIN destinations ON (calls.prefix = destinations.prefix) LEFT JOIN directions ON (destinations.direction_code = directions.code) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE calls.card_id = 0 AND disposition = 'ANSWERED'  AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND devices.user_id = '#{user.id}' AND calls.did_inc_price > 0 AND calls.src = '#{src}' GROUP BY directions.name ORDER BY directions.name ASC"
      end
      directions = ActiveRecord::Base.connection.select_all(sql)

      total_price = 0.0
      items << [' ', '', '', '', '', '']
      directions.each do |item|
        items << [
            '',
            '',
            '',
            item['direction'],
            nice_invoice_number(item["price"], nice_number_hash),
            dc.to_s + " (" + _('Without_VAT') + ")"
        ]
        total_price += item["price"].to_f
      end

      items << ['', '', '', _('Total') + ":", nice_invoice_number(total_price, nice_number_hash), dc.to_s + " (" + _('Without_VAT') + ")"]
      items << [' ', '', '', '', '', '']
      ttp += total_price.to_f
    end

    sql = "SELECT COUNT(calls.id) as calls_size, SUM(#{options[:billsec_cond]}) as billsec, SUM(#{options[:user_price]}) as 'user_price' FROM calls JOIN devices ON (calls.dst_device_id = devices.id) #{SqlExport.left_join_reseler_providers_to_calls_sql} WHERE devices.user_id = #{user.id} AND calls.calldate BETWEEN '#{period_start} 00:00:00' AND '#{period_end} 23:59:59' AND calls.disposition = 'ANSWERED' AND billsec > 0 AND card_id = 0 #{options[:zero_calls_sql]};"

    in_calls = ActiveRecord::Base.connection.select_all(sql)

    if in_calls and in_calls[0]['calls_size'].to_i > 0
      items << [_('incoming_calls'), _('Duration'), _('Price') + " (#{dc})", '', '', '']
      items << ['', nice_time(in_calls[0]["billsec"], options[:min_type]), nice_invoice_number(in_calls[0]["user_price"], nice_number_hash), '', '', '']
      ttp += in_calls[0]["user_price"].to_f
      items << [' ', '', '', '', '', '']
    end


    if invoicedetails and invoicedetails.size.to_i > 0
      for id in invoicedetails
        if id.invdet_type > 0 and id.name != 'Calls'

          items << ['', {:text => id.nice_inv_name, :colspan => 3}, self.nice_invoice_number((id.quantity * id.converted_price(ex)), nice_number_hash).to_s, dc.to_s + " (" + _('Without_VAT') + ")"]
          ttp += id.price.to_f
        end
      end
      items << [' ', '', '', '', '', '']
    end

    items << ['', {:text => _('SUBTOTAL') + ":", :colspan => 3, :align => :right}, nice_cell(self.nice_invoice_number(self.converted_price(ex))), dc.to_s + " (" + _('Without_VAT') + ")"]
    items_t, up_string, tax_amount, price_with_tax = tax_items(ex, nc, nice_number_hash, 3, dc, options[:show_avg_rate])
    items += items_t
    items << ['', {:text => _('TOTAL')+ ":", :colspan => 3, :align => :right}, {:text => self.nice_invoice_number(price_with_tax, nice_number_hash).to_s, :align => :right}, dc]


    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf = PdfGen::Generate.invoice_header_pdf(self, pdf, options[:company], current_user.currency.name)


    items << [' ', '', '', '', '', ''] if items.size.to_i < 1

    pdf.table(items,
              :width => 550,
              :font_size => 5, :border_width => 0, :vertical_padding => 1,
              :align => {0 => :left, 1 => :right, 2 => :left, 3 => :right})

    pdf = pdf_end(pdf, options)

    test_return = testing_mode ? items : []
    return pdf, test_return
  end

  def new_invoice_type(user)
    if invoice_type.to_s == 'prepaid' and user.owner_id == 0
      return "Prepaid_", "prepaid"
    else
      return "", "postpaid"
    end
  end

  def pdf_end(pdf, options)
    if Confline.get_value("#{options[:prepaid]}Invoice_show_additional_details_on_separate_page", options[:owner].id).to_i == 1
      pdf = PdfGen::Generate.generate_additional_details_for_invoice_pdf(pdf, Confline.get_value2("#{options[:prepaid]}Invoice_show_additional_details_on_separate_page", options[:owner].id))
    end
    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt
    return pdf
  end


  def nice_cell(text, font = nil)
    {:text => text.to_s, :background_color => "FFFFFF", :align => :right, :border_style => :all, :font_size => font}
  end


  def nice_invoice_number(number, options = {})
    nc = options[:nc] ? options[:nc] : 2
    n = sprintf("%0.#{nc}f", number.to_f) if number
    if options[:change_decimal] and options[:no_repl].to_i == 0
      n = n.gsub('.', options[:global_decimal])
    end
    n
  end

  def nice_time(time, type)
    if type.to_i == 0
      nice_time_inv(time)
    else
      nice_time_in_minits(time)
    end
  end

  def nice_time_in_minits(time)
    time = time.to_i
    return "" if time == 0
    m = time / 60
    s = time - (60 * m)
    good_date(m) + ":" + good_date(s)
  end

  def nice_time_inv(time)
    time = time.to_i
    return "" if time == 0
    h = time / 3600
    m = (time - (3600 * h)) / 60
    s = time - (3600 * h) - (60 * m)
    good_date(h) + ":" + good_date(m) + ":" + good_date(s)
  end

  # adding 0 to day or month <10
  def good_date(dd)
    dd = dd.to_s
    dd = "0" + dd if dd.length<2
    dd
  end

  def owned_balance_from_previous_month
    user = self.user
    # check if invoice is for whole month
    first_day = self.period_start.to_s[8, 2]
    last_day = self.period_end.to_s[8, 2]
    year = self.period_start.to_s[0, 4]
    month = self.period_start.to_s[5, 2].to_i.to_s #remove leading 0

    if first_day.to_i == 1 and last_day.to_i == Invoice.last_day_of_month(year, month).to_i
      # get balance from actions for last month
      action = Action.find(:first, :conditions => "user_id = #{self.user_id} AND action = 'user_balance_at_month_end' AND data = '#{year}-#{month}'")
      if action
        # count invoice details price in invoice
        #inv_details_price = 0.0
        #inv_details = invoice.invoicedetails
        #inv_details.each{|id| inv_details_price += id.price.to_f if id.invdet_type > 0}

        # count calls price in invoice
        inv_calls_price = 0.0
        inv_details = self.invoicedetails
        inv_details.each { |id| inv_calls_price += id.price.to_f if id.invdet_type == 0 }

        # count balance
        #balance = sprintf("%0.#{2}f", user.balance.to_f + user.get_tax.count_tax_amount(user.balance.to_f ))
        #owned_balance = action.data2.to_f - inv_details_price.to_f
        owned_balance = (action.data2.to_f * (-1)) - inv_calls_price.to_f

        balance_with_tax = owned_balance.to_f + user.get_tax.count_tax_amount(owned_balance.to_f)
        return [owned_balance, balance_with_tax]
      else
        MorLog.my_debug("Balance will not be shown because not found balance at the end of month, invoice id: #{id}")
        return nil
      end
    else
      MorLog.my_debug("Balance will not be shown because invoice is not for whole month, invoice id: #{id}")
      return nil
    end
  end

  def Invoice.last_day_of_month(year, month)

    year = year.to_i
    month = month.to_i

    if (month == 1) or (month == 3) or (month == 5) or (month == 7) or (month == 8) or (month == 10) or (month == 12)
      day = "31"
    else
      if  (month == 4) or (month == 6) or (month == 9) or (month == 11)
        day = "30"
      else
        if year % 4 == 0
          day = "29"
        else
          day = "28"
        end
      end
    end
    day
  end

end
