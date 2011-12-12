require File.expand_path(File.dirname(__FILE__) +"/../../../spec/spec_helper.rb")

describe Ouroboros::Payment, ".format_policy" do

  before (:each) do
  end
  
  it "should return empty policy" do
    Ouroboros::Payment.format_policy().should eql([])
  end
  
  it "should return array of policies" do
    Ouroboros::Payment.format_policy(1,2,0,12).should eql(["amount_limit-100", "retry_count-2", "completion-0", "completion_over-1200"])
  end
end

describe Ouroboros::Payment, ".format_amount" do

  before(:each) do
  end
 
  it "should ser proper amount" do
    Ouroboros::Payment.format_amount(10, 3, 30).should eql(10.0)
    Ouroboros::Payment.format_amount(1, 3, 30).should eql(3.0)
    Ouroboros::Payment.format_amount(100, 3, 30).should eql(30.0)
  end
  
end




