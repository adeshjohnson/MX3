# -*- encoding : utf-8 -*-
class TaxTableFactory
  def effective_tax_tables_at(time)
    table = Google4R::Checkout::TaxTable.new(false)
    [ table ]
  end
end

