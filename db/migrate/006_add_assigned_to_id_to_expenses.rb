class AddAssignedToIdToExpenses < ActiveRecord::Migration
  def change
    add_column :expenses, :assigned_to_id, :integer 
    add_index :expenses, :assigned_to_id
  end
end
