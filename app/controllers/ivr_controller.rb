# -*- encoding : utf-8 -*-
class IvrController < ApplicationController
  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_action_silent, :only => [:update_data1, :update_data2, :action_params]
  before_filter :find_ivr_block_silent, :only => [:update_block_timeout_digits, :update_block_timeout_response, :update_block_name]
  before_filter :find_ivr, :only => [:edit, :update_ivr_name, :destroy]
  before_filter :find_ivr_block, :only => [:add_ivr_extension, :ivr_extlines, :change_block, :add_block]
  before_filter :check_reseller

  # Global variables. Defines possile choices for extensions and actions
  $pos_actions = ['Playback', 'Change Voice', 'Delay', 'Hangup', 'Transfer To', 'Debug', 'Set Accountcode', 'Change CallerID (Number)']
  $pos_extensions = %w(0 1 2 3 4 5 6 7 8 9 # * i t)
  $pos_variables = ['MOR_ASK_DST_TIMES']


  def settings
    @page_title = _('IVR_Settings')
    @page_icon = "play.png"
  end

  def settings_change
    Confline.set_value("IVR_Voice_Dir", params[:voice_dir])
    redirect_to :controller => "ivr", :action => "settings"
  end


  def index
    @page_title = _('IVRs')
    @page_icon = "play.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system"

    logger.fatal session[:ivr_index].to_yaml
    if session[:ivr_index] and session[:ivr_index].to_i > 0
      session_page_no = session[:ivr_index]
    else
      session_page_no = 1
    end

    @options = {}
    @options[:page] = ((params[:page].to_i < 1) ? session_page_no : params[:page].to_i)
    @total_ivrs = current_user.ivrs.count()
    @total_pages = (@total_ivrs.to_f / session[:items_per_page].to_f).ceil
    @options[:page] = @total_pages if @options[:page].to_i > @total_pages.to_i and @total_pages.to_i > 0
    fpage = ((@options[:page] - 1) * session[:items_per_page]).to_i

    session[:ivr_index] = 1 unless session[:ivr_index]
    session[:ivr_index] = @options[:page]

    @ivrs = current_user.ivrs.find(:all, :order => " name ASC", :offset => fpage.to_i, :limit => session[:items_per_page].to_i)

  end

  def new
    @page_title = _('New_IVR')
    @page_icon = "add.png"
  end

  def create
    @ivr = Ivr.new()
    @block = IvrBlock.new()
    @block.name = "New_Block"
    @block.name = params[:block_name].to_s if params[:block_name].to_s != ""
    @block.save

    @ivr.name = "New_Ivr"
    @ivr.start_block_id = @block.id
    @ivr.name = params[:ivr_name].to_s if params[:ivr_name].to_s != ""
    if @ivr.save
      @block.ivr_id = @ivr.id
      @block.timeout_response = 10
      @block.timeout_digits = 3
      @block.save
      flash[:status] = _('IVR_Was_Created')
    else
      @block.destroy
      flash[:notice] = _('IVR_Was_Not_Created')
    end
    redirect_to :action => :index
  end

  def edit
    @page_title = _('Edit_IVR')
    @page_icon = "edit.png"
    @help_link = "http://wiki.kolmisoft.com/index.php/IVR_system"

    @ivr_voices = current_user.ivr_voices.find(:first)
    @ivr_sound_files = current_user.ivr_sound_files.find(:first)

    @block = @ivr.start_block
    @blocks = IvrBlock.find(:all, :include => [:ivr_extensions, :ivr_actions], :conditions => ["ivr_id = ?", @ivr.id])
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions
  end

  # Sets default values for added and changed actions.
  #
  # Actions : <tt>['Playback', 'Delay', 'Change Voice', 'Hangup', 'Transfer To', 'Debug', 'Set Accountcode', 'Mor']</tt>
  # Variables: <tt>['MOR_DESTINATION']</tt>
  # <tt>params[:id]</tt> must be set to ID of an coresponding action.
  #
  # * *Playback*
  # Answer is performed before this action
  #
  # * *Delay*
  # * *Change* *Voice*
  # * *Hangup*
  # * *Transfer* *To*
  # * *Debug*
  # * *Set* *Accountcode*
  # <tt>data1</tt> - device name.
  #
  # * *Mor* - Sends user to MOR internal engine
  # Takes no params.
  #
  # * *Set* *Variable* - allows user to set some Asteris internal variable.
  # <tt>data1</tt> - variable name.
  # <tt>data2</tt> - variable value.

  def action_params
    @num = params[:action_name]
    #    @action = IvrAction.find(:first, :conditions => ["id = ?", params[:id]])
    #    params.each { |key, val|
    #      MorLog.my_debug("#{key} -> #{val}")
    #    }
    @action.name = @num.to_s
    @action.data1 = ""
    @action.data2 = ""
    @action.data3 = ""
    @action.data4 = ""
    @action.data5 = ""
    @action.data6 = ""

    case @action.name
      when "Playback"
        voice = current_user.ivr_voices.find(:first)
        voice ? @action.data1 = voice.voice : @action.data1 = ""
        if !@action.data1.blank?
          sound_file = current_user.ivr_sound_files.find(:first,
                                                         :joins => "LEFT JOIN ivr_voices ON (ivr_voices.id = ivr_sound_files.ivr_voice_id)",
                                                         :conditions => ["ivr_voices.voice = ?", @action.data1])
        end
        if sound_file
          @action.data2 = sound_file ? sound_file.path.to_s : ""
        end
      when "Delay"
        @action.data1 = 0
      when "Change Voice"
        @action.data1 = current_user.ivr_voices.find(:first) ? current_user.ivr_voices.find(:first).voice.to_s : ""
      when "Hangup"
        @action.data1 = "Busy"
      when "Transfer To"
        @action.data1 ="IVR"
        @action.data2 =current_user.ivrs.find(:first).id
      when "Debug"
        @action.data1 = "#{@action.ivr_block.name}_was_reached."
      when "Set Accountcode"
        @action.data1 = current_user.load_users_devices(:first, :conditions => "user_id > -1").id
      when "Mor"
      when "Set Variable"
        @action.data1 = $pos_variables[0]
        @action.data2 = "0"
      when "Change CallerID (Number)"
        @action.data1 = 0
    end
    @action.save
    critical_update(@action)

    render(:layout => false)
  end

  def update_block_name
    # @block is set in before filter
    @name = params[:data].to_s
    unless @name.blank?
      @block.name = @name
      @block.save
    end
    render :nothing => true
  end

  def update_ivr_name
    @name = params[:data].to_s
    if @ivr
      @ivr.name = @name if @name.to_s != ""
      @ivr.save
    end
    render :nothing => true and return false
  end

  def update_block_timeout_digits
    # @block is set in before filter
    @data = params[:data].to_i
    if @data.to_i >= 5
      @block.timeout_digits = @data.to_i
      @block.save
      critical_update(@block)
    end
    render_javascript "$('block_timeout_digits').value = #{@block.timeout_digits};"
  end

  def update_block_timeout_response
    # @block is set in before filter
    @data = params[:data].to_i
    if @data.to_i >= 10
      @block.timeout_response = @data.to_i
      @block.save
      critical_update(@block)
    end
    render_javascript "$('block_timeout_response').value = #{@block.timeout_response};"
  end

  def update_data1
    @data = params[:data]

    case params[:number]
      when "2"
        @action.data2 = @data
      when "3"
        @action.data3 = @data
      when "4"
        @action.data4 = @data
      when "5"
        @action.data5 = @data
      when "6"
        @action.data6 = @data
      else
        @action.data1 = @data
    end
    if @action.name == "Delay"
      @action.data1 = 2
      @action.data1 = @data.to_i if @data.to_i > 0
    end
    if @action.name == "Transfer To"
      case @action.data1
        when 'IVR'
          ivr = current_user.ivrs.find(:first)
          @action.data2 = ivr ? ivr.start_block_id : 0
        when 'DID'
          did = current_user.load_dids(:first)
          @action.data2 = did ? did.did : 0
        when 'Device'
          device = Device.find_by_sql("SELECT devices.id as id, users.first_name as first_name, users.last_name as last_name, devices.device_type as dev_type, devices.name as dev_name, devices.extension as dev_extension FROM devices LEFT JOIN users ON (devices.user_id = users.id) WHERE devices.user_id > -1 AND users.owner_id = #{current_user.id}")
          @action.data2 = device[0] ? device[0].dev_extension : 0
        when 'Block'
          block = @action.ivr_block.ivr.start_block_id
          @action.data2 = block ? block : 0
      end
    end

    if @action.name == "Playback"
      if !@action.data1.blank?
        file = current_user.ivr_sound_files.find(:first,
                                                 :joins => "LEFT JOIN ivr_voices ON (ivr_voices.id = ivr_sound_files.ivr_voice_id)",
                                                 :conditions => ["ivr_voices.voice = ?", @action.data1])
      end
      if file
        @action.data2 = file.path
      else
        @action.data2 = ""
      end
    end
    if @action.name == "Change CallerID (Number)"
      @action.data1 = @data.gsub(/\"|\'/, '')
    end

    @action.save
    critical_update(@action)

    if @action.name == "Transfer To" or @action.name == "Playback"
      render :layout => false
    else
      render :nothing => true and return false
    end
  end

  def update_data2
    if @action and params[:data]
      @action.data2 = params[:data]
      @action.save
      critical_update(@action)
    end
    render :nothing => true and return false
  end

  def extension_extent
    @ext = IvrExtension.find(:first, :conditions => ["id = ?", params[:id]])
    if @ext
      @data = request.raw_post.gsub("=", "")
      @data = "#" if @data == ""
      @ext.exten = @data.to_s
      @ext.save
      critical_update(@ext)
    end
    render :nothing => true and return false
  end

  def extension_block
    @data = params[:data]
    if params[:id] != '0' and @data.to_i != 0 # Hack for IE... it sometimes sends zeros instead ob block numbers.
      @ext = IvrExtension.find(:first, :include => [:ivr_block], :conditions => ["ivr_block_id = ? AND exten = ?", params[:id], params[:ext]])
      if @data.to_s == "-1"
        if @ext
          @ext.destroy
          critical_update(@ext)
        end
      else
        if @ext
          @ext.goto_ivr_block_id = @data.to_i
        else
          @ext = IvrExtension.new(:exten => params[:ext], :goto_ivr_block_id => @data.to_i, :ivr_block_id => params[:id])
        end
        @ext.save
        critical_update(@ext)
      end
    end
    render :nothing => true and return false
  end

  def add_ivr_action
    @ivr_voices = current_user.ivr_voices.find(:first)
    @ivr_sound_files = current_user.ivr_sound_files.find(:first)

    if params[:rm].to_s == 'true'
      @action = IvrAction.find(:first, :include => [:ivr_block], :conditions => ["ivr_actions.id = ?", params[:id]])
      @action.destroy if @action
    else
      @action = IvrAction.new(:ivr_block_id => params[:block_id], :name => "Delay", :data1 => "0")
      @action.save
    end
    @actions = IvrAction.find(:all, :conditions => ["ivr_block_id = ?", params[:block_id]])
    if @action
      @block = @action.ivr_block
      critical_update(@block)
    end
    render :layout => false
  end

  def add_ivr_extension
    # @block = IvrBlock.find(:first, :conditions => ["id = ?", params[:block_id]])
    @ivr = @block.ivr
    if params[:rm].to_s == 'true'
      ext=IvrExtension.find(:first, :conditions => ["id = ?", params[:id]])
      ext.destroy
    else
      ext = IvrExtension.new
      ext.ivr_block = @block
      ext.goto_ivr_block_id = @block.id
      ext.exten= $pos_extensions[0]
      ext.save
    end

    @ivr_voices = current_user.ivr_voices.find(:first)
    @ivr_sound_files = current_user.ivr_sound_files.find(:first)

    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    critical_update(@block)
    render :layout => false
  end

  def add_block
    # @block = IvrBlock.find(:first, :include => [:ivr], :conditions => ["ivr_blocks.id = ?", params[:block_id]])
    unless @block
      flash[:notice] = _("Block_Not_Found")
      render :partial => "redirect_home" and return false
    else
      @ivr = @block.ivr
      if params[:rm].to_s == "true"
        if IvrExtension.find(:all, :conditions => ["goto_ivr_block_id = ? and ivr_block_id != ?", @block.id, @block.id]).size == 0 and @block.id != @ivr.start_block.id
          @block.destroy
          @block = @ivr.start_block
        end
      else
        new_block = IvrBlock.new(:name => _("New_Block"), :timeout_digits => 3, :timeout_response => 10)
        new_block.ivr = @ivr
        new_block.save
        @block = new_block
      end
      @ivr_voices = current_user.ivr_voices.find(:first)
      @ivr_sound_files = current_user.ivr_sound_files.find(:first)
      @blocks = @ivr.ivr_blocks
      @extensions = @block.ivr_extensions
      @actions = @block.ivr_actions
      critical_update(@block)
      render(:layout => false) and return false
    end
  end

  def refresh_edit_window

    # reload servers to activate ivr changes - tmp workaround to activate ivr changes
    for server in Server.find(:all)
      if server.active == 1
        server.ami_cmd("extensions reload")
      end
    end

    unless (@block = IvrBlock.find(:first, :include => [:ivr], :conditions => ["ivr_blocks.id = ?", params[:block_id].gsub('=', '')]))
      flash[:notice] = _("Block_Not_Found")
      redirect_to :controller => :callc, :action => :main and return false
    end

    @ivr_voices = current_user.ivr_voices.find(:first)
    @ivr_sound_files = current_user.ivr_sound_files.find(:first)

    @ivr = @block.ivr
    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions
    render(:layout => false, :action => "add_block")
  end

  def change_block
    #@block = IvrBlock.find(:first, :conditions => "id = #{params[:block_id]}")
    @ivr = @block.ivr
    @blocks = @ivr.ivr_blocks
    @extensions = @block.ivr_extensions
    @actions = @block.ivr_actions
    render(:action => "add_block", :layout => false)
  end

  def ivr_extlines
    @page_title = _('IVR_Extlines')
    @page_icon = "asterisk.png"
    #@block = IvrBlock.find(:first, :conditions => "id = #{params[:block_id]}")
    @extlines = Extline.find(:all, :conditions => ["context = ?", 'ivr_block' + params[:block_id]])
  end

  def destroy
    if !current_user.dialplans.find(:first, :conditions => ["dptype = 'ivr' and (data2 = ? or data4 = ? or data6 = ? or data7 = ? )", @ivr.id, @ivr.id, @ivr.id, @ivr.id])
      @ivr.destroy
      flash[:status] = _("IVR_Deleted")
    else
      flash[:notice] = _("IVR_Is_In_Use")
    end
    redirect_to :controller => :ivr, :action => :index
  end

  # //IVR EDITING ################################################################

  private
=begin
  Is called when some value is changed and there is need to regenerate coresponding extlines.
  +object+ - IvrAction, IvrBlock, IvrExtension, IvrTimeperiod and of those objects are accepted as params. Finds IvrBlock and regenerates Extlines for this block.
=end
  def critical_update(object)
    case object.class.to_s
      when 'IvrAction'
        block = object.ivr_block
      when 'IvrBlock'
        block = object
      when 'IvrExtension'
        block = object.ivr_block
      when 'IvrTimeperiod'
        plans = current_user.dialplans.find(:all, :conditions => ["dptype = 'ivr' and (data1 = ? or data3 = ? or data5 = ?)", object.id, object.id, object.id])
        for plan in plans do
          plan.regenerate_ivr_dialplan
        end
      else
        block = nil
    end
    if block
      block.regenerate_extlines
    end
  end

  def find_ivr_action_silent
    @action = IvrAction.find(:first, :conditions => ["id = ?", params[:id]])
    unless @action
      render :nothing => true and return false
    end
  end

  def find_ivr_block_silent
    @block = IvrBlock.find(:first, :conditions => ["id = ?", params[:id]])
    unless @block
      render :nothing => true and return false
    end
  end

  def find_ivr
    @ivr = current_user.ivrs.find(:first, :conditions => ["id = ?", params[:id]])
    unless @ivr
      flash[:notice] = _('IVR_Was_Not_Found')
      redirect_to :controller => :ivr, :action => :index and return false
    end
  end

  def find_ivr_block
    @block = IvrBlock.find(:first, :conditions => ["id = ?", params[:block_id]])
    unless @block
      flash[:notice] = _('IVR_Block_Was_Not_Found')
      redirect_to :controller => :ivr, :action => :index and return false
    end
    if !@block.ivr or @block.ivr.user_id != current_user.id
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main
    end
  end

end
