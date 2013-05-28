
class InvoiceImport
  extend ActiveModel::Naming
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include CSVImportable

  attr_accessor :file, :project, :quotes_type

  def klass
    Invoice
  end

  def build_from_fcsv_row(row)
    ret = Hash[row.to_hash.map{ |k,v| [k.underscore.gsub(' ','_'), force_utf8(v)] }].delete_if{ |k,v| !klass.column_names.include?(k) }
    ret[:status_id] = klass::STATUSES.respond_to?(:key) ? klass::STATUSES.key(row['status']) : klass::STATUSES.index(row['status'])
    ret[:number] = row['#']
    ret[:invoice_date] = Date.parse(row['invoice date'])
    ret[:discount] = row['discount'].to_f
    ret
  end

end
