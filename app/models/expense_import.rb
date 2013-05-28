class ExpenseImport
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include CSVImportable

  attr_accessor :file, :project, :quotes_type

  def build_from_fcsv_row(row)
    ret = Hash[row.to_hash.map{ |k,v| [k.underscore.gsub(' ','_'), force_utf8(v)] }].delete_if{ |k,v| !klass.column_names.include?(k) }
    ret[:expense_date] = Date.strptime( (row['expense_date'] || row['expense date']), '%m/%d/%Y')
    ret
  end

  def klass
    Expense
  end
end
