module ExpensesHelper
  include CustomFieldsHelper
  
  def expense_status_tag(expense)
    status_tag = content_tag(:span, expense_status_name(expense.status_id)) 
    content_tag(:span, status_tag, :class => "deal-status expense-status tags #{expense_status_name(expense.status_id, true).to_s}")
  end
  
  def expense_status_name(status, code=false)
    return (code ? "draft" : l(:label_expense_status_draft)) unless collection_expense_statuses.map{|v| v[1]}.include?(status)

    status_data = collection_expense_statuses.select{|s| s[1] == status }.first[0]
    status_name = collection_expense_status_names.select{|s| s[1] == status}.first[0]
    return (code ? status_name : status_data)
  end
  
  def expense_price(sum)
    [RedmineContactsInvoices.settings[:invoices_default_currency], invoice_price(sum)].join(" ") 
  end

  def collection_expense_status_names
    [[:draft, Expense::DRAFT_EXPENSE], 
     [:new, Expense::NEW_EXPENSE], 
     [:billed, Expense::BILLED_EXPENSE],
     [:paid, Expense::PAID_EXPENSE]]
  end

  def collection_expense_statuses
    [[l(:label_expense_status_draft), Expense::DRAFT_EXPENSE], 
     [l(:label_expense_status_new), Expense::NEW_EXPENSE], 
     [l(:label_expense_status_billed), Expense::BILLED_EXPENSE],
     [l(:label_expense_status_paid), Expense::PAID_EXPENSE]]
  end
  
  def collection_for_expense_status_for_select(status_id)
    collection = collection_expense_statuses.map{|s| [s[0], s[1].to_s]}
    collection.insert 0, [l(:label_open_issues), "o"]
    collection.insert 0, [l(:label_all), ""]
    
    options_for_select(collection, status_id)
    
  end
  
  def expenses_is_no_filters
    (params[:status_id] == 'o' && (params[:period].blank? || params[:period] == 'all') && params[:contact_id].blank?)
  end

  def expenses_to_csv(expenses)
    decimal_separator = l(:general_csv_decimal_separator)
    encoding = l(:general_csv_encoding)
    export = FCSV.generate(:col_sep => l(:general_csv_separator)) do |csv|
      # csv header fields
      headers = [ "#",
                  'Expense date',
                  'Price',
                  'Currency',
                  'Description',
                  'Contact',
                  'Status',
                  'Created',
                  'Updated'
                  ]
      custom_fields = ExpenseCustomField.all
      custom_fields.each {|f| headers << f.name}
      # Description in the last column
      csv << headers.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      # csv lines
      expenses.each do |expense|
        fields = [expense.id,
                  format_date(expense.expense_date),
                  expense.price,
                  RedmineContactsInvoices.settings[:invoices_default_currency] || '',
                  expense.description,
                  !expense.contact.blank? ? expense.contact.name : '',
                  expense.status,
                  format_date(expense.created_at),
                  format_date(expense.updated_at)
                  ]
        custom_fields.each {|f| fields << show_value(expense.custom_value_for(f)) }
        csv << fields.collect {|c| Redmine::CodesetUtil.from_utf8(c.to_s, encoding) }
      end
    end
    export
  end

end
