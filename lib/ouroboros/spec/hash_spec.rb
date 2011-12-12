require File.expand_path(File.dirname(__FILE__) +"/../../../spec/spec_helper.rb")
describe Ouroboros::Hash, ".reply_hash" do


  before(:each) do
 
  end  
 
  it "should genarate hash form data" do
    ha = Ouroboros::Hash.reply_hash({:tid => "123", :order_id => "az123", :card=> "American Express", :amount=> "1200"}, "key")
    ha.should eql("17e41ac1dedd03f8223b3fdf86208f93")
  end
end

describe Ouroboros, ".format_signature" do

  before(:each) do
    @hash = {
      :mch_code => "mechant", 
      :order_id => "123", 
      :amount => "1200", 
      :currency => "HRK",
      :payment_policy => "test_policy", 
      :secret_key => ""
    }
  end
  
  it "should format signature from data hash" do
    ha = Ouroboros::Hash.format_signature(@hash)
    ha.should eql("111e4dbb09413e336c2d2f7e822942b6")
  end
  
end
