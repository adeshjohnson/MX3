# -*- encoding : utf-8 -*-
require 'application_helper'
include ApplicationHelper

module PdfGen
  module Generate

    def Generate.call_list_to_pdf_header_basic
      [_('date'), _('called_from'), _('called_to'), _('duration'), _('hangup_cause')]
    end


    def Generate.call_list_to_pdf_header(pdf, direction, usertype, i, options)
      top_options = {
          :rowspan => 2
      }
      top_options2 = {
          :colspan => 3
      }

      headers = [{:text => _('date')}.merge(top_options),
                 {:text => _('called_from')}.merge(top_options),
                 {:text => _('called_to')}.merge(top_options),
                 {:text => _('duration')}.merge(top_options)]
      headers << {:text => _('hangup_cause')}.merge(top_options)  if usertype != 'user'
      headers2 = [{:text =>'', :colspan => usertype != 'user' ? 6 : 5}]

      if options[:pdf_last_calls].to_i == 1
        if ['admin', 'accountant'].include?(usertype)
          headers << {:text => _('Server')}.merge(top_options)
          headers << {:text => _('Provider')}.merge(top_options2)
          #--------------------- rate price name

          headers2 << {:text => _('Name')}
          headers2 << {:text => _('Rate')}
          headers2 << {:text => _('Price')}
          #headers << headers2
          if options[:rs_active]
            headers << {:text => _('Reseller')}.merge(top_options2)
            #--------------------- rate price name
            headers2 << {:text => _('Name')}
            headers2 << {:text => _('Rate')}
            headers2 << {:text => _('Price')}
          end
          headers << {:text => _('User')}.merge(top_options2)
          #--------------------- rate price name
          headers2 << {:text => _('Name')}
          headers2 << {:text => _('Rate')}
          headers2 << {:text => _('Price')}

          headers << {:text => _('Did'), :colspan => 4}
          #--------------------- rate price name

          headers2 << {:text => _('Number')}
          headers2 << {:text => _('Provider')}
          headers2 << {:text => _('Incoming')}
          headers2 << {:text => _('Owner')}
          #  headers << headers2
        end
        if usertype == 'reseller'
          if options[:reseller_allow_providers_tariff]
            headers << {:text => _('Provider')}.merge(top_options2)
            #--------------------- rate price name
            headers2 << _('Name')
            headers2 << {:text => _('Rate')}
            headers2 << {:text => _('Price')}
          end
          headers << {:text => _('Selfcost')}.merge(top_options2) if options[:rs_active]
          headers2 << {:text => _('Rate')}
          headers2 << {:text => _('Price')}
          headers2 << {:text => _('User')}
          #--------------------- rate price name
          headers2 << {:text => _('Name')}
          headers2 << {:text => _('Rate')}
          headers2 << {:text => _('Price')}
          headers2 << {:text => _('Did')}
          #--------------------- rate price name
          headers << {:text => _('Number')}.merge(top_options)
        end
        if usertype == 'user'
          headers << {:text => _('Prefix_used')}.merge(top_options)
          headers << {:text => _('Price')}.merge(top_options)
        end
      else
        if usertype == "admin"
          if direction == "incoming"
            headers << {:text => _('Provider')}.merge(top_options)
            headers << {:text => _('Incoming')}.merge(top_options)
            headers << {:text => _('Owner')}.merge(top_options)
            headers << {:text => _('Profit')}.merge(top_options)
          else
            headers << {:text => _('Price')}.merge(top_options)
            headers << {:text => _('Provider_price')}.merge(top_options)
            headers << {:text => _('Profit')}.merge(top_options)
            headers << {:text => _('Margin')}.merge(top_options)
            headers << {:text => _('Markup')}.merge(top_options)
          end
        end

        if usertype == "reseller"
          if direction == "incoming"
            headers << {:text => _('Price')}.merge(top_options)
          else
            headers << {:text => _('Price')}.merge(top_options)
            headers << {:text => _('Provider_price')}.merge(top_options)
            headers << {:text => _('Profit')}.merge(top_options)
            headers << {:text => _('Margin')}.merge(top_options)
            headers << {:text => _('Markup')}.merge(top_options)
          end
        end

        if usertype == "user"
          #if direction != "incoming"
          headers << {:text => _('Price')}.merge(top_options)
          #end
        end
      end


      return headers, headers2
    end

