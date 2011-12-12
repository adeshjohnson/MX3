class StylesheetsController < ApplicationController
#  layout  nil
#  session :off
#  def rcss
#    if rcss = params[:rcss]
#      file_base = rcss.gsub(/\.css$/i, '')
#      file_path = "#{RAILS_ROOT}/app/views/stylesheets/#{file_base}.rcss"
#
#      @usual_text_font_color=Confline.get_value("Usual_text_font_color").to_s
#      @usual_text_font_size = Confline.get_value("Usual_text_font_size").to_s
#      style(Confline.get_value("Usual_text_font_style").to_i)
#      @usual_text_font_style1 = @ar[0].to_s
#      @usual_text_font_style2 = @ar[1].to_s
#      @usual_text_font_style3 = @ar[2].to_s
#      @usual_text_highlighted_text_color = Confline.get_value("Usual_text_highlighted_text_color").to_s
#      style(Confline.get_value("Usual_text_highlighted_text_style").to_i)
#      @usual_text_highlighted_text_style1 = @ar[0].to_s
#      @usual_text_highlighted_text_style2 = @ar[1].to_s
#      @usual_text_highlighted_text_style3 = @ar[2].to_s
#      @usual_text_highlighted_text_size = Confline.get_value("Usual_text_highlighted_text_size").to_s
#      @header_footer_font_color = Confline.get_value("Header_footer_font_color").to_s
#      @header_footer_font_size = Confline.get_value("Header_footer_font_size").to_s
#      style(Confline.get_value("Header_footer_font_style").to_i)
#      @header_footer_font_style1 = @ar[0].to_s
#      @header_footer_font_style2 = @ar[1].to_s
#      @header_footer_font_style3 = @ar[2].to_s
#      @background_color = Confline.get_value("Background_color").to_s
#      @row1_color = Confline.get_value("Row1_color").to_s
#      @row2_color = Confline.get_value("Row2_color").to_s
#      @first_3_rows_color = Confline.get_value("3_first_rows_color").to_s
#      render(:file => file_path, :content_type => "text/css")
#    else
#      render(:nothing => true, :status => 404)
#    end
#  end
#
#  def show
#    @user = User.find(params[:id])
#    respond_to do |format|
#      format.html
#      format.css
#    end
#  end
#
#  def style(stile)
#    @ar = []
#    if stile >= 8
#      a=8
#      @ar[0]= "underline"
#    else
#      @ar[0]= "none"
#      a=0
#    end
#    stile = stile - a
#
#    if stile >= 6
#      @ar[1]= "italic"
#      b=4
#    else
#      @ar[1]= "none"
#      b=0
#    end
#    stile = stile - b
#
#    if stile >= 2
#      @ar[2]= "bold"
#    else
#      @ar[2]= "none"
#    end
#
#    return @ar
#
#  end

end
