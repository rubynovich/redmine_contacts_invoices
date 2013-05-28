require_dependency 'custom_fields_helper'

module RedmineContactsInvoices
  module Patches    

    module CustomFieldsHelperPatch
      def self.included(base) # :nodoc:
        base.send(:include, InstanceMethods)

        base.class_eval do
          alias_method_chain :custom_fields_tabs, :invoice_tab
        end
      end

      module InstanceMethods
        # Adds a rates tab to the user administration page
        def custom_fields_tabs_with_invoice_tab
          tabs = custom_fields_tabs_without_invoice_tab
          tabs << {:name => 'InvoiceCustomField', :partial => 'custom_fields/index', :label => :label_invoice_plural}
          tabs << {:name => 'ExpenseCustomField', :partial => 'custom_fields/index', :label => :label_expense_plural}
          return tabs
        end
      end
      
    end
    
  end
end

unless CustomFieldsHelper.included_modules.include?(RedmineContactsInvoices::Patches::CustomFieldsHelperPatch)
  CustomFieldsHelper.send(:include, RedmineContactsInvoices::Patches::CustomFieldsHelperPatch)
end
