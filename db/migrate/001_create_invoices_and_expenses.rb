class CreateInvoicesAndExpenses < ActiveRecord::Migration
  def self.up
    create_table :invoices do |t|
      t.string :number
      t.datetime :invoice_date
      t.decimal :discount, :precision => 10, :scale => 2, :default => 0, :null => false
      t.integer :discount_type, :default => 0, :null => false
      t.text :description
      t.datetime :due_date
      t.string :language
      t.string :currency, :size => 3
      t.integer :status_id
      t.integer :contact_id
      t.integer :project_id
      t.integer :assigned_to_id
      t.integer :author_id
      t.timestamps
    end
    add_index :invoices, :contact_id 
    add_index :invoices, :project_id
    add_index :invoices, :status_id
    add_index :invoices, :assigned_to_id
    add_index :invoices, :author_id

    create_table :expenses do |t|
      t.date :expense_date
      t.decimal :price, :precision => 10, :scale => 2, :default => 0, :null => false
      t.text :description
      t.integer :contact_id
      t.integer :author_id
      t.integer :project_id
      t.integer :status_id
      t.timestamps
    end
    add_index :expenses, :contact_id 
    add_index :expenses, :project_id
    add_index :expenses, :status_id
    add_index :expenses, :author_id    
  end

  def self.down
    drop_table :invoices
  end
end
