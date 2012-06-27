# -*- encoding : utf-8 -*-
class CurrenciesController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization, :except => [:calculate]
  before_filter :authorize, :except => [:calculate]
  before_filter :find_currecy, :only => [:currencies_change_update_status, :currencies_change_status, :currencies_change_default, :edit, :update, :destroy]

  def calculate
    @without_tax = (params[:curr1].to_s == params[:curr2].to_s ? round_to_cents(params[:amount].to_f) : exchange(params[:amount], params[:curr1], params[:curr2]).to_f)
    @without_tax = params[:min_amount].to_f if !params[:min_amount].blank? and @without_tax.to_f < params[:min_amount].to_f
    @without_tax = params[:max_amount].to_f if !params[:max_amount].blank? and !params[:max_amount].to_f.zero? and @without_tax.to_f > params[:max_amount].to_f
    @tax_in_amount = params[:tax_in_amount].to_s
    if @tax_in_amount == 'excluded'
      @with_tax = ActiveProcessor.configuration.substract_tax.call(params[:user].to_i, @without_tax.to_f)
      @with_tax, @without_tax = @without_tax, @with_tax
    else
      @with_tax = ActiveProcessor.configuration.calculate_tax.call(params[:user].to_i, @without_tax.to_f)
    end

    result = {
        :without_tax => round_to_cents(@without_tax.to_f),
        :with_tax => round_to_cents(@with_tax.to_f)
    }

    respond_to do |format|
      format.json {
        render :json => result.to_json
      }
    end
  end

  def currencies
    @page_title = _('Currencies')
    @page_icon = "money_dollar.png"
    @currs = Currency.find(:all, :order => "id ASC")
  end


  def currencies_change_update_status
    @currency.curr_update = @currency.curr_update == 1 ? 0 : 1
    if @currency.save
      flash[:status] = @currency.curr_update == 1 ? _('Currency_update_enabled') : _('Currency_update_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def currencies_change_status
    @currency.active = @currency.active == 1 ? 0 : 1
    if @currency.save
      flash[:status] = @currency.active == 1 ? _('Currency_enabled') : _('Currency_disabled')
    else
      flash_errors_for(_('Currency_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def change_default
    @page_title = _('Default_currency')
    @page_icon = 'money_dollar.png'
    @currs = Currency.find(:all)
  end

  def currencies_change_default
    curr = @currency.set_default_currency
    if curr
      session[:default_currency] = curr
      flash[:status] = _('Currencies_rates_updated')
    else
      flash[:notice] = _('Error_Please_Try_Again_Later')
    end
    redirect_to :action => :change_default
  end

  def update_currencies_rates
    if params[:all].to_i == 1
      begin
        Currency.transaction do
          Currency.update_currency_rates
        end
      rescue Exception => e
      end
    else
      @currency = Currency.find(:first, :conditions => ['id=?', params[:id]])
      unless @currency
        flash[:notice] = _('Currency_was_not_found')
        redirect_back_or_default("/currencies/currencies")
      end
      @currency.update_rate
      if @currency.exchange_rate == 0 
        flash[:notice] = _('Yahoo_could_not_find_currency') 
        redirect_to :action => 'currencies' and return false 
      end 
    end
    flash[:status] = _('Currencies_rates_updated')
    redirect_to :action => 'currencies'
  end

  def edit
    @page_title = _('Currency_edit')
    @page_icon = 'edit.png'
  end

  def update
    @currency.full_name = params[:full_name]
    if params[:exchange_rate].to_f > 0.to_f
      @currency.exchange_rate = params[:exchange_rate].to_f
      @currency.exchange_rate = 1 if @currency.id == 1
      @currency.last_update = Time.now
    else
      @currency.active = 0
      @currency.last_update = Time.now
    end
    if @currency.save
      flash[:status] = _('Currency_details_updated')
    else
      flash_errors_for(_('Currency_details_not_updated'), @currency)
    end
    redirect_to :action => 'currencies'
  end

  def destroy
    total_tariffs = @currency.tariffs.size

    if (@currency.id != 1) and (total_tariffs == 0) and (@currency.curr_edit != 1) #AND check if some tariff etc uses this currency
      session[:show_currency] = session[:default_currency] if session[:show_currency] == @currency.name
      @currency.destroy
      flash[:status] = _('Currency_deleted')
    else
      flash[:notice] = _('Cant_delete_this_currency_some_tariffs_are_using_it') if total_tariffs != 0
    end
    redirect_to :action => 'currencies'

  end

  private

  def exchange(amount, curr1, curr2)
    amount = amount.to_f * ActiveProcessor.configuration.currency_exchange.call(curr1, curr2) if defined? ActiveProcessor.configuration.currency_exchange
    return round_to_cents(amount)
  end

  def round_to_cents(amount)
    sprintf("%.2f", amount)
  end

  def find_currecy
    @currency = Currency.find(:first, :conditions => ['id=?', params[:id]])
    unless @currency
      flash[:notice] = _('Currency_was_not_found')
      redirect_back_or_default("/currencies/currencies") and return false
    end
  end

end
