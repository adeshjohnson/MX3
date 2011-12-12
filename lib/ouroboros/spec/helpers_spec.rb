require File.expand_path(File.dirname(__FILE__) +"/../../../spec/spec_helper.rb")

describe Ouroboros::Helpers, ".ouroboros_form_tag" do

  before (:each) do
  end
  
  it "should create form_tag" do
   ouroboros_form_tag.should eql("<form action=\"https://secure.ouroboros.hr/payment/auth.php\" method=\"post\">")
#   MorLog.my_debug(a)
  end
  
end

describe Ouroboros::Helpers, ".ouroboros_setup" do

  before(:each) do
    
  end
  it "should denny form if no needed data is delivered" do
    options = {:mch_code => "asasa"}
    ouroboros_setup(options).should eql("")
  end
  
  it "should should format form if all data is passed" do
    options = {:mch_code => "asasa", :amount => "1200", :secret_key => "Very_secret_key"}
    ouroboros_setup(options).length.should > 10
  end
  
end


