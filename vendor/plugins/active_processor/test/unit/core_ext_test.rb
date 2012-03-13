# -*- encoding : utf-8 -*-
require 'test/test_helper'
 
class HashTest < Test::Unit::TestCase

  context "A hash" do
    should "allow deep merging without replacing original" do
      h1 = { :a => { :b => {} } }
      h2 = { :a => { :b => :c } }
      assert_equal h1.deep_merge(h2), { :a => { :b => :c } }
      assert_equal h1, { :a => { :b => {} } }
    end

    should "allow deep merging and replace original" do
      h1 = { :a => { :b => {} } }
      h2 = { :a => { :b => :c } }
      assert_equal h1.deep_merge!(h2), { :a => { :b => :c } }
      assert_equal h1, { :a => { :b => :c } }
    end

    should "return all keys except specified ones" do
      hash = { :a => :b, :c => :d }
      other_hash = { :a => :b }
      assert_equal other_hash, hash.except(:c)
    end
  end

end
