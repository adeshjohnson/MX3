# -*- encoding : utf-8 -*-
class PbxFunctionsController < ApplicationController

  require "yaml"
  layout "callc"
  before_filter :check_post_method, :only=>[:destroy, :create, :update, :set_allow]
  before_filter :check_localization
  before_filter :authorize
  before_filter :find_pbx_function, :only=>[:edit, :update, :set_allow]


  def list
    @page_title = _('Pbx_functions')

    @pbx_functions = Pbxfunction.find(:all, :order => "pf_type ASC")
  end

  def edit
    @page_title = _('Pbx_functions_edit')
  end

  def update
    @pbx_function.update_attributes(params[:pbx_function])
    if @pbx_function.save
      flash[:status] = _('Pbx_function_updated')
      redirect_to :action => :list and return false
    else
      flash[:notice] = _('Pbx_function_not_updated')
      redirect_to :action => :list and return false
    end
  end


  def set_allow
    @pbx_function.allow_resellers = @pbx_function.allow_resellers.to_i == 1 ? 0 : 1
    if @pbx_function.save
      flash[:status] = _('Pbx_function_updated')
      redirect_to :action => :list and return false
    else
      flash[:notice] = _('Pbx_function_not_updated')
      redirect_to :action => :list and return false
    end
  end

  private

  def find_pbx_function
    @pbx_function = Pbxfunction.find(:first, :conditions=>{:id=>params[:id]})
    unless @pbx_function
      flash[:notice] = _('Pbx_functions_was_not_found')
      redirect_to :controller=>"pbx_functions", :action => 'pbx_functions' and return false
    end
  end
end
