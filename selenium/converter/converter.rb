# encoding: utf-8
#!/usr/bin/env ruby
require 'rexml/document'
# MAYBE useless function
class String
  def gsub_by_array(hash)
    str = self
    hash.each { |key, value|
      str = str.gsub(key.to_s, value.to_s)
    }
    str
  end
end


class Base
  #  attr_reader :options
  @@options ={
      :global_timeout => 60000,
      :receiver => "@selenium",
      :header =>
          "# encoding: utf-8
require 'rubygems'
require 'selenium'
require 'test/unit'
gem 'selenium-client'
require 'selenium/client'

class NewTest < Test::Unit::TestCase
  def setup
    @verification_errors = []
    #if $selenium
     # @selenium = $selenium
    #else
     # @selenium = Selenium::SeleniumDriver.new(\"localhost\", 4444, \"*chrome\", \"${baseURL}\", 10000);
     # @selenium.start
    #end
@selenium = Selenium::Client::Driver.new( \
      :host => \"localhost\",
      :port => 4444,
      :browser => \"*chrome\",
      :url => \"${baseURL}\",
      :timeout_in_second => 10000)

    @selenium.start_new_browser_session
    @selenium.set_context(\"${test_name}\")
  end

  def teardown
   # @selenium.stop unless $selenium
@selenium.close_current_browser_session
  #  assert_equal [], @verification_errors

    @verification_errors.each {|e| puts '\n\n' + e.class.to_s + ' >>>>>>>> ' + e.to_s + '\n'
    puts e.backtrace
    }
    assert_equal [], @verification_errors
  end

  def test_${test_name}",
      :footer =>
          "  end\nend",
      :host => "http://localhost:3000",
      :indent => 2,
      :initialIdents => 4,
      :debug => 0
  }

  def Base.debug= (debug)
    @@options[:debug]= debug
  end

  def Base.host= (host)
    @@options[:host]= host
  end

  def Base.timeout= (time)
    @@options[:global_timeout]= time
  end

  def Base.options
    @@options
  end

  def Base.underscore(text)
    under = text.to_s.gsub(/[A-Z]/) { |a| "_"+a.downcase }
    under = under [1, 255] if under[0, 1] == "_"
    return under
  end

  def Base.formatComment(comment)
    ret "#"+comment
  end

  def Base.verify(statement)
    return "begin\n" +
        " "*Base.options[:indent] + statement + "\n" +
        "rescue Exception=>e\n" +
        " "*Base.options[:indent] + "@verification_errors << e\n" +
        "end"
  end

  def Base.deb(msg)
    puts msg if @@options[:debug] == 1
  end

  def deb(msg)
    puts msg if @@options[:debug] == 1
  end
end


class Command < Base
  @command = ""
  @target = ""
  @value = ""
  @type = :command
  @negative = false
  @assertOrVerifyFailureOnNext = false

  def initialize(command = "", target ="", value = "", type = :command, negative = false)
    @command = command
    @target = target
    @value = value
    @type = type
    @negative = negative
    @assertOrVerifyFailureOnNext = false
  end

  def getDefinition
    commandName = @command.gsub(/AndWait$/, '')
    api = API.load_api

    r = commandName.scan(/^(assert|verify|store|waitFor)(.*)$/)
    if r.size > 0
      suffix = r[0][1]
      prefix = ""
      if (r = suffix.scan(/^(.*)NotPresent$/)).size > 0
        suffix = r[0][0] + "Present";
        prefix = "!"
      else
        if (r = suffix.scan(/^(.*)Not$/)).size > 0
          suffix = r[0][0];
          prefix = "!"
        end
      end
      booleanAccessor = api[prefix + "is" + suffix];
      if (booleanAccessor)
        return booleanAccessor;
      end

      accessor = api[prefix + "get" + suffix];
      if (accessor)
        return accessor;
      end
    end
    return api[commandName]
  end

  def sanitize_value_old(string)
    string = string.to_s.gsub("\"", "'")
    string = string.to_s.inspect.to_s.gsub("\\", "\\\\").gsub("\"", "")
    string
  end

  def sanitize_value(string)
    string = string.to_s.inspect.to_s.gsub("\\", "\\\\")[1..-1][0..-2]
    string = string.to_s.gsub("\"", "\\\"")
    string = string.to_s.gsub("&quot;", "\\\"").gsub("&gt;", ">").gsub("&lt;", "<").gsub("&amp;", "&")
    string
  end

  def sanitize_for_regexp(string)
    # old version
    #    string = string.gsub("[", "\\[").gsub("]", "\\]")
    #    string = string.gsub("(s", "\\(").gsub(")", "\\)")
    #    string = string.gsub("^", "\\^").gsub("$", "\\$").gsub(".", "\\.").gsub("|", "\\|").gsub("?", "\\?").gsub("+", "\\+").gsub("&gt;", ">").gsub("/", "\\/")
    #    string = string.to_s.gsub("*", ".*")
    #    string = string[1..-1][0..-2]

    replaces = {"[" => "\\[", "]" => "\\]",
                "(" => "\\(", ")" => "\\)",
                "^" => "\\^", "$" => "\\$", "." => "\\.", "|" => "\\|",
                "?" => "\\?", "+" => "\\+", "&gt;" => ">", "\/" => "\\/"}

    string = string.gsub_by_array(replaces).gsub("*", ".*")[1..-1][0..-2]
    string = "/^[\\s\\S]{0,1}#{string}$/"
    string
  end

  def extract_variables(string)
    string = "\"" + string.to_s + "\""
    string.scan(/\$\{.*?\}/).each { |occurance|
      string.sub!(occurance, "\" + "+occurance[2, occurance.size - 3] + " + \"")
    }
    string.gsub(" + \"\"", "").gsub("\"\" + ", "")
  end

  def format_command
    if @value =~ /^regexp:/
      @value = "/#{@value.sub("regexp:", "")}/"
    else
      @value = extract_variables(sanitize_value(@value))
    end

    if @target =~ /^regexp:/
      @target = "/#{@target.sub("regexp:", "")}/"
    else
      @target = extract_variables(sanitize_value(@target))
    end

    line = Base.options[:receiver]+"."
    case @command
      when "pause"
        line = "sleep #{@target.to_i/1000}"
      when "open"
        line += "open #{@target}"
      when "goBack"
        line = "@selenium.go_back"
      when "type"
        line += "type #{@target}, #{@value}"
      when "typeKeys"
        line += "type_keys #{@target}, #{@value}"
      when "click"
        line += "click #{@target}"
      when "clickAt"
        line += "click_at #{@target}, #{@value}"
      when "dragAndDropToObject"
        line += "drag_and_drop_to_object #{@target}, #{@value}"
      when "waitForPageToLoad"
        line += "wait_for_page_to_load #{@target}"
      when "select"
        line += "select #{@target}, #{@value}"
      when "selectWindow"
        line += "select_window #{@target}"
      when "selectFrame"
        line += "select_frame #{@target}"
      when "mouseOver"
        line += "mouse_over #{@target}"
      when "mouseOut"
        line += "mouse_out #{@target}"
      when "keyUp"
        line += "key_up #{@target}, #{@value}"
      when "chooseCancelOnNextConfirmation"
        line += "choose_cancel_on_next_confirmation"
      when "verifyAlertPresent"
        line = "begin\n    assert @selenium.is_alert_present\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyAlertNotPresent"
        line = "begin\n    assert !@selenium.is_alert_present\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyTable"
        line = "begin\n    assert_equal #{@value}, @selenium.get_table(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyNotTable"
        line = "begin\n    assert_equal #{@value}, !@selenium.get_table(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyText"
        line ="begin\n    assert_equal #{@value}, @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target}) \nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyTextPresent"
        line ="begin\n     assert @selenium.is_text_present(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyTextNotPresent"
        line = "begin\n    assert !@selenium.is_text_present(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "assertText"
        line = "assert_equal #{@value}, @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target}) "
      when "assertTable"
        line = "assert_equal #{@value}, @selenium.get_table(#{@target})"
      when "assertValue"
        line = "assert_equal #{@value}, @selenium.get_value(#{@target})"
      when "assertConfirmation"
        line = "assert_equal #{@target}, @selenium.get_confirmation"
      when "verifyElementPresent"
        line = "begin\n    assert @selenium.is_element_present(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyElementNotPresent"
        line = "begin\n    assert !@selenium.is_element_present(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyValue"
        line = "begin\n    assert_equal #{@value}, @selenium.get_value(#{@target}).respond_to?(:force_encoding) ? @selenium.get_value(#{@target}).force_encoding('UTF-8') : @selenium.get_value(#{@target}) \nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifySelectOptions"
        line = "begin\n    assert #{sanitize_for_regexp(@value)} =~ @selenium.get_select_options(#{@target}).join(\",\")\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyNotSelectOptions"
        line = "begin\n    assert_not_equal #{@value}, @selenium.get_select_options(#{@target}).join(\",\")\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "assertChecked"
        line = "assert @selenium.is_checked(#{@target})"
      when "waitForElementPresent"
        line = "assert !60.times{ break if (@selenium.is_element_present(#{@target}) rescue false); sleep 1 }"
      when "waitForElementNotPresent"
        line = "assert !60.times{ break unless (@selenium.is_element_present(#{@target}) rescue false); sleep 1 }"
      when "openWindow"
        line += "open_window #{@target}, #{@value}"
      when "waitForPopUp"
        line += "wait_for_pop_up #{@target}, #{@value}"
      when "waitForValue"
        line = "assert !60.times{ break if (#{@value} == @selenium.get_value(#{@target}) rescue false); sleep 1 }"
      when "waitForTable"
        line = "assert !60.times{ break if (#{@value} == @selenium.get_table(#{@target}) rescue false); sleep 1 }"
      when "waitForText"
        line = "assert !60.times{ break if (#{sanitize_for_regexp(@value)} =~ @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target})  rescue false); sleep 1 }"
      when "waitForNotText"
        line = "assert !60.times{ break unless (#{sanitize_for_regexp(@value)} == @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target})  rescue false); sleep 1 }"
      when "waitForTextPresent"
        line = "assert !60.times{ break if (@selenium.is_text_present(#{@target}) rescue false); sleep 1 }"
      when "waitForTextNotPresent"
        line = "assert !60.times{ break unless (@selenium.is_text_present(#{@target}) rescue true); sleep 1 }"
      when "waitForSelectedLabel"
        line = "assert !60.times{ break if (#{@value} == @selenium.get_selected_label(#{@target}) rescue false); sleep 1 }"
      when "waitForSelectedValue"
        line = "assert !60.times{ break if (#{@value} == @selenium.get_selected_value(#{@target}) rescue false); sleep 1 }"
      when "waitForSelectedIndex"
        line = "assert !60.times{ break if (#{@value} == @selenium.get_selected_index(#{@target}) rescue false); sleep 1 }"
      when "waitForSelectOptions"
        line = "assert !60.times{ break if (#{sanitize_for_regexp(@value)} =~ @selenium.get_select_options(#{@target}).join(\",\") rescue false); sleep 1 }"
      when "waitForSomethingSelected"
        line = "assert !60.times{ break if (@selenium.is_something_selected(#{@target}) rescue false); sleep 1 }"
      when "waitForEditable"
        line = "assert !60.times{ break if (@selenium.is_editable(#{@target}) rescue false); sleep 1 }"
      when "waitForNotEditable"
        line = "assert !60.times{ break unless (@selenium.is_editable(#{@target}) rescue true); sleep 1 }"
      when "waitForVisible"
        line = "assert !60.times{ break if (@selenium.is_visible(#{@target}) rescue false); sleep 1 }"
      when "waitForNotVisible"
        line = "assert !60.times{ break unless (@selenium.is_visible(#{@target}) rescue true); sleep 1 }"
      when "waitForChecked"
        line = "assert !60.times{ break if (@selenium.is_checked(#{@target}) rescue false); sleep 1 }"
      when "verifyNotValue"
        line = "begin\n    assert_not_equal #{@value}, @selenium.get_value(#{@target})\nrescue Exception=>e\n        @verification_errors << e\nend"
      when "verifyNotText"
        line = "begin\n    assert_not_equal #{@value}, @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target}) \nrescue Exception=>e\n    @verification_errors << e\nend"
      when "store"
        line = "#{@value} = #{@target}"
      when "storeSelectOptions"
        line = "#{@value.gsub(/\"/, "")} = @selenium.get_select_options(#{@target})"
      when "storeSelectedValue"
        line = "#{@value.gsub(/\"/, "")} = @selenium.get_selected_value(#{@target})"
      when "verifyExpression"
        target = @target.gsub(/[${}]/, "")
        line = "begin\n    assert_equal #{@value}, @selenium.get_expression(#{target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyVisible"
        line = "begin\n    assert @selenium.is_visible(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyNotVisible"
        line = "begin\n    assert !@selenium.is_visible(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyNotEditable"
        line = "begin\n    assert !@selenium.is_editable(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "uncheck"
        line += "uncheck #{@target}"
      when "check"
        line += "check #{@target}"
      when "fireEvent"
        line = "@selenium.fire_event #{@target}, #{@value}"
      when "focus"
        line = "@selenium.focus #{@target}"
      when "keyPress"
        line = "@selenium.key_press #{@target}, #{@value}"
      when "verifyEditable"
        line = "begin    \nassert @selenium.is_editable(#{@target})\nrescue Exception=>e    \n@verification_errors << e\nend"
      when "verifyNotChecked"
        line = "begin\n    assert !@selenium.is_checked(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifySelectedLabel"
        line = "begin\n    assert_equal #{@value}, @selenium.get_selected_label(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyNotSelectedLabel"
        line = "begin\n    assert_not_equal #{@value}, @selenium.get_selected_label(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifySelectedValue"
        line = "begin\n    assert_equal #{@value}, @selenium.get_selected_value(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "verifyCursorPosition"
        line = "begin\n    assert_equal #{@value}, @selenium.get_cursor_position(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "assertNotChecked"
        line = "assert !@selenium.is_checked(#{@target})"
      when "verifyChecked"
        line = "begin\n    assert @selenium.is_checked(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "assertElementPresent"
        line = "assert @selenium.is_element_present(#{@target})"
      when "assertElementNotPresent"
        line = "assert !@selenium.is_element_present(#{@target})"
      when "storeText"
        line = "#{@value.gsub(/\"/, "")} = @selenium.get_text(#{@target}).respond_to?(:force_encoding) ? @selenium.get_text(#{@target}).force_encoding('UTF-8') : @selenium.get_text(#{@target}) "
      when "storeValue"
        line = "#{@value.gsub(/\"/, "")} = @selenium.get_value(#{@target})"
      when "verifyNotExpression"
        line = "begin\n    assert_not_equal #{@value}, @selenium.get_expression(#{@target})\nrescue Exception=>e\n    @verification_errors << e\nend"
      when "getEval"
        line = "@selenium.get_eval(#{@target})"
      when "dragAndDrop"
        line = "@selenium.drag_and_drop #{@target}, #{@value}"
      when "storeElementPositionLeft"
        line = "I_position = @selenium.get_element_position_left(#{@target})"
      when "waitForElementPositionLeft"
        line = "assert !60.times{ break if (I_position == @selenium.get_element_position_left(#{@target}) rescue false); sleep 1 }"
      when "verifySelected"
        line = "begin\n    assert_equal #{@value}, @selenium.get_selected_label(#{@target})\n    rescue Test::Unit::AssertionFailedError\n    @verification_errors << $!\n    end"
      when "waitForNotValue"
        line = "assert !60.times{ break unless (#{@value} == @selenium.get_value(#{@target}) rescue true); sleep 1 }"
      when 'close'
        line = "@selenium.select_window #{@target}"
      when "assertAlert"
        line = "assert_equal #{@target}, @selenium.get_alert"
      when "answerOnNextPrompt"
        line = "@selenium.answer_on_next_prompt #{@target}"
      when "assertPromptPresent"
        line = "assert @selenium.is_prompt_present"
      when "refresh"
        line = "@selenium.refresh"
      else
        line = "flunk \"Unknown command #{@command}(#{@target}, #{@value})\""
        puts line
    end

    # example: assert /^Are you sure[\s\S]$/ =~ @selenium.get_confirmation
    if @command == "assertConfirmation" and @target[-1, 1] == '?'
      line = "assert /^#{@target[0..-2]}[\\s\\S]$/ =~ @selenium.get_confirmation"
    end

    return line
  end


  def waitForTrue(expression)
    return "assert !60.times{ break if (" + expression.to_s + " rescue false); sleep 1 }"
  end

  def waitForFalse(expression)
    return "assert !60.times{ break unless (" + expression.invert.to_s + " rescue true); sleep 1 }"
  end

  def verifyTrue(statement)
    return Base.verify(assertTrue(statement))
  end

  def verifyFalse(statement)
    return Base.verify(assertFalse(statement))
  end

  def assertTrue(expression)
    return "assert " + expression.to_s
  end

  def assertFalse(expression)
    return "assert " + expression.invert.to_s
  end

  def invert
    if @negative == true
      @negative == false
    else
      @negative == true
    end
    self
  end

end

class Converter < Base

  def Converter.convert(file_name)
    file = File.new(file_name, "r")
    output_name = file_name.gsub(".case", ".rb")
    output = File.new(output_name, "w")

    doc = REXML::Document.new(file)
    #puts doc
    test_name = doc.elements["/html/head/title"][0].to_s.gsub(/[^a-zA-Z0-9_]/, "")
    output.puts(Base.options[:header].gsub("${baseURL}", Base.options[:host]).gsub("${test_name}", test_name))

    doc.elements.each("html/body/table/tbody/tr") { |element|
      if element.to_s.delete('<tr>
        <td></td>
        <td></td>
        <td></td>
</tr>').to_s != ''
        if  Converter.convert_element(element).size.to_i > 0
          Converter.convert_element(element).each { |com_line|
            output.puts " "*Base.options[:initialIdents] + com_line
          }
        end
      end
    }
    output.puts(Base.options[:footer])
    puts output_name
  end


  def Converter.convert_element(element)
    #puts element
    if !element or element.to_s.length == 0
      return ""
    end
    a = element.elements.to_a
    ret = ""
    method = Converter.clear_tags(a[0].to_s.strip)
    e1 = Converter.clear_tags(a[1].to_s.strip)
    e2 = Converter.clear_tags(a[2].to_s.strip)
    return "" if method.length == 0
    #puts method.scan(/AndWait$/)
    if method.scan(/AndWait$/).size > 0
      method = method.gsub(/AndWait$/, "")
      ret += Command.new("waitForPageToLoad", Base.options[:global_timeout]).format_command+"\n"
    end
    ret = [Command.new(method, e1, e2).format_command+"\n" + ret]
    #puts ret
    return ret
  end

  def Converter.verify(statement)
    return "begin\n" +
        " "*Base.options[:indent] + statement + "\n" +
        "rescue Exception=>e\n" +
        " "*Base.options[:indent] + "@verification_errors << e\n" +
        "end"
  end

  def Converter.clear_tags(text)
    text.gsub(/<td>|<\/td>|<td\/>/, "")
  end

end

ARGV.each_with_index do |a, i|
  if ((a == "-h" or a == "--host") and ARGV[i+1])
    Base.host = ARGV[i+1]
    ARGV.delete_at(i+1)
    ARGV.delete_at(i)
  end

  if ((a == "-t" or a == "--timeout") and ARGV[i+1])
    Base.timeout = ARGV[i+1]
    ARGV.delete_at(i+1)
    ARGV.delete_at(i)
  end
end

ARGV.each_with_index do |a, i|
  Converter.convert(a) if a and a != ""
end
