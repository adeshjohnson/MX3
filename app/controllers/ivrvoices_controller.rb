# -*- encoding : utf-8 -*-
class IvrvoicesController < ApplicationController

  layout "callc"
  before_filter :check_post_method, :only => [:destroy, :create, :update]
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_voice, :only => [:update, :edit, :destroy]
  before_filter :check_reseller
  before_filter :check_sound_direction


  def index
    @page_title = _('IVR_Voices')
    @page_icon = "play.png"
    @voices = current_user.ivr_voices
  end

  def sound_files 
    @page_title = _('IVR_sound_files')
    @page_icon = "play.png"
    @voices = current_user.ivr_voices
    @sounds = current_user.find_sound_files_for_ivrs
  end
   
  def new
    @page_title = _('New_IVR_Voice')
    @page_icon = "add.png"
  end

  def create
    ivr_voice = IvrVoice.new(params[:ivr])

    if ivr_voice.save
      flash[:status] = _('IVR_Voice_Created')
    else
      flash_errors_for(_('IVR_Voice_Not_Created'), ivr_voice)
    end
    redirect_to :action => :index and return false
  end

  def destroy

    if @voice.readonly.to_i == 1
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :action => :index and return false
    end

    if !IvrAction.find(:first, :conditions => "name = 'Change Voice' and data1 = '#{@voice.voice}'") and !IvrAction.find(:first, :conditions => "name = 'Playback' and data1 = '#{@voice.voice}'")
      sounds = @voice.ivr_sound_files
      flag = true
      for sound in sounds do
        if IvrAction.find(:first, :conditions => "name = 'Playback' and data2 = '#{sound.path}'")
          flag = false
        end
      end
      if flag
        @voice.destroy_with_file
        flash[:status] = _("IVR_Voice_Deleted")
      else
        flash[:notice] = _("Can_Not_Delete_Some_Sound_File_Are_In_Use")
      end
    else
      flash[:notice] = _("Can_Not_Delete_Voice_Is_In_Use")
    end
    redirect_to :action => :index
  end

=begin
  Before filter variables: @voice
=end

  def edit
    @page_title = _('Edit_IVR_Voice')
    @page_icon = "edit.png"
    @files = @voice.ivr_sound_files
  end

=begin
  Before filter variables: @voice
=end

  def update
    @voice.description = params[:voice][:description] if params[:voice]
    if @voice.save
      flash[:status] = _("IVR_Voice_Updated")
    else
      flash_errors_for(_('IVR_Voice_Not_Updated'), @voice)
    end
    redirect_to :action => :index
  end

  private

  def find_ivr_voice
    @voice = current_user.ivr_voices.find(:first, :conditions => ["id = ?", params[:id]])
    unless @voice
      flash[:notice] = _("Ivr_Voice_Was_Not_Found")
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main and return false
    end
  end

  def check_sound_direction
    dir = Confline.get_value("IVR_Voice_Dir")
    if !File.directory?(dir)
      flash[:notice] = _("Cannot_access") + ": #{dir}"
      redirect_to :controller => :callc, :action => :main
    end
  end

end
