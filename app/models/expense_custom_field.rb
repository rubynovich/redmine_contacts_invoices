class ExpenseCustomField < CustomField
  unloadable
  
  def type_name
    :label_expense_plural
  end
end
