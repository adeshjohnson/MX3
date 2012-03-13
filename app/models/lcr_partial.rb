# -*- encoding : utf-8 -*-
class LcrPartial < ActiveRecord::Base
  belongs_to :lcr
  # finds if such partial allready exists
  def duplicate_partials
    sql = "SELECT COUNT(*) as 'count' FROM lcr_partials WHERE main_lcr_id = '#{self.main_lcr_id}' AND prefix = '#{self.prefix}' AND user_id = #{self.user_id};"
    dup_partials = ActiveRecord::Base.connection.select_one(sql)
    dup_partials['count'].to_s.to_i
  end


  # checks for lower partial (which prefix starts as our original partial)
  def lower_partials
    LcrPartial.find_by_sql("SELECT * FROM lcr_partials WHERE main_lcr_id = '#{self.main_lcr_id}' AND user_id = #{self.user_id} AND prefix LIKE '#{self.prefix}%' AND LENGTH(prefix) > LENGTH('#{self.prefix}')")
  end

=begin
=end
  def self.clone_partials(lcr, original_lcr_id)
    query = "INSERT INTO lcr_partials (main_lcr_id, prefix, lcr_id, user_id)
             SELECT lcr_partials.main_lcr_id, lcr_partials.prefix, #{lcr.id}, #{lcr.user_id} 
             FROM   lcr_partials
             WHERE  lcr_partials.lcr_id = #{original_lcr_id}"
    ActiveRecord::Base.connection.execute(query)
  end

end