=begin rdoc

=end

    def Generate.providers_calls_to_pdf_header
      headers = call_list_to_pdf_header_basic
      headers << _('User_price')
      headers << _('Provider_price')
      headers << _('Profit')

      headers
    end

    def Generate.providers_calls_to_pdf(provider, calls, options)

      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true

      ###### Generate PDF ########
      pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
      pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

      pdf.text(_('CDR_Records') + ": #{provider.name}", {:left => 40, :size => 16})
      pdf.text(_('Call_type') + ": " + options[:call_type], {:left => 40, :size => 10})
      pdf.text(_('Period') + ": " + options[:date_from] + "  -  " + options[:date_till], {:left => 40, :size => 8})
      pdf.text(_('Currency') + ": #{options[:currency]}", {:left => 40, :size => 8})
      pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

      total_price = 0
      total_billsec = 0
      exrate = Currency.count_exchange_rate(options[:default_currency], options[:currency])

      items = []
      for call in calls
        item = []
        rate_cur, rate_cpr = Rate.get_provider_rate(call, options[:direction], exrate)
        item << call.calldate.strftime("%Y-%m-%d %H:%M:%S")
        item << call.src
        item << call.dst

        if @direction == "incoming"
          billsec = call.did_billsec
        else
          billsec = call.billsec
        end

        if billsec == 0
          item << "00:00:00"
        else
          pitem << nice_time(billsec)
        end
        item << call.disposition
        item << nice_number(rate_cur, {:nice_number_digits => options[:nice_number_digits]})
        item << nice_number(rate_cpr, {:nice_number_digits => options[:nice_number_digits]})
        user_price = 0
        user_price = rate_cur if call.user_price
        provider_price = 0
        provider_price = rate_cpr if provider_price
        item << nice_number(user_price - provider_price, {:nice_number_digits => options[:nice_number_digits]})


        total_price +=rate_cur if call.user_price
        total_billsec += call.billsec
        items << item
      end
      item = []
      item << _('Profit')
      if total_billsec == 0
        item << "00:00:00"
      else
        item << nice_time(total_billsec)
      end
      item << nice_number(total_price, options)

      items << item

      headers = Generate.providers_calls_to_pdf_header

      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 6,
                :headers => headers) do
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf

    end


    # ******************************************** Rates ###############################################################

    def Generate.generate_personal_rates(pdf, dgroups, tariff, tax, usr, options)
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])

      items = []
      items << [' ', '', '', '']

      for dg in dgroups
        item = []


        @arates, @crates, @arate_cur = Rate.get_personal_rate_details(tariff, dg, usr.id, exrate)
        if @arates.size > 0
          item << dg.name
          item << dg.desttype
          if @arates.size > 0
            if @arates.size > 1 || (@arates.size > 0 && @crates.size > 0)
              @arate_cur_ = nice_number(@arate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd}).to_s + " *"
            else
              @arate_cur_ = nice_number(@arate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            end
            item << @arate_cur_
            item << nice_number(tax.count_tax_amount(@arate_cur)+@arate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          else
            item << nice_number(0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << nice_number(0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          end

        end
        items << item
      end
      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 7,
                :headers => [_('Name'), _('Type'), _('Rate'), _('Rate_with_VAT')],
                :align_headers => {0 => :left, 1 => :left, 2 => :right, 3 => :right}) do
        column(0).style(:align => :left)
        column(1).style(:align => :left)
        column(2).style(:align => :right)
        column(3).style(:align => :right)
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf
    end


    def Generate.generate_personal_wholesale_rates_pdf(pdf, rates, tariff, options)
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true

      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])

      items = []
      items << [' ', '', '', '', '', '', '']

      for rate in rates
        item = []
        rate_details, rate_cur = Rate.get_provider_rate_details(rate, exrate)
        if rate.destination && rate.destination.direction
          item << rate.destination.direction.name
          item << rate.destination.subcode
          item << {:text => rate.destination.prefix.to_s, :align => :left}
        else
          item << " "
          item << " "
          item << " "
        end
        if rate_details.size > 0
          rate_cur = rate_details.size > 1 ? nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd}).to_s + " *" : nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << rate_cur
          item << rate_details[0]['connection_fee']
          item << rate_details[0]['increment_s']
          item << rate_details[0]['min_time']
        else
          item << nice_number(0.0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(0.0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << 0
        end

        items << item

        if rate_details.size > 1
          items << [{:text => _('*_Maximum_rate'), :colspan => 7}]
          items << [' ', '', '', '', '', '', '']
        end

      end


      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 7,
                :headers => [_('Destination'), _('Subcode'), _('Prefix'), _('Rate'), _('Connection_Fee'), _('Increment'), _('Min_Time')],
                :align_headers => {0 => :left, 1 => :left, 2 => :left, 3 => :right, 4 => :right, 5 => :right, 6 => :right}) do
        column(0).style(:align => :left)
        column(1).style(:align => :left)
        column(2).style(:align => :left)
        column(3).style(:align => :right)
        column(4).style(:align => :right)
        column(5).style(:align => :right)
        column(6).style(:align => :right)
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf
    end


    def Generate.generate_user_rates_pdf(pdf, rates, tariff, options)
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true

      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])

      items = []
      items << [' ', '', '', '']
      for rate in rates
        item = []
        arate_details, arate_cur = Rate.get_user_rate_details(rate, exrate)

        if rate.destinationgroup
          item << rate.destinationgroup.name
          item << rate.destinationgroup.desttype
        else
          item << " "
          item << " "
        end
        if arate_details.size > 0
          if arate_details.size > 1
            arate_cur = nice_number(arate_cur[0], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd}).to_s + " *"
          else
            arate_cur = nice_number(arate_cur[0], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          end
          item << arate_cur
          item << arate_details[0]['round']
        else
          item << nice_number(0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(0, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end
        items << item
      end

      pdf.table(items,
                :width => 550, :border_width => 0,
                :font_size => 10,
                :headers => [_('Destination'), _('Subcode'), _('Rate'), _('Round')],
                :align_headers => {0 => :left, 1 => :center, 2 => :right, 3 => :right}) do
        column(0).style(:align => :left, :height => 15, :width => 450)
        column(1).style(:align => :center, :height => 15)
        column(2).style(:align => :right, :height => 15)
        column(3).style(:align => :right, :height => 15)
      end

      string = "<page>/<total>"
      opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
      pdf.number_pages string, opt

      pdf
    end


=begin rdoc

=end

    def Generate.generate_cc_invoice(invoice, options)
      # additional values used in header generation
      options[:box_bottom] = options[:item_line_start]+options[:lines]*options[:item_line_height]
      options[:box_right] = options[:left]+options[:length]
      options[:box2_length] = options[:box_right]- options[:col3_x]

      options[:tax_start] = options[:box_bottom] + options[:item_line_height]+options[:tax_box_text_add_y]
      options[:tax_box_start] = options[:box_bottom] + options[:item_line_height]

      options[:gnd] = Confline.get_value("Global_Number_Decimal").to_s
      options[:cgnd] = options[:gnd].to_s == '.' ? false : true

      i = 1
      in_page = 1
      subtotal = 0
      options[:order] = invoice.ccorder
      line_items = Cclineitem.find(:all, :include => [:cardgroup], :conditions => "ccorder_id = #{options[:order].id}")

      cg = line_items[0].cardgroup
      options[:owner_id] = cg.owner_id.to_i
      options[:company] = Confline.get_value("Company", options[:owner_id]).to_s
      options[:tax] = cg.get_tax
      options[:total_tax_name] = options[:tax].total_tax_name.to_s
      options[:total_tax_name] += " " + nice_number(options[:tax].tax1_value.to_f, {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}).to_s + "%" if options[:tax].get_tax_count == 1

      options[:email] =invoice.email
      Confline.get_value("Round_finals_to_2_decimals").to_i == 1 ? options[:nice_num_dig] = 2 : options[:nice_num_dig] = Confline.get_value("Nice_Number_Digits").to_i
      options[:line_items] = line_items.size
      options[:total_pages] = PdfGen::Count.pages(options[:line_items], options[:lines])
      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      pdf = Generate.generate_cc_invoice_header(pdf, invoice, i, options)
      txt_start = options[:item_line_start] + options[:item_line_add_y]-options[:item_line_height]
      line_items.each { |item|
        pdf.text(item.cardgroup.name, {:left => options[:left] + options[:item_line_add_x], :top => txt_start + in_page*options[:item_line_height], :font_size => options[:address_fontsize]})
        pdf.text(item.quantity, {:left => options[:col1_x]+options[:item_line_add_x], :top => txt_start + in_page*options[:item_line_height], :font_size => options[:address_fontsize]})
        pdf.text(nice_number(item.price, {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col2_x]+options[:item_line_add_x], :top => txt_start + in_page*options[:item_line_height], :font_size => options[:address_fontsize]})
        pdf.text(nice_number(item.price*item.quantity, {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col3_x]+options[:item_line_add_x], :top => txt_start + in_page*options[:item_line_height], :font_size => options[:address_fontsize]})
        subtotal += (item.price*item.quantity).to_f
        if (in_page == options[:lines]) and (i != options[:line_items])
          pdf.start_new_page
          pdf = Generate.generate_cc_invoice_header(pdf, invoice, i, options)
          in_page =0
        end
        i += 1
        in_page +=1
      }
      options[:taxes] = options[:tax].applied_tax_list(subtotal)
      pdf = Generate.generate_cc_invoice_tax_and_total(pdf, subtotal, options)
      pdf
    end

  end


  def Generate.invoice_header_pdf(invoice, pdf, company, currency)
    user = invoice.user
    address = user.address

    (invoice.invoice_type.to_s == 'prepaid' and user.owner_id == 0) ? prepaid = "Prepaid_" : prepaid = ""


    # ---------- Company details ----------

    pdf.text(company, {:left => 40, :size => 23})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address1", user.owner_id), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address2", user.owner_id), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address3", user.owner_id), {:left => 40, :size => 12})
    pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Address4", user.owner_id), {:left => 40, :size => 12})

    # ----------- Invoice details ----------

    pdf.fill_color('DCDCDC')
    pdf.draw_text(_('INVOICE'), {:at => [330, 700], :size => 26})
    pdf.fill_color('000000')
    pdf.draw_text(_('Date') + ": " + invoice.issue_date.to_s, {:at => [330, 685], :size => 12})
    pdf.draw_text(_('Invoice_number') + ": " + invoice.number.to_s, {:at => [330, 675], :size => 12})


    # ----------- Separation line ---------
    pdf.fill_color('DDDDDD')
    pdf.move_down 2
    pdf.stroke do
      pdf.horizontal_line 0, 550, :fill_color => 'DDDDDD'
    end
    pdf.move_down 20
    pdf.fill_color('000000')


    # ---------- Client details -----------
    if user.owner_id != 0
      inv_address_format = Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i == 0 ? Confline.get_value("Invoice_Address_Format", 0).to_i : Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i
    else
      inv_address_format = Confline.get_value("#{prepaid.to_s}Invoice_Address_Format", user.owner_id).to_i
    end

    if inv_address_format == 1
      pdf.text(user.first_name.to_s + " " + user.last_name.to_s, {:left => 40, :size => 23})
      if address
        adr_direction = address.direction
        pdf.text(address.address.to_s, {:left => 40, :size => 12})
        pdf.text(address.city.to_s + ", " + address.postcode.to_s + ", " + address.state.to_s, {:left => 40, :size => 12})
        if adr_direction
          pdf.text(adr_direction.name.to_s, {:left => 40, :size => 12})
        end
      end
    end

    if inv_address_format == 2
      pdf.text(user.first_name.to_s + " " + user.last_name.to_s, {:left => 40, :size => 23})
      if address
        pdf.text(address.address.to_s, {:left => 40, :size => 12})
        pdf.text(address.city.to_s + ", " + address.state.to_s, {:left => 40, :size => 12})
        pdf.text(address.postcode.to_s, {:left => 40, :size => 12})
      end
    end

    pdf.text(_('Company_Personal_ID') + " : " + user.clientid.to_s, {:left => 40, :size => 12})
    pdf.text(_('VAT_Reg_number') + " : " + user.vat_number.to_s, {:left => 40, :size => 12})
    pdf.text(_('Agreement_number') + " : " + user.agreement_number.to_s, {:left => 40, :size => 12})
    pdf.text(_('Agreement_date') + " : " + user.agreement_date.to_s, {:left => 40, :size => 12})

    pdf.move_down 20
    pdf.text(_('Time_period') + ": " + invoice.period_start.to_s + " - " + invoice.period_end.to_s, {:left => 40, :size => 12})
    pdf.move_down 20
    #balance line
    if Confline.get_value("#{prepaid.to_s}Invoice_Show_Balance_Line", user.owner_id).to_i == 1
      balance = invoice.owned_balance_from_previous_month
      if balance
        pdf.text(Confline.get_value("#{prepaid.to_s}Invoice_Balance_Line", user.owner_id) + " " + sprintf("%0.#{2}f", balance[0].to_f) + " (" + _('With_TAX') + " " + sprintf("%0.#{2}f", balance[1]).to_s + ") " + currency.to_s, {:left => 40, :size => 12})
      end
    end
    pdf
  end

  def Generate.invoice_footer_pdf(pdf, invoice, options = {})
    opts = {
        :show_end_title => true
    }.merge(options)

    owner = invoice.user.owner_id
    prepaid = (invoice.invoice_type.to_s == 'prepaid' and owner == 0) ? "Prepaid_" : ""
    pdf.move_down(10)
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line1", owner), {:left => 50, :size => 12}) #,605]
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line2", owner), {:left => 50, :size => 12})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line3", owner), {:left => 50, :size => 12})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line4", owner), {:left => 50, :size => 12})
    pdf.text(Confline.get_value("#{prepaid}Invoice_Bank_Details_Line5", owner), {:left => 50, :size => 12})
                                                                                                            #    if opts[:show_end_title] == true
                                                                                                            #      inv_end_title = Confline.get_value("#{prepaid}Invoice_End_Title", owner)
                                                                                                            #      pdf.text(inv_end_title.to_s, {:left => 0, :size =>14, :alignment=>:center})
                                                                                                            #    end
    pdf
  end


  # 8********************************* rates *************************************


  def Generate.generate_rates_header(options)
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")
    pdf.text(options[:pdf_name], {:left => 40, :size => 23})
    pdf.text(_('Name') + ": #{options[:name]}", {:left => 40, :size => 12}) if !options[:hide_tariff]
    pdf.text(_('Currency') + ": " + options[:currency], {:left => 40, :size => 12})
    pdf
  end


  private
