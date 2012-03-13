# -*- encoding : utf-8 -*-
module TerminatorsHelper
  def terminator_delete(term)
    if current_user.id.to_i == term.user_id.to_i
      link_to b_delete, { :action => :destroy, :id => term.id }, :confirm => _('Are_you_sure'), :method => :post, :id=> "delete_link_" + term.id.to_s
    else
      ""
    end
  end

  def terminator_edit(term)
    if current_user.id.to_i == term.user_id.to_i
      link_to b_edit, {:action => :edit, :id => term.id}, {:id => "edit_link_" + term.id.to_s}
    else
      ""
    end
  end
end
