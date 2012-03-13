# -*- encoding : utf-8 -*-
class SQLCache
  attr_accessor :header
  attr_accessor :table
  attr_accessor :treshold
  attr_accessor :values

  def to_s
    [super,
      "Table: #{@table}",
      "Header: #{@header}",
      "Treshold: #{@treshold}",
      "Values: #{@values.size}"].join("\n")
  end

  def initialize(table_name, header, treshold = 1000)
    @table = table_name.to_s
    @header = header.to_s

    @values = []
    @treshold = treshold
  end

  def add(new_values, bulk = false)
    case new_values.class.to_s
    when "String" then @values << new_values
    when "Array" then
      bulk ?  @values.concat(new_values) : @values << new_values.join(", ")
    end
    flush if @values.size > @treshold
  end

  def flush()
    if @values.size > 0
      ActiveRecord::Base.connection.insert("INSERT INTO #{@table} (#{@header}) VALUES (#{@values.join("), (")})")
    end
    @values = []
  end

end
