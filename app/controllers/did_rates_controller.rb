# -*- encoding : utf-8 -*-
class DidRatesController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only=>[:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter { |c|
    view = [:index]
    edit = [:edit]
    allow_read, allow_edit = c.check_read_write_permission(view, edit, {:role => "accountant", :right => :acc_manage_dids_opt_1, :ignore => true})
    c.instance_variable_set :@allow_read, allow_read
    c.instance_variable_set :@allow_edit, allow_edit
    true
  }

  before_filter :check_reseller
  before_filter :find_did, :only => [:index]
  before_filter :find_did_rate, :only=>[:edit, :update, :manage]


  def index
    @page_title = _('Did_rates')
    @page_icon = 'coins.png'

    @did.check_did_rates

    @did_prov_rates_c = @did.did_prov_rates
    @did_incoming_rates_c = @did.did_incoming_rates
    @did_owner_rates_c = @did.did_owner_rates

    @did_prov_rates_f = @did.did_prov_rates("FD")
    @did_incoming_rates_f = @did.did_incoming_rates("FD")
    @did_owner_rates_f = @did.did_owner_rates("FD")

    @did_prov_rates_w = @did.did_prov_rates("WD")
    @did_incoming_rates_w = @did.did_incoming_rates("WD")
    @did_owner_rates_w = @did.did_owner_rates("WD")

    store_location
  end

  def edit
    @did = @did_rate.did
    @page_title = _('Edit_Did_rates')+ ": " + @did.did
    @page_icon = 'edit.png'
  end

  def update

    if (params[:did_rate] and params[:did_rate][:end_time]) and ((nice_time2(@did_rate.start_time) > params[:did_rate][:end_time]) or (params[:did_rate][:end_time] > "23:59:59"))
      flash[:notice] = _('Bad_time')
      redirect_to :action => :edit, :id => @did_rate.id and return false
    end

    rdetails = @did_rate.did_rate_details
    if @did_rate.update_attributes(params[:did_rate])

      # we need to create new rd to cover all day
      if (nice_time2(@did_rate.end_time) != "23:59:59") and ((rdetails[(rdetails.size - 1)] == @did_rate) )
        st = @did_rate.end_time + 1.second

        nrd = Didrate.new
        nrd.start_time = st.to_s
        nrd.end_time = "23:59:59"
        nrd.rate = @did_rate.rate
        nrd.connection_fee = @did_rate.connection_fee
        nrd.did_id = @did_rate.did_id
        nrd.increment_s = @did_rate.increment_s
        nrd.min_time = @did_rate.min_time
        nrd.daytype = @did_rate.daytype
        nrd.rate_type = @did_rate.rate_type
        if nrd.save
          Action.add_action_hash(current_user, {:action=>'did_rate_created', :target_id=>nrd.id, :target_type=>"Didrate", :data=>nrd.did_id})
        end
      end

      Action.add_action_hash(current_user, {:action=>'did_rate_edited', :target_id=>@did_rate.id, :target_type=>"Didrate", :data=>@did_rate.did_id})
      flash[:status] = _('Rate_details_was_successfully_updated')
      redirect_to :action => :index, :id => @did_rate.did_id
    else
      render :action => :edit
    end
  end


  def manage
    rdetails = @did_rate.did_rate_details_all

    rdaction = params[:rdaction]

    if rdaction == "COMB_WD"
      for rd in rdetails
        if rd.daytype == "WD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == "COMB_FD"
      for rd in rdetails
        if rd.daytype == "FD"
          rd.daytype = ""
          rd.save
        else
          rd.destroy
        end
      end
      flash[:status] = _('Rate_details_combined')
    end

    if rdaction == "SPLIT"

      for rd in rdetails
        nrd = Didrate.new
        nrd.start_time = rd.start_time
        nrd.end_time = rd.end_time
        nrd.rate = rd.rate
        nrd.connection_fee = rd.connection_fee
        nrd.did_id = rd.did_id
        nrd.increment_s = rd.increment_s
        nrd.min_time = rd.min_time
        nrd.daytype = "FD"
        nrd.rate_type = rd.rate_type
        nrd.save

        rd.daytype = "WD"
        rd.save
      end

      flash[:status] = _('Rate_details_split')
    end


    redirect_to :action => :index, :id => @did_rate.did_id
  end


  private

  def find_did
    @did = Did.find(:first, :conditions =>["id = ?", params[:id]])
    unless @did
      flash[:notice]=_('DID_was_not_found')
      redirect_to :controller=>:dids, :action=>:list and return false
    end
    if @did.reseller_id != session[:user_id] and session[:usertype].to_s == 'reseller'
      flash[:notice]=_('DID_was_not_found')
      redirect_to :controller=>:dids, :action=>:list and return false
    end
  end

  def check_reseller
    if current_user.usertype == 'reseller'
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def find_did_rate
    @did_rate = Didrate.find(:first, :conditions =>["id = ?", params[:id]])
    unless @did_rate
      flash[:notice]=_('Rate_was_not_found')
      redirect_to :controller=>:callc, :action=>:main and return false
    end
  end
end