=begin rdoc

=end

  def Generate.generate_cc_invoice_header(pdf, invoice, current_position, options)
    #additional values
    #options[:box_top]
    #options[:box2_bottom] = options[:box_bottom] + options[:box2_items]*options[:item_line_height]
    # text
    page = PdfGen::Count.pages(current_position+1, options[:lines])
    pdf.color(:Gray)
    pdf.text(_('INVOICE'), {:left => options[:title_left2], :top => options[:title_pos0], :font_size => options[:title_fontsize1]})
    pdf.color(:Black)
    pdf.text(_('Date') + ": " + nice_date_time(invoice.created_at).to_s, {:left => options[:title_left2], :top => options[:title_pos1], :font_size => options[:title_fontsize2]})
    pdf.text(_('Invoice_number') + ": " + invoice.number.to_s, {:left => options[:title_left2], :top => options[:title_pos2], :font_size => options[:title_fontsize2]})

    pdf.text(options[:company], {:left => options[:left], :top => options[:address_pos1], :font_size => options[:title_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address1", options[:owner_id]), {:left => options[:left], :top => options[:address_pos2], :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address2", options[:owner_id]), {:left => options[:left], :top => options[:address_pos3], :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address3", options[:owner_id]), {:left => options[:left], :top => options[:address_pos4], :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address4", options[:owner_id]), {:left => options[:left], :top => options[:address_pos5], :font_size => options[:address_fontsize]})

    pdf.text("#{_("Email")}: #{options[:email]}", {:left => options[:left], :top => (options[:line_y]+options[:item_line_start] - options[:item_line_height])/2, :font_size => options[:address_fontsize]})
    # grid
    pdf.rectangle(options[:left], options[:line_y], options[:length], 0, {:line_width => 1, :fill_color => :Gray, :color => :Gray})
    (options[:lines]/2).times { |i|
      pdf.rectangle(options[:left], options[:item_line_start]+(i)*options[:item_line_height]*2, options[:length], options[:item_line_height], {:line_width => 0, :fill_color => :LIGHT_GREY})
    }
    pdf.line(options[:left], options[:item_line_start]-options[:item_line_height], options[:left]+options[:length], options[:item_line_start]-options[:item_line_height], {:line_width => 1})
    pdf.line(options[:left], options[:item_line_start], options[:box_right], options[:item_line_start], {:line_width => 1})
    pdf.line(options[:left], options[:box_bottom], options[:box_right], options[:box_bottom], {:line_width => 1})

    pdf.line(options[:left], options[:item_line_start] -options[:item_line_height], options[:left], options[:box_bottom], {:line_width => 1})
    pdf.line(options[:box_right], options[:item_line_start]-options[:item_line_height], options[:box_right], options[:box_bottom], {:line_width => 1})

    pdf.line(options[:col1_x], options[:item_line_start]-options[:item_line_height], options[:col1_x], options[:box_bottom], {:line_width => 1})
    pdf.line(options[:col2_x], options[:item_line_start]-options[:item_line_height], options[:col2_x], options[:box_bottom], {:line_width => 1})
    pdf.line(options[:col3_x], options[:item_line_start]-options[:item_line_height], options[:col3_x], options[:box_bottom], {:line_width => 1})
    # header text
    pdf.text(_("Card"), {:left => options[:left]+ options[:item_line_add_x], :top => options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y], :font_size => options[:address_fontsize]})
    pdf.text(_("Quantity"), {:left => options[:col1_x]+options[:item_line_add_x], :top => options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y], :font_size => options[:address_fontsize]})
    pdf.text(_("Price"), {:left => options[:col2_x]+options[:item_line_add_x], :top => options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y], :font_size => options[:address_fontsize]})
    pdf.text(_("Total"), {:left => options[:col3_x]+options[:item_line_add_x], :top => options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y], :font_size => options[:address_fontsize]})

    #address
    if page == options[:total_pages]
      bank_y = options[:box_bottom]+ options[:item_line_add_y]
      i = -1
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line1", options[:owner_id]), {:left => options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1), :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line2", options[:owner_id]), {:left => options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1), :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line3", options[:owner_id]), {:left => options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1), :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line4", options[:owner_id]), {:left => options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1), :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line5", options[:owner_id]), {:left => options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1), :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_End_Title", options[:owner_id]), {:left => 0, :top => 770, :font_size => options[:title_fontsize], :alignment => :center})
    end
    pdf.text(page.to_s + "/#{options[:total_pages]}", {:alignment => :right, :top => 770, :font_size => options[:title_fontsize2]})
    pdf
  end

