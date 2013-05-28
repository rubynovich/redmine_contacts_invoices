module RedmineContactsInvoices
  module Hooks
    class ViewsCustomFieldsHook < Redmine::Hook::ViewListener     
      render_on :view_custom_fields_form_invoice_custom_field, :partial => "invoices/custom_field_form" 
    end   
  end
end
