class AddCommentsCountToInvoices < ActiveRecord::Migration
  def change
    add_column :invoices, :comments_count, :integer 
  end
end
