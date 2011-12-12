class IvrSoundFilesController < ApplicationController

  layout "callc"
  before_filter :check_localization
  before_filter :authorize

  before_filter :find_ivr_voice, :only => [:create]
  before_filter :find_ivr_sound_file, :only => [:destroy, :play_sound, :edit, :update]
  before_filter :check_reseller



  verify :method => :post, :only => [  :create, :destroy, :update ],
    :redirect_to => {:controller=>:callc, :action => :main },
    :add_flash => { :notice => _('Dont_be_so_smart'),
    :params => {:dont_be_so_smart => true}}


  def new
    @page_title = _('New_IVR_Sound_File')
    @page_icon = "add.png"
    @id = params[:id]
  end

=begin
  Before filter variables: @voice
=end

  def create
    @sound = IvrSoundFile.new({:ivr_voice_id => params[:id], :description => params[:description]})

    notice, name = Audio.create_file(params[:file], @voice, "/var/lib/asterisk/sounds/mor/ivr_voices/")
    if notice.blank?
      @sound.path = name
      @sound.size = params[:file].size.to_i
      if @sound.save
        flash[:status] = _("Sound_File_Was_Uploaded")
      else
        flash_errors_for(_("File_Not_Uploaded"), @sound)
      end
    else
      flash[:notice] = notice
    end
    redirect_to :controller => :ivrvoices,  :action => :edit, :id => params[:id]
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def destroy
    @voice = @file.voice

    if @file.readonly.to_i == 1
      flash[:notice] = _('Dont_be_so_smart')
      redirect_to :controller => :ivrvoices,  :action => :edit, :id => @voice.id and return false
    end

    if !IvrAction.find(:first, :conditions => ["name = 'Playback' and data2 = ?", @file.path])

      @file.destroy_with_file
      flash[:status] = _("Sound_File_Deleted")
    else
      flash[:notice] = _("Sound_File_Can_Not_Be_Deleted_In_Use")
    end
    redirect_to :controller => :ivrvoices,  :action => :edit, :id => @voice.id
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def play_sound
    @voice = @file.voice
    @dir = Confline.get_value("IVR_Voice_Dir")
    @title = Confline.get_value("Admin_Browser_Title")
    dst = @dir + @voice.voice+"/"+@file.path
    @dst = Web_Dir+"/ivr_voices/"+@voice.voice+"/"+@file.path
    if !File.exists?(dst)
      redirect_to :controller => :callc,  :action => :main and return false
    else
      render(:layout => "play_rec")
    end
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def edit
    @page_title = _('Edit_IVR_Sound_File')
    @page_icon = "edit.png"
  end

  #
  # @file set in before_filter (find_ivr_sound_file)
  #
  def update
    if !IvrAction.find(:first, :conditions => ["name = 'Playback' and data1 = ?", @file.path])
      @file.description = params[:description]
      @file.save
      flash[:status] = _("Sound_File_Updated")
    else
      flash_errors_for(_("Sound_File_Was_Not_Updated"), @file)
    end

    redirect_to :controller => :ivrvoices,  :action => :edit, :id => @file.ivr_voice_id
  end

  private

  def find_ivr_voice
    @voice = current_user.ivr_voices.find(:first, :conditions => ["id = ?", params[:id]])
    unless @voice
      flash[:notice] = _("Ivr_Voice_Was_Not_Found")
      redirect_to :controller => :callc, :action => :main
    end
  end

  def find_ivr_sound_file
    @file = current_user.ivr_sound_files.find(:first, :conditions => ["id = ?", params[:id]])

    unless @file
      flash[:notice] = _("Ivr_Sound_File_Was_Not_Found")
      redirect_to :controller => :callc, :action => :main
    end
  end

  def check_reseller
    if reseller? and current_user.own_providers.to_i == 0
      dont_be_so_smart
      redirect_to :controller => :callc, :action => :main
    end
  end

end
