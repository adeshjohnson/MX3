require File.dirname(__FILE__) + '/../../../test/test_helper'
require 'payments_controller'

class PaymentsControllerTest < Test::Unit::TestCase

  def setup
    @controller = PaymentsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def test_successful_payment
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :amount => "3.0")

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")
    Confline.expects(:get_value).with("PayPal_User_Pays_Transfer_Fee", 0).returns("0")
    Paypal::Notification.any_instance.expects(:pending_reason).returns("Completed")
    Paypal::Notification.any_instance.expects(:custom).returns("3.0")
    Paypal::Notification.any_instance.expects(:business).returns("hello@email.com")
    Confline.expects(:get_value).with("PayPal_Payment_Confirmation", 0).returns("none")

    # action!
    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "tax"=>"0.00",
      "receiver_email"=>"hello@email.com",
      "payment_gross"=>"3.00",
      "transaction_subject"=>"3.0",
      "receiver_id"=>"M66NKFPNTM6EN",
      "quantity"=>"1",
      "business"=>"hello@email.com",
      "action"=>"paypal_ipn",
      "mc_currency"=>"USD",
      "payment_fee"=>"0.39",
      "notify_version"=>"3.0",
      "shipping"=>"0.00",
      "item_name"=>"KolmiSoft balance update",
      "txn_id"=>"40S02951816987047",
      "verify_sign"=>"An5ns1Kso7MWUdW4ErQKJJJ4qi4-AXKFy3agXclPVVqJB9Ok4ZBw9v3A",
      "test_ipn"=>"1",
      "txn_type"=>"web_accept",
      "last_name"=>"User",
      "mc_fee"=>"0.39",
      "charset"=>"windows-1252",
      "payer_id"=>"9H4NLKPBSSTJ4",
      "mc_gross"=>"3.00",
      "controller"=>"payments",
      "payer_status"=>"unverified",
      "custom"=>"3.0",
      "handling_amount"=>"0.00",
      "residence_country"=>"US",
      "payer_email"=>"hello@email.com",
      "payment_date"=>"22:50:24 Jun 17, 2010 PDT",
      "protection_eligibility"=>"Ineligible",
      "item_number"=>payment.id,
      "payment_type"=>"instant",
      "first_name"=>"Test" }

    user.reload

    assert_equal payment.completed, 1
    assert_equal user.balance, 3.0
    assert_equal payment.pending_reason, 'Completed'
    assert_response :success
  end

 def test_all_payments_require_confirmation
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :amount => "3.0")

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")
    #Confline.expects(:get_value).with("PayPal_User_Pays_Transfer_Fee", 0).returns("0")
    Paypal::Notification.any_instance.expects(:pending_reason).returns("Completed")
    Paypal::Notification.any_instance.expects(:custom).returns("3.0")
    Paypal::Notification.any_instance.expects(:business).returns("hello@email.com")
    Confline.expects(:get_value).with("PayPal_Payment_Confirmation", 0).returns("all")

    # action!
    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "tax"=>"0.00",
      "receiver_email"=>"hello@email.com",
      "payment_gross"=>"3.00",
      "transaction_subject"=>"3.0",
      "receiver_id"=>"M66NKFPNTM6EN",
      "quantity"=>"1",
      "business"=>"hello@email.com",
      "action"=>"paypal_ipn",
      "mc_currency"=>"USD",
      "payment_fee"=>"0.39",
      "notify_version"=>"3.0",
      "shipping"=>"0.00",
      "item_name"=>"KolmiSoft balance update",
      "txn_id"=>"40S02951816987047",
      "verify_sign"=>"An5ns1Kso7MWUdW4ErQKJJJ4qi4-AXKFy3agXclPVVqJB9Ok4ZBw9v3A",
      "test_ipn"=>"1",
      "txn_type"=>"web_accept",
      "last_name"=>"User",
      "mc_fee"=>"0.39",
      "charset"=>"windows-1252",
      "payer_id"=>"9H4NLKPBSSTJ4",
      "mc_gross"=>"3.00",
      "controller"=>"payments",
      "payer_status"=>"unverified",
      "custom"=>"3.0",
      "handling_amount"=>"0.00",
      "residence_country"=>"US",
      "payer_email"=>"hello@email.com",
      "payment_date"=>"22:50:24 Jun 17, 2010 PDT",
      "protection_eligibility"=>"Ineligible",
      "item_number"=>payment.id,
      "payment_type"=>"instant",
      "first_name"=>"Test" }

    user.reload

    assert_equal payment.completed, 0
    assert_equal user.balance, 0.0
    assert_equal payment.pending_reason, 'Waiting for confirmation'
    assert_response :success
 end

 def test_suspicious_payments_require_confirmation
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :amount => "3.0")

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")
    #Confline.expects(:get_value).with("PayPal_User_Pays_Transfer_Fee", 0).returns("0")
    Paypal::Notification.any_instance.expects(:pending_reason).returns("Completed")
    Paypal::Notification.any_instance.expects(:custom).returns("3.0")
    Paypal::Notification.any_instance.expects(:business).returns("hello@email.com")
    Confline.expects(:get_value).with("PayPal_Payment_Confirmation", 0).returns("suspicious")

    # action!
    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "tax"=>"0.00",
      "receiver_email"=>"hello@email.com",
      "payment_gross"=>"3.00",
      "transaction_subject"=>"3.0",
      "receiver_id"=>"M66NKFPNTM6EN",
      "quantity"=>"1",
      "business"=>"hello@email.com",
      "action"=>"paypal_ipn",
      "mc_currency"=>"USD",
      "payment_fee"=>"0.39",
      "notify_version"=>"3.0",
      "shipping"=>"0.00",
      "item_name"=>"KolmiSoft balance update",
      "txn_id"=>"40S02951816987047",
      "verify_sign"=>"An5ns1Kso7MWUdW4ErQKJJJ4qi4-AXKFy3agXclPVVqJB9Ok4ZBw9v3A",
      "test_ipn"=>"1",
      "txn_type"=>"web_accept",
      "last_name"=>"User",
      "mc_fee"=>"0.39",
      "charset"=>"windows-1252",
      "payer_id"=>"9H4NLKPBSSTJ4",
      "mc_gross"=>"3.00",
      "controller"=>"payments",
      "payer_status"=>"unverified",
      "custom"=>"3.0",
      "handling_amount"=>"0.00",
      "residence_country"=>"US",
      "payer_email"=>"hello@email.com",
      "payment_date"=>"22:50:24 Jun 17, 2010 PDT",
      "protection_eligibility"=>"Ineligible",
      "item_number"=>payment.id,
      "payment_type"=>"instant",
      "first_name"=>"Test" }

    user.reload

    assert_equal payment.completed, 0
    assert_equal user.balance, 0.0
    assert_equal payment.pending_reason, 'Waiting for confirmation'
    assert_response :success
 end

 def test_unsuccessful_payment_no_params
    post :paypal_ipn
    assert_equal 'Don\'t be so smart...', flash[:notice]
    assert_redirected_to :controller => "callc", :action => "main"
  end

  def test_payment_not_found
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :amount => "3.0")

    # action!
    actions = Action.count

    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "item_number"=>"999",
    }

    assert_operator Action.count, :>, actions
    assert_equal Action.find(:first, :order => "id desc").action, "hacking_attempt" # Action.last :|
    assert_equal payment.completed, 0
    assert_equal 'Don\'t be so smart...', flash[:notice]
    assert_redirected_to :controller => "callc", :action => "main"
  end

  def test_payment_has_no_user
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => nil, :currency => "USD", :amount => "3.0")

    # action!
    Payment.expects(:find).once.returns(payment) # use our stub payment
    # assert_difference does not work :(

    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "item_number"=>payment.id,
    }

    assert_equal 'Don\'t be so smart...', flash[:notice]
    assert_redirected_to :controller => "callc", :action => "main"
  end

  def test_payment_not_acknowledged
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :amount => "3.0")

    # action!
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(false) # everything is fine with payment :)
    # assert_difference does not work :(

    post :paypal_ipn, {
      "payment_status"=>"Completed",
      "item_number"=>payment.id,
    }

    assert_equal payment.completed, 0
    assert_response :success
  end

  def test_email_changed_in_html
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :pending_reason => "Unnotified", :amount => "3.0")

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")


    actions = Action.count

    # action!
    post :paypal_ipn, {
      "receiver_email"=>"hello@email.com",
      "business"=>"wrong@email_hack.com",
      "item_number"=>payment.id,
    }

    assert_operator Action.count, :>, actions
    assert_equal Action.find(:first, :order => "id desc").data =~ /hack attempt/i, 0
    assert_equal payment.completed, 0
    assert_equal payment.pending_reason, 'Unnotified'
    assert_response :success
  end

  def test_sum_changed_in_html
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)
    payment = Payment.create(:user_id => user.id, :currency => "USD", :pending_reason => "Unnotified", :amount => "3.0")

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.expects(:find).once.returns(payment) # use our stub payment
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")


    actions = Action.count

    # action!
    post :paypal_ipn, {
      "receiver_email"=>"hello@email.com",
      "business"=>"hello@email.com",
      "gross" => "1.0", # wrong!
      "item_number"=>payment.id,
    }

    assert_operator Action.count, :>, actions
    assert_equal Action.find(:first, :order => "id desc").data =~ /hack attempt/i, 0
    assert_equal payment.completed, 0
    assert_equal payment.pending_reason, 'Unnotified'
    assert_response :success
  end

  def test_reversed_payment
    # data
    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0, :balance => 33.46)
    payment = Payment.create(:user_id => user.id, :completed => 1, :currency => "USD", :amount => "33.46")

    balance = user.balance

    # mock mock mock
    Confline.expects(:get_value).with("PayPal_Enabled", 0).returns(1) # paypal is on
    Confline.expects(:get_value).with("PayPal_Test", 0).returns(0) # paypal is not in testing mode
    Payment.stubs(:find => payment)
    Paypal::Notification.any_instance.expects(:acknowledge).returns(true) # everything is fine with payment :)
    Confline.expects(:get_value).with("PayPal_Email", 0).returns("hello@email.com")
    Confline.expects(:get_value).with("PayPal_User_Pays_Transfer_Fee", 0).returns("0")
    Paypal::Notification.any_instance.expects(:custom).returns("33.46")
    Paypal::Notification.any_instance.expects(:business).returns("hello@email.com")

    post :paypal_ipn, {
      "payment_status"=>"Reversed",
      "handling_amount"=>"0.00",
      "receiver_id"=>"VX5EETRBRHKDL",
      "payer_email"=>"some@other.email",
      "protection_eligibility"=>"Ineligible",
      "business"=>"hello@email.com",
      "payment_gross"=>"",
      "residence_country"=>"GB",
      "reason_code"=>"other",
      "receiver_email"=>"hello@email.com",
      "verify_sign"=>"A0asK6oiIZmtBFrRCq-Iiqf8lrk.AMGQ39lO00UmbsVJ9WDIL4YCyxVz",
      "mc_currency"=>"USD",
      "transaction_subject"=>"35.0",
      "charset"=>"windows-1252",
      "parent_txn_id"=>"2A012561NN725251C",
      "txn_id"=>"90N44928DR486981A",
      "item_name"=>"balance update",
      "notify_version"=>"2.9",
      "payment_fee"=>"",
      "shipping"=>"0.00",
      "mc_fee"=>"-1.54",
      "payment_date"=>"16:43:36 Jun 16, 2010 PDT",
      "first_name"=>"Helen",
      "payment_type"=>"instant",
      "mc_gross"=>"-33.46",
      "payer_id"=>"FP58LXVN2W9PG",
      "last_name"=>"Logan",
      "custom"=>"35.0",
      "item_number" => payment.id
    }

    user.reload
    assert_equal payment.completed, 1
    assert_equal user.balance, 0.0
    assert_equal payment.pending_reason, 'Reversed'
    assert_response :success
  end

  def test_payment_confirmation_by_admin
    login

    user = User.create(:username => "eheyh", :password => "ohhoh", :last_name => "uph", :first_name => "uu", :owner_id => 0)

    orig_balance = user.balance

    payment = Payment.create({
      "tax" => "0", 
      "shipped_at" => nil, 
      "completed" => "0", 
      "paymenttype" => "paypal",
      "pending_reason" => "Waiting for confirmation", 
      "amount" => "5", 
      "card" => "0", 
      "owner_id" => "0", 
      "user_id" => "0", 
      "gross" => "5", 
      "fee" => "0.45", 
      "last_name" => "User",
      "user_id" => user.id,
      "currency" => "USD",
      "payer_email" => "payer@email.com",
      "email" => "seller@email.com"
    }) 

    post :confirm_payment, { :id => payment.id }

    user.reload

    assert_equal user.balance, orig_balance + 5.0
    assert_equal 'Payment was successfully confirmed', flash[:status]
  end

end