=begin rdoc

=end
  def Generate.generate_cc_invoice_tax_and_total_box(pdf, options)
    i = 0
    pdf.rectangle(options[:col3_x], options[:box_bottom], options[:box2_length], options[:item_line_height], {:line_width => 1})
    pdf.text(_("Subtotal"), {:left => options[:tax_box_text_x], :top => options[:box_bottom] +options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    if (options[:order].amount*100).to_i == ((options[:order].gross + options[:tax].count_tax_amount(options[:order].gross))*100).to_i
      options[:taxes].each { |tax|
        pdf.text(tax[:name] + ": " +tax[:value].to_s+ " %", {:left => options[:tax_box_text_x], :top => options[:tax_start]+i*options[:tax_box_h], :font_size => options[:tax_fontsize]})
        pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h], options[:box2_length], options[:tax_box_h], {:line_width => 1})
        i+=1
      }
    end
    pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h], options[:box2_length], options[:item_line_height], {:line_width => 1})
    pdf.text(options[:total_tax_name], {:left => options[:tax_box_text_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    #total price box
    pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_height], options[:box2_length], options[:item_line_height], {:line_width => 1})
    pdf.text(_("Total"), {:left => options[:tax_box_text_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y]+options[:item_line_height], :font_size => options[:title_fontsize2]})
    pdf
  end

=begin rdoc

=end
  def Generate.generate_cc_invoice_tax_and_total(pdf, subtotal, options)
    pdf = Generate.generate_cc_invoice_tax_and_total_box(pdf, options)
    i = 0
    pdf.text(nice_number(subtotal, {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col3_x]+options[:item_line_add_x], :top => options[:box_bottom] + options[:item_line_add_y], :font_size => options[:address_fontsize]})
    if (options[:order].amount*100).to_i == ((options[:order].gross + options[:tax].count_tax_amount(options[:order].gross))*100).to_i
      options[:taxes].each { |tax|
        pdf.text(nice_number(tax[:tax], {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col3_x] + options[:item_line_add_x], :top => options[:tax_start]+i*options[:tax_box_h], :font_size => options[:tax_fontsize]})
        i+=1
      }
    end
    pdf.text(nice_number(options[:tax].count_tax_amount(subtotal), {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col3_x] + options[:item_line_add_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    pdf.text(nice_number(subtotal+options[:tax].count_tax_amount(subtotal), {:nice_number_digits => options[:nice_num_dig], :change_decimal => options[:cgnd], :global_decimal => options[:gnd]}), {:left => options[:col3_x] + options[:item_line_add_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y]+options[:item_line_height], :font_size => options[:title_fontsize2]})
    pdf
  end


=begin rdoc
 Generates last calls pdf.
=end

  def Generate.generate_last_calls_pdf(calls, total_calls, current_user, main_options={})
    digits = Confline.get_value("Nice_Number_Digits").to_i
    gnd = Confline.get_value("Global_Number_Decimal").to_s
    cgnd = gnd.to_s == '.' ? false : true

    usertype = current_user.usertype
    #options
    options = {}
    options = options.merge({
                                :pdf_last_calls => 1,
                                :rs_active => main_options[:rs_active],
                                :can_see_finaces => main_options[:can_see_finances],
                                :reseller_allow_providers_tariff => current_user.reseller_allow_providers_tariff?})

    ###### Generate PDF ########
    pdf = Prawn::Document.new(:size => 'A4', :layout => :portrait)
    pdf.font("#{Prawn::BASEDIR}/data/fonts/DejaVuSans.ttf")

    pdf.text(_('Period') + ": " + main_options[:date_from] + "  -  " + main_options[:date_till], {:left => 40, :size => 10})
    pdf.text(_('Currency') + ":#{main_options[:show_currency]}", {:left => 40, :size => 8})
    pdf.text(_('Total_calls') + ": #{calls.size}", {:left => 40, :size => 8})

    options[:total_calls] = calls.size
    options[:calls_per_page] = options[:calls_per_page_first]

    items = []
    h, h2 = call_list_to_pdf_header(pdf, main_options[:direction], usertype, 0, options)
    items << h2 if current_user.usertype.to_s != 'user'
    for call in calls
      item = []
      #calldate2 - because something overwites calldate when changing date format
      item << call.calldate2.to_s
      item << {:text => nice_src(call, {:pdf => 1}).to_s, :align => :left}
      item << {:text => hide_dst_for_user(current_user, "pdf", call.dst.to_s).to_s, :align => :left}
      item << nice_time(call['nice_billsec'])
      item << call.dispod.to_s

      if ['admin', 'accountant'].include?(usertype)

        item << call.server_id.to_s
        item << call['provider_name'].to_s
        if main_options[:can_see_finances]

          item << nice_number(call['provider_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(call['provider_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end
        if main_options[:rs_active]

          item << call['nice_reseller'].to_s
          if main_options[:can_see_finances]

            item << nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          end
        end

        item << call['user'].to_s
        if main_options[:can_see_finances]

          item << nice_number(call['user_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end

        item << {:text => call['did'].to_s, :align => :left}
        if main_options[:can_see_finances]

          item << nice_number(call['did_prov_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(call['did_inc_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          item << nice_number(call['did_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end
      else
        if current_user.show_billing_info == 1 and main_options[:can_see_finances]
          if usertype == 'reseller'
            if current_user.reseller_allow_providers_tariff?

              item << call['provider_name'].to_s
              if main_options[:can_see_finances]

                item << nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
                item << nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
              end
            end

            item << nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << call['user'].to_s
            item << nice_number(call['user_rate'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
            item << call['did'].to_s
          end
          if usertype == 'user'

            item << call['prefix'].to_s
            item << nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
          end
        end
      end
      items << item
    end
    item = []
    #Totals

    item << {:text => _('Total'), :colspan => 3}
    item << nice_time(total_calls.total_duration)
    item << {:text => '', :colspan => 4}
    if main_options[:can_see_finances]
      if ['admin', 'accountant'].include?(usertype)

        item << nice_number(total_calls.total_provider_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << {:text => '', :colspan => 2}
        item << nice_number(total_calls.total_reseller_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << {:text => '', :colspan => 2}
        item << nice_number(total_calls.total_user_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << {:text => ''}
        item << nice_number(total_calls.total_did_prov_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << nice_number(total_calls.total_did_inc_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << nice_number(total_calls.total_did_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
      end
      if usertype == 'reseller'
        if current_user.reseller_allow_providers_tariff?

          item << nice_number(total_calls.total_provider_price, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        end

        item << nice_number(total_calls.total_reseller_price_with_dids, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
        item << nice_number(total_calls.total_user_price_with_dids, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
      end
      if usertype == 'user'

        item << nice_number(total_calls.total_user_price_with_dids, {:nice_number_digits => digits, :change_decimal => cgnd, :global_decimal => gnd})
      end
    end


    items << item

    Rails.logger.fatal h2.to_yaml


    pdf.table(items,
              :width => 540, :border_width => 0,
              :font_size => 3, :padding => 1,
              :headers => h) do
    end

    string = "<page>/<total>"
    opt = {:at => [500, 0], :size => 9, :align => :right, :start_count_at => 1}
    pdf.number_pages string, opt

    pdf
  end

  def Generate.generate_additional_details_for_invoice_pdf(pdf, details, options={})
    xdelta = 15
    ystart = 20
    dts = details.split("\n")
    pdf.start_new_page
    if options[:page]
      pdf = PdfGen::Count.page_number(pdf, options[:page], options[:pages])
    end
    i = 0
    dts.each { |d|
      numbers = (d.to_s.length.to_i / 93)
      if numbers.to_f > 1.to_f
        pdf.text(d.to_s, {:left => 10, :top => ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
        (numbers.ceil.to_i-1).to_i.times {
          pdf.text('', {:left => 10, :top => ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
          i+=1
        }
      else
        pdf.text(d.to_s, {:left => 10, :top => ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
      end
      i+=1
    }
    return pdf
  end


end

