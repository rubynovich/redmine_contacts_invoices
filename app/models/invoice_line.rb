class InvoiceLine < ActiveRecord::Base
  unloadable
  belongs_to :invoice
  
  validates_presence_of :description, :price, :quantity
  validates_uniqueness_of :description, :scope => :invoice_id
  validates_numericality_of :price, :quantity
  
  after_save :save_invoice_amount
  after_destroy :save_invoice_amount_destroy

  acts_as_list :scope => :invoice
  
  def total
    price.to_f * quantity.to_f
  end

  def tax_amount
    (tax.to_f / 100) * total.to_f
  end

  def price=(pr)
    super pr.to_s.gsub(/,/,'.')
  end

  def quantity=(q)
    super q.to_s.gsub(/,/,'.')
  end

  private

  def save_invoice_amount
    self.invoice.calculate_amount
    # self.invoice.save unless self.invoice.new_record?
  end

  def save_invoice_amount_destroy
    self.invoice.lines.delete(self)
    self.invoice.calculate_amount
    self.invoice.save unless self.invoice.new_record?
  end

end
