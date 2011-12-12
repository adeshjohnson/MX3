require 'application_helper'
include ApplicationHelper

module PdfGen
  module Generate
    require 'pdf/wrapper'

=begin rdoc
 Generates header for Tariff.generate_provider_rates_pdf

 *Params*

 +pdf+ - PdfWrapper PDF object
 +i+ - current possition
 +options+ - pdf options hash.

 *Returns*

 +pdf+ - PdfWrapper PDF object with header and page number.
=end

    def Generate.generate_provider_rates_pdf_header(pdf, i, options)
      pdf.text(_('Destination'),    {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col1_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Subcode'),        {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col2_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Prefix'),         {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col3_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Rate'),           {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col4_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Connection_Fee'), {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col5_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Increment'),      {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col6_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Min_Time'),       {:top=> options[:page_pos] - options[:header_eleveation], :left=> options[:col7_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text("#{PdfGen::Count.pages(i+1, options[:per_page_1], options[:per_page_2] )}/#{options[:total_pages]}", {:top => options[:page_num_pos],:font_size => options[:fontsize] + options[:header_size_add] , :alignment => :right})
      pdf
    end

    # Personal Rates ###############################################################
=begin rdoc
=end
    def Generate.generate_personal_rates(dgroups, tariff, tax, usr, currency, options)
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true
      i = 1
      in_page = 1
      options[:page_pos] = options[:first_page_pos]
      options[:total_pages] = PdfGen::Count.pages(dgroups.size, options[:per_page1], options[:per_page2])
      options[:per_page] = options[:per_page1]
      options[:total_items] = dgroups.size

      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")

      pdf.text(_('Personal_rates'),             {:top => options[:title_pos],  :font_size => options[:title_fontsize],  :alignment => :left})
      pdf.text(_('Name') + ": #{usr.username}", {:top => options[:title2_pos], :font_size => options[:title2_fontsize], :alignment => :left})
      pdf.text(_('Currency') + ": " +currency , {:top => options[:title3_pos], :font_size => options[:title2_fontsize], :alignment => :left})
      pdf = PdfGen::Generate.generate_personal_rates_pdf_header(pdf,i, options)
      exrate = Currency.count_exchange_rate(tariff.currency, currency)
      for dg in dgroups
        @arates, @crates, @arate_cur = Rate.get_personal_rate_details(tariff, dg, usr.id, exrate)
        if @arates.size > 0
          pdf.text(dg.name, {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
          pdf.text(dg.desttype, {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
          if @arates.size > 0
            if @arates.size > 1  || (@arates.size > 0 && @crates.size > 0)
              @arate_cur_ = nice_number(@arate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}).to_s + " *"
            else
              @arate_cur_ = nice_number(@arate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd})
            end
            pdf.text(@arate_cur_,                                 {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
            pdf.text(nice_number(tax.count_tax_amount(@arate_cur)+@arate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})
          else
            pdf.text("0", {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
            pdf.text("0", {:top => options[:page_pos]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})
          end
          if in_page == options[:per_page] and i != options[:total_items]
            pdf.start_new_page
            options[:per_page] = options[:per_page2]
            options[:page_pos] = options[:second_page_pos]
            pdf = PdfGen::Generate.generate_personal_rates_pdf_header(pdf,i, options)
            in_page = 0
          end
          i += 1
          in_page += 1
        end
      end
      pdf
    end

=begin rdoc

=end

    def Generate.generate_personal_rates_pdf_header(pdf, i, options)
      pdf.text(_('Name'),          {:top => options[:page_pos] - options[:header_elevation], :left => options[:col1_x], :font_size => options[:fontsize] + options[:header_add_size]})
      pdf.text(_('Type'),          {:top => options[:page_pos] - options[:header_elevation], :left => options[:col2_x], :font_size => options[:fontsize] + options[:header_add_size]})
      pdf.text(_('Rate'),          {:top => options[:page_pos] - options[:header_elevation], :left => options[:col3_x], :font_size => options[:fontsize] + options[:header_add_size]})
      pdf.text(_('Rate_with_VAT'), {:top => options[:page_pos] - options[:header_elevation], :left => options[:col4_x], :font_size => options[:fontsize] + options[:header_add_size]})
      pdf.text(PdfGen::Count.pages(i+1,options[:per_page1], options[:per_page2]).to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> options[:page_number_pos] , :font_size =>options[:fontsize] + options[:header_add_size]})
      pdf
    end

=begin rdoc
 Generates basic header data for pdf with given options

 *Params*

 <tt>pdf</tt> - PDF::Wrapper pdf object.
 <tt>options</tt> - hash containing setup values.

 *Returns*

 <tt>pdf</tt> -  PDF::Wrapper pdf object with basic pdf header data
=end

    def Generate.call_list_to_pdf_header_basic(pdf, options)
      pdf.text(_('date'),         {:left=> options[:dat_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('called_from'),  {:left=> options[:caf_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('called_to'),    {:left=> options[:cat_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('duration'),     {:left=> options[:dur_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('hangup_cause'), {:left=> options[:han_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf
    end

=begin rdoc
 Need def
=end

    def Generate.call_list_to_pdf_header(pdf, direction, usertype, i,options)
      ystart = options[:ystart]
      header_elevation = options[:header_elevation]
      fontsize = options[:fontsize]
      header_add_size = options[:header_add_size]
      pdf = call_list_to_pdf_header_basic(pdf, options)
      if options[:pdf_last_calls].to_i == 1
        header_elevation2 = options[:header_elevation2]
        if ['admin', 'accountant'].include?(usertype)
          pdf.text(_('Server'),{:left=> options[:ser],  :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          pdf.text(_('Provider'),{:left=> options[:p_na], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #--------------------- rate price name
          pdf.text(_('Name'),{:left=> options[:p_na], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Rate'),{:left=> options[:p_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Price'),{:left=> options[:p_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})
          if options[:rs_active]
            pdf.text(_('Reseller'),{:left=> options[:r_na], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            #--------------------- rate price name
            pdf.text(_('Name'),{:left=> options[:r_na], :top=> ystart - header_elevation2, :font_size =>fontsize})
            pdf.text(_('Rate'),{:left=> options[:r_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
            pdf.text(_('Price'),{:left=> options[:r_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})
          end
          pdf.text(_('User'),{:left=> options[:u_na], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #--------------------- rate price name
          pdf.text(_('Name'),{:left=> options[:u_na], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Rate'),{:left=> options[:u_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Price'),{:left=> options[:u_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})

          pdf.text(_('Did'),{:left=> options[:did], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #--------------------- rate price name
          pdf.text(_('Number'),{:left=> options[:did], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Provider'),{:left=> options[:did_p], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Incoming'),{:left=> options[:did_inc], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Owner'),{:left=> options[:did_ow], :top=> ystart - header_elevation2, :font_size =>fontsize})
        end
        if usertype == 'reseller'
          if options[:reseller_allow_providers_tariff]
            pdf.text(_('Provider'),{:left=> options[:p_na], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            #--------------------- rate price name
            pdf.text(_('Name'),{:left=> options[:p_na], :top=> ystart - header_elevation2, :font_size =>fontsize})
            pdf.text(_('Rate'),{:left=> options[:p_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
            pdf.text(_('Price'),{:left=> options[:p_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})
          end
          pdf.text(_('Selfcost'),{:left=> options[:r_ra], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size}) if options[:rs_active]
          pdf.text(_('Rate'),{:left=> options[:r_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Price'),{:left=> options[:r_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('User'),{:left=> options[:u_na], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #--------------------- rate price name
          pdf.text(_('Name'),{:left=> options[:u_na], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Rate'),{:left=> options[:u_ra], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Price'),{:left=> options[:u_pr], :top=> ystart - header_elevation2, :font_size =>fontsize})
          pdf.text(_('Did'),{:left=> options[:did], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #--------------------- rate price name
          pdf.text(_('Number'),{:left=> options[:did], :top=> ystart - header_elevation2, :font_size =>fontsize})
        end
        if usertype == 'user'
          pdf.text(_('Prefix_used'),{:left=> options[:prefix], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          pdf.text(_('Price'),{:left=> options[:u_pr], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
        end
      else
        if usertype == "admin"
          if direction == "incoming"
            pdf.text(_('Provider'),{:left=> options[:pri_x],  :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Incoming'),{:left=> options[:pri2_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Owner'),   {:left=> options[:pri3_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Profit'),        {:left=> options[:pri4_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          else
            pdf.text(_('Price'),         {:left=> options[:pri_x],  :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Provider_price'),{:left=> options[:pri2_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Profit'),        {:left=> options[:pri3_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Margin'),        {:left=> options[:pri4_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Markup'),        {:left=> options[:pri5_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          end
        end

        if usertype == "reseller"
          if direction == "incoming"
            #          pdf.text(_('Provider'),{:left=> options[:pri_x],  :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            #          pdf.text(_('Incoming'),{:left=> options[:pri2_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            #          pdf.text(_('Owner'),   {:left=> options[:pri3_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            #          pdf.text(_('Profit'),        {:left=> options[:pri4_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Price'),{:left=> options[:pri_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          else
            pdf.text(_('Price'),         {:left=> options[:pri_x],  :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Provider_price'),{:left=> options[:pri2_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Profit'),        {:left=> options[:pri3_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Margin'),        {:left=> options[:pri4_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
            pdf.text(_('Markup'),        {:left=> options[:pri5_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          end
        end

        if usertype == "user"
          #if direction != "incoming"
          pdf.text(_('Price'),{:left=> options[:pri_x], :top=> ystart - header_elevation, :font_size =>fontsize+header_add_size})
          #end
        end
      end



      pdf.text(PdfGen::Count.pages(i+1,options[:calls_per_page_first], options[:calls_per_page_second]).to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> 780, :font_size =>options[:page_number_size]})
      pdf
    end

=begin rdoc

=end

    def Generate.providers_calls_to_pdf_header(pdf, i,options)
      pdf = call_list_to_pdf_header_basic(pdf, options)
      pdf.text(_('User_price'),     {:left=> options[:col1_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('Provider_price'), {:left=> options[:col2_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(_('Profit'),         {:left=> options[:col3_x], :top=> options[:ystart] - options[:header_elevation], :font_size => options[:fontsize]+options[:header_add_size]})
      pdf.text(PdfGen::Count.pages(i+1,options[:first_page_items], options[:second_page_items]).to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> 780, :font_size =>options[:page_number_size]})
      pdf
    end

=begin rdoc
 Generate provider calls PDF.

 *Params*

 <tt>provider</tt> - Provider object.
 <tt>calls</tt> - Array of Call objects.
 <tt>options</tt> - hash containing format options.

 *Returns*

 <tt>pdf</tt> - PDF::Wrapper generated document.
=end

    def Generate.providers_calls_to_pdf(provider, calls ,options)
      options[:ystart] = options[:first_page_pos]
      options[:per_page] = options[:first_page_items]
      options[:total_items] = calls.size
      options[:total_pages] = PdfGen::Count.pages(options[:total_items],options[:first_page_items], options[:second_page_items]).to_i
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true
      i = 1
      in_page = 1
      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      # title
      pdf.text(_('CDR_Records') + ": #{provider.name}",                                  {:top => options[:title_pos1], :font_size => options[:title_fontsize],  :alignment => :left})
      pdf.text(_('Call_type') + ": " + options[:call_type],                              {:top => options[:title_pos2], :font_size => options[:title_fontsize2], :alignment => :left})
      pdf.text(_('Period') + ": " + options[:date_from] + "  -  " + options[:date_till], {:top => options[:title_pos3], :font_size => options[:title_fontsize2], :alignment => :left})
      pdf.text(_('Currency') +  ": #{options[:currency]}",                               {:top => options[:title_pos4], :font_size => options[:title_fontsize3], :alignment => :left})
      pdf.text(_('Total_calls') + ": #{calls.size}",                                     {:top => options[:title_pos5], :font_size => options[:title_fontsize3], :alignment => :left})

      pdf = Generate.providers_calls_to_pdf_header(pdf,i, options)

      total_price = 0
      total_billsec = 0
      exrate = Currency.count_exchange_rate(options[:default_currency], options[:currency])
      for call in calls
        rate_cur, rate_cpr = Rate.get_provider_rate(call, options[:direction],exrate)
        pdf.text(call.calldate.strftime("%Y-%m-%d %H:%M:%S"), {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:dat_x], :font_size => options[:fontsize]})
        pdf.text(call.src,                                    {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:caf_x], :font_size => options[:fontsize]})
        pdf.text(call.dst,                                    {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:cat_x], :font_size => options[:fontsize]})

        if @direction == "incoming"
          billsec = call.did_billsec
        else
          billsec = call.billsec
        end

        if billsec == 0
          pdf.text("00:00:00",                                {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:dur_x ], :font_size => options[:fontsize]})
        else
          pdf.text(nice_time(billsec),                   {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:dur_x ], :font_size => options[:fontsize]})
        end
        pdf.text(call.disposition,                            {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:han_x], :font_size => options[:fontsize]})
        pdf.text(nice_number(rate_cur, {:nice_number_digits => options [:nice_number_digits]}), {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
        pdf.text(nice_number(rate_cpr, {:nice_number_digits => options [:nice_number_digits]}), {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
        user_price = 0
        user_price = rate_cur if call.user_price
        provider_price = 0
        provider_price = rate_cpr if provider_price
        pdf.text(nice_number(user_price - provider_price,  {:nice_number_digits => options [:nice_number_digits]}), {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
        if in_page == options[:per_page] and i != options[:total_items]
          pdf.start_new_page
          options[:per_page] = options[:second_page_items]
          options[:ystart] = options[:second_page_pos]
          pdf = Generate.providers_calls_to_pdf_header(pdf,i, options)
          in_page = 0
        end
        total_price +=rate_cur if call.user_price
        total_billsec += call.billsec
        i += 1
        in_page += 1
      end
      pdf.text(_('Profit'),                       {:left=> options[:dat_x], :top=> 760, :font_size => options[:fontsize]+options[:header_add_size]})
      if total_billsec == 0
        pdf.text("00:00:00",                      {:left=> options[:dur_x], :top=> 760, :font_size => options[:fontsize]+options[:header_add_size]})
      else
        pdf.text(nice_time(total_billsec),        {:left=> options[:dur_x], :top=> 760, :font_size => options[:fontsize]+options[:header_add_size]})
      end
      pdf.text(nice_number(total_price, options), {:left=> options[:col3_x], :top=> 760, :font_size => options[:fontsize]+options[:header_add_size]})

      pdf

    end

=begin rdoc
 Generates header for wholesale rates pdf.
=end

    def Generate.generate_personal_wholesale_rates_pdf_header(pdf, i, options)
      pdf.text(_('Destination'),    {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col1_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Subcode'),        {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col2_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Prefix'),         {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col3_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Rate'),           {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col4_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Connection_Fee'), {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col5_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Increment'),      {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col6_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Min_Time'),       {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col7_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(PdfGen::Count.pages(i+1,options[:first_page_items], options[:second_page_items]).to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> options[:page_num_pos], :font_size =>options[:page_number_size]})
      pdf
    end

=begin rdoc
 Generates wholesale rates pdf.
=end

    def Generate.generate_personal_wholesale_rates_pdf(rates,tariff, user, options)
      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      options[:ystart] = options[:first_page_pos]
      options[:per_page] = options[:first_page_items]
      options[:total_items] = rates.size
      options[:total_pages] = PdfGen::Count.pages(options[:total_items],options[:first_page_items], options[:second_page_items]).to_i
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true
      i = 1
      in_page = 1

      pdf.text(_('Rates') ,                                      {:top => options[:title_pos1], :font_size => options[:title_fontsize1],  :alignment => :left})
      pdf.text(_('Currency') + ": " +  (options[:currency]).to_s,{:top => options[:title_pos2], :font_size => options[:title_fontsize2],  :alignment => :left})
      pdf = Generate.generate_personal_wholesale_rates_pdf_header(pdf, i,options)
      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])
      for rate in rates
        rate_details, rate_cur = Rate.get_provider_rate_details(rate, exrate)
        if rate.destination && rate.destination.direction
          pdf.text(rate.destination.direction.name, {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
          pdf.text(rate.destination.subcode,        {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
          pdf.text(rate.destination.prefix,         {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
        else
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
        end
        if rate_details.size > 0
          rate_cur = rate_details.size > 1 ? nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}).to_s + " *" : nice_number(rate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd})
          pdf.text(rate_cur,                          {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})
          pdf.text(rate_details[0]['connection_fee'], {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col5_x], :font_size => options[:fontsize]})
          pdf.text(rate_details[0]['increment_s'],    {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col6_x], :font_size => options[:fontsize]})
          pdf.text(rate_details[0]['min_time'],       {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col7_x], :font_size => options[:fontsize]})
        else
          pdf.text("0.0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})
          pdf.text("0.0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col5_x], :font_size => options[:fontsize]})
          pdf.text(0,     {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col6_x], :font_size => options[:fontsize]})
          pdf.text(0,     {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col7_x], :font_size => options[:fontsize]})
        end

        if rate_details.size > 1
          pdf.text(_('*_Maximum_rate'),     {:top => options[:page_num_pos], :left => options[:col1_x], :font_size => options[:fontsize]})
        end

        if in_page == options[:per_page] and i != options[:total_items]
          pdf.start_new_page
          options[:per_page] = options[:second_page_items]
          options[:ystart] = options[:second_page_pos]
          pdf = Generate.generate_personal_wholesale_rates_pdf_header(pdf, i,options)
          in_page = 0
        end
        i += 1
        in_page += 1
      end
      pdf
    end

=begin rdoc

=end

    def Generate.generate_user_rates_pdf_header(pdf, i, options)
      pdf.text(_('Destination'), {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col1_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Subcode'),     {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col2_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Rate'),        {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col3_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(_('Round'),       {:top=> options[:ystart] - options[:header_eleveation], :left=> options[:col4_x], :font_size => options[:fontsize] + options[:header_size_add]} )
      pdf.text(PdfGen::Count.pages(i+1,options[:first_page_items], options[:second_page_items]).to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> options[:page_num_pos], :font_size =>options[:page_number_size]})
      pdf
    end

=begin rdoc

=end

    def Generate.generate_user_rates_pdf(rates, tariff, options)
      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      options[:ystart] = options[:first_page_pos]
      options[:per_page] = options[:first_page_items]
      options[:total_items] = rates.size
      options[:total_pages] = PdfGen::Count.pages(options[:total_items],options[:first_page_items], options[:second_page_items]).to_i
      digits = Confline.get_value("Nice_Number_Digits").to_i
      gnd = Confline.get_value("Global_Number_Decimal").to_s
      cgnd = gnd.to_s == '.' ? false : true
      i = 1
      in_page = 1

      pdf.text(_('Users_rates') ,                         {:top => options[:title_pos1], :font_size => options[:title_fontsize1],  :alignment => :left})
      pdf.text(_('Name') + ": #{tariff.name}",            {:top => options[:title_pos2], :font_size => options[:title_fontsize2],  :alignment => :left})
      pdf.text(_('Currency') + ": " + options[:currency], {:top => options[:title_pos3], :font_size => options[:title_fontsize2],  :alignment => :left})
      pdf = Generate.generate_user_rates_pdf_header(pdf, i, options)
      exrate = Currency.count_exchange_rate(tariff.currency, options[:currency])
      for rate in rates
        arate_details, arate_cur = Rate.get_user_rate_details(rate, exrate)

        if rate.destinationgroup
          pdf.text(rate.destinationgroup.name,     {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
          pdf.text(rate.destinationgroup.desttype, {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
        else
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col1_x], :font_size => options[:fontsize]})
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col2_x], :font_size => options[:fontsize]})
        end
        if arate_details.size > 0
          arate_cur = arate_details.size > 1 ? nice_number(arate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}).to_s + " *" : nice_number(arate_cur, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd})
          pdf.text(arate_cur,                 {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
          pdf.text(arate_details[0]['round'], {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})

        else
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col3_x], :font_size => options[:fontsize]})
          pdf.text("0", {:top => options[:ystart]+ in_page*options[:step_size], :left => options[:col4_x], :font_size => options[:fontsize]})
        end
        if in_page == options[:per_page] and i != options[:total_items]
          pdf.start_new_page
          options[:per_page] = options[:second_page_items]
          options[:ystart] = options[:second_page_pos]
          pdf = Generate.generate_user_rates_pdf_header(pdf, i, options)
          in_page = 0
        end
        i += 1
        in_page += 1
      end

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
      options[:total_tax_name] += " " + nice_number(options[:tax].tax1_value.to_f, {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}).to_s + "%" if options[:tax].get_tax_count == 1

      options[:email] =invoice.email
      Confline.get_value("Round_finals_to_2_decimals").to_i == 1 ? options[:nice_num_dig] = 2 : options[:nice_num_dig] = Confline.get_value("Nice_Number_Digits").to_i
      options[:line_items] = line_items.size
      options[:total_pages] = PdfGen::Count.pages(options[:line_items],options[:lines])
      pdf = PDF::Wrapper.new(:paper => :A4)
      pdf.font("Nimbus Sans L")
      pdf = Generate.generate_cc_invoice_header(pdf, invoice,i,options)
      txt_start = options[:item_line_start] + options[:item_line_add_y]-options[:item_line_height]
      line_items.each{ |item|
        pdf.text(item.cardgroup.name,                  {:left => options[:left] + options[:item_line_add_x], :top =>txt_start + in_page*options[:item_line_height] ,  :font_size => options[:address_fontsize]})
        pdf.text(item.quantity,                        {:left => options[:col1_x]+options[:item_line_add_x], :top =>txt_start + in_page*options[:item_line_height] ,  :font_size => options[:address_fontsize]})
        pdf.text(nice_number(item.price,               {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}), {:left => options[:col2_x]+options[:item_line_add_x], :top =>txt_start + in_page*options[:item_line_height] ,  :font_size => options[:address_fontsize]})
        pdf.text(nice_number(item.price*item.quantity, {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}), {:left => options[:col3_x]+options[:item_line_add_x], :top =>txt_start + in_page*options[:item_line_height] ,  :font_size => options[:address_fontsize]})
        subtotal += (item.price*item.quantity).to_f
        if (in_page == options[:lines]) and (i != options[:line_items])
          pdf.start_new_page
          pdf = Generate.generate_cc_invoice_header(pdf, invoice,i,options)
          in_page =0
        end
        i += 1
        in_page +=1
      }
      options[:taxes] = options[:tax].applied_tax_list(subtotal)
      pdf = Generate.generate_cc_invoice_tax_and_total(pdf,subtotal, options)
      pdf
    end

  end
  private
=begin rdoc

=end

  def Generate.generate_cc_invoice_header(pdf, invoice, current_position, options)
    #additional values
    #options[:box_top]
    #options[:box2_bottom] = options[:box_bottom] + options[:box2_items]*options[:item_line_height]
    # text
    page = PdfGen::Count.pages(current_position+1,options[:lines])
    pdf.color(:Gray)
    pdf.text( _('INVOICE'), {:left => options[:title_left2], :top => options[:title_pos0], :font_size =>options[:title_fontsize1]})
    pdf.color(:Black)
    pdf.text(_('Date') + ": " + nice_date_time(invoice.created_at).to_s, {:left => options[:title_left2], :top => options[:title_pos1], :font_size => options[:title_fontsize2]})
    pdf.text(_('Invoice_number') + ": " + invoice.number.to_s,           {:left => options[:title_left2], :top => options[:title_pos2], :font_size => options[:title_fontsize2]})

    pdf.text(options[:company],                                          {:left => options[:left], :top => options[:address_pos1], :font_size => options[:title_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address1", options[:owner_id]), {:left => options[:left], :top => options[:address_pos2],  :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address2", options[:owner_id]), {:left => options[:left], :top => options[:address_pos3],  :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address3", options[:owner_id]), {:left => options[:left], :top => options[:address_pos4], :font_size => options[:address_fontsize]})
    pdf.text(Confline.get_value("Invoice_Address4", options[:owner_id]), {:left => options[:left], :top => options[:address_pos5], :font_size => options[:address_fontsize]})

    pdf.text("#{_("Email")}: #{options[:email]}", {:left => options[:left], :top =>(options[:line_y]+options[:item_line_start] - options[:item_line_height])/2 , :font_size => options[:address_fontsize]})
    # grid
    pdf.rectangle(options[:left], options[:line_y], options[:length], 0,{:line_width => 1, :fill_color => :Gray, :color => :Gray})
    (options[:lines]/2).times { |i|
      pdf.rectangle(options[:left], options[:item_line_start]+(i)*options[:item_line_height]*2,options[:length] , options[:item_line_height], {:line_width => 0, :fill_color => :LIGHT_GREY})
    }
    pdf.line(options[:left], options[:item_line_start]-options[:item_line_height], options[:left]+options[:length], options[:item_line_start]-options[:item_line_height],{:line_width => 1})
    pdf.line(options[:left], options[:item_line_start], options[:box_right], options[:item_line_start],{:line_width => 1})
    pdf.line(options[:left], options[:box_bottom], options[:box_right], options[:box_bottom],{:line_width => 1})

    pdf.line(options[:left], options[:item_line_start] -options[:item_line_height], options[:left], options[:box_bottom],{:line_width => 1})
    pdf.line(options[:box_right], options[:item_line_start]-options[:item_line_height], options[:box_right], options[:box_bottom],{:line_width => 1})

    pdf.line(options[:col1_x], options[:item_line_start]-options[:item_line_height], options[:col1_x], options[:box_bottom],{:line_width => 1})
    pdf.line(options[:col2_x], options[:item_line_start]-options[:item_line_height], options[:col2_x], options[:box_bottom],{:line_width => 1})
    pdf.line(options[:col3_x], options[:item_line_start]-options[:item_line_height], options[:col3_x], options[:box_bottom],{:line_width => 1})
    # header text
    pdf.text(_("Card"),     {:left => options[:left]+  options[:item_line_add_x] , :top =>options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y] ,  :font_size => options[:address_fontsize]})
    pdf.text(_("Quantity"), {:left => options[:col1_x]+options[:item_line_add_x] , :top =>options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y] ,  :font_size => options[:address_fontsize]})
    pdf.text(_("Price"),    {:left => options[:col2_x]+options[:item_line_add_x] , :top =>options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y] ,  :font_size => options[:address_fontsize]})
    pdf.text(_("Total"),    {:left => options[:col3_x]+options[:item_line_add_x] , :top =>options[:item_line_start] - options[:item_line_height] + options[:item_line_add_y] ,  :font_size => options[:address_fontsize]})

    #address
    if page == options[:total_pages]
      bank_y = options[:box_bottom]+ options[:item_line_add_y]
      i = -1
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line1", options[:owner_id]), {:left =>options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1) , :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line2", options[:owner_id]), {:left =>options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1) , :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line3", options[:owner_id]), {:left =>options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1) , :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line4", options[:owner_id]), {:left =>options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1) , :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_Bank_Details_Line5", options[:owner_id]), {:left =>options[:left]+options[:item_line_add_x], :top => bank_y+options[:bank_details_step]*(i+=1) , :font_size => options[:title_fontsize2]})
      pdf.text(Confline.get_value("Invoice_End_Title", options[:owner_id]), {:left => 0, :top => 770, :font_size =>options[:title_fontsize], :alignment=>:center})
    end
    pdf.text(page.to_s + "/#{options[:total_pages]}",{:alignment => :right, :top=> 770, :font_size =>options[:title_fontsize2]})
    pdf
  end
=begin rdoc

=end
  def Generate.generate_cc_invoice_tax_and_total_box(pdf, options)
    i = 0
    pdf.rectangle(options[:col3_x], options[:box_bottom],options[:box2_length] , options[:item_line_height],{:line_width => 1})
    pdf.text(_("Subtotal"), {:left =>options[:tax_box_text_x], :top => options[:box_bottom] +options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    if (options[:order].amount*100).to_i == ((options[:order].gross + options[:tax].count_tax_amount(options[:order].gross))*100).to_i
      options[:taxes].each { |tax|
        pdf.text(tax[:name] + ": " +tax[:value].to_s+ " %", {:left =>options[:tax_box_text_x], :top => options[:tax_start]+i*options[:tax_box_h], :font_size => options[:tax_fontsize]})
        pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h],options[:box2_length], options[:tax_box_h],{:line_width => 1})
        i+=1
      }
    end
    pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h],options[:box2_length] , options[:item_line_height],{:line_width => 1})
    pdf.text(options[:total_tax_name], {:left =>options[:tax_box_text_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    #total price box
    pdf.rectangle(options[:col3_x], options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_height],options[:box2_length] , options[:item_line_height],{:line_width => 1})
    pdf.text(_("Total"), {:left =>options[:tax_box_text_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y]+options[:item_line_height], :font_size => options[:title_fontsize2]})
    pdf
  end

=begin rdoc

=end
  def Generate.generate_cc_invoice_tax_and_total(pdf, subtotal, options)
    pdf = Generate.generate_cc_invoice_tax_and_total_box(pdf, options)
    i = 0
    pdf.text(nice_number(subtotal, {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}), {:left => options[:col3_x]+options[:item_line_add_x] ,  :top => options[:box_bottom] + options[:item_line_add_y],  :font_size => options[:address_fontsize]})
    if (options[:order].amount*100).to_i == ((options[:order].gross + options[:tax].count_tax_amount(options[:order].gross))*100).to_i
      options[:taxes].each { |tax|
        pdf.text(nice_number(tax[:tax], {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}), {:left =>options[:col3_x] + options[:item_line_add_x], :top => options[:tax_start]+i*options[:tax_box_h], :font_size => options[:tax_fontsize]})
        i+=1
      }
    end
    pdf.text(nice_number(options[:tax].count_tax_amount(subtotal), {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}),          {:left =>options[:col3_x] + options[:item_line_add_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y], :font_size => options[:title_fontsize2]})
    pdf.text(nice_number(subtotal+options[:tax].count_tax_amount(subtotal), {:nice_number_digits => options[:nice_num_dig], :change_decimal=>options[:cgnd], :global_decimal=>options[:gnd]}), {:left =>options[:col3_x] + options[:item_line_add_x], :top => options[:tax_box_start]+i*options[:tax_box_h]+options[:item_line_add_y]+options[:item_line_height], :font_size => options[:title_fontsize2]})
    pdf
  end



=begin rdoc
 Generates last calls pdf.
=end

  def Generate.generate_last_calls_pdf(calls, total_calls, current_user, main_options={})
    ###### Generate PDF ########
    pdf = PDF::Wrapper.new(:paper => :A4)
    pdf.font("Nimbus Sans L")
    #logo
    #pdf.image "../images/logo/kolmisoft.png", :justification => :center, :resize => 0.75

    digits = Confline.get_value("Nice_Number_Digits").to_i
    gnd = Confline.get_value("Global_Number_Decimal").to_s
    cgnd = gnd.to_s == '.' ? false : true

    usertype = current_user.usertype
    #options
    options = {}
    options = options.merge({
        :xdelta => 9,
        :fontsize => 3,
        :calls_per_page_first => 70,
        :calls_per_page_second => 80,
        :ystart => 125,
        :second_page_start => 50,
        :header_elevation => 15,
        :header_elevation2 => 6,
        :header_add_size => 1,
        :total_possition => 770,
        :pdf_last_calls=>1,
        :rs_active=>main_options[:rs_active],
        :can_see_finaces=>main_options[:can_see_finances],
        :reseller_allow_providers_tariff => current_user.reseller_allow_providers_tariff?,
        :page_number_size => 10})
    z = options[:rs_active] ? 0 : 90
    if ['admin', 'accountant'].include?(usertype)
      options = options.merge({
          :dat_x => 5,
          :caf_x => 50,
          :cat_x => 105,
          :dur_x => 145,
          :han_x => 175,
          :ser => 215,
          :p_na => 240,
          :p_ra => 275,
          :p_pr => 295,
          :r_na => 315,
          :r_ra => 365,
          :r_pr => 385,
          :u_na => 405-z,
          :u_ra => 450-z,
          :u_pr => 470-z,
          :did => 490-z,
          :did_p => 529-z,
          :did_inc => 548-z,
          :did_ow =>572-z,
          :pri_x => 360,
          :pri2_x => 395,
          :pri3_x => 450,
          :pri4_x => 485,
          :pri5_x => 500
        })
    end
    z = main_options[:can_see_finances] ? 0 : 50
    zz = current_user.reseller_allow_providers_tariff? ? 0 : 110
    if usertype == 'reseller'
      options = options.merge({
          :fontsize => 3,
          :dat_x => 15,
          :caf_x => 65,
          :cat_x => 125,
          :dur_x => 170,
          :han_x => 200,
          :p_na => 260,
          :p_ra => 310-z-zz,
          :p_pr => 340-z-zz,
          :r_ra => 370-z-zz,
          :r_pr => 400-z-zz,
          :u_na => 430-z-zz,
          :u_ra => 480-z-zz,
          :u_pr => 500-z-zz,
          :did => 530-z-zz
        })
    end
    if usertype == 'user'
      options = options.merge({
          :fontsize => 5,
          :dat_x => 15,
          :caf_x => 100,
          :cat_x => 200,
          :prefix => 270,
          :dur_x => 350,
          :han_x => 400,
          :u_pr => 500
        })
    end

    #  pdf.text(_('CDR_Records') + ": #{user.first_name} #{user.last_name}", {:font_size => 16, :top => 30, :alignment => :left})
    pdf.text(_('Period') + ": " + main_options[:date_from] + "  -  " + main_options[:date_till],        {:font_size => 10, :top => 55, :alignment => :left})
    pdf.text(_('Currency') + ": #{main_options[:show_currency]}",              {:font_size => 8,  :top => 74, :alignment => :left})
    pdf.text(_('Total_calls') + ": #{calls.size}",                        {:font_size => 8,  :top => 94, :alignment => :left})

    options[:total_calls] = calls.size
    options[:calls_per_page] = options[:calls_per_page_first]
    options = options.merge({:total_pages =>  PdfGen::Count.pages(calls.size, options[:calls_per_page], options[:calls_per_page_second])})
    #/options
    i = 1
    page_calls = 1
    #table header
    pdf = PdfGen::Generate.call_list_to_pdf_header(pdf, main_options[:direction], usertype, i, options)
    #/table header
    #page

    for call in calls
      #calldate2 - because something overwites calldate when changing date format
      pdf.text(call.calldate2,{:left=>options[:dat_x] , :top=>options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
      pdf.text(nice_src(call, {:pdf=>1}),                                   {:left=>options[:caf_x] , :top=>options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
      pdf.text(hide_dst_for_user(current_user, "pdf", call.dst.to_s),                                   {:left=>options[:cat_x] , :top=>options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
      pdf.text(nice_time(call['nice_billsec']),                         {:left=>options[:dur_x] , :top=>options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
      pdf.text(call.dispod,                           {:left=>options[:han_x] , :top=>options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})

      if ['admin', 'accountant'].include?(usertype)
        pdf.text(call.server_id,                               {:left=> options[:ser],  :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        pdf.text(call['provider_name'],                               {:left=> options[:p_na], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        if main_options[:can_see_finances]
          pdf.text(nice_number(call['provider_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                               {:left=> options[:p_ra], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          pdf.text(nice_number(call['provider_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),             {:left=> options[:p_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        end
        if main_options[:rs_active]
          pdf.text(call['nice_reseller'],                               {:left=> options[:r_na], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          if main_options[:can_see_finances]
            pdf.text(nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                {:left=> options[:r_ra], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:r_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          end
        end
        pdf.text(call['user'],                                                        {:left=> options[:u_na],  :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        if main_options[:can_see_finances]
          pdf.text(nice_number(call['user_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                                        {:left=> options[:u_ra],  :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          pdf.text(nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                                        {:left=> options[:u_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        end
        pdf.text(call['did'],                                 {:left=> options[:did], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        if main_options[:can_see_finances]
          pdf.text(nice_number(call['did_prov_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),{:left=> options[:did_p], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          pdf.text(nice_number(call['did_inc_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),             {:left=> options[:did_inc], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          pdf.text(nice_number(call['did_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),             {:left=> options[:did_ow], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
        end
      else
        if current_user.show_billing_info == 1 and main_options[:can_see_finances]
          if usertype == 'reseller'
            if current_user.reseller_allow_providers_tariff?
              pdf.text(call['provider_name'],                               {:left=> options[:p_na], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
              if main_options[:can_see_finances]
                pdf.text(nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                {:left=> options[:p_ra], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
                pdf.text(nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:p_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
              end
            end
            pdf.text(nice_number(call['reseller_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                {:left=> options[:r_ra], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(nice_number(call['reseller_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:r_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(call['user'],                                                        {:left=> options[:u_na],  :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(nice_number(call['user_rate'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                                        {:left=> options[:u_ra],  :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                                        {:left=> options[:u_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(call['did'],                                                                                                                                                          {:left=> options[:did], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          end
          if usertype == 'user'
            pdf.text(call['prefix'],                                                        {:left=> options[:prefix], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
            pdf.text(nice_number(call['user_price'], {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}),                                                        {:left=> options[:u_pr], :top=> options[:ystart]+(page_calls % options[:calls_per_page] * options[:xdelta]), :font_size =>options[:fontsize]})
          end
        end
      end
      if page_calls == options[:calls_per_page] and i != options[:total_calls]
        options[:ystart] = options[:second_page_start]
        page_calls = 0
        pdf.start_new_page
        pdf = PdfGen::Generate.call_list_to_pdf_header(pdf, main_options[:direction],current_user.usertype, i, options)
        options[:calls_per_page] = options[:calls_per_page_second]
      end


      page_calls += 1
      i += 1
    end

    #Totals
    pdf.text(_('Total'),               {:left=> 40,    :top=>options[:total_possition], :font_size =>options[:fontsize]})
    pdf.text(nice_time(total_calls.total_duration),{:left=> options[:dur_x], :top=>options[:total_possition], :font_size =>options[:fontsize]})
    if main_options[:can_see_finances]
      if ['admin', 'accountant'].include?(usertype)
        pdf.text(nice_number(total_calls.total_provider_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:p_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_reseller_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:r_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_user_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:u_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_did_prov_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:did_p], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_did_inc_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:did_inc], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_did_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:did_ow], :top=>options[:total_possition], :font_size =>options[:fontsize]})
      end
      if usertype == 'reseller'
        if current_user.reseller_allow_providers_tariff?
          pdf.text(nice_number(total_calls.total_provider_price, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:p_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        end
        pdf.text(nice_number(total_calls.total_reseller_price_with_dids, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:r_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
        pdf.text(nice_number(total_calls.total_user_price_with_dids, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:u_pr], :top=>options[:total_possition], :font_size =>options[:fontsize]})
      end
      if usertype == 'user'
        pdf.text(nice_number(total_calls.total_user_price_with_dids, {:nice_number_digits => digits, :change_decimal=>cgnd, :global_decimal=>gnd}), {:left=> options[:u_pr], :top=>options[:total_possition], :font_size =>options[:fontsize] })
      end
    end
    page_calls +=1
    # end
    return pdf
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
    dts.each{|d|
      numbers = (d.to_s.length.to_i / 93)
      if numbers.to_f > 1.to_f
        pdf.text(d.to_s, {:left =>10, :top=> ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
        (numbers.ceil.to_i-1).to_i.times{
          pdf.text('', {:left =>10, :top=> ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
          i+=1
        }
      else
        pdf.text(d.to_s, {:left =>10, :top=> ystart+(i.to_i % 30 * xdelta), :font_size => 8, :alignment => :left})
      end
      i+=1
    }
    return pdf
  end
end

