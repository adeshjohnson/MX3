module FunctionsHelper
  def signup_url
    Web_URL.to_s + Web_Dir + "/callc/signup_start/" + current_user.get_hash
  end

  def homepage_url
    Web_URL.to_s + Web_Dir + "/callc/login/" + current_user.get_hash
  end

=begin
 Wrapper to create settings grouping.

 *Params*

 +name+ - ID for group. Every group must have unique ID in HTML page. Othevise
 it would be impossible to create gruop.
 +height+ - height of the box.
 +width+ - width of the box.
 +block+ - HTML code to be wraped inside block.

 *Helpers*

 It is designed to be used with other settings helpers.
 * setting_group_boolean - true/false settings
 * settings_group_text - text field with numeric
 * settings_group_number - text field with text value
=end

  def settings_group(nice_name, id, width, height, &block)
    res = ["<div id='#{id}'>"]
    res << "<div class='dhtmlgoodies_aTab'>"
    res << "<table class='simple' width='100%'>"
    res << capture(&block)
    res << "</table>"
    res << "</div>"
    res << "</div>"
    dtree_group_script(nice_name, id, width, height)
    concat(res.join("\n"), block.binding)
  end

=begin
 Simple helper to generate script yhat shows tabs.
=end

  def dtree_group_script(name ,div_name, width, height)
    content_for :scripts do
      content_tag(:script, "initTabs('#{div_name}', Array('#{name}'),0,#{width},#{height});", :type=>"text/javascript")
    end
  end

=begin
  Boolean setting.

 *Params*

 +name+ - nice name. It will be displayed as a text near checkbox.
 +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 +conf_name+ - Confline name. This value will be selected when form is being generated.

=end

  def setting_group_boolean(name, prop_name, conf_name, options = {})
    opts ={}.merge(options)
    settings_group_line(name, options[:tip]){
      "#{check_box_tag  prop_name, "1", Confline.get_value(conf_name, session[:user_id]).to_i == 1}#{opts[:sufix]}"
    }
  end

=begin
  Text setting.

 *Params*

 +name+ - nice name. It will be displayed as a text near text field.
 +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 +conf_name+ - Confline name. This value will be selected when form is being generated.

=end

  def settings_group_text(name, prop_name, conf_name, options = {}, html_options = {})
    opts = {:sufix => ""}.merge(options)
    html_opts ={
      :class => "input",
      :size => "35",
      :maxlength => "50"}.merge(html_options)
    settings_group_line(name, html_options[:tip]){
      "#{text_field_tag(prop_name, Confline.get_value(conf_name, session[:user_id]) , html_opts )}#{opts[:sufix]}"
    }
  end

=begin
  numeric setting.

 *Params*

 +name+ - nice name. It will be displayed as a text near text field.
 +prop_name+ - HTML name value. This will be sent to params[:prop_name] when you submit the form.
 +conf_name+ - Confline name. This value will be selected when form is being generated.

=end

  def settings_group_number(name, prop_name, conf_name, options = {}, html_options = {})
    opts = {:sufix => ""}.merge(options)
    html_opts ={
      :class => "input",
      :size => "35",
      :maxlength => "50"}.merge(html_options)
    settings_group_line(name, html_options[:tip]){
      "#{text_field_tag(prop_name, Confline.get_value(conf_name, session[:user_id]).to_i, html_opts)}#{opts[:sufix]}"
    }
  end

  def disabled_if_not(curr_func, name)
    "; display: none;" if curr_func.pf_type != name
  end

  def disabled_if(curr_func, *names)
    "; display: none;" if names.include?(curr_func.pf_type)
  end

end
