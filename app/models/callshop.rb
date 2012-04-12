# -*- encoding : utf-8 -*-
class Callshop < ActiveRecord::Base
  include UniversalHelpers
  set_table_name "groups"

  has_many :invoices, :class_name => "CsInvoice"
  has_many :unpaid_invoices, :class_name => "CsInvoice", :conditions => {:paid => false}
  has_many :users, :through => "usergroups", :foreign_key => "group_id", :order => "usergroups.position asc" # should be has many through :
  belongs_to :user, :through => "usergroups", :foreign_key => "group_id", :order => "usergroups.position asc"
  has_many :usergroups, :foreign_key => "group_id"

  def free_booths_count
    # all users in callshop - unpaid (reserved or occupied) booths
    users.size - invoices.count(:conditions => ["paid_at IS NULL"])
  end

  def status
    calls = 0
    return {
        :free_booths => free_booths_count,
        :booths => users.inject([]) { |booths, user|
          created_at = (user.cs_invoices.first.try(:created_at)) ? user.cs_invoices.first.created_at.strftime("%Y-%m-%d %H:%M:%S") : nil
          booth = {:id => user.id, :element => nil, :state => user.booth_status, :number => nil, :duration => nil, :country => nil, :user_rate => nil, :local_state => false, :comment => nil, :created_at => nil, :balance => nil, :timestamp => nil}

          case booth[:state]
            when "free" :
              booth
            when "reserved" :
              invoice = user.cs_invoices.first
              booth.merge!({
                               :comment => invoice.comment,
                               :created_at => created_at,
                               :balance => balance(user),
                               :timestamp => stamp(user),
                               :user_type => invoice.invoice_type,
                               :server => "",
                               :channel => ""
                           })
            when "occupied" :
              calls += 1
              active_call = user.activecalls.first
              invoice = user.cs_invoices.first
              destination = active_call.try(:destination)


              booth.merge!(
                  {:comment => invoice.comment,
                   :created_at => created_at,
                   :balance => balance(user),
                   :country => destination.try(:direction).try(:name),
                   :number => active_call.try(:dst),
                   :channel => active_call.try(:channel),
                   :user_type => invoice.invoice_type,
                   :server => active_call.try(:server_id),
                   :user_rate => active_call.try(:user_rate),
                   :duration => nice_time(active_call.try(:duration)),
                   :timestamp => stamp(user)
                  }
              )
          end

          booths.push(booth)
        },
        :active_calls => calls
    }
  end

  private

  def stamp(booth)
    stamps = []
    if booth.cs_invoices.any?
      invoice = booth.cs_invoices.first
      calls = booth.activecalls_since(invoice.created_at)
      if calls.size > 0
        stamps.push(calls[0].start_time.to_i)
      end
      stamps.push(invoice.updated_at.to_i)
    else
      nil
    end
    stamps.max
  end

  def balance(booth)
    if booth.cs_invoices.any?
      invoice = booth.cs_invoices.first
      if invoice.postpaid?
        -1 * invoice.call_price
      else # prepaid
        invoice.balance - invoice.call_price
      end
    else
      nil
    end
  end

end
