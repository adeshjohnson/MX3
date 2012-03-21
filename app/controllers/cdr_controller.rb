# -*- encoding : utf-8 -*-
class CdrController < ApplicationController
  layout "callc"
  before_filter :check_localization
  before_filter :authorize

  def index
    redirect_to :controller => :callc, :action=> :main
  end

  # ======== CSV IMPORT =================

  def import_csv

    step_names = [_('Import_CDR'), _('File_upload'), _('Column_assignment'), _('Column_confirmation'),_('Select_details'), _('Analysis'), _('Fix_clis'), _('Create_clis'), _('Assigne_clis'), _('Import_CDR')]
    params[:step] ? @step = params[:step].to_i : @step = 0
    @step = 0 if @step > step_names.size or @step < 0
    @step_name = step_names[@step]

    @page_title = _('Import_CSV') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name.to_s
    @page_icon = 'excel.png';

    @sep, @dec = nice_action_session_csv

    if @step == 0
      my_debug_time "**********import CDR ************************"
      my_debug_time "step 0"
      session[:cdr_import_csv] = nil
      session[:temp_cdr_import_csv] = nil
      session[:import_csv_cdr_import_csv_options] = nil
      session[:file_lines] = 0
      session[:cdrs_import] = nil
    end

    if @step == 1
      my_debug_time "step 1"
      session[:temp_cdr_import_csv] = nil
      session[:cdr_import_csv] = nil
      session[:cdrs_import]  = nil
      if params[:file]
        @file = params[:file]
        if  @file.size > 0
          if !@file.respond_to?(:original_filename) or !@file.respond_to?(:read) or !@file.respond_to?(:rewind)
            flash[:notice] = _('Please_select_file')
            redirect_to :action => :import_csv,  :step => 0 and return false
          end
          if get_file_ext(@file.original_filename, "csv") == false
            @file.original_filename
            flash[:notice] = _('Please_select_CSV_file')
            redirect_to :action => :import_csv,  :step => 0 and return false
          end
          @file.rewind
          file = @file.read
          session[:cdr_file_size] = file.size
          session[:temp_cdr_import_csv] = CsvImportDb.save_file("_crd_",file)
          flash[:status] = _('File_downloaded')
          redirect_to :action => :import_csv,  :step => 2 and return false
        else
          session[:temp_cdr_import_csv] = nil
          flash[:notice] = _('Please_select_file')
          redirect_to :action => :import_csv,  :step => 0 and return false
        end
      else
        session[:temp_cdr_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 0 and return false
      end
    end


    if @step == 2
      my_debug_time "step 2"
      my_debug_time "use : #{session[:temp_cdr_import_csv]}"
      if session[:temp_cdr_import_csv]
        file = CsvImportDb.head_of_file("/tmp/#{session[:temp_cdr_import_csv]}.csv", 20).join("").to_s
        session[:file] = file
        a = check_csv_file_seperators(file, 2,2, {:line=>0})
        if a
          @fl = CsvImportDb.head_of_file("/tmp/#{session[:temp_cdr_import_csv]}.csv", 1).join("").to_s.split(@sep)
          begin
            colums ={}
            colums[:colums] = [{:name=>"f_error", :type=>"INT(4)", :default=>0}, {:name=>"nice_error", :type=>"INT(4)", :default=>0},{:name=>"do_not_import", :type=>"INT(4)", :default=>0},{:name=>"changed", :type=>"INT(4)", :default=>0}, {:name=>"not_found_in_db", :type=>"INT(4)", :default=>0}, {:name=>"id", :type=>'INT(11)', :inscrement=>' NOT NULL auto_increment '}]
            session[:cdr_import_csv] = CsvImportDb.load_csv_into_db(session[:temp_cdr_import_csv], @sep, @dec, @fl, nil, colums)
            session[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:temp_cdr_import_csv]}")
          rescue Exception => e
            MorLog.log_exception(e, Time.now.to_i, params[:controller], params[:action])
            session[:import_csv_cdr_import_csv_options] = {}
            session[:import_csv_cdr_import_csv_options][:sep] = @sep
            session[:import_csv_cdr_import_csv_options][:dec] = @dec
            session[:file] = File.open("/tmp/#{session[:temp_cdr_import_csv]}.csv", "rb").read
            CsvImportDb.clean_after_import(session[:temp_cdr_import_csv])
            session[:temp_cdr_import_csv] = nil
            redirect_to :action => "import_csv",  :step => 2 and return false
          end
          flash[:status] = _('File_uploaded') if !flash[:notice]
        end
      else
        session[:cdr_import_csv] = nil
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 1 and return false
      end
      
    end

    if  @step > 2

      unless ActiveRecord::Base.connection.tables.include?(session[:temp_cdr_import_csv])
        flash[:notice] = _('Please_upload_file')
        redirect_to :action => :import_csv,  :step => 0 and return false
      end

      if session[:cdr_import_csv]

        if @step == 3
          my_debug_time "step 3"
          if params[:calldate_id] and params[:billsec_id] and params[:calldate_id].to_i >= 0 and params[:billsec_id].to_i >= 0
            @options = {}

            @options[:imp_calldate] = return_correct_select_value(params[:calldate_id])
            @options[:imp_date] = -1 #params[:date_id].to_i
            @options[:imp_time] = -1 #params[:time_id].to_i
            @options[:imp_clid] = return_correct_select_value(params[:clid_id])
            @options[:imp_src_name] = return_correct_select_value(params[:src_name_id])
            @options[:imp_src_number] = return_correct_select_value(params[:src_number_id])
            @options[:imp_dst] = return_correct_select_value(params[:dst_id])
            @options[:imp_duration] = return_correct_select_value(params[:duration_id])
            @options[:imp_billsec] = return_correct_select_value(params[:billsec_id])
            @options[:imp_disposition] = return_correct_select_value(params[:disposition_id])
            @options[:imp_accountcode] = return_correct_select_value(params[:accountcode_id])
            @options[:sep] = @sep
            @options[:dec] = @dec

            @options[:file]= session[:file]
            @options[:file_lines] = ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:temp_cdr_import_csv]}")
            session[:cdr_import_csv2] = @options
            flash[:status] = _('Columns_assigned')
          else
            flash[:notice] = _('Please_Select_Columns')
            redirect_to :action => :import_csv,  :step => 2 and return false
          end
        end

        if session[:cdr_import_csv2] and session[:cdr_import_csv2][:imp_calldate] and session[:cdr_import_csv2][:imp_billsec]


          if @step == 4
            my_debug_time "step 4"
            @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}", :order => "nice_user ASC", :group=>'users.id')
            @providers = current_user.load_providers(:all , :conditions=>'hidden=0')
            if !@providers or @providers.size.to_i < 1
              flash[:notice] = _('No_Providers')
              redirect_to :action => :import_csv,  :step => 0 and return false
            end
          end

          #check how many destinations and should we create new ones?
          if @step == 5
            my_debug_time "step 5"
            @new_step = 6
            session[:cdr_import_csv2][:import_type] = params[:import_type].to_i
            session[:cdr_import_csv2][:import_provider] = params[:provider].to_i
            unless params[:provider]
              flash[:notice] = _('Please_select_Provider')
              redirect_to :action => :import_csv,  :step => 4 and return false
            end
            if session[:cdr_import_csv2][:import_type].to_i == 0
              session[:cdr_import_csv2][:import_user] = params[:user].to_i
              session[:cdr_import_csv2][:import_device] = params[:device_id].to_i
              if User.find(:first, :conditions=>{:id=>params[:user]}) and Device.find(:first, :conditions=>{:id=>params[:device_id]})
                @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
                @new_step = 9
                @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
                session[:cdr_analize] = @cdr_analize
              else
                flash[:notice] = _('User_and_Device_is_bad')
                redirect_to :action => :import_csv,  :step => 4 and return false
              end
            else
              if session[:cdr_import_csv2][:imp_clid].to_i == -1
                flash[:notice] = _('Please_select_CLID_commun')
                redirect_to :action => :import_csv,  :step => 2 and return false
              end
              session[:cdr_import_csv2][:create_callerid]  =  params[:create_callerid].to_i
              @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
              @new_step = 9 if @cdr_analize[:bad_clis].to_i == 0 and @cdr_analize[:new_clis_to_create].to_i == 0
              flash[:status] = _('Analysis_completed')
              @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
              session[:cdr_analize] = @cdr_analize
            end
          end

          # fix bad cdrs
          if @step == 6
            my_debug_time "step 6"
            @cdr_analize = session[:cdr_analize]
            @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
            @options = {}
            session[:cdrs_import] ? @options = session[:cdrs_import] : @options = {}
            # search
            params[:page]  ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])
            params[:hide_error]  ? @options[:hide] = params[:hide_error].to_i : (@options[:hide] = 0 if !@options[:hide])

            cond = ""
            if @options[:hide].to_i > 0
              cond = " AND nice_error != 2"
            end
            
            fpage, @total_pages, @options = pages_validator(@options, ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 #{cond }").to_f, params[:page])
            @import_cdrs = ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 #{cond } LIMIT #{fpage}, #{session[:items_per_page]}")
            @next_step = session[:cdr_import_csv2][:create_callerid].to_i == 0 ? 9 : 7
          end

          if  session[:cdr_import_csv2][:create_callerid].to_i == 1 and @step == 7 or @step == 8
            # create clis
            if @step == 7
              my_debug_time "step 7"
              @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
              @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
              cclid = Callerid.create_from_csv(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
              flash[:status] = _('Create_clis') + ": #{cclid.to_i}"
            end

            # assigne clis
            if @step == 8
              my_debug_time "step 8"
              session[:cdr_import_csv2][:step] = 8
              session[:cdrs_import2] ? @options = session[:cdrs_import2] : @options = {}
              # search
              params[:page]  ? @options[:page] = params[:page].to_i : (@options[:page] = 1 if !@options[:page])


              @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
              @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]

              fpage, @total_pages, @options = pages_validator(@options, Callerid.count(:all, :conditions=>{:device_id => -1}).to_f, params[:page])
              @clis = Callerid.find(:all, :conditions=>{:device_id => -1}, :offset=>fpage, :limit=>session[:items_per_page])

              @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}", :order => "nice_user ASC", :group=>'users.id')
            end
          else
            if @step == 7 or @step == 8
              dont_be_so_smart
              redirect_to :action => :import_csv,  :step => 6 and return false
            end
          end

          # create cdrs with user and device
          if @step == 9
            my_debug_time "step 9"
            start_time = Time.now
            @cdr_analize = Call.analize_cdr_import(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
            @cdr_analize[:file_lines] = session[:cdr_import_csv2][:file_lines]
            begin
              @total_cdrs, @errors =  Call.insert_cdrs_from_csv(session[:temp_cdr_import_csv], session[:cdr_import_csv2])
              flash[:status] = _('Import_completed')
              session[:temp_cdr_import_csv] = nil
              @run_time = Time.now - start_time
              MorLog.my_debug Time.now - start_time
            rescue Exception => e
              flash[:notice] = _('Error')
              MorLog.log_exception(e, Time.now, 'CDR', 'csv_import')
            end
          end
        else
          flash[:notice] = _('Please_Select_Columns')
          redirect_to :action => :import_csv,  :step => "2" and return false
        end
      else
        flash[:notice] = _('Zero_file')
        redirect_to :controller=>"tariffs", :action=>"list" and return false
      end
    end
  end


  def cli_add
    @dev = Device.find(:first, :conditions=>{:id=>params[:device_id]})
    @cli = Callerid.find(:first, :conditions=>{:id=>params[:id]})

    unless @dev or @cli
      @error = _('Device_or_Cli_not_found')
      @users = User.find(:all, :select=>"users.*, #{SqlExport.nice_user_sql}", :joins=>"JOIN devices ON (users.id = devices.user_id)", :conditions => "hidden = 0 and devices.id > 0 AND owner_id = #{correct_owner_id}", :order => "nice_user ASC", :group=>'users.id')
    else
      @cli.device_id = @dev.id
      @cli.added_at = Time.now
      @cli.save
    end
    render :layout => false and return false
  end


  def fix_bad_cdr
    id = params[:id].to_i
    cli = params[:cli]
    calldate = params[:calldate]
    dst = params[:dst]
    billsec = params[:billsec]
    source_number = params[:src_number]

    unless ActiveRecord::Base.connection.tables.include?(session[:temp_cdr_import_csv])
      @error = _('CDR_not_found')
      redirect_to  :layout => false and return false
    end

    MorLog.my_debug "SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 and id = #{params[:id]}"
    @cdr =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 and id = #{params[:id]}")

    unless @cdr  and @cdr.size > 0
      @error = _('CDR_not_found')
      render :layout => false and return false
    end

    if cli.to_s.match(/^[0-9]+$/) == nil
      @error = _('CLI_is_not_number')
      render :layout => false and return false
    else
      MorLog.my_debug "UPDATE #{session[:temp_cdr_import_csv]} SET col_#{session[:cdr_import_csv2][:imp_clid]} = '#{cli}', col_#{session[:cdr_import_csv2][:imp_calldate]} = '#{calldate}', col_#{session[:cdr_import_csv2][:imp_billsec]} = '#{billsec}', col_#{session[:cdr_import_csv2][:imp_dst]} = '#{dst}', f_error = 0, changed = 1 WHERE f_error = 1 and id = #{params[:id]}"
      ActiveRecord::Base.connection.execute("UPDATE #{session[:temp_cdr_import_csv]} SET col_#{session[:cdr_import_csv2][:imp_clid]} = '#{cli}', col_#{session[:cdr_import_csv2][:imp_calldate]} = '#{calldate}', col_#{session[:cdr_import_csv2][:imp_billsec]} = '#{billsec}', col_#{session[:cdr_import_csv2][:imp_dst]} = '#{dst}', f_error = 0, changed = 1 WHERE f_error = 1 and id = #{params[:id]}")
    end

    if Call.find(:first, :conditions=>{:calldate=>calldate, :billsec=>billsec, :dst=>dst})
      @error = _('CDR_exist_in_db_match_caldate_dst_src')
      render :layout => false and return false
    else
      ActiveRecord::Base.connection.execute("UPDATE #{session[:temp_cdr_import_csv]} SET col_#{session[:cdr_import_csv2][:imp_clid]} = '#{cli}', col_#{session[:cdr_import_csv2][:imp_calldate]} = '#{calldate}', col_#{session[:cdr_import_csv2][:imp_billsec]} = '#{billsec}', col_#{session[:cdr_import_csv2][:imp_dst]} = '#{dst}', f_error = 0, changed = 1 WHERE f_error = 1 and id = #{params[:id]}")
      @cdr =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 0 and id = #{params[:id]}")
      render :layout => false and return false
    end

   
  end

  def not_import_bad_cdr
    @cdr =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE f_error = 1 and id = #{params[:id]}")

    unless @cdr
      @error = _('CDR_not_found')
    else
      ActiveRecord::Base.connection.execute("UPDATE #{session[:temp_cdr_import_csv]} SET do_not_import = 1 WHERE f_error = 1 and id = #{params[:id]}")
      @cdr =  ActiveRecord::Base.connection.select_all("SELECT * FROM #{session[:temp_cdr_import_csv]} WHERE do_not_import = 1 and id = #{params[:id]}")
    end
    render :layout => false and return false
  end


  def rerating
    @step =  (params[:step] ? params[:step].to_i : 1)
    @step_name = [nil, _('Select_details'), _('Confirm'), _('Status')][@step]

    @page_title = _('CDR_Rerating') + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + _('Step') + ": " + @step.to_s + "&nbsp;&nbsp;&nbsp;-&nbsp;&nbsp;&nbsp;" + @step_name
    @page_icon = 'coins.png';

    if @step == 1
      @users = User.find(:all, :select=>"*, #{SqlExport.nice_user_sql}", :conditions => "hidden = 0", :order => "nice_user ASC")
      @tariffs = Tariff.find(:all, :conditions => "purpose != 'provider' ", :order => "name ASC")
    end

    if @step == 2

      session[:rerating_testing] = params[:rerating_testing].to_i

      change_date

      users = []

      if params[:user].to_i == -1
        users = User.find(:all)
      else
        user = User.find(:first, :conditions => ["users.id = ?", params[:user]])
        users << user if user
      end

      unless users and users.size.to_i > 0
        flash[:notice] = _('User_not_found')
        redirect_to :action=>:rerating and return false
      end

      @calls_stats = 0
      @billsec = 0
      @provider_price = 0
      @reseller_price = 0
      @user_price = 0
      @total_calls = 0
      @users_with_calls = 0

      for @user in users

        if @user

          @calls_stats = @user.calls_total_stats('answered', session_from_datetime, session_till_datetime)
          @billsec += @calls_stats["total_billsec"].to_f
          @provider_price += @calls_stats["total_provider_price"].to_f
          @reseller_price +=  @calls_stats["total_reseller_price"].to_f
          @user_price += @calls_stats["total_user_price"].to_f
          @total_calls += @calls_stats["total_calls"].to_i
          @users_with_calls +=1 if @calls_stats["total_calls"].to_i > 0

        end

      end

      flash[:notice] = _('No_calls_to_rerate') if @total_calls == 0

      session[:rerating_testing] = params[:rerating_testing].to_i
      session[:rerating_testing_tariff_id] = params[:test_tariff_id].to_i
      session[:rerating_user_id] = params[:user].to_i

      @user_id = params[:user].to_i

    end




    if @step == 3

      @user_id = params[:user].to_i

      users = []

      if params[:user].to_i == -1
        users = User.find(:all, :include =>[:tariff])
      else
        user = User.find(:first, :include =>[:tariff], :conditions => ["users.id = ?", params[:user]])
        users << user if user
      end

      unless users and users.size.to_i > 0
        flash[:notice] = _('User_not_found')
        redirect_to :action=>:rerating and return false
      end

      @old_billsec = params[:billsec].to_i
      @old_provider_price = params[:pprice].to_f
      @old_reseller_price = params[:rprice].to_f
      @old_user_price = params[:price].to_f

      testing = session[:rerating_testing].to_i
      test_tariff_id = 0
      test_tariff_id = session[:rerating_testing_tariff_id].to_i if testing == 1

      @billsec = 0
      @provider_price = 0
      @reseller_price = 0
      @user_price = 0
      @total_calls = 0
      @total_users = 0

      providers_cache = {}


      for @user in users

        if @user

          @calls = @user.calls('answered', session_from_datetime, session_till_datetime)

          if @calls and @calls.size > 0
            @total_calls += @calls.size
            @total_users += 1
          end

          one_user_price = 0
          one_old_user_price = 0
          one_reseller_price = 0
          one_old_reseller_price = 0

          for call in @calls
            
            one_old_user_price += call.user_price.to_f
            one_old_reseller_price += call.reseller_price.to_f

            provider = providers_cache["p_#{call.provider_id}".to_sym] ||= Provider.find(:first, :include => [:tariff], :conditions => ["providers.id = ?", call.provider_id])
            if provider.user_id == current_user.get_corrected_owner_id
              call = call.count_cdr2call_details(provider.tariff, @user, test_tariff_id) if provider and call.user_id

              if testing == 0
                call.save
              end

              one_user_price += call.user_price.to_f
              one_reseller_price += call.reseller_price.to_f

              @billsec += call.billsec
              @provider_price += call.provider_price.to_f
            else
              one_user_price += 0.to_f
              one_reseller_price += 0.to_f

              @billsec += call.billsec
              @provider_price += 0.to_f
            end
          end

          @reseller_price += one_reseller_price
          @user_price += one_user_price

          #update prepaid user balance  (why only prepaid? - postpaid should be also edited)
          #if @user.postpaid == 0
          @user.balance = @user.balance - (one_user_price - one_old_user_price)
          if testing == 0
            @user.save
          end

          # handle resellers balance
          if @user.owner_id > 0
            @reseller == nil
            @reseller = User.find(:first, :conditions => ["id = ?", @user.owner_id])
            if @reseller
              @reseller.balance = @reseller.balance - (one_reseller_price - one_old_reseller_price)
              if testing == 0
                @reseller.save
              end
            end
          end


        end #if @user
      end #for @user in users

      #end
      flash[:status] = _('Rerating_completed')
    end #step 3
  end

  private

  def clean_value(value)
    cv = value.to_s.gsub("\"", "")
    cv
  end

  def return_correct_select_value(param)
    param ?  param.to_i : -1
  end
end
